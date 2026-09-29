# Google SSO — Flutter Frontend Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** "Continue with Google" on the auth screen (web, Android, iOS), completing the backend SSO contract (PKCE-bound one-time code → Wanderer tokens) and logging the user in exactly like password login does.

**Architecture:** The backend owns the Google handshake. The client (1) generates a PKCE pair (S256), (2) opens `<authBaseUrl>/oauth2/authorization/google?return_to=<callback>&code_challenge=<challenge>&code_challenge_method=S256`, (3) receives `<callback>?code=…` (or `?error=sso_failed`), (4) `POST <authBaseUrl>/sso/exchange {code, codeVerifier}` → `AuthResponse`, (5) persists tokens + profile like `AuthService.login`. **Web** uses a full-page redirect: the verifier is persisted in `SharedPreferences` (localStorage) before leaving and a new route `/auth/sso-callback` finishes the flow. **Mobile** uses `flutter_web_auth_2` (system browser / ASWebAuthenticationSession) with callback scheme `wanderer` (`wanderer://auth/sso-callback`); the verifier stays in memory. Providers are data (`SsoProvider` with an `id`), so a new backend provider only needs a new constant + button.

**Tech Stack:** Flutter 3.35 (CI) / Dart 3.5+, `http`, `shared_preferences`, new deps `flutter_web_auth_2` and `crypto`.

## Backend contract (fixed — do not change)
- Start (browser navigation, not XHR): `GET {authBaseUrl}/oauth2/authorization/{providerId}` with query `return_to` (exact-match allowlisted server-side), `code_challenge` (base64url no padding, 43 chars, = BASE64URL(SHA256(ASCII(verifier)))), `code_challenge_method=S256`.
  - `authBaseUrl` is `http://localhost:8083/api/1/auth` locally, `/api/auth` (web, via nginx) or `https://<host>/api/auth` (mobile dart-define) in deployed envs; all three reach the backend correctly.
- Callback: `{return_to}?code=<code>` on success, `{return_to}?error=sso_failed` on any failure (cancel, unverified email, disabled account, …).
- Exchange: `POST {authBaseUrl}/sso/exchange` JSON `{"code": "...", "codeVerifier": "..."}` → 200 `{accessToken, refreshToken, tokenType, expiresIn, username}`; 400 for unknown/expired/used code or wrong verifier (code is single-use and burned on any attempt). No auth header.
- Verifier: 43–128 chars from `[A-Za-z0-9-._~]`; generate a fresh one per login from 32 bytes of `Random.secure()` base64url-encoded without padding (43 chars).

