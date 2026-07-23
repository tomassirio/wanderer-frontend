# Phase 4b (Batch A) Implementation Plan — Convert Auth-Flow Screens to Riverpod DI

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert the first batch of screens (`auth_screen.dart`, `verify_email_screen.dart`, `initial_screen.dart`) from manually constructing their own `AuthRepository`/`TokenStorage` instances to reading them from the Riverpod providers built in Phase 4a — the first of several batches covering all 25 screen/widget files identified in Phase 4's scoping.

**Architecture:** Each `StatefulWidget`/`State<X>` pair becomes `ConsumerStatefulWidget`/`ConsumerState<X>`, gaining access to `ref`. Every `final XService _x = XService();` field initializer (which runs before `ref` exists) becomes `late final XService _x;` declared at the field site and assigned via `_x = ref.read(xServiceProvider);` inside `initState()` — mirroring the `late final` + initState-assignment pattern this codebase already uses elsewhere (e.g. `trip_plans_screen.dart`'s existing `late final TripService _tripService;`). `ref.read` (not `ref.watch`) is correct here since these are one-time DI lookups, not values whose changes should trigger a rebuild.

**Tech Stack:** `flutter_riverpod` (provider graph from Phase 4a, `lib/core/providers/app_providers.dart`).

## Global Constraints

- `flutter analyze` zero new warnings; `flutter test` stays green throughout. Baseline on this branch: **1383 tests passing**.
- No change to any widget's public constructor signature or field (`startInSignup`, `initialUsername`, etc.) — only the internal dependency-construction mechanism changes.
- No behavior change — same auth flow, same verify-email flow, same initial-screen routing logic. This is a pure DI-wiring refactor.
- `ConsumerStatefulWidget`/`ConsumerState` come from `package:flutter_riverpod/flutter_riverpod.dart`, already a dependency.

---

## Task 1: `auth_screen.dart`

**Files:**
- Modify: `lib/presentation/screens/auth_screen.dart`
- Test: `test/widgets/auth_screen_test.dart` if it exists (check first; if not, no new test file is required — this is a mechanical DI-wiring change with no new observable behavior, verified by the existing test suite continuing to pass)

**Interfaces:**
- Consumes: `authRepositoryProvider` (`lib/core/providers/app_providers.dart`, Phase 4a).

- [ ] **Step 1: Check for an existing widget test**

Run: `find test -iname "*auth_screen*"`
If a test file exists, read it to confirm it doesn't directly instantiate `_AuthScreenState` internals (it shouldn't — Flutter widget tests interact via `find.byType`/`find.text`, not private state) and note whether it wraps `AuthScreen` in a `MaterialApp` alone or already inside a `ProviderScope`. If it only wraps in `MaterialApp`, this task must also wrap it in `ProviderScope` (Step 4) since `ConsumerStatefulWidget` requires an ancestor `ProviderScope` to resolve providers — without one, the widget throws at runtime/in tests.

- [ ] **Step 2: Convert the widget class**

In `lib/presentation/screens/auth_screen.dart`, add the import:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wanderer_frontend/core/providers/app_providers.dart';
```

Change the class declarations (currently `lib/presentation/screens/auth_screen.dart:11-20`):

```dart
class AuthScreen extends StatefulWidget {
  final bool startInSignup;
  final String? initialUsername;

  const AuthScreen(
      {super.key, this.startInSignup = false, this.initialUsername});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}
```

to:

```dart
class AuthScreen extends ConsumerStatefulWidget {
  final bool startInSignup;
  final String? initialUsername;

  const AuthScreen(
      {super.key, this.startInSignup = false, this.initialUsername});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}
