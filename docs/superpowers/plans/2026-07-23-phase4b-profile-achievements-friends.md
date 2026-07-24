# Phase 4b (Batch C) Implementation Plan — Convert Profile/Achievements/Friends Screens to Riverpod DI

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert the third batch of screens (`profile_screen.dart`, `achievements_screen.dart`, `friends_followers_screen.dart`) to read their services/repository from the Phase 4a Riverpod provider graph instead of constructing them directly.

**Architecture:** Same pattern as Batches A/B: `StatefulWidget`/`State<X>` → `ConsumerStatefulWidget`/`ConsumerState<X>`, fields become `late final` assigned via `ref.read(...)` at the top of `initState()`, before that `initState()`'s existing WebSocket-subscription/data-loading calls. Two of these files (`achievements_screen.dart`, `friends_followers_screen.dart`) also have a **standalone inline `AuthService().logout()` call elsewhere in the file** (not the converted field) — since each file already converts its own `_authService` field to a provider-sourced instance, these inline calls are updated to reuse `_authService.logout()` instead of constructing a second throwaway `AuthService()`, consistent with the whole point of this refactor (share instances, don't re-construct).

**Tech Stack:** `flutter_riverpod` (provider graph from Phase 4a, `lib/core/providers/app_providers.dart`).

## Global Constraints

- `flutter analyze` zero new warnings; `flutter test` stays green throughout. Baseline on this branch: **1383 tests passing**.
- No change to any widget's public constructor signature (`ProfileScreen`'s `userId` parameter, `AchievementsScreen`/`FriendsFollowersScreen`'s parameterless constructors).
- No behavior change — pure DI-wiring refactor.
- `friends_followers_screen.dart`'s existing mixin (`SingleTickerProviderStateMixin`) must be preserved exactly.
- Check every task for indirect test construction (via `InitialScreen`/`MyApp`/route-strategy tests), not just direct `grep "ScreenName("` — Batch B's Task 3 found a real gap this way (`test/widget_test.dart` reaching `HomeScreen` through `InitialScreen`'s fallback). None of these 3 screens are reachable from that specific fallback path, but check independently rather than assuming.

---

## Task 1: `achievements_screen.dart`

**Files:**
- Modify: `lib/presentation/screens/achievements_screen.dart`
- Test: check `find test -iname "*achievements_screen*"` and `grep -rln "AchievementsScreen(" test/` first

**Interfaces:**
- Consumes: `achievementServiceProvider`, `authServiceProvider` (Phase 4a).

- [ ] **Step 1: Check for existing test coverage**

Run: `find test -iname "*achievements_screen*"` and `grep -rln "AchievementsScreen(" test/`.

- [ ] **Step 2: Convert the widget class**

Add the imports:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wanderer_frontend/core/providers/app_providers.dart';
```

Change (currently `lib/presentation/screens/achievements_screen.dart:16-21`):

```dart
class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}
```

to:

```dart
class AchievementsScreen extends ConsumerStatefulWidget {
  const AchievementsScreen({super.key});