## Global Constraints
- `flutter pub get` first; `make verify` (format + analyze + test) must pass with zero analyzer warnings; formatting via `dart format .`.
- State management: `StatefulWidget` + `setState` (existing screens use `ConsumerStatefulWidget` with `ref.read(...Provider)` — follow the file you're in). No new state libraries.
- Import barrels (`auth_models.dart`, `clients.dart`, `services.dart`) where they exist.
- All user-facing strings via `context.l10n` with keys added to **all four** translation maps (en, es, fr, nl) in `lib/core/l10n/translations/`.
- Web UI follows `docs/design-system.md` and the existing `WebAuthForm` look; mobile follows the existing `AuthForm` look.
- Tests mirror `lib/` under `test/`; follow the existing patterns (client tests inject `MockHttpClient`/`MockTokenStorage` into `ApiClient`; `test/services/auth_service_test.dart` uses mockito `@GenerateMocks` — regenerate mocks with `dart run build_runner build --delete-conflicting-outputs` if you change mocked classes).
- Don't change `pubspec.yaml` `version`. Don't commit `.env` or `web/index.html.template`.
- Commits end with a blank line then `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

---

### Task 1: PKCE + SSO data layer

**Files:**
- Modify: `pubspec.yaml` (add `crypto` and `flutter_web_auth_2` — latest stable versions compatible with the SDK constraint; run `flutter pub get`)
- Create: `lib/data/services/sso/pkce.dart` — `class PkcePair { final String verifier; final String challenge; }` and `PkcePair.generate({Random? random})` + `static String challengeFor(String verifier)`.
- Create: `lib/data/models/sso_provider.dart` — `class SsoProvider { final String id; const SsoProvider._(this.id); static const google = SsoProvider._('google'); }` (export via `auth_models.dart` barrel if that barrel covers auth models).
- Create: `lib/data/models/requests/sso_exchange_request.dart` — `{code, codeVerifier}` with `toJson()` → `{'code':…, 'codeVerifier':…}`; export via the auth models barrel.
- Modify: `lib/core/constants/api_endpoints.dart` — `static const String authSsoExchange = '/sso/exchange';`, `static String ssoAuthorizationPath(String providerId) => '/oauth2/authorization/$providerId';`, and `static const String ssoWebCallbackPath = '/auth/sso-callback';`, `static const String ssoMobileCallbackScheme = 'wanderer';`, `static const String ssoMobileCallbackUrl = 'wanderer://auth/sso-callback';`.
- Modify: `lib/data/client/auth/auth_client.dart` — `Future<AuthResponse> exchangeSsoCode(SsoExchangeRequest request)` (POST, `requireAuth: false`, `handleResponse(..., AuthResponse.fromJson)`).
- Modify: `lib/data/services/auth_service.dart` — extract the duplicated "save tokens, fetch profile, save again + avatar" block used by `login` and `verifyEmail` into one private `_persistSession(AuthResponse)`; add `Future<AuthResponse> completeSsoLogin({required String code, required String codeVerifier})` that calls `exchangeSsoCode` then `_persistSession`.
- Create: `lib/data/services/sso/sso_service.dart` — builds the authorization URL and holds the web verifier:
  - `Uri buildAuthorizationUri({required SsoProvider provider, required String returnTo, required String codeChallenge})` — resolves `ApiEndpoints.authBaseUrl + ssoAuthorizationPath(provider.id)`; if `authBaseUrl` is relative (starts with `/`), resolve it against `ApiEndpoints.appBaseUrl`; adds `return_to`, `code_challenge`, `code_challenge_method=S256` query params (properly encoded).
  - `String webReturnUri()` → `ApiEndpoints.appBaseUrl` (trailing slashes trimmed) + `ssoWebCallbackPath`.
  - `Future<void> savePendingVerifier(String verifier)` / `Future<String?> takePendingVerifier()` (read-and-delete) using `SharedPreferences` key `sso_pending_code_verifier`.
- Modify: `lib/data/repositories/auth_repository.dart` — `Future<void> completeSsoLogin(String code, String codeVerifier)` delegating to `AuthService`.

**Tests (write first):**
- `test/services/sso/pkce_test.dart`: RFC 7636 Appendix B vector — `challengeFor('dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk') == 'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM'`; `generate()` verifier is 43 chars of `[A-Za-z0-9_-]`, challenge 43 chars, two generations differ.
- `test/services/sso/sso_service_test.dart`: absolute authBaseUrl → URI with exact path + all three query params (encoded `wanderer://auth/sso-callback`); `webReturnUri()` shape; verifier save/take round-trip and take clears (use `SharedPreferences.setMockInitialValues({})`). (If `ApiEndpoints` can't be overridden in tests, make `SsoService` take `authBaseUrl`/`appBaseUrl` via optional constructor params defaulting to `ApiEndpoints` — keep it minimal.)
- `test/client/auth/auth_client_test.dart`: `exchangeSsoCode` POSTs to `/sso/exchange` with `{code, codeVerifier}`, no auth header, parses `AuthResponse`; 400 throws.
- `test/services/auth_service_test.dart`: `completeSsoLogin` saves tokens and profile (same assertions as the existing login test); existing login/verifyEmail tests still pass after the `_persistSession` extraction.

- [ ] Write failing tests → run → implement → `flutter test` on those files → `make verify` → commit `feat(auth): add PKCE and SSO code exchange to the auth data layer`.

---

### Task 2: Web callback route

**Files:**
- Create: `lib/presentation/screens/sso_callback_screen.dart` — `SsoCallbackScreen({String? code, String? error})` (`ConsumerStatefulWidget`, like `VerifyEmailScreen`): on init, if `error != null` or `code == null` → show an error state with a "Back to login" button (`pushReplacementNamed('/auth')`, same as VerifyEmailScreen); else `takePendingVerifier()` — missing → error state (e.g. flow started in another browser / storage cleared); present → `authRepository.completeSsoLogin(code, verifier)` → on success `pushNamedAndRemoveUntil('/', (_) => false)` (same as VerifyEmailScreen); on failure → error state. Loading state while exchanging. Web design system styling consistent with VerifyEmailScreen.
- Create: `lib/core/routing/strategies/sso_callback_route_strategy.dart` — matches `uri.path == ApiEndpoints.ssoWebCallbackPath`, passes `code`/`error` query params; register in `AppRouter._strategies` (before `LoginRouteStrategy` if its matcher could also match `/auth/...` — check).
- l10n keys (all four languages): `ssoSigningIn` ("Signing you in…"), `ssoFailed` ("We couldn't sign you in with Google. Please try again."), `ssoSessionExpired` ("Your sign-in link expired or was opened in a different browser. Please try again."), reuse existing "back to login" key if present.

**Tests:** `test/core/routing/sso_callback_route_strategy_test.dart` (matches/doesn't match, passes params); `test/widgets/…` or `test/presentation/…` widget test for `SsoCallbackScreen`: error param → error text shown and exchange never called; missing verifier → session-expired text; success → repository called with code + verifier. Follow the existing screen/widget test patterns (inject a fake repository via provider override or constructor).

- [ ] TDD → `make verify` → commit `feat(auth): handle SSO web callback route`.

---

### Task 3: "Continue with Google" button + mobile flow + platform config

**Files:**
- Create: `lib/presentation/widgets/auth/sso_button.dart` — `SsoButton({required SsoProvider provider, required VoidCallback? onPressed, bool isLoading = false})` rendering "Continue with Google" (l10n key `continueWithGoogle`; map provider id → label key inside the widget). No Google logo asset required; an outlined button consistent with each layout is fine (don't add trademark assets).
- Modify: `lib/presentation/widgets/auth/auth_form.dart` (mobile) and the `WebAuthForm` in `web_auth_layout.dart` (web): add an "or" divider (l10n `orDivider`) + `SsoButton` below the submit button, in both login and signup modes; new required-or-optional callback `onSsoPressed` passed from `AuthScreen`.
- Modify: `lib/presentation/screens/auth_screen.dart` — `_startSso(SsoProvider provider)`:
  - generate `PkcePair`;
  - **web** (`kIsWeb`): `savePendingVerifier(verifier)`, then navigate the whole page to `buildAuthorizationUri(returnTo: webReturnUri(), …)` via `url_launcher` `launchUrl(uri, webOnlyWindowName: '_self')` (already a dependency);
  - **mobile**: `FlutterWebAuth2.authenticate(url: uri.toString(), callbackUrlScheme: ApiEndpoints.ssoMobileCallbackScheme)` with `returnTo: ApiEndpoints.ssoMobileCallbackUrl`; parse the returned URL; `error` → show `ssoFailed` in the existing error area; `code` → `completeSsoLogin(code, verifier)` → `Navigator.of(context).pop(true)` (same as password login success); user cancel (`PlatformException` with code `CANCELED`) → silently stop loading, no error.
  - loading/disabled state while in flight; errors reuse `_errorMessage`.
  - keep the platform branching small and testable (e.g. a tiny `SsoLauncher` abstraction with web/mobile implementations injected into the screen is acceptable if it's the simplest way to unit-test; otherwise keep it inline).
- Modify: `android/app/src/main/AndroidManifest.xml` — add the `flutter_web_auth_2` callback activity inside `<application>`:
  ```xml
  <activity
      android:name="com.linusu.flutter_web_auth_2.CallbackActivity"
      android:exported="true">
      <intent-filter android:label="flutter_web_auth_2">
          <action android:name="android.intent.action.VIEW" />
          <category android:name="android.intent.category.DEFAULT" />
          <category android:name="android.intent.category.BROWSABLE" />
          <data android:scheme="wanderer" />
      </intent-filter>
  </activity>
  ```
  (verify the class name against the installed package version's README). iOS needs no Info.plist change (ASWebAuthenticationSession); confirm against the package README.
- l10n (all four languages): `continueWithGoogle`, `orDivider`.

**Tests:** widget tests that the Google button renders in login and signup modes on both `AuthForm` and `WebAuthForm` and invokes the callback; unit test for the callback-URL parsing (code / error / neither).

- [ ] TDD → `make verify` → commit `feat(auth): add Continue with Google on web and mobile`.

---

### Task 4: Docs

- Modify: `README.md` (or the most relevant existing doc under `docs/`) — short "Google sign-in" section: how the flow works, that `SSO_ALLOWED_RETURN_URIS` on the backend must contain `<appBaseUrl>/auth/sso-callback` for each web env and `wanderer://auth/sso-callback` for mobile, and that mobile builds need `AUTH_BASE_URL` pointing at the public host.
- [ ] Commit `docs: document Google sign-in`.