```

- [ ] **Step 3: Convert the State class and repository construction**

Change (currently `lib/presentation/screens/auth_screen.dart:22-44`):

```dart
class _AuthScreenState extends State<AuthScreen> {
  final AuthRepository _repository = AuthRepository();
  final _formKey = GlobalKey<FormState>();
```

to:

```dart
class _AuthScreenState extends ConsumerState<AuthScreen> {
  late final AuthRepository _repository;
  final _formKey = GlobalKey<FormState>();
```

And change the existing `initState` (currently `:40-44`):

```dart
  @override
  void initState() {
    super.initState();
    _prefillUsername();
  }
```

to:

```dart
  @override
  void initState() {
    super.initState();
    _repository = ref.read(authRepositoryProvider);
    _prefillUsername();
  }
```

- [ ] **Step 4: If a widget test exists and doesn't already use `ProviderScope`, add it**

If Step 1 found a test file wrapping `AuthScreen` only in `MaterialApp`, add `ProviderScope` as the outermost wrapper in every `pumpWidget` call, e.g.:

```dart
await tester.pumpWidget(
  const ProviderScope(
    child: MaterialApp(home: AuthScreen()),
  ),
);
```

If no test file exists for this screen, skip this step — nothing to update.

- [ ] **Step 5: Run analyze + the relevant test(s)**

Run: `flutter analyze`
Expected: clean, no new warnings.

If a test file exists: `flutter test test/widgets/auth_screen_test.dart` (or wherever Step 1 found it) — expect PASS, same test count as before.

- [ ] **Step 6: Full suite**

Run: `flutter test`
Expected: 1383 tests passing (no new tests added in this task — pure rewiring), same as baseline.

- [ ] **Step 7: Commit**

```bash
git add lib/presentation/screens/auth_screen.dart
git commit -m "refactor: convert AuthScreen to ConsumerStatefulWidget, read AuthRepository via provider

First of several screen-conversion batches for Phase 4 (Riverpod DI).
AuthRepository is now sourced from authRepositoryProvider instead of
being constructed directly - same repository class, same behavior,
now shares the app-wide instance."
```

(If Step 4 required test changes, include the test file in this commit too.)

---

## Task 2: `verify_email_screen.dart`

**Files:**
- Modify: `lib/presentation/screens/verify_email_screen.dart`
- Test: `test/widgets/verify_email_screen_test.dart` if it exists (same check as Task 1)

**Interfaces:**
- Consumes: `authRepositoryProvider` (Phase 4a).

- [ ] **Step 1: Check for an existing widget test**

Run: `find test -iname "*verify_email*"` — same reasoning as Task 1 Step 1.

- [ ] **Step 2: Convert the widget class**

Add the same two imports as Task 1. Change (currently `lib/presentation/screens/verify_email_screen.dart:12-17`):

```dart
class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}
```

to:

```dart
class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}
```

- [ ] **Step 3: Convert the State class and repository construction**

Change (currently `:19-36`):

```dart
class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final AuthRepository _repository = AuthRepository();
  final _tokenController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  bool _verified = false;

  @override
  void initState() {
    super.initState();
    // On web, read the token from the URL query string automatically
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _tryVerifyFromUrl();
      });
    }
  }
```

to:

```dart
class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  late final AuthRepository _repository;
  final _tokenController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  bool _verified = false;

  @override
  void initState() {
    super.initState();
    _repository = ref.read(authRepositoryProvider);
    // On web, read the token from the URL query string automatically
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _tryVerifyFromUrl();
      });
    }
  }
