# Phase 4b (Batch F) Implementation Plan — Convert Admin/Promotion/Maintenance Screens to Riverpod DI

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert the sixth batch of screens (`admin_users_screen.dart`, `trip_promotion_screen.dart`, `trip_maintenance_screen.dart`) to read their services/repository from the Phase 4a Riverpod provider graph.

**Architecture:** Same conversion pattern as every prior batch — all three fields in each file are eager `final X _x = X();` initializers, converting to `late final` + assignment at the top of `initState()`, before each file's existing `_loadUserInfo()`/`_loadTrips()`/`_loadUsers()`/`_loadPromotedTrips()` calls.

**Tech Stack:** `flutter_riverpod` (provider graph from Phase 4a, `lib/core/providers/app_providers.dart`).

## Global Constraints

- `flutter analyze` zero new warnings; `flutter test` stays green throughout. Baseline on this branch: **1383 tests passing**.
- No change to any widget's public constructor signature (all three are parameterless).
- No behavior change — pure DI-wiring refactor.
- Check every task for indirect test construction (via other screens' navigation tests), not just direct `grep "ScreenName("`.

---

## Task 1: `admin_users_screen.dart`

**Files:**
- Modify: `lib/presentation/screens/admin_users_screen.dart`
- Test: check `find test -iname "*admin_users_screen*"` and `grep -rln "AdminUsersScreen(" test/` first

**Interfaces:**
- Consumes: `adminServiceProvider`, `homeRepositoryProvider` (Phase 4a).

- [ ] **Step 1: Check for existing test coverage**

Run: `find test -iname "*admin_users_screen*"` and `grep -rln "AdminUsersScreen(" test/`.

- [ ] **Step 2: Convert the widget class**

Add the imports:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wanderer_frontend/core/providers/app_providers.dart';
```

Change (currently `lib/presentation/screens/admin_users_screen.dart:17-22`):

```dart
class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}
```

to:

```dart
class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}
```

- [ ] **Step 3: Convert the State class and the 2 field constructions**

Change (currently `:24-26`):

```dart
class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final AdminService _adminService = AdminService();
  final HomeRepository _homeRepository = HomeRepository();
```

to:

```dart
class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  late final AdminService _adminService;
  late final HomeRepository _homeRepository;
```

- [ ] **Step 4: Assign both fields at the top of `initState()`**

Change (currently `:54-60`):

```dart
  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _loadUsers();
    _searchController.addListener(_filterUsers);
  }
```

to:

```dart
  @override
  void initState() {
    super.initState();
    _adminService = ref.read(adminServiceProvider);
    _homeRepository = ref.read(homeRepositoryProvider);
    _loadUserInfo();
    _loadUsers();
    _searchController.addListener(_filterUsers);
  }
```

- [ ] **Step 5: If a test exists and doesn't already use `ProviderScope`, add it**

Same approach as previous batches.

- [ ] **Step 6: Run analyze + relevant test(s) + full suite**

Run: `flutter analyze` — expect clean.
If a test exists: run it, expect PASS.
Run: `flutter test` — expect 1383 passing (unchanged).

- [ ] **Step 7: Commit**

```bash
git add lib/presentation/screens/admin_users_screen.dart
git commit -m "refactor: convert AdminUsersScreen to ConsumerStatefulWidget, read AdminService/HomeRepository via provider"
```

(Include the test file too if Step 5 changed one.)

---

## Task 2: `trip_promotion_screen.dart`

**Files:**
- Modify: `lib/presentation/screens/trip_promotion_screen.dart`
- Test: check `find test -iname "*trip_promotion_screen*"` and `grep -rln "TripPromotionScreen(" test/` first

**Interfaces:**
- Consumes: `adminServiceProvider`, `homeRepositoryProvider`, `tripServiceProvider` (Phase 4a).

- [ ] **Step 1: Check for existing test coverage**

Run: `find test -iname "*trip_promotion_screen*"` and `grep -rln "TripPromotionScreen(" test/`.

- [ ] **Step 2: Convert the widget class**

Add the same two imports as Task 1. Change (currently `lib/presentation/screens/trip_promotion_screen.dart:19-24`):

```dart
class TripPromotionScreen extends StatefulWidget {
  const TripPromotionScreen({super.key});

  @override
  State<TripPromotionScreen> createState() => _TripPromotionScreenState();
}
```

to:

```dart
class TripPromotionScreen extends ConsumerStatefulWidget {
  const TripPromotionScreen({super.key});

