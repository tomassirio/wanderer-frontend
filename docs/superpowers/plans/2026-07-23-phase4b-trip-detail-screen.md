# Phase 4b (Batch E) Implementation Plan — Convert `trip_detail_screen.dart` to Riverpod DI

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert `trip_detail_screen.dart` — the largest and highest-risk file in the Phase 4b screen-conversion effort (3,151 lines, 83 `setState` calls, WebSocket event handling, comment/reaction logic) — to read its 5 dependencies from the Phase 4a Riverpod provider graph instead of constructing them directly. This is a single-file batch, isolated on its own given the file's size and risk, unlike prior batches which grouped 3 files together.

**Architecture:** Same conversion pattern as every prior batch. One field (`_repository`, a `TripDetailRepository`) is already `late final` and assigned at the very top of `initState()`. The other four (`_userService`, `_promotionQueryClient`, `_achievementService`, `_webSocketService`) are eager field-initializers that convert to `late final` + `initState()` assignment, joining `_repository`'s existing assignment block. Note `_promotionQueryClient` is a raw CQRS query client (not a service) — Phase 4a's `promotionQueryClientProvider` covers it directly.

**This task does NOT touch business logic.** `trip_detail_screen.dart`'s ~50+ methods (WebSocket event handlers, comment pagination, optimistic reaction updates, trip lifecycle actions) are completely out of scope — only the dependency-construction mechanism changes. Breaking up this file's business logic into notifiers is a separate, later phase (the original high-level plan's Phase 5).

## Global Constraints

- `flutter analyze` zero new warnings; `flutter test` stays green throughout. Baseline on this branch: **1383 tests passing**.
- No change to `TripDetailScreen`'s public constructor (`final Trip trip;` parameter stays exactly as-is).
- No behavior change — pure DI-wiring refactor. Not one line of business logic in this file changes.
- No test file references `TripDetailScreen` anywhere in the repository, direct or indirect (confirmed via `find test -iname "*trip_detail_screen*"` and `grep -rln "TripDetailScreen(" test/`, both empty) — no test updates are needed for this task.
- `lib/presentation/screens/trip_detail_screen_riverpod.dart` and `lib/presentation/state/trip_detail/*` (the abandoned earlier Riverpod migration attempt) are **out of scope** — do not touch them, do not reference them, do not try to reconcile this task's work with them. That reconciliation is a separate, later effort.

---

## Task 1: Convert `trip_detail_screen.dart`'s 5 dependencies

**Files:**
- Modify: `lib/presentation/screens/trip_detail_screen.dart`

**Interfaces:**
- Consumes: `tripDetailRepositoryProvider`, `userServiceProvider`, `promotionQueryClientProvider`, `achievementServiceProvider`, `websocketServiceProvider` (all from Phase 4a, `lib/core/providers/app_providers.dart`).

- [ ] **Step 1: Convert the widget class**

Add the imports:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wanderer_frontend/core/providers/app_providers.dart';
```

Change (currently `lib/presentation/screens/trip_detail_screen.dart:46-54` — find the exact class declaration; the `Trip trip` constructor parameter is preserved verbatim):

```dart
class TripDetailScreen extends StatefulWidget {
  final Trip trip;

  const TripDetailScreen({super.key, required this.trip});

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}
```

to:

```dart
class TripDetailScreen extends ConsumerStatefulWidget {
  final Trip trip;

  const TripDetailScreen({super.key, required this.trip});

  @override
  ConsumerState<TripDetailScreen> createState() => _TripDetailScreenState();
}
```

(Match the constructor's actual current parameter list exactly as found in the file — this shows the expected shape based on the field declaration at line 47; adjust only if the real constructor differs in a way that doesn't change its public signature, e.g. additional optional params also present.)

- [ ] **Step 2: Convert the State class and the 4 eager field-initializers**

Change (currently `lib/presentation/screens/trip_detail_screen.dart:55-60`):

```dart
class _TripDetailScreenState extends State<TripDetailScreen> {
  late final TripDetailRepository _repository;
  final UserService _userService = UserService();
  final PromotionQueryClient _promotionQueryClient = PromotionQueryClient();
  final AchievementService _achievementService = AchievementService();
  final WebSocketService _webSocketService = WebSocketService();
```

to:

```dart
class _TripDetailScreenState extends ConsumerState<TripDetailScreen> {
  late final TripDetailRepository _repository;
  late final UserService _userService;
  late final PromotionQueryClient _promotionQueryClient;
  late final AchievementService _achievementService;
  late final WebSocketService _webSocketService;
```

(`_repository`'s declaration was already `late final` — unchanged. The other 4 change from eager `final ... = X();` to `late final`.)

- [ ] **Step 3: Update `initState()` — add 4 new assignments alongside the existing one**

Change (currently `lib/presentation/screens/trip_detail_screen.dart:187-193`):

```dart
  @override
  void initState() {
    super.initState();

    // Initialize repository
    _repository = TripDetailRepository();

    _trip = widget.trip;
```

to:

```dart
  @override
  void initState() {
    super.initState();

    // Initialize repository and services
    _repository = ref.read(tripDetailRepositoryProvider);
    _userService = ref.read(userServiceProvider);
    _promotionQueryClient = ref.read(promotionQueryClientProvider);
    _achievementService = ref.read(achievementServiceProvider);
    _webSocketService = ref.read(websocketServiceProvider);

    _trip = widget.trip;
```

Everything else in `initState()` after `_trip = widget.trip;` (the login-status check, comment/promotion/achievement loading, WebSocket init, map position setup — through the closing `_initializeMapPosition();` call) is **completely unchanged**. Do not reorder, modify, or touch any line of it.

- [ ] **Step 4: Verify no other direct construction remains**

Run: `grep -n "TripDetailRepository()\|UserService()\|PromotionQueryClient()\|AchievementService()\|WebSocketService()" lib/presentation/screens/trip_detail_screen.dart`
Expected: no matches (all 5 were only ever constructed at the field/initState level converted above).

Run: `grep -n "import.*query/promotion_query_client" lib/presentation/screens/trip_detail_screen.dart` — this import (a direct `data/client/*` import from the presentation layer, flagged in the original codebase audit) stays in this task since `PromotionQueryClient` is still the field's type annotation; removing the *construction* doesn't remove the *type reference*. Do not attempt to remove this import.

- [ ] **Step 5: Run analyze + full suite**

Run: `flutter analyze`
Expected: clean, zero new warnings.

Run: `flutter test`
Expected: 1383 tests passing (unchanged — no test references this screen).

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/screens/trip_detail_screen.dart
git commit -m "refactor: convert TripDetailScreen to ConsumerStatefulWidget, read 5 dependencies via provider

TripDetailRepository, UserService, PromotionQueryClient,
AchievementService, and WebSocketService are now sourced from the
Phase 4a provider graph instead of being constructed directly. Pure
DI-wiring change - no business logic in this 3000+ line screen was
touched. No test file references this screen, so no test updates
were needed."
```

---

## Overall verification

- [ ] `flutter analyze` — clean, zero new warnings vs the 1383-test/clean-analyze baseline.
- [ ] `flutter test` — 1383 passing (unchanged — no test covers this screen).
- [ ] Manual smoke test: `flutter run` — open a trip's detail screen, verify the map loads, comments load and can be posted/reacted to, the timeline loads, WebSocket-driven live updates still arrive (e.g. post an update from another session/device and confirm it appears), trip lifecycle actions (pause/resume/finish) still work, achievements display correctly, and the promotion banner (if the trip is promoted) still shows. This is the single highest-value manual check in the whole Phase 4b effort given the file's size and the total absence of automated test coverage for it.
- [ ] `git log --oneline` shows the one commit for this task, independently revertable.
- [ ] Confirm scope discipline: `git diff --stat` shows only `lib/presentation/screens/trip_detail_screen.dart` changed, and the diff touches only the class declaration, field declarations, and the first ~5 lines of `initState()` — nothing else in this 3000+ line file should appear in the diff.
