# Activation Funnel Fixes — Design

## Problem

72 registered users. Most show 0 trips, 0 friends, 0 comments (see admin User Management panel). Three drop-off points in the funnel:

1. Signup → user lands on an empty home screen with no clear next action → never creates a trip.
2. Trip created → left as a draft, never started (first location update never posted).
3. Trip started → kept Private → no comments/reactions/followers → nothing pulls the user back into the app.

Target audience for these signups: people who want to track their own trips (not just followers of the original Camino pilgrimage).

## Goals

- Reduce the signup → first-trip-created gap.
- Reduce the trip-created → trip-started gap.
- Give newly-created trips a path to social visibility so achievements/comments/reactions actually fire and create a reason to return.

## Non-goals

- No new backend systems. `TripPlan`, `PromotedTrip`, `Achievement`, and push notifications already exist in `wanderer-backend` — this design reuses them, it does not add new domain concepts.
- No referral/invite system, no re-onboarding wizard/tutorial, no new gamification mechanics. Revisit only if the fixes below don't move activation enough.

## Funnel Stage 1: Signup → First Trip Created

**Current:** home screen renders empty with no CTA when the user has 0 trips.

**Fix:**
- Home screen empty state: when `trips.isEmpty`, replace the blank list with a single prominent CTA — "Start your first trip" — instead of an empty list widget or menu of equal-weight options.
- Move trip creation earlier: after email verification, route directly into trip-creation instead of dropping onto home. The first trip's name can be captured as the last step of onboarding, before the user ever sees an empty home screen.

**Touches:** `wanderer-frontend` only (home screen widget, post-verification routing). No backend change — `POST /api/1/trips` already supports this.

## Funnel Stage 2: Trip Created → Trip Started

**Current:** creating a trip means filling in visibility, modality, and settings before anything happens — a blank-form problem, not a missing-feature problem.

**Fix:**
- "Quick Start" entry point: one tap, uses current location, defaults to `Private` + `Simple` modality, skips the settings form entirely. Full settings remain editable later from trip detail.
- Surface existing `TripPlan` templates (e.g. "Walk to work", "Weekend hike") as a second entry point next to Quick Start, so the user picks a plan instead of facing a blank creation form.

**Touches:** `wanderer-frontend` only. `POST /api/1/trips` and `POST /api/1/trips/from-plan/{tripPlanId}` already support both paths — this is a UI entry-point change, not a new endpoint.

## Funnel Stage 3: Private Trip → Social Visibility

**Current:** default visibility and lack of an audience mean comments/reactions/achievements never get seen, so there's no pull back into the app.

**Fix:**
- Change default visibility on trip creation from `Private` to `Protected` (friends-only). `Private` becomes an explicit downgrade the user opts into, not the default.
- Immediately after first trip start, prompt "find people you know" using existing follow endpoints (`POST /api/1/users/follows`).
- Home screen for users with 0 trips (or generally, as a discovery feed) shows a "trending trips" feed sourced from the existing `GET /api/1/promoted-trips` / `GET /api/1/trips/public` — gives lurkers something to look at, and gives new trip-creators a reason to believe an audience exists.
- Trip detail screen shows a progress bar toward the user's next unlockable `Achievement` (data already available via `GET /api/1/users/me/achievements` and `GET /api/1/achievements`), and an existing push notification fires when a milestone is close.

**Touches:** `wanderer-frontend` (trip creation default, home feed, trip detail progress bar). `wanderer-backend`: only a default-value change to `TripVisibility` on trip creation (`wanderer-command`) — no schema or endpoint change. No new endpoints needed anywhere in this stage.

## Phasing / Priority

Ship in this order — each stage is independently shippable and independently measurable:

1. Stage 1 (empty-state CTA + routing) — cheapest, fixes the biggest-volume leak.
2. Stage 2 (Quick Start + templates surfaced) — removes the blank-form friction.
3. Stage 3 (default visibility, follow prompt, trending feed, achievement progress) — closes the loop that brings users back.

## Success Metrics

- % of new signups that create a trip within 24h.
- % of created trips that receive at least one `TripUpdate` (i.e. get "started").
- % of started trips that are `Protected`/`Public` rather than `Private`.
- 7-day return rate for users with at least one started trip.

## Risks / Open Questions

- Changing the default visibility to `Protected` affects users with zero friends yet (everything they post is effectively private anyway until they have a friend). Acceptable since it costs nothing and removes a manual step later.
- "Trending trips" home feed needs enough public/promoted trip volume to not look empty itself — with only 72 users this may need seeding (the project owner's own trip) until organic public trips exist.
