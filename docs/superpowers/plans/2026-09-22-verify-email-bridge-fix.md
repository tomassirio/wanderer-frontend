# Verify-Email Bridge Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give users who tap the email verification link on a native mobile install a working path back into the Wanderer app, instead of being stranded in a browser with no way back.

**Architecture:** The verification email link hits the backend (`wanderer-auth`) directly and returns a server-rendered HTML page — it never touches the Flutter app, on any platform, because there is no OS-level deep-link registration (confirmed: no Android intent-filter, no iOS associated domains/URL scheme, no `app_links`/`uni_links` package). Building real OS deep linking is out of scope (rejected in favor of the minimal fix). Instead: (1) fix two small existing bugs in the Flutter app's already-built (but currently unreachable) manual-token verification screen, (2) make that screen reachable from the app's own UI so a user who has the token (shown in the email) can paste it in without ever needing a working deep link, and (3) stop the backend's confirmation page from auto-redirecting mobile users into a website login they don't want.

**Tech Stack:** Flutter (Dart) frontend with Riverpod + mockito for tests; Spring Boot (Java) backend with MockMvc for tests.

## Global Constraints

- No new dependencies (no deep-link package, no native manifest/plist changes).
- No l10n/.arb changes — use plain hardcoded English strings for new UI text, matching existing precedent in the codebase (e.g. `create_trip_screen.dart` has multiple hardcoded English labels alongside l10n-driven ones).
- Frontend tasks operate in repo `wanderer-frontend` (already on branch `refactor/phase-5-notifier-extraction`). Backend task operates in the separate repo `wanderer-backend`.

---

### Task 1: `VerifyEmailScreen` accepts an initial token and auto-verifies on any platform

**Files:**
- Modify: `wanderer-frontend/lib/presentation/screens/verify_email_screen.dart`
- Test: `wanderer-frontend/test/widgets/verify_email_screen_test.dart` (new)

**Interfaces:**
- Produces: `VerifyEmailScreen({Key? key, String? initialToken})` — when `initialToken` is non-null and non-empty, the screen calls its existing `_verifyToken(token)` automatically on init, regardless of `kIsWeb`.

- [ ] **Step 1: Add mockito mock generation for `AuthRepository`**

Add to the top of a new test file:

```dart
// wanderer-frontend/test/widgets/verify_email_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:wanderer_frontend/core/providers/app_providers.dart';
import 'package:wanderer_frontend/data/models/auth_models.dart';
import 'package:wanderer_frontend/data/repositories/auth_repository.dart';
import 'package:wanderer_frontend/presentation/screens/verify_email_screen.dart';

import 'verify_email_screen_test.mocks.dart';

@GenerateMocks([AuthRepository])
void main() {}
```

- [ ] **Step 2: Run codegen to generate the mock (expected to produce an empty/no-op mock file since `main()` has no tests yet)**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: `test/widgets/verify_email_screen_test.mocks.dart` is generated, defining `MockAuthRepository`.

- [ ] **Step 3: Write the failing test**

Replace the `void main() {}` body from Step 1 with:

```dart
void main() {
  late MockAuthRepository mockRepository;

  setUp(() {
    mockRepository = MockAuthRepository();
  });

  Widget buildScreen({String? initialToken}) {
    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(mockRepository),
      ],
      child: MaterialApp(
        home: VerifyEmailScreen(initialToken: initialToken),
      ),
    );
  }

  testWidgets(
    'auto-verifies with initialToken without requiring kIsWeb',
    (tester) async {
      when(mockRepository.verifyEmail('token-abc')).thenAnswer((_) async {});

      await tester.pumpWidget(buildScreen(initialToken: 'token-abc'));
      await tester.pumpAndSettle();

      verify(mockRepository.verifyEmail('token-abc')).called(1);
      expect(find.text('Email Verified!'), findsOneWidget);
    },
  );

  testWidgets(
    'shows manual entry form when no initialToken is provided',
    (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      verifyNever(mockRepository.verifyEmail(any));
      expect(find.byType(TextField), findsOneWidget);
    },
  );
}
```

- [ ] **Step 4: Run test to verify it fails**

Run: `flutter test test/widgets/verify_email_screen_test.dart`
Expected: FAIL — `VerifyEmailScreen` has no `initialToken` parameter (compile error), or first test fails because auto-verify never happens.

- [ ] **Step 5: Implement `initialToken` support**

In `lib/presentation/screens/verify_email_screen.dart`, change the widget declaration and `initState`:

```dart
class VerifyEmailScreen extends ConsumerStatefulWidget {
  final String? initialToken;

  const VerifyEmailScreen({super.key, this.initialToken});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}
```