  @override
  ConsumerState<AchievementsScreen> createState() =>
      _AchievementsScreenState();
}
```

- [ ] **Step 3: Convert the State class and the 2 field constructions**

Change (currently `:23-25`):

```dart
class _AchievementsScreenState extends State<AchievementsScreen> {
  final AchievementService _achievementService = AchievementService();
  final AuthService _authService = AuthService();
```

to:

```dart
class _AchievementsScreenState extends ConsumerState<AchievementsScreen> {
  late final AchievementService _achievementService;
  late final AuthService _authService;
```

- [ ] **Step 4: Assign both fields at the top of `initState()`**

Change (currently `:39-43`):

```dart
  @override
  void initState() {
    super.initState();
    _loadData();
  }
```

to:

```dart
  @override
  void initState() {
    super.initState();
    _achievementService = ref.read(achievementServiceProvider);
    _authService = ref.read(authServiceProvider);
    _loadData();
  }
```

- [ ] **Step 5: Update the standalone inline `AuthService().logout()` call**

At line 134 (`await AuthService().logout();`, inside a method later in the file), change to reuse the now-injected field:

```dart
      await _authService.logout();
```

Verify with `grep -n "AuthService()" lib/presentation/screens/achievements_screen.dart` after this change that no other `AuthService()` construction remains in the file.

- [ ] **Step 6: If a test exists and doesn't already use `ProviderScope`, add it**

Same approach as previous batches.

- [ ] **Step 7: Run analyze + relevant test(s) + full suite**

Run: `flutter analyze` — expect clean.
If a test exists: run it, expect PASS.
Run: `flutter test` — expect 1383 passing (unchanged).

- [ ] **Step 8: Commit**

```bash
git add lib/presentation/screens/achievements_screen.dart
git commit -m "refactor: convert AchievementsScreen to ConsumerStatefulWidget, read AchievementService/AuthService via provider

Also updates the standalone AuthService().logout() call to reuse the
now-injected _authService field instead of constructing a second
throwaway instance."
```

(Include the test file too if Step 6 changed one.)

---

## Task 2: `friends_followers_screen.dart`

**Files:**
- Modify: `lib/presentation/screens/friends_followers_screen.dart`
- Test: check `find test -iname "*friends_followers*"` and `grep -rln "FriendsFollowersScreen(" test/` first

**Interfaces:**
- Consumes: `userServiceProvider`, `authServiceProvider`, `websocketServiceProvider` (Phase 4a).

- [ ] **Step 1: Check for existing test coverage**

Run: `find test -iname "*friends_followers*"` and `grep -rln "FriendsFollowersScreen(" test/`.

- [ ] **Step 2: Convert the widget class**

Add the same two imports as Task 1. Change (currently `lib/presentation/screens/friends_followers_screen.dart:23-28`):

```dart
class FriendsFollowersScreen extends StatefulWidget {
  const FriendsFollowersScreen({super.key});

  @override
  State<FriendsFollowersScreen> createState() => _FriendsFollowersScreenState();
}
```

to:

```dart
class FriendsFollowersScreen extends ConsumerStatefulWidget {
  const FriendsFollowersScreen({super.key});

