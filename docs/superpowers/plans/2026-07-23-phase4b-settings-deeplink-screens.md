# Phase 4b (Batch G) Implementation Plan — Convert Settings/Deep-Link Screens to Riverpod DI

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert the seventh batch of screens (`settings_screen.dart`, `trip_deep_link_screen.dart`, `user_deep_link_screen.dart`) to read their services/repository from the Phase 4a Riverpod provider graph.

**Architecture:** Same pattern as every prior batch. The two deep-link screens are small, self-contained wrapper screens (each just resolves an ID/username then navigates onward) with a single field each. `settings_screen.dart` has 3 fields to convert, plus a `PushNotificationManager` field that — same as `home_screen.dart` in Batch B — is left untouched since no provider exists for it (different layer, `core/services` not `data/*`).

**Tech Stack:** `flutter_riverpod` (provider graph from Phase 4a, `lib/core/providers/app_providers.dart`).

## Global Constraints

- `flutter analyze` zero new warnings; `flutter test` stays green throughout. Baseline on this branch: **1383 tests passing**.
- No change to any widget's public constructor signature (`SettingsScreen` parameterless; `TripDeepLinkScreen`'s `tripId` and `UserDeepLinkScreen`'s `username` stay exactly as-is).
- No behavior change — pure DI-wiring refactor.
- `settings_screen.dart`'s `PushNotificationManager` field must be left completely untouched (no provider exists for it, same exception as `home_screen.dart` in Batch B).
- Check every task for indirect test construction, not just direct `grep "ScreenName("`.

---

## Task 1: `trip_deep_link_screen.dart`

**Files:**
- Modify: `lib/presentation/screens/trip_deep_link_screen.dart`
- Test: check `find test -iname "*trip_deep_link*"` and `grep -rln "TripDeepLinkScreen(" test/` first

**Interfaces:**
- Consumes: `tripServiceProvider` (Phase 4a).

- [ ] **Step 1: Check for existing test coverage**

Run: `find test -iname "*trip_deep_link*"` and `grep -rln "TripDeepLinkScreen(" test/`.

- [ ] **Step 2: Convert the widget class**

Add the imports:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wanderer_frontend/core/providers/app_providers.dart';
```

Change (currently `lib/presentation/screens/trip_deep_link_screen.dart:9-16`):

```dart
class TripDeepLinkScreen extends StatefulWidget {
  final String tripId;

  const TripDeepLinkScreen({super.key, required this.tripId});

  @override
  State<TripDeepLinkScreen> createState() => _TripDeepLinkScreenState();
}
```

to:

```dart
class TripDeepLinkScreen extends ConsumerStatefulWidget {
  final String tripId;

  const TripDeepLinkScreen({super.key, required this.tripId});

  @override
  ConsumerState<TripDeepLinkScreen> createState() =>
      _TripDeepLinkScreenState();
}
```

- [ ] **Step 3: Convert the State class and the `TripService` field**

Change (currently `:18-27`):

```dart
class _TripDeepLinkScreenState extends State<TripDeepLinkScreen> {
  final TripService _tripService = TripService();
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTrip();
  }
```

to:

```dart
class _TripDeepLinkScreenState extends ConsumerState<TripDeepLinkScreen> {
  late final TripService _tripService;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tripService = ref.read(tripServiceProvider);
    _loadTrip();
  }
```

- [ ] **Step 4: If a test exists and doesn't already use `ProviderScope`, add it**

Same approach as previous batches.

- [ ] **Step 5: Run analyze + relevant test(s) + full suite**

Run: `flutter analyze` — expect clean.
If a test exists: run it, expect PASS.
Run: `flutter test` — expect 1383 passing (unchanged).

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/screens/trip_deep_link_screen.dart
git commit -m "refactor: convert TripDeepLinkScreen to ConsumerStatefulWidget, read TripService via provider"
```

(Include the test file too if Step 4 changed one.)

---

## Task 2: `user_deep_link_screen.dart`

**Files:**
- Modify: `lib/presentation/screens/user_deep_link_screen.dart`
- Test: check `find test -iname "*user_deep_link*"` and `grep -rln "UserDeepLinkScreen(" test/` first

**Interfaces:**
- Consumes: `userServiceProvider` (Phase 4a).

- [ ] **Step 1: Check for existing test coverage**

Run: `find test -iname "*user_deep_link*"` and `grep -rln "UserDeepLinkScreen(" test/`.

- [ ] **Step 2: Convert the widget class**

Add the same two imports as Task 1. Change (currently `lib/presentation/screens/user_deep_link_screen.dart:9-16`):

```dart
class UserDeepLinkScreen extends StatefulWidget {
  final String username;

  const UserDeepLinkScreen({super.key, required this.username});

  @override
  State<UserDeepLinkScreen> createState() => _UserDeepLinkScreenState();
}
```