```

- [ ] **Step 4: If a widget test exists and doesn't already use `ProviderScope`, add it**

Same approach as Task 1 Step 4.

- [ ] **Step 5: Run analyze + the relevant test(s)**

Run: `flutter analyze` — expect clean.
If a test exists: run it, expect PASS.

- [ ] **Step 6: Full suite**

Run: `flutter test`
Expected: 1383 tests passing.

- [ ] **Step 7: Commit**

```bash
git add lib/presentation/screens/verify_email_screen.dart
git commit -m "refactor: convert VerifyEmailScreen to ConsumerStatefulWidget, read AuthRepository via provider"
```

(Include the test file too if Step 4 changed one.)

---

## Task 3: `initial_screen.dart`

**Context:** Unlike Tasks 1-2, this screen doesn't hold `TokenStorage` as a field — it constructs a local `final tokenStorage = TokenStorage();` inside the `_checkAuthState()` method body. The conversion is the same class-level change (`StatefulWidget`→`ConsumerStatefulWidget`), but the provider read happens at the point of use inside the method rather than in `initState`.

**Files:**
- Modify: `lib/presentation/screens/initial_screen.dart`
- Test: `test/widgets/initial_screen_test.dart` or similar if it exists (check first)

**Interfaces:**
- Consumes: `tokenStorageProvider` (Phase 4a).

- [ ] **Step 1: Check for an existing widget test**

Run: `find test -iname "*initial_screen*"` — same reasoning as Task 1 Step 1.

- [ ] **Step 2: Convert the widget class**

Add the same two imports as Task 1. Change (currently `lib/presentation/screens/initial_screen.dart:9-14`):

```dart
class InitialScreen extends StatefulWidget {
  const InitialScreen({super.key});

  @override
  State<InitialScreen> createState() => _InitialScreenState();
}
```

to:

```dart
class InitialScreen extends ConsumerStatefulWidget {
  const InitialScreen({super.key});

  @override
  ConsumerState<InitialScreen> createState() => _InitialScreenState();
}
```

- [ ] **Step 3: Convert the State class and the local TokenStorage construction**

Change (currently `:16-26`):

```dart
class _InitialScreenState extends State<InitialScreen> {
  bool _isChecking = true;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    // Proactively refresh the access token if it has expired while the app
    // was closed.  This prevents the user from appearing "logged out" when
    // they still have a valid refresh token.
    try {
      final tokenStorage = TokenStorage();
```

to:

```dart
class _InitialScreenState extends ConsumerState<InitialScreen> {
  bool _isChecking = true;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    // Proactively refresh the access token if it has expired while the app
    // was closed.  This prevents the user from appearing "logged out" when
    // they still have a valid refresh token.
    try {
      final tokenStorage = ref.read(tokenStorageProvider);
```

Note: `import 'package:wanderer_frontend/data/storage/token_storage.dart';` (currently line 3) can likely be removed if `TokenStorage` is no longer referenced by name anywhere else in this file — check with `grep -n "TokenStorage" lib/presentation/screens/initial_screen.dart` after the edit; if the only remaining reference is the import itself, remove it (the type is still used as the provider's generic parameter internally in `app_providers.dart`, not here).

- [ ] **Step 4: If a widget test exists and doesn't already use `ProviderScope`, add it**

Same approach as Task 1 Step 4.

- [ ] **Step 5: Run analyze + the relevant test(s)**

Run: `flutter analyze` — expect clean, and confirm the `token_storage.dart` import removal (if made) didn't leave anything else broken.
If a test exists: run it, expect PASS.

- [ ] **Step 6: Full suite**

Run: `flutter test`
Expected: 1383 tests passing.

- [ ] **Step 7: Commit**

```bash
git add lib/presentation/screens/initial_screen.dart
git commit -m "refactor: convert InitialScreen to ConsumerStatefulWidget, read TokenStorage via provider"
```

(Include the test file too if Step 4 changed one.)

---

## Overall verification

- [ ] `flutter analyze` — clean throughout, zero new warnings vs the 1383-test/clean-analyze baseline.
- [ ] `flutter test` — 1383 passing at the end (no new tests added in this batch — pure DI rewiring of 3 files, existing tests are the regression net).
- [ ] Manual smoke test: `flutter run` — launch the app fresh (initial screen routing to landing/home based on login state), log out and back in (auth screen), and if reachable, exercise the email-verification flow. Behavior should be identical to before this batch.
- [ ] `git log --oneline` shows one commit per task, each independently revertable.
- [ ] Confirm scope discipline: `git diff --stat <task-1-base>..HEAD` touches only the 3 named screen files (plus any test files Step 4 touched) — no other screens converted yet, no changes to `lib/core/providers/app_providers.dart`.
