# Phase 4b (Batch D) Implementation Plan — Convert Trip-Creation Screens to Riverpod DI

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert the fourth batch of screens (`create_trip_screen.dart`, `create_trip_plan_screen.dart`, `trip_plans_screen.dart`) to read their services/repository from the Phase 4a Riverpod provider graph.

**Architecture:** Same pattern as prior batches, with one variation: some fields in this batch are **already** `late final` declared and assigned via direct construction inside `initState()` (rather than at field-declaration time) — for those, only the assignment's right-hand side changes (`TripService()` → `ref.read(tripServiceProvider)`), the `late final` declaration itself is untouched. `create_trip_plan_screen.dart` also converts its `GoogleDirectionsApiClient` construction to `googleDirectionsApiClientProvider` — a provider Phase 4a already built for exactly this.

**Tech Stack:** `flutter_riverpod` (provider graph from Phase 4a, `lib/core/providers/app_providers.dart`).

## Global Constraints

- `flutter analyze` zero new warnings; `flutter test` stays green throughout. Baseline on this branch: **1383 tests passing**.
- No change to any widget's public constructor signature (all three are parameterless).
- No behavior change — pure DI-wiring refactor.
- Check every task for indirect test construction (via other screens' navigation tests), not just direct `grep "ScreenName("` — this has found real gaps twice already in this effort (`HomeScreen` via `InitialScreen`'s fallback).

---

## Task 1: `create_trip_screen.dart`

**Files:**
- Modify: `lib/presentation/screens/create_trip_screen.dart`
- Test: check `find test -iname "*create_trip_screen*"` and `grep -rln "CreateTripScreen(" test/` first

**Interfaces:**
- Consumes: `createTripRepositoryProvider`, `tripPlanServiceProvider`, `tripServiceProvider` (Phase 4a).

- [ ] **Step 1: Check for existing test coverage**

Run: `find test -iname "*create_trip_screen*"` and `grep -rln "CreateTripScreen(" test/`.

- [ ] **Step 2: Convert the widget class**

Add the imports:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wanderer_frontend/core/providers/app_providers.dart';
```

Change (currently `lib/presentation/screens/create_trip_screen.dart:17-22`):

```dart
class CreateTripScreen extends StatefulWidget {
  const CreateTripScreen({super.key});

  @override
  State<CreateTripScreen> createState() => _CreateTripScreenState();
}
```

to:

```dart
class CreateTripScreen extends ConsumerStatefulWidget {
  const CreateTripScreen({super.key});

