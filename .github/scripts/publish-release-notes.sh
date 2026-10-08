#!/usr/bin/env bash
# Writes the in-app "What's new" for a release and publishes it.
#
# Collects the PRs merged since the previous tag, has Claude turn them into notes for
# travellers (headline + New / Improved / Fixed items), and sends them to the backend's
# POST /releases/publish. Admins can still edit them afterwards in Admin › Release notes.
#
# Usage: publish-release-notes.sh VERSION
# Env: ANTHROPIC_API_KEY, RELEASE_CI_TOKEN, GH_TOKEN, PUBLISH_URL
#      DRY_RUN=1 prints the notes instead of publishing them.
set -euo pipefail

VERSION=$1
MODEL=claude-opus-5-5

# Release tags sit on CI commits off master, so take the next lower tag by version rather
# than walking history.
PREV_TAG=$(git tag -l 'v*' --sort=-v:refname | awk -v cur="v${VERSION}" 'seen {print; exit} $0 == cur {seen = 1}')
RANGE="${PREV_TAG:+${PREV_TAG}..}v${VERSION}"

# Squash-merge subjects end in "(#123)". Internal-only types are left out.
PRS=""
while IFS= read -r subject; do
  NUMBER=$(sed -nE 's/.*\(#([0-9]+)\)$/\1/p' <<< "$subject")
  [ -z "$NUMBER" ] && continue
  TYPE=$(sed -nE 's/^([a-zA-Z]+)(\([^)]*\))?!?: .*/\1/p' <<< "$subject" | tr 'A-Z' 'a-z')
  case "$TYPE" in ci|chore|docs|test|refactor|build|style) continue ;; esac
  BODY=$(gh pr view "$NUMBER" --json body -q .body 2>/dev/null | head -c 6000 || true)
  PRS+=$'\n\n'"### PR #${NUMBER}: ${subject}"$'\n'"${BODY}"
done < <(git log --pretty=format:%s "$RANGE")

if [ -z "$PRS" ]; then
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

REQUEST=$(jq -n --arg model "$MODEL" --arg guide "$GUIDE" \
  --arg prs "Version ${VERSION}. Pull requests since ${PREV_TAG:-the first release}:${PRS}" '{
  model: $model,
  max_tokens: 2000,
  system: $guide,
  tools: [{
    name: "release_notes",
    description: "The What'\''s new notes for this version.",
    input_schema: {
      type: "object",
      required: ["headline", "items"],
      properties: {
        headline: {type: "string", maxLength: 80},
        items: {type: "array", items: {
          type: "object",
          required: ["type", "title", "text"],
          properties: {
            type: {type: "string", enum: ["NEW", "IMPROVED", "FIXED"]},
            title: {type: "string", maxLength: 80},
            text: {type: "string", maxLength: 300}
          }
        }}
      }
    }
  }],
  tool_choice: {type: "tool", name: "release_notes"},
  messages: [{role: "user", content: $prs}]
}')

NOTES=$(curl -sS --fail-with-body https://api.anthropic.com/v1/messages \
    -H "x-api-key: ${ANTHROPIC_API_KEY}" -H 'anthropic-version: 2023-06-01' \
    -H 'content-type: application/json' --data "$REQUEST" \
  | jq -c --arg v "$VERSION" '.content[] | select(.type == "tool_use") | .input + {version: $v}')

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