```dart
  @override
  void initState() {
    super.initState();
    _repository = ref.read(authRepositoryProvider);

    final initialToken = widget.initialToken;
    if (initialToken != null && initialToken.isNotEmpty) {
      // A token was already extracted by the router (e.g. from a
      // /verify-email?token=... route) — verify immediately on any
      // platform instead of only on web.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _verifyToken(initialToken);
      });
    } else if (kIsWeb) {
      // Fallback: read the token from the browser URL directly (covers
      // navigation that bypassed the router's own query-param parsing).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _tryVerifyFromUrl();
      });
    }
  }
```

Leave the rest of the file (`_tryVerifyFromUrl`, `_verifyToken`, build methods) unchanged.

- [ ] **Step 6: Run test to verify it passes**

Run: `flutter test test/widgets/verify_email_screen_test.dart`
Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add lib/presentation/screens/verify_email_screen.dart test/widgets/verify_email_screen_test.dart test/widgets/verify_email_screen_test.mocks.dart
git commit -m "feat: VerifyEmailScreen auto-verifies from an initial token on any platform"
```

---

### Task 2: `VerifyEmailRouteStrategy` extracts and passes the token

**Files:**
- Modify: `wanderer-frontend/lib/core/routing/strategies/verify_email_route_strategy.dart`
- Test: `wanderer-frontend/test/core/verify_email_route_strategy_test.dart` (new)

**Interfaces:**
- Consumes: `VerifyEmailScreen({String? initialToken})` from Task 1.
- Produces: nothing further consumed by other tasks.

- [ ] **Step 1: Write the failing test**

```dart
// wanderer-frontend/test/core/verify_email_route_strategy_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wanderer_frontend/core/routing/strategies/verify_email_route_strategy.dart';
import 'package:wanderer_frontend/presentation/screens/verify_email_screen.dart';