  @override
  ConsumerState<CreateTripScreen> createState() => _CreateTripScreenState();
}
```

- [ ] **Step 3: Convert the State class and the `CreateTripRepository` field**

Change (currently `:24-26`, only the class header and the one eager-constructed field — `_tripPlanService`/`_tripService` below it, already `late final`, are handled in Step 4):

```dart
class _CreateTripScreenState extends State<CreateTripScreen> {
  final CreateTripRepository _repository = CreateTripRepository();
  final _formKey = GlobalKey<FormState>();
```

to:

```dart
class _CreateTripScreenState extends ConsumerState<CreateTripScreen> {
  late final CreateTripRepository _repository;
  final _formKey = GlobalKey<FormState>();
```

- [ ] **Step 4: Update `initState()` — add the new assignment, convert the two existing ones**

Change (currently `:49-54`):

```dart
  @override
  void initState() {
    super.initState();
    _tripPlanService = TripPlanService();
    _tripService = TripService();
    _loadTripPlans();
```

to:

```dart
  @override
  void initState() {
    super.initState();
    _repository = ref.read(createTripRepositoryProvider);
    _tripPlanService = ref.read(tripPlanServiceProvider);
    _tripService = ref.read(tripServiceProvider);
    _loadTripPlans();
```

(Everything after `_loadTripPlans();` in `initState()` — the post-frame callback and its animation-listener logic — is unchanged, keep it exactly as it is.)

- [ ] **Step 5: If a test exists and doesn't already use `ProviderScope`, add it**

Same approach as previous batches.

- [ ] **Step 6: Run analyze + relevant test(s) + full suite**

Run: `flutter analyze` — expect clean.
If a test exists: run it, expect PASS.
Run: `flutter test` — expect 1383 passing (unchanged).

- [ ] **Step 7: Commit**

```bash
git add lib/presentation/screens/create_trip_screen.dart
git commit -m "refactor: convert CreateTripScreen to ConsumerStatefulWidget, read CreateTripRepository/TripPlanService/TripService via provider"
```

(Include the test file too if Step 5 changed one.)

---

## Task 2: `create_trip_plan_screen.dart`

**Context:** This screen has two dependencies to convert: `TripPlanService` (eager field-initializer, same pattern as every prior batch) and `GoogleDirectionsApiClient` (already `late final`, assigned in `initState()` via direct construction with the Google Maps API key — Phase 4a's `googleDirectionsApiClientProvider` already wraps this exact construction).

**Files:**
- Modify: `lib/presentation/screens/create_trip_plan_screen.dart`
- Test: check `find test -iname "*create_trip_plan*"` and `grep -rln "CreateTripPlanScreen(" test/` first

**Interfaces:**
- Consumes: `tripPlanServiceProvider`, `googleDirectionsApiClientProvider` (Phase 4a).

- [ ] **Step 1: Check for existing test coverage**

Run: `find test -iname "*create_trip_plan*"` and `grep -rln "CreateTripPlanScreen(" test/`.

- [ ] **Step 2: Convert the widget class**

Add the same two imports as Task 1. Change (currently `lib/presentation/screens/create_trip_plan_screen.dart:18-23`):

```dart
class CreateTripPlanScreen extends StatefulWidget {
  const CreateTripPlanScreen({super.key});

  @override
  State<CreateTripPlanScreen> createState() => _CreateTripPlanScreenState();
}
```

to:

```dart
class CreateTripPlanScreen extends ConsumerStatefulWidget {
  const CreateTripPlanScreen({super.key});

  @override
  ConsumerState<CreateTripPlanScreen> createState() =>
      _CreateTripPlanScreenState();
}
```

- [ ] **Step 3: Convert the State class and the `TripPlanService` field**

Change (currently `:28-29`):

```dart
class _CreateTripPlanScreenState extends State<CreateTripPlanScreen> {
  final TripPlanService _tripPlanService = TripPlanService();
```

to:

```dart
class _CreateTripPlanScreenState extends ConsumerState<CreateTripPlanScreen> {
  late final TripPlanService _tripPlanService;
```

(The `_directionsClient` field declaration itself, currently `late final GoogleDirectionsApiClient _directionsClient;` around line 40, stays exactly as `late final` — only its assignment changes, in Step 4.)

- [ ] **Step 4: Update `initState()`**

Change (currently `:85-91`):

```dart
  @override
  void initState() {
    super.initState();
    _directionsClient =
        GoogleDirectionsApiClient(ApiEndpoints.googleMapsApiKey);
    _getCurrentLocation();
  }
```

to:

```dart
  @override
  void initState() {
    super.initState();
    _tripPlanService = ref.read(tripPlanServiceProvider);
    _directionsClient = ref.read(googleDirectionsApiClientProvider);
    _getCurrentLocation();
  }
```

Note: `import 'package:wanderer_frontend/core/constants/api_endpoints.dart';` and `import 'package:wanderer_frontend/data/client/google_directions_api_client.dart';` may still be needed for other purposes in this file (check with `grep -n "ApiEndpoints\.\|GoogleDirectionsApiClient" lib/presentation/screens/create_trip_plan_screen.dart` — `GoogleDirectionsApiClient` is still used as `_directionsClient`'s type annotation, so that import stays; `ApiEndpoints` may become unused if this was its only reference in the file — remove the import only if the grep confirms zero remaining uses).

- [ ] **Step 5: If a test exists and doesn't already use `ProviderScope`, add it**

Same approach as before.

- [ ] **Step 6: Run analyze + relevant test(s) + full suite**

Run: `flutter analyze` — expect clean.
If a test exists: run it, expect PASS.
Run: `flutter test` — expect 1383 passing (unchanged).

- [ ] **Step 7: Commit**

```bash
git add lib/presentation/screens/create_trip_plan_screen.dart
git commit -m "refactor: convert CreateTripPlanScreen to ConsumerStatefulWidget, read TripPlanService/GoogleDirectionsApiClient via provider"
```

(Include the test file too if Step 5 changed one.)

---

## Task 3: `trip_plans_screen.dart`

**Context:** Two eager field-initializers (`TripPlanService`, `HomeRepository`) plus one already-`late final` field (`TripService`) assigned via direct construction in `initState()`.

**Files:**
- Modify: `lib/presentation/screens/trip_plans_screen.dart`
- Test: check `find test -iname "*trip_plans_screen*"` and `grep -rln "TripPlansScreen(" test/` first

**Interfaces:**
- Consumes: `tripPlanServiceProvider`, `homeRepositoryProvider`, `tripServiceProvider` (Phase 4a).

- [ ] **Step 1: Check for existing test coverage**

Run: `find test -iname "*trip_plans_screen*"` and `grep -rln "TripPlansScreen(" test/`.

- [ ] **Step 2: Convert the widget class**

Add the same two imports as Task 1. Change (currently `lib/presentation/screens/trip_plans_screen.dart:23-28`):

```dart
class TripPlansScreen extends StatefulWidget {
  const TripPlansScreen({super.key});

  @override
  State<TripPlansScreen> createState() => _TripPlansScreenState();
}
```

to:

```dart
class TripPlansScreen extends ConsumerStatefulWidget {
  const TripPlansScreen({super.key});

  @override
  ConsumerState<TripPlansScreen> createState() => _TripPlansScreenState();
}
```

- [ ] **Step 3: Convert the State class and the 2 eager field-initializers**

Change (currently `:30-33`):

```dart
class _TripPlansScreenState extends State<TripPlansScreen> {
  final TripPlanService _tripPlanService = TripPlanService();
  final HomeRepository _homeRepository = HomeRepository();
  late final TripService _tripService;
```

to:

```dart
class _TripPlansScreenState extends ConsumerState<TripPlansScreen> {
  late final TripPlanService _tripPlanService;
  late final HomeRepository _homeRepository;
  late final TripService _tripService;
```

- [ ] **Step 4: Update `initState()`**

Change (currently `:46-52`):

```dart
  @override
  void initState() {
    super.initState();
    _tripService = TripService();
    _loadUserInfo();
    _loadTripPlans();
  }
```

to:

```dart
  @override
  void initState() {
    super.initState();
    _tripPlanService = ref.read(tripPlanServiceProvider);
    _homeRepository = ref.read(homeRepositoryProvider);
    _tripService = ref.read(tripServiceProvider);
    _loadUserInfo();
    _loadTripPlans();
  }
```

- [ ] **Step 5: If a test exists and doesn't already use `ProviderScope`, add it**

Same approach as before.

- [ ] **Step 6: Run analyze + relevant test(s) + full suite**

Run: `flutter analyze` — expect clean.
If a test exists: run it, expect PASS.
Run: `flutter test` — expect 1383 passing (unchanged).

- [ ] **Step 7: Commit**

```bash
git add lib/presentation/screens/trip_plans_screen.dart
git commit -m "refactor: convert TripPlansScreen to ConsumerStatefulWidget, read TripPlanService/HomeRepository/TripService via provider"
```

(Include the test file too if Step 5 changed one.)

---

## Overall verification

- [ ] `flutter analyze` — clean throughout, zero new warnings vs the 1383-test/clean-analyze baseline.
- [ ] `flutter test` — 1383 passing at the end (no new tests — pure DI rewiring of 3 files).
- [ ] Manual smoke test: `flutter run` — create a new simple trip, create a new trip plan with a route on the map, view the trip plans list. Behavior identical to before this batch.
- [ ] `git log --oneline` shows one commit per task, each independently revertable.
- [ ] Confirm scope discipline: only the 3 named files (plus any test files touched) changed.