  @override
  ConsumerState<TripPromotionScreen> createState() =>
      _TripPromotionScreenState();
}
```

- [ ] **Step 3: Convert the State class and the 3 field constructions**

Change (currently `:26-29`):

```dart
class _TripPromotionScreenState extends State<TripPromotionScreen> {
  final AdminService _adminService = AdminService();
  final HomeRepository _homeRepository = HomeRepository();
  final TripService _tripService = TripService();
```

to:

```dart
class _TripPromotionScreenState extends ConsumerState<TripPromotionScreen> {
  late final AdminService _adminService;
  late final HomeRepository _homeRepository;
  late final TripService _tripService;
```

- [ ] **Step 4: Assign all 3 fields at the top of `initState()`**

Change (currently `:50-57`):

```dart
  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _loadTrips();
    _loadPromotedTrips();
    _searchController.addListener(_filterTrips);
  }
```

to:

```dart
  @override
  void initState() {
    super.initState();
    _adminService = ref.read(adminServiceProvider);
    _homeRepository = ref.read(homeRepositoryProvider);
    _tripService = ref.read(tripServiceProvider);
    _loadUserInfo();
    _loadTrips();
    _loadPromotedTrips();
    _searchController.addListener(_filterTrips);
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
git add lib/presentation/screens/trip_promotion_screen.dart
git commit -m "refactor: convert TripPromotionScreen to ConsumerStatefulWidget, read AdminService/HomeRepository/TripService via provider"
```

(Include the test file too if Step 5 changed one.)

---

## Task 3: `trip_maintenance_screen.dart`

**Files:**
- Modify: `lib/presentation/screens/trip_maintenance_screen.dart`
- Test: check `find test -iname "*trip_maintenance_screen*"` and `grep -rln "TripMaintenanceScreen(" test/` first

**Interfaces:**
- Consumes: `adminServiceProvider`, `tripServiceProvider`, `homeRepositoryProvider` (Phase 4a).

- [ ] **Step 1: Check for existing test coverage**

Run: `find test -iname "*trip_maintenance_screen*"` and `grep -rln "TripMaintenanceScreen(" test/`.

- [ ] **Step 2: Convert the widget class**

Add the same two imports as Task 1. Change (currently `lib/presentation/screens/trip_maintenance_screen.dart:22-27`):

```dart
class TripMaintenanceScreen extends StatefulWidget {
  const TripMaintenanceScreen({super.key});

  @override
  State<TripMaintenanceScreen> createState() => _TripMaintenanceScreenState();
}
```

to:

```dart
class TripMaintenanceScreen extends ConsumerStatefulWidget {
  const TripMaintenanceScreen({super.key});

  @override
  ConsumerState<TripMaintenanceScreen> createState() =>
      _TripMaintenanceScreenState();
}
```

- [ ] **Step 3: Convert the State class and the 3 field constructions**

Change (currently `:29-32`):

```dart
class _TripMaintenanceScreenState extends State<TripMaintenanceScreen> {
  final AdminService _adminService = AdminService();
  final TripService _tripService = TripService();
  final HomeRepository _homeRepository = HomeRepository();
```

to:

```dart
class _TripMaintenanceScreenState extends ConsumerState<TripMaintenanceScreen> {
  late final AdminService _adminService;
  late final TripService _tripService;
  late final HomeRepository _homeRepository;
```

- [ ] **Step 4: Assign all 3 fields at the top of `initState()`**

Change (currently `:64-70`):

```dart
  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _loadTrips();
    _searchController.addListener(_filterTrips);
  }
```

to:

```dart
  @override
  void initState() {
    super.initState();
    _adminService = ref.read(adminServiceProvider);
    _tripService = ref.read(tripServiceProvider);
    _homeRepository = ref.read(homeRepositoryProvider);
    _loadUserInfo();
    _loadTrips();
    _searchController.addListener(_filterTrips);
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
git add lib/presentation/screens/trip_maintenance_screen.dart
git commit -m "refactor: convert TripMaintenanceScreen to ConsumerStatefulWidget, read AdminService/TripService/HomeRepository via provider"
```

(Include the test file too if Step 5 changed one.)

---

## Overall verification

- [ ] `flutter analyze` — clean throughout, zero new warnings vs the 1383-test/clean-analyze baseline.
- [ ] `flutter test` — 1383 passing at the end (no new tests — pure DI rewiring of 3 files).
- [ ] Manual smoke test: `flutter run` as an admin user — visit User Management (list loads, search works), Trip Promotion (promotable/promoted lists load), Trip Maintenance (stats load, recompute actions work). Behavior identical to before this batch.
- [ ] `git log --oneline` shows one commit per task, each independently revertable.
- [ ] Confirm scope discipline: only the 3 named files (plus any test files touched) changed.
