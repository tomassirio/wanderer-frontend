#!/usr/bin/env bash
# Writes the in-app "What's new" for a release and publishes it.
#
# Collects the PRs merged since the previous tag and sends the backend's
# POST /releases/publish a headline plus New / Improved / Fixed items for travellers:
# - a PR's own "## Release notes" block is used word for word, e.g.
#     ## Release notes
#     New — Save trips for later
#     Not ready to go? Save your trip as a plan and come back to it whenever you're ready.
# - every other PR is written up by Gemini (free tier), which also writes the headline.
#   Without GEMINI_API_KEY only the blocks are published, headed by the first one's title.
# Admins can still edit the notes afterwards in Admin › Release notes.
#
# Usage: publish-release-notes.sh VERSION
# Env: GH_TOKEN (pull-requests:read), RELEASE_CI_TOKEN, PUBLISH_URL,
#      GEMINI_API_KEY (optional), GEMINI_MODEL (optional: free-tier models to try in order)
#      FROM_TAG (optional) to cover more than the previous release, e.g. v2.0.5
#      DRY_RUN=1 prints the notes instead of publishing them.
set -euo pipefail

VERSION=$1
MODELS=${GEMINI_MODEL:-gemini-flash-latest gemini-flash-lite-latest}

# Release tags sit on CI commits off master, so take the next lower tag by version rather
# than walking history.
PREV_TAG=${FROM_TAG:-}
[ -n "$PREV_TAG" ] || PREV_TAG=$(git tag -l 'v*' --sort=-v:refname | awk -v cur="v${VERSION}" 'seen {print; exit} $0 == cur {seen = 1}')
RANGE="${PREV_TAG:+${PREV_TAG}..}v${VERSION}"

# "New — Title" / next line as text, from a PR body's "## Release notes" section.
release_notes_block() {
  awk '
    /^##[^#]/ { inside = tolower($0) ~ /^## *release notes/; next }
    !inside { next }
    { sub(/\r$/, ""); sub(/^[[:space:]]*[-*][[:space:]]*/, "") }
    # Skip HTML comments (the PR template instructions), even multi-line ones.
    /<!--/ { comment = 1 }
    comment { if (/-->/) comment = 0; next }
    /^[[:space:]]*$/ { next }
    title == "" && match(tolower($0), /^(new|improved|fixed)[[:space:]]*(—|–|-|:|·)[[:space:]]*/) {
      type = tolower($0) ~ /^new/ ? "NEW" : tolower($0) ~ /^improved/ ? "IMPROVED" : "FIXED"
      title = substr($0, RLENGTH + 1); next
    }
    title != "" { printf "%s\t%s\t%s\n", type, title, $0; title = "" }
  '
}

# Squash-merge subjects end in "(#123)". Internal-only types are left out.
PRS=""
WRITTEN='[]'
while IFS= read -r subject; do
  NUMBER=$(sed -nE 's/.*\(#([0-9]+)\)$/\1/p' <<< "$subject")
  [ -z "$NUMBER" ] && continue
  TYPE=$(sed -nE 's/^([a-zA-Z]+)(\([^)]*\))?!?: .*/\1/p' <<< "$subject" | tr 'A-Z' 'a-z')
  case "$TYPE" in ci|chore|docs|test|refactor|build|style) continue ;; esac
  BODY=$(gh pr view "$NUMBER" --json body -q .body 2>/dev/null || true)
  BLOCK=$(release_notes_block <<< "$BODY")
  if [ -n "$BLOCK" ]; then
    WRITTEN=$(jq -c --arg b "$BLOCK" '. + [$b | split("\n")[] | split("\t") | {type: .[0], title: .[1], text: .[2]}]' <<< "$WRITTEN")
  else
    # Keep the request small; the free tier limits tokens per minute.
    PRS+=$'\n\n'"### PR #${NUMBER}: ${subject}"$'\n'"$(head -c 3000 <<< "$BODY")"
  fi
done < <(git log --pretty=format:%s "$RANGE")
PRS=$(head -c 24000 <<< "$PRS")

if [ -z "$PRS" ] && [ "$WRITTEN" == '[]' ]; then
  echo "No user-facing PRs since ${PREV_TAG:-the start}; no release notes for ${VERSION}"
  exit 0
fi

read -r -d '' GUIDE <<'EOF' || true
You write the in-app "What's new" notes for Wanderer, an app where travellers plan, start and share trips (Android and web).

From the pull requests below, write notes for the people using the app, not developers:
- Only changes a traveller can notice. Leave out admin tools, CI, tests, refactors, dependency bumps, internal tooling and anything only developers would care about. Merge PRs that are one change for the user.
- Each item: type NEW, IMPROVED or FIXED; a short title (2 to 6 words, no trailing full stop); one or two plain sentences saying what the traveller can now do or what now works. Friendly, concrete, second person ("you"), no jargon, no PR numbers, no exclamation marks.
- Order: NEW first, then IMPROVED, then FIXED. Most noticeable first within each.
- Headline: up to 8 words naming the biggest change, like "A simpler way to start your trips".
- British English ("traveller").
- If nothing is noticeable to travellers, return an empty items list.