to:

```dart
class UserDeepLinkScreen extends ConsumerStatefulWidget {
  final String username;

  const UserDeepLinkScreen({super.key, required this.username});

  @override
  ConsumerState<UserDeepLinkScreen> createState() =>
      _UserDeepLinkScreenState();
}
```

- [ ] **Step 3: Convert the State class and the `UserService` field**

Change (currently `:18-27`):

```dart
class _UserDeepLinkScreenState extends State<UserDeepLinkScreen> {
  final UserService _userService = UserService();
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }
```

to:

```dart
class _UserDeepLinkScreenState extends ConsumerState<UserDeepLinkScreen> {
  late final UserService _userService;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _userService = ref.read(userServiceProvider);
    _loadUser();
  }
```

- [ ] **Step 4: If a test exists and doesn't already use `ProviderScope`, add it**

Same approach as before.

- [ ] **Step 5: Run analyze + relevant test(s) + full suite**

Run: `flutter analyze` — expect clean.
If a test exists: run it, expect PASS.
Run: `flutter test` — expect 1383 passing (unchanged).

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/screens/user_deep_link_screen.dart
git commit -m "refactor: convert UserDeepLinkScreen to ConsumerStatefulWidget, read UserService via provider"
```

(Include the test file too if Step 4 changed one.)

---

## Task 3: `settings_screen.dart`

**Context:** 3 dependencies convert (`AuthService`, `UserService`, `HomeRepository`); `PushNotificationManager` is left untouched (no provider exists for it, same rule as `home_screen.dart` in Batch B). This file has a second `initState()` at line ~802 belonging to a different, unrelated widget class defined later in the same file — do not touch that one.

**Files:**
- Modify: `lib/presentation/screens/settings_screen.dart`
- Test: check `find test -iname "*settings_screen*"` and `grep -rln "SettingsScreen(" test/` first

**Interfaces:**
- Consumes: `authServiceProvider`, `userServiceProvider`, `homeRepositoryProvider` (Phase 4a).

- [ ] **Step 1: Check for existing test coverage**

Run: `find test -iname "*settings_screen*"` and `grep -rln "SettingsScreen(" test/`.

- [ ] **Step 2: Convert the widget class**

Add the same two imports as Task 1. Change (currently `lib/presentation/screens/settings_screen.dart:24-29`):

```dart
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}
```

to:

```dart
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}
```

- [ ] **Step 3: Convert the State class and the 3 in-scope field constructions**

Change (currently `:31-36`):

```dart
class _SettingsScreenState extends State<SettingsScreen> {
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();
  final HomeRepository _homeRepository = HomeRepository();
  final PushNotificationManager _pushNotificationManager =
      PushNotificationManager();
```

to:

```dart
class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final AuthService _authService;
  late final UserService _userService;
  late final HomeRepository _homeRepository;
  final PushNotificationManager _pushNotificationManager =
      PushNotificationManager();
```

(`PushNotificationManager` stays exactly as-is — out of scope per Global Constraints.)

- [ ] **Step 4: Assign the 3 fields at the top of `initState()` (the FIRST `initState()` in the file, around line 49 — not the second one around line 802, which belongs to a different class)**

Change (currently `:48-55`):

```dart
  @override
  void initState() {
    super.initState();
    _loadPushPreference();
    _loadAppVersion();
    _loadAdminStatus();
    _isDarkMode = ThemeController().isDarkMode;
  }
```

to:

```dart
  @override
  void initState() {
    super.initState();
    _authService = ref.read(authServiceProvider);
    _userService = ref.read(userServiceProvider);
    _homeRepository = ref.read(homeRepositoryProvider);
    _loadPushPreference();
    _loadAppVersion();
    _loadAdminStatus();
    _isDarkMode = ThemeController().isDarkMode;
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
git add lib/presentation/screens/settings_screen.dart
git commit -m "refactor: convert SettingsScreen to ConsumerStatefulWidget, read AuthService/UserService/HomeRepository via provider

PushNotificationManager is left untouched - no provider exists for it
in the Phase 4a graph, same exception as home_screen.dart."
```

(Include the test file too if Step 5 changed one.)

---

## Overall verification

- [ ] `flutter analyze` — clean throughout, zero new warnings vs the 1383-test/clean-analyze baseline.
- [ ] `flutter test` — 1383 passing at the end (no new tests — pure DI rewiring of 3 files).
- [ ] Manual smoke test: `flutter run` — open a trip deep link and a profile deep link (both should resolve and navigate), visit Settings (toggle dark mode, check push preference, view admin status if applicable). Behavior identical to before this batch.
- [ ] `git log --oneline` shows one commit per task, each independently revertable.
- [ ] Confirm scope discipline: only the 3 named files (plus any test files touched) changed, `PushNotificationManager` untouched in `settings_screen.dart`.
