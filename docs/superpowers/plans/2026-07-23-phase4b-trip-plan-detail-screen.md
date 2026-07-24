# Phase 4b (Batch I) Implementation Plan — Convert `trip_plan_detail_screen.dart` to Riverpod DI

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert `trip_plan_detail_screen.dart` (2,284 lines) — the second-largest and second-highest-risk file in the Phase 4b effort — to read its 4 dependencies from the Phase 4a Riverpod provider graph. This is a single-file batch, isolated given the file's size and one genuine behavioral subtlety it contains (see below).

**Architecture:** Same conversion pattern as every prior batch, plus one deliberate, reasoned exception that must be called out explicitly rather than applied silently.

## The one behavioral subtlety in this file — read carefully before starting

`_directionsClient` (a `GoogleDirectionsApiClient`) is currently constructed fresh by this screen in `initState()` and **disposed by this screen** in `dispose()` (`_directionsClient.dispose();`, which closes the client's internal `http.Client`). This was correct when each screen owned its own private instance.

However, `create_trip_plan_screen.dart` (Batch D of this effort) already converted its own `GoogleDirectionsApiClient` construction to `ref.read(googleDirectionsApiClientProvider)` — a `Provider` in Riverpod is cached for the lifetime of the root `ProviderScope` (the whole app session), not per-screen. If this screen also switches to the same provider **and keeps calling `.dispose()` on it**, closing the shared `http.Client` when this screen closes would break the instance for any other screen still relying on it (including `create_trip_plan_screen.dart`, or this same screen if the user navigates back into it later in the same session).

**Resolution for this task:** convert `_directionsClient` to `ref.read(googleDirectionsApiClientProvider)`, **and remove the `_directionsClient.dispose();` line from this screen's `dispose()` method.** This is a deliberate, explicit behavior change (not an oversight) — once the client is shared app-wide via the provider, no single screen should close its underlying `http.Client`. This matches the existing codebase convention already established elsewhere: `ApiClient`'s own `http.Client` is never explicitly disposed by any screen either — shared, provider-scoped resources in this app live for the app's lifetime, they aren't disposed by individual consumers.

## Global Constraints

- `flutter analyze` zero new warnings; `flutter test` stays green throughout. Baseline on this branch: **1383 tests passing**.
- No change to `TripPlanDetailScreen`'s public constructor (`final TripPlan tripPlan;` parameter stays exactly as-is).
- No behavior change **except** the one explicitly-reasoned exception above (removing the `_directionsClient.dispose()` call). Every other line of this file's business logic (map rendering, route editing, waypoint placement, etc.) stays untouched.
- A test file exists for this screen: `test/widgets/trip_plan_detail_screen_test.dart` — check it during this task, it may need `ProviderScope` wrapping.

---

## Task 1: Convert `trip_plan_detail_screen.dart`'s 4 dependencies

**Files:**
- Modify: `lib/presentation/screens/trip_plan_detail_screen.dart`
- Test: `test/widgets/trip_plan_detail_screen_test.dart` (confirmed to exist — check whether it needs `ProviderScope`)

**Interfaces:**
- Consumes: `tripPlanServiceProvider`, `tripServiceProvider`, `homeRepositoryProvider`, `googleDirectionsApiClientProvider` (all from Phase 4a, `lib/core/providers/app_providers.dart`).

- [ ] **Step 1: Check the existing test file's current state**

Read `test/widgets/trip_plan_detail_screen_test.dart` to see whether it wraps `TripPlanDetailScreen` in `ProviderScope` already, or only in `MaterialApp`.

- [ ] **Step 2: Convert the widget class**

Add the imports:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wanderer_frontend/core/providers/app_providers.dart';
```

Change (currently `lib/presentation/screens/trip_plan_detail_screen.dart:32-39`):

```dart
class TripPlanDetailScreen extends StatefulWidget {
  final TripPlan tripPlan;

  const TripPlanDetailScreen({super.key, required this.tripPlan});

  @override
  State<TripPlanDetailScreen> createState() => _TripPlanDetailScreenState();
}
```

to:

```dart
class TripPlanDetailScreen extends ConsumerStatefulWidget {
  final TripPlan tripPlan;

  const TripPlanDetailScreen({super.key, required this.tripPlan});

  @override
  ConsumerState<TripPlanDetailScreen> createState() =>
      _TripPlanDetailScreenState();
}
```

- [ ] **Step 3: Convert the State class and the 3 eager field-initializers**

Change (currently `:41-45` — `_directionsClient`'s declaration was already `late final`, unchanged in this step):

```dart
class _TripPlanDetailScreenState extends State<TripPlanDetailScreen> {
  final TripPlanService _tripPlanService = TripPlanService();
  final TripService _tripService = TripService();
  final HomeRepository _homeRepository = HomeRepository();
  late final GoogleDirectionsApiClient _directionsClient;
```

to:

```dart
class _TripPlanDetailScreenState extends ConsumerState<TripPlanDetailScreen> {
  late final TripPlanService _tripPlanService;
  late final TripService _tripService;
  late final HomeRepository _homeRepository;
  late final GoogleDirectionsApiClient _directionsClient;
```

- [ ] **Step 4: Update `initState()` — add 3 new assignments, convert the 4th**

Change (currently `:98-111`):

```dart
  @override
  void initState() {
    super.initState();
    _directionsClient =
        GoogleDirectionsApiClient(ApiEndpoints.googleMapsApiKey);
    _tripPlan = widget.tripPlan;
    _nameController = TextEditingController(text: _tripPlan.name);
    _selectedPlanType = _tripPlan.planType;
    _startDate = _tripPlan.startDate;
    _endDate = _tripPlan.endDate;
    _initEditLocations();
    _updateMapData();
    _loadUserInfo();
  }
```

to:

```dart
  @override
  void initState() {
    super.initState();
    _tripPlanService = ref.read(tripPlanServiceProvider);
    _tripService = ref.read(tripServiceProvider);
    _homeRepository = ref.read(homeRepositoryProvider);
    _directionsClient = ref.read(googleDirectionsApiClientProvider);
    _tripPlan = widget.tripPlan;
    _nameController = TextEditingController(text: _tripPlan.name);
    _selectedPlanType = _tripPlan.planType;
    _startDate = _tripPlan.startDate;
    _endDate = _tripPlan.endDate;
    _initEditLocations();
    _updateMapData();
    _loadUserInfo();
  }
```

- [ ] **Step 5: Remove the `_directionsClient.dispose()` call — see the "behavioral subtlety" section above for why**

Change (currently `:113-118`):

```dart
  @override
  void dispose() {
    _nameController.dispose();
    _mapController?.dispose();
    _directionsClient.dispose();
```

to:

```dart
  @override
  void dispose() {
    _nameController.dispose();
    _mapController?.dispose();
```

(Leave whatever else follows in `dispose()` — e.g. other controller disposals — completely unchanged; only the `_directionsClient.dispose();` line is removed.)

- [ ] **Step 6: Verify no other direct construction remains**

Run: `grep -n "TripPlanService()\|TripService()\|HomeRepository()\|GoogleDirectionsApiClient(" lib/presentation/screens/trip_plan_detail_screen.dart`
Expected: no matches (all 4 were only ever constructed at the field/initState level converted above).

The `import 'package:wanderer_frontend/core/constants/api_endpoints.dart';` import may now be unused if `ApiEndpoints.googleMapsApiKey` was its only reference in this file — check with `grep -n "ApiEndpoints\." lib/presentation/screens/trip_plan_detail_screen.dart` and remove the import only if genuinely unused (this screen likely uses `ApiEndpoints` elsewhere too, e.g. for thumbnail URLs — verify rather than assume).

- [ ] **Step 7: Update the test file if needed**

If Step 1 found `test/widgets/trip_plan_detail_screen_test.dart` wraps only in `MaterialApp`, wrap every `pumpWidget` call in `ProviderScope`, matching the pattern used in every prior batch's test updates.

- [ ] **Step 8: Run analyze + relevant test file + full suite**

Run: `flutter analyze` — expect clean.
Run: `flutter test test/widgets/trip_plan_detail_screen_test.dart` — expect PASS, same test count as before.
Run: `flutter test` — expect 1383 passing (unchanged — existing test count, no new tests added).

- [ ] **Step 9: Commit**

```bash
git add lib/presentation/screens/trip_plan_detail_screen.dart test/widgets/trip_plan_detail_screen_test.dart
git commit -m "refactor: convert TripPlanDetailScreen to ConsumerStatefulWidget, read 4 dependencies via provider

TripPlanService, TripService, HomeRepository, and
GoogleDirectionsApiClient are now sourced from the Phase 4a provider
graph. Also removes this screen's _directionsClient.dispose() call:
create_trip_plan_screen.dart (Batch D) already shares the same
googleDirectionsApiClientProvider instance app-wide, so no single
screen should close its underlying http.Client anymore - this
mirrors how ApiClient's own http.Client is never explicitly disposed
by any screen either."
```

(Omit the test file from `git add` if Step 7 found no changes were needed.)

---

## Overall verification

- [ ] `flutter analyze` — clean, zero new warnings vs the 1383-test/clean-analyze baseline.
- [ ] `flutter test` — 1383 passing (unchanged — existing test file, no new tests).
- [ ] Manual smoke test: `flutter run` — open a trip plan's detail screen, verify the map and route render, edit the plan (add/remove waypoints, drag markers), save changes, and — importantly, given the dispose() change — navigate away and back into this screen (and into `CreateTripPlanScreen`) multiple times in the same session to confirm route computation still works every time (this is the specific behavior the dispose() removal is meant to protect).
- [ ] `git log --oneline` shows the one commit for this task, independently revertable.
- [ ] Confirm scope discipline: `git diff --stat` shows only `trip_plan_detail_screen.dart` (and its test file, if touched) changed — nothing else in this 2000+ line file's business logic appears in the diff besides the class declaration, field declarations, `initState()`'s first ~5 lines, and the one removed `dispose()` line.