Example of the style:
NEW · A simpler way to start a trip: Tap Wander to set up and start your trip from one place.
NEW · Save trips for later: Not ready to go? Save your trip as a plan and come back to it whenever you're ready.
IMPROVED · Plans without a route: Create plans even when you don't know your route yet. You can decide where to go when you start.
FIXED · Achievement counts: Your profile now shows the correct number of unlocked achievements.
EOF

USER_MSG="Version ${VERSION}.
Items already written (do not repeat them, but take them into account for the headline):
$(jq -r '.[] | "\(.type) · \(.title): \(.text)"' <<< "$WRITTEN")

Pull requests to write up:${PRS:- none}"

if [ -z "${GEMINI_API_KEY:-}" ]; then
  if [ "$WRITTEN" == '[]' ]; then
    echo "::warning::No GEMINI_API_KEY and no Release notes blocks in the PRs; no release notes for ${VERSION}"
    exit 0
  fi
  [ -n "$PRS" ] && echo "::warning::No GEMINI_API_KEY: PRs without a Release notes block are left out"
  GENERATED=$(jq -c '{headline: .[0].title, items: []}' <<< "$WRITTEN")
else
  SCHEMA='{
    "type": "object", "required": ["headline", "items"],
    "properties": {
      "headline": {"type": "string"},
      "items": {"type": "array", "items": {
        "type": "object", "required": ["type", "title", "text"],
        "properties": {
          "type": {"type": "string", "enum": ["NEW", "IMPROVED", "FIXED"]},
          "title": {"type": "string"},
          "text": {"type": "string"}
        }
      }}
    }
  }'
  REQUEST=$(jq -n --arg guide "$GUIDE" --arg user "$USER_MSG" --argjson schema "$SCHEMA" '{
    temperature: 0.3,
    messages: [{role: "system", content: $guide}, {role: "user", content: $user}],
    response_format: {type: "json_schema", json_schema: {name: "release_notes", schema: $schema}}
  }')
  # Gemini's OpenAI-compatible endpoint. Free-tier models are often briefly busy (429/503),
  # so retry, then fall back to the next model.
  for MODEL in $MODELS; do
    for delay in 15 30 0; do
      CODE=$(jq --arg m "$MODEL" '. + {model: $m}' <<< "$REQUEST" | curl -sS -o gemini.json -w '%{http_code}' \
        https://generativelanguage.googleapis.com/v1beta/openai/chat/completions \
        -H "Authorization: Bearer ${GEMINI_API_KEY}" -H 'Content-Type: application/json' --data @-)
      case "$CODE" in 429|500|502|503|504) ;; *) break 2 ;; esac
      [ "$delay" -eq 0 ] && break
      echo "${MODEL} busy (HTTP ${CODE}), retrying in ${delay}s"
      sleep "$delay"
    done
    echo "${MODEL} unavailable, trying the next model"
  done
  RESPONSE=$(cat gemini.json)
  GENERATED=$(jq -ce '.choices[0].message.content | fromjson | select(.headline and .items)' <<< "$RESPONSE" 2>/dev/null) || {
    echo "::error::Unexpected Gemini response: $(head -c 500 <<< "$RESPONSE")"; exit 1; }
  echo "Written by ${MODEL}"
fi

# PR-written items first within each type; New, Improved, Fixed. Backend length limits apply.
NOTES=$(jq -c --arg v "$VERSION" --argjson written "$WRITTEN" '
  {NEW: 0, IMPROVED: 1, FIXED: 2} as $order
  | {version: $v,
     headline: (.headline[0:200]),
     items: ([$written[], .items[]] | to_entries
       | sort_by($order[.value.type], .key) | map(.value | .title |= .[0:200] | .text |= .[0:500]))}
' <<< "$GENERATED")

if [ "$(jq '.items | length' <<< "$NOTES")" -eq 0 ]; then
  echo "Nothing noticeable to travellers in ${VERSION}; no release notes"
  exit 0
fi
jq -r '"# \(.headline)", (.items[] | "\(.type) · \(.title): \(.text)")' <<< "$NOTES"

if [ "${DRY_RUN:-}" == "1" ]; then exit 0; fi

STATUS=$(curl -sS -o response.json -w '%{http_code}' -X POST "$PUBLISH_URL" \
  -H 'Content-Type: application/json' -H "X-Release-Token: ${RELEASE_CI_TOKEN}" --data "$NOTES")
case "$STATUS" in
  200) echo "✅ Published What's new for ${VERSION}" ;;
  409) echo "::notice::${VERSION} is already published; notes left alone (edit them in Admin › Release notes)" ;;
  *) cat response.json; echo; echo "::error::Publishing release notes failed with HTTP ${STATUS}"; exit 1 ;;
esac