  @override
  ConsumerState<FriendsFollowersScreen> createState() =>
      _FriendsFollowersScreenState();
}
```

- [ ] **Step 3: Convert the State class and the 3 field constructions**

Change (currently `:30-34`):

```dart
class _FriendsFollowersScreenState extends State<FriendsFollowersScreen>
    with SingleTickerProviderStateMixin {
  final UserService _userService = UserService();
  final AuthService _authService = AuthService();
  final WebSocketService _webSocketService = WebSocketService();
```

to:

```dart
class _FriendsFollowersScreenState extends ConsumerState<FriendsFollowersScreen>
    with SingleTickerProviderStateMixin {
  late final UserService _userService;
  late final AuthService _authService;
  late final WebSocketService _webSocketService;
```

- [ ] **Step 4: Assign all 3 fields at the top of `initState()`**

Change (currently `:70-86`):

```dart
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();

    // Listen to the global WebSocket events stream immediately so events
    // are caught even before the async connect / userId resolution finishes.
    _wsSubscription = _webSocketService.events.listen(_handleWebSocketEvent);

    // Fire-and-forget: connect to WebSocket server. Once connected the
    // pending user subscriptions will be activated automatically.
    _webSocketService.connect();

    // Start periodic polling as a reliable fallback — ensures the
    // relationship lists stay fresh even when WebSocket events are missed.
    _startPolling();
```

to:

```dart
  @override
  void initState() {
    super.initState();
    _userService = ref.read(userServiceProvider);
    _authService = ref.read(authServiceProvider);
    _webSocketService = ref.read(websocketServiceProvider);

    _tabController = TabController(length: 3, vsync: this);
    _loadData();

    // Listen to the global WebSocket events stream immediately so events
    // are caught even before the async connect / userId resolution finishes.
    _wsSubscription = _webSocketService.events.listen(_handleWebSocketEvent);

    // Fire-and-forget: connect to WebSocket server. Once connected the
    // pending user subscriptions will be activated automatically.
    _webSocketService.connect();

    // Start periodic polling as a reliable fallback — ensures the
    // relationship lists stay fresh even when WebSocket events are missed.
    _startPolling();
```

(The rest of `initState()`'s body after this point, and the closing `}`, are unchanged — only shown up to `_startPolling();` above for context; do not truncate anything that follows it in the real file.)

- [ ] **Step 5: Update the standalone inline `AuthService().logout()` call**

At line 365 (`await AuthService().logout();`), change to:

```dart
      await _authService.logout();
```

Verify with `grep -n "AuthService()" lib/presentation/screens/friends_followers_screen.dart` after this change that no other `AuthService()` construction remains.

- [ ] **Step 6: If a test exists and doesn't already use `ProviderScope`, add it**

Same approach as before.

- [ ] **Step 7: Run analyze + relevant test(s) + full suite**

Run: `flutter analyze` — expect clean.
If a test exists: run it, expect PASS.
Run: `flutter test` — expect 1383 passing (unchanged).

- [ ] **Step 8: Commit**

```bash
git add lib/presentation/screens/friends_followers_screen.dart
git commit -m "refactor: convert FriendsFollowersScreen to ConsumerStatefulWidget, read UserService/AuthService/WebSocketService via provider

Also updates the standalone AuthService().logout() call to reuse the
now-injected _authService field."
```

(Include the test file too if Step 6 changed one.)

---

## Task 3: `profile_screen.dart`

**Files:**
- Modify: `lib/presentation/screens/profile_screen.dart`
- Test: check `find test -iname "*profile_screen*"` and `grep -rln "ProfileScreen(" test/` first

**Interfaces:**
- Consumes: `profileRepositoryProvider`, `userServiceProvider`, `websocketServiceProvider` (Phase 4a).

- [ ] **Step 1: Check for existing test coverage**

Run: `find test -iname "*profile_screen*"` and `grep -rln "ProfileScreen(" test/`.

- [ ] **Step 2: Convert the widget class**

Add the same two imports as Task 1. Change (currently `lib/presentation/screens/profile_screen.dart:87-94`):

```dart
class ProfileScreen extends StatefulWidget {
  final String? userId;

  const ProfileScreen({super.key, this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}
```

to:

```dart
class ProfileScreen extends ConsumerStatefulWidget {
  final String? userId;

  const ProfileScreen({super.key, this.userId});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}
```

- [ ] **Step 3: Convert the State class and the 3 field constructions**

Change (currently `:96-99`):

```dart
class _ProfileScreenState extends State<ProfileScreen> {
  final ProfileRepository _repository = ProfileRepository();
  final UserService _userService = UserService();
  final WebSocketService _webSocketService = WebSocketService();
```

to:

```dart
class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late final ProfileRepository _repository;
  late final UserService _userService;
  late final WebSocketService _webSocketService;
```

- [ ] **Step 4: Assign all 3 fields at the top of `initState()`**

Change (currently `:131-136`):

```dart
  @override
  void initState() {
    super.initState();
    _loadProfile();
    _setupUserWebSocket();
  }
```

to:

```dart
  @override
  void initState() {
    super.initState();
    _repository = ref.read(profileRepositoryProvider);
    _userService = ref.read(userServiceProvider);
    _webSocketService = ref.read(websocketServiceProvider);
    _loadProfile();
    _setupUserWebSocket();
  }
```

`_setupUserWebSocket()` (defined later in the file, called from here) uses `_webSocketService` internally — since the field is now assigned before this call, no other change is needed there.

- [ ] **Step 5: If a test exists and doesn't already use `ProviderScope`, add it**

Same approach as before — also check whether this screen is reachable indirectly (e.g. from a profile-navigation test in another screen's test file, similar to what Batch B's Task 2/3 found for `SearchScreen`/`HomeScreen`).

- [ ] **Step 6: Run analyze + relevant test(s) + full suite**

Run: `flutter analyze` — expect clean.
If a test exists: run it, expect PASS.
Run: `flutter test` — expect 1383 passing (unchanged).

- [ ] **Step 7: Commit**

```bash
git add lib/presentation/screens/profile_screen.dart
git commit -m "refactor: convert ProfileScreen to ConsumerStatefulWidget, read ProfileRepository/UserService/WebSocketService via provider"
```

(Include the test file too if Step 5 changed one.)

---

## Overall verification

- [ ] `flutter analyze` — clean throughout, zero new warnings vs the 1383-test/clean-analyze baseline.
- [ ] `flutter test` — 1383 passing at the end (no new tests — pure DI rewiring of 3 files).
- [ ] Manual smoke test: `flutter run` — visit Profile (own and another user's), Achievements (list loads, logout works), Friends & Followers (tabs, WebSocket-driven updates, logout works from that screen too if reachable). Behavior identical to before this batch.
- [ ] `git log --oneline` shows one commit per task, each independently revertable.
- [ ] Confirm scope discipline: only the 3 named files (plus any test files touched) changed.