void main() {
  group('VerifyEmailRouteStrategy', () {
    late VerifyEmailRouteStrategy strategy;

    setUp(() {
      strategy = VerifyEmailRouteStrategy();
    });

    group('matches', () {
      test('matches /verify-email path', () {
        expect(strategy.matches(Uri.parse('/verify-email')), isTrue);
      });

      test('matches /verify-email with token query parameter', () {
        expect(
          strategy.matches(Uri.parse('/verify-email?token=abc123')),
          isTrue,
        );
      });

      test('does not match other paths', () {
        expect(strategy.matches(Uri.parse('/login')), isFalse);
      });
    });

    group('build', () {
      testWidgets('passes token query parameter to VerifyEmailScreen',
          (tester) async {
        final uri = Uri.parse('/verify-email?token=abc123');
        final settings =
            const RouteSettings(name: '/verify-email?token=abc123');
        final route = strategy.build(uri, settings);

        await tester.pumpWidget(MaterialApp(onGenerateRoute: (_) => route));
        await tester.pump();

        final screen = tester.widget<VerifyEmailScreen>(
          find.byType(VerifyEmailScreen),
        );
        expect(screen.initialToken, 'abc123');
      });

      testWidgets('builds VerifyEmailScreen without token when absent',
          (tester) async {
        final uri = Uri.parse('/verify-email');
        final settings = const RouteSettings(name: '/verify-email');
        final route = strategy.build(uri, settings);

        await tester.pumpWidget(MaterialApp(onGenerateRoute: (_) => route));
        await tester.pump();

        final screen = tester.widget<VerifyEmailScreen>(
          find.byType(VerifyEmailScreen),
        );
        expect(screen.initialToken, isNull);
      });
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/verify_email_route_strategy_test.dart`
Expected: FAIL — `screen.initialToken` is `null` in the first test (route strategy doesn't pass it yet).

- [ ] **Step 3: Implement the fix**

```dart
// wanderer-frontend/lib/core/routing/strategies/verify_email_route_strategy.dart
import 'package:flutter/material.dart';
import 'package:wanderer_frontend/core/routing/route_strategy.dart';
import 'package:wanderer_frontend/presentation/helpers/page_transitions.dart';
import 'package:wanderer_frontend/presentation/screens/verify_email_screen.dart';

/// Handles `/verify-email` → VerifyEmailScreen.
class VerifyEmailRouteStrategy implements RouteStrategy {
  @override
  bool matches(Uri uri) => uri.path == '/verify-email';

  @override
  PageRoute build(Uri uri, RouteSettings settings) {
    final token = uri.queryParameters['token'];
    return PageTransitions.fade(
      VerifyEmailScreen(initialToken: token),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/verify_email_route_strategy_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/core/routing/strategies/verify_email_route_strategy.dart test/core/verify_email_route_strategy_test.dart
git commit -m "fix: VerifyEmailRouteStrategy passes the token query param through, matching the TripRouteStrategy pattern"
```

---

### Task 3: Discoverable "enter verification code manually" path from the registration-pending screen

This is the change that actually helps a stranded mobile user: the verification email always displays the raw token (see `verification-email.html`'s `token-box`), but there was no button anywhere in the app to reach the screen that accepts it. This adds one.

**Files:**
- Modify: `wanderer-frontend/lib/presentation/screens/auth_screen.dart`
- Test: `wanderer-frontend/test/widgets/auth_screen_registration_pending_test.dart` (new)

**Interfaces:**
- Consumes: `VerifyEmailScreen({String? initialToken})` from Task 1 (called with no argument here, since the user types the token in manually).

- [ ] **Step 1: Add mock generation for `AuthRepository` in the new test file**

```dart
// wanderer-frontend/test/widgets/auth_screen_registration_pending_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:wanderer_frontend/core/providers/app_providers.dart';
import 'package:wanderer_frontend/data/models/auth_models.dart';
import 'package:wanderer_frontend/data/repositories/auth_repository.dart';
import 'package:wanderer_frontend/presentation/screens/auth_screen.dart';
import 'package:wanderer_frontend/presentation/screens/verify_email_screen.dart';

import 'auth_screen_registration_pending_test.mocks.dart';

@GenerateMocks([AuthRepository])
void main() {}
```

- [ ] **Step 2: Run codegen**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: `test/widgets/auth_screen_registration_pending_test.mocks.dart` generated, defining `MockAuthRepository`.

- [ ] **Step 3: Write the failing test**

Replace `void main() {}` with:

```dart
void main() {
  late MockAuthRepository mockRepository;

  setUp(() {
    mockRepository = MockAuthRepository();
  });

  Future<void> fillAndSubmitRegistrationForm(WidgetTester tester) async {
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'newuser'); // username
    await tester.enterText(fields.at(1), 'newuser@example.com'); // email
    await tester.enterText(fields.at(2), 'Password1!'); // password
    await tester.enterText(fields.at(3), 'Password1!'); // confirm password
    await tester.tap(find.text('Sign Up'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'shows a manual verification entry point after registering, '
    'which navigates to VerifyEmailScreen',
    (tester) async {
      when(mockRepository.register('newuser', 'newuser@example.com', 'Password1!'))
          .thenAnswer((_) async => RegisterPendingResponse(
                message: 'Registration pending.',
              ));

      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(mockRepository),
          ],
          child: const MaterialApp(
            home: AuthScreen(startInSignup: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await fillAndSubmitRegistrationForm(tester);

      expect(find.text('Enter verification code manually'), findsOneWidget);

      await tester.tap(find.text('Enter verification code manually'));
      await tester.pumpAndSettle();

      expect(find.byType(VerifyEmailScreen), findsOneWidget);
    },
  );
}
```

- [ ] **Step 4: Run test to verify it fails**

Run: `flutter test test/widgets/auth_screen_registration_pending_test.dart`
Expected: FAIL — `find.text('Enter verification code manually')` finds nothing.

- [ ] **Step 5: Implement the button**

In `lib/presentation/screens/auth_screen.dart`, add the import and a navigation handler, then wire it into `_buildRegistrationPendingView`:

```dart
import 'package:wanderer_frontend/presentation/screens/verify_email_screen.dart';
```

```dart
  void _navigateToManualVerification() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const VerifyEmailScreen()),
    );
  }
```

Then extend `_buildRegistrationPendingView()`'s `Column` children, right after the existing "Back to Login" `TextButton`:

```dart
            TextButton(
              onPressed: () {
                setState(() {
                  _registrationPending = false;
                  _isLogin = true;
                  _errorMessage = null;
                  _formKey.currentState?.reset();
                });
              },
              child: Text(l10n.backToLogin),
            ),
            TextButton(
              onPressed: _navigateToManualVerification,
              child: const Text('Enter verification code manually'),
            ),
```

- [ ] **Step 6: Run test to verify it passes**

Run: `flutter test test/widgets/auth_screen_registration_pending_test.dart`
Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add lib/presentation/screens/auth_screen.dart test/widgets/auth_screen_registration_pending_test.dart test/widgets/auth_screen_registration_pending_test.mocks.dart
git commit -m "feat: add discoverable manual email-verification entry point to the pending-registration screen"
```

---

### Task 4: Backend confirmation page stops auto-redirecting to the web login

**Repo:** `wanderer-backend` (separate git repo from the frontend tasks above).

**Files:**
- Modify: `wanderer-backend/wanderer-auth/src/main/resources/templates/email/verification-success.html`
- Modify: `wanderer-backend/wanderer-auth/src/test/java/com/tomassirio/wanderer/auth/controller/AuthControllerTest.java:295-318`

**Interfaces:** none (template + test only, no code interface changes).

- [ ] **Step 1: Extend the failing test first**

In `AuthControllerTest.java`, extend the existing `verifyEmailViaLink_whenValidToken_shouldReturnHtmlSuccess` test (around line 295) with two more assertions, keeping the existing ones:

```java
    @Test
    void verifyEmailViaLink_whenValidToken_shouldReturnHtmlSuccess() throws Exception {
        LoginResponse response =
                new LoginResponse(
                        "jwt.access.token", "refresh.token", "Bearer", 3600000L, "testuser");
        when(authService.verifyEmail("valid.token")).thenReturn(response);

        mockMvc.perform(
                        get("/api/1/auth/verify-email")
                                .param("token", "valid.token")
                                .accept(MediaType.TEXT_HTML))
                .andExpect(status().isOk())
                .andExpect(
                        content().string(org.hamcrest.Matchers.containsString("Email Verified!")))
                .andExpect(
                        content()
                                .string(
                                        org.hamcrest.Matchers.containsString(
                                                "Your email has been verified successfully")))
                .andExpect(
                        content()
                                .string(
                                        org.hamcrest.Matchers.containsString(
                                                "/login?username=testuser")))
                .andExpect(
                        content()
                                .string(
                                        org.hamcrest.Matchers.containsString(
                                                "Go back to the Wanderer app")))
                .andExpect(
                        content()
                                .string(
                                        org.hamcrest.Matchers.not(
                                                org.hamcrest.Matchers.containsString(
                                                        "Redirecting to login"))));
    }
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mvn -pl wanderer-auth test -Dtest=AuthControllerTest#verifyEmailViaLink_whenValidToken_shouldReturnHtmlSuccess`
Expected: FAIL — template still contains "Redirecting to login" and not "Go back to the Wanderer app".

- [ ] **Step 3: Update the template**

In `verification-success.html`, remove line 6 (the auto-redirect meta tag):

```html
    <meta http-equiv="refresh" content="5;url={{loginUrl}}">
```

Replace the body copy block:

```html
                <h2>Email Verified!</h2>
                <p>Your email has been verified successfully. You can now log in to your account and start tracking your adventures.</p>
                <p class="redirect-text">Redirecting to login in <span id="countdown">5</span> seconds&hellip; or <a href="{{loginUrl}}">click here</a></p>
```

with:

```html
                <h2>Email Verified!</h2>
                <p>Your email has been verified successfully. You can now log in to your account and start tracking your adventures.</p>
                <p class="redirect-text">Go back to the Wanderer app on your phone and log in &mdash; or <a href="{{loginUrl}}">log in on the web</a> instead.</p>
```

And remove the now-unused countdown script at the bottom of the file:

```html
    <script>
        var seconds = 5;
        var el = document.getElementById('countdown');
        setInterval(function() {
            seconds--;
            if (el) el.textContent = seconds;
        }, 1000);
    </script>
```

- [ ] **Step 4: Run test to verify it passes**

Run: `mvn -pl wanderer-auth test -Dtest=AuthControllerTest#verifyEmailViaLink_whenValidToken_shouldReturnHtmlSuccess`
Expected: PASS

- [ ] **Step 5: Run the full auth module test suite to check nothing else references the removed markup**

Run: `mvn -pl wanderer-auth test`
Expected: PASS (no other test asserts on "Redirecting to login" or the countdown script)

- [ ] **Step 6: Commit**

```bash
git add wanderer-auth/src/main/resources/templates/email/verification-success.html wanderer-auth/src/test/java/com/tomassirio/wanderer/auth/controller/AuthControllerTest.java
git commit -m "fix: stop auto-redirecting verified users into the web login; point them back to the app they installed"
```

---

## Self-Review Notes

- **Spec coverage:** Task 1+2 fix the two concrete bugs found in root-cause investigation (dropped token, `kIsWeb` gate). Task 3 is the load-bearing fix — a discoverable in-app path that doesn't depend on any deep-link plumbing (none exists, and building it was explicitly out of scope). Task 4 stops the backend from actively working against Task 3 by yanking mobile users into a web login. All four together close the "verify → stranded outside the app" gap without adding deep-link infrastructure.
- **Placeholder scan:** none found — every step has complete code.
- **Type consistency:** `VerifyEmailScreen({String? initialToken})` defined in Task 1 is used identically in Task 2's route strategy and Task 3's manual-entry button (called with no argument).
