# Phase 3 Implementation Plan — ApiClient Retry Collapse + UI-Layer HTTP Extraction

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Collapse the 401-retry-then-refresh boilerplate copy-pasted across 7 `ApiClient` methods into one private helper, and move the one raw `package:http` call living in the UI layer (a third-party URL-shortener call in `trip_share_dialog.dart`) into a proper service.

**Architecture:** A new private `ApiClient._withAuthRetry(bool requireAuth, Future<http.Response> Function() attempt)` runs the proactive-refresh-then-attempt-then-retry-on-401 sequence once; every one of `get`/`post`/`postRaw`/`put`/`patch`/`delete`/`postMultipart` becomes a thin wrapper that builds its request as a closure and hands it to this helper. Separately, a new `UrlShortenerService` (mirroring the codebase's existing "optional constructor param defaulting to `http.Client()`" testability pattern) replaces the direct `package:http` call in `TripShareDialog`.

**Tech Stack:** Flutter/Dart, `http`, `mockito` (existing test doubles), `flutter_test`.

## Global Constraints

- `flutter analyze` zero new warnings; `flutter test` stays green throughout. Baseline on this branch: **1363 tests passing**.
- This is a **pure behavior-preserving refactor** for the 5 already-tested methods (`get`/`post`/`put`/`patch`/`delete` all have existing 401-retry tests in `test/client/api_client_test.dart`) — no new tests are required for those, only "still green before and after."
- `postRaw` and `postMultipart` currently have **zero test coverage** (verified: `grep -n "test(" test/client/api_client_test.dart` shows no `postRaw`/`multipart` cases) — this plan adds tests for both as part of the safety net before/while refactoring them, since there's no existing characterization to lean on.
- `postMultipart`'s auth header is hardcoded to `'Bearer $token'` (not going through `_buildHeaders`, which would use the stored `tokenType`) — this is a **pre-existing inconsistency**, not something this plan fixes. Preserve it exactly; do not silently "correct" it to use `_buildHeaders`, since that would be an unreviewed behavior change outside this plan's scope.
- Do not change any public method signature on `ApiClient` — every caller across the 8 command/query clients and 5 repositories must keep compiling unchanged.

---

## Task 1: `_withAuthRetry` core + `get`/`post`/`postRaw`/`put`/`patch`/`delete`

**Files:**
- Modify: `lib/data/client/api_client.dart`
- Modify: `test/client/api_client_test.dart` (add 2 new tests for `postRaw`, which currently has none)

**Interfaces:**
- Produces: `Future<http.Response> _withAuthRetry(bool requireAuth, Future<http.Response> Function() attempt)` — private, consumed by every method in this file including `postMultipart` (Task 2).

- [ ] **Step 1: Write the two missing `postRaw` tests (characterizing current behavior before touching it)**

Add to `test/client/api_client_test.dart`, inside a new `group('postRaw requests', ...)` (place it near the existing `group('POST requests', ...)`):

```dart
    group('postRaw requests', () {
      test('successful postRaw without auth', () async {
        final uri = Uri.parse('https://api.example.com/status');
        when(
          mockHttpClient.post(
            uri,
            headers: anyNamed('headers'),
            body: anyNamed('body'),
          ),
        ).thenAnswer((_) async => http.Response('{"ok": true}', 200));

        final response = await apiClient.postRaw('/status', body: 'PAUSED');

        expect(response.statusCode, 200);
        verify(
          mockHttpClient.post(
            uri,
            headers: anyNamed('headers'),
            body: jsonEncode('PAUSED'),
          ),
        ).called(1);
      });

      test('postRaw with 401 triggers token refresh and retry', () async {
        when(
          mockTokenStorage.isAccessTokenExpired(),
        ).thenAnswer((_) async => false);
        when(
          mockTokenStorage.getAccessToken(),
        ).thenAnswer((_) async => 'old-token');
        when(mockTokenStorage.getTokenType()).thenAnswer((_) async => 'Bearer');
        when(
          mockTokenStorage.getRefreshToken(),
        ).thenAnswer((_) async => 'refresh-token');

        final uri = Uri.parse('https://api.example.com/status');
        final refreshUri =
            Uri.parse('http://localhost:8083/api/1/auth/refresh');

        var postCallCount = 0;
        when(
          mockHttpClient.post(
            uri,
            headers: anyNamed('headers'),
            body: anyNamed('body'),
          ),
        ).thenAnswer((_) async {
          postCallCount++;
          if (postCallCount == 1) {
            return http.Response('Unauthorized', 401);
          } else {
            return http.Response('{"ok": true}', 200);
          }
        });

        when(
          mockHttpClient.post(
            refreshUri,
            headers: anyNamed('headers'),
            body: anyNamed('body'),
          ),
        ).thenAnswer(
          (_) async => http.Response(
            jsonEncode({
              'accessToken': 'new-token',
              'refreshToken': 'new-refresh-token',
              'tokenType': 'Bearer',
              'expiresIn': 3600,
            }),
            200,
          ),
        );

        when(
          mockTokenStorage.saveTokens(
            accessToken: anyNamed('accessToken'),
            refreshToken: anyNamed('refreshToken'),
            tokenType: anyNamed('tokenType'),
            expiresIn: anyNamed('expiresIn'),
          ),
        ).thenAnswer((_) async => {});

        final response = await apiClient.postRaw(
          '/status',
          body: 'PAUSED',
          requireAuth: true,
        );

        expect(response.statusCode, 200);
        verify(
          mockTokenStorage.saveTokens(
            accessToken: 'new-token',
            refreshToken: 'new-refresh-token',
            tokenType: 'Bearer',
            expiresIn: 3600,
          ),
        ).called(1);
      });
    });
```

- [ ] **Step 2: Run the new tests against the CURRENT (unrefactored) implementation to confirm they pass**

Run: `flutter test test/client/api_client_test.dart`
Expected: PASS — these two tests characterize the existing `postRaw` behavior before any refactor, same mocking pattern as the existing `POST requests` group.

- [ ] **Step 3: Add `_withAuthRetry` and refactor the 6 methods**

In `lib/data/client/api_client.dart`, add the new private helper (place it right after the constructor, before `get`):

```dart
  /// Runs [attempt], retrying it once with a refreshed token if it returns
  /// a 401 and [requireAuth] is true. Proactively refreshes an expired
  /// token before the first attempt (OAuth2 best practice). Throws
  /// [AuthenticationRedirectException] if a 401 survives a failed refresh.
  Future<http.Response> _withAuthRetry(
    bool requireAuth,
    Future<http.Response> Function() attempt,
  ) async {
    if (requireAuth) {
      await _ensureValidToken();
    }

    var response = await attempt();

    if (response.statusCode == 401 && requireAuth) {
      final refreshed = await _refreshTokenIfNeeded();
      if (refreshed) {
        response = await attempt();
      } else {
        _handleUnauthorized();
      }
    }

    return response;
  }
```

Replace the full bodies of `get`, `post`, `postRaw`, `put`, `patch`, `delete` (currently `lib/data/client/api_client.dart:34-348`) with:

```dart
  /// GET request
  Future<http.Response> get(
    String endpoint, {
    bool requireAuth = false,
    Map<String, String>? headers,
  }) {
    final uri = Uri.parse('$baseUrl$endpoint');
    return _withAuthRetry(requireAuth, () async {
      final requestHeaders = await _buildHeaders(requireAuth, headers);
      return _httpClient.get(uri, headers: requestHeaders);
    });
  }

  /// POST request
  Future<http.Response> post(
    String endpoint, {
    required Map<String, dynamic> body,
    bool requireAuth = false,
    Map<String, String>? headers,
  }) {
    final uri = Uri.parse('$baseUrl$endpoint');
    return _withAuthRetry(requireAuth, () async {
      final requestHeaders = await _buildHeaders(requireAuth, headers);
      return _httpClient.post(uri, headers: requestHeaders, body: jsonEncode(body));
    });
  }

  /// POST request with raw body (for sending plain values like enums)
  Future<http.Response> postRaw(
    String endpoint, {
    required dynamic body,
    bool requireAuth = false,
    Map<String, String>? headers,
  }) {
    final uri = Uri.parse('$baseUrl$endpoint');
    return _withAuthRetry(requireAuth, () async {
      final requestHeaders = await _buildHeaders(requireAuth, headers);
      return _httpClient.post(uri, headers: requestHeaders, body: jsonEncode(body));
    });
  }

  /// PUT request
  Future<http.Response> put(
    String endpoint, {
    required Map<String, dynamic> body,
    bool requireAuth = false,
    Map<String, String>? headers,
  }) {
    final uri = Uri.parse('$baseUrl$endpoint');
    return _withAuthRetry(requireAuth, () async {
      final requestHeaders = await _buildHeaders(requireAuth, headers);
      return _httpClient.put(uri, headers: requestHeaders, body: jsonEncode(body));
    });
  }

  /// PATCH request
  Future<http.Response> patch(
    String endpoint, {
    required Map<String, dynamic> body,
    bool requireAuth = false,
    Map<String, String>? headers,
  }) {
    final uri = Uri.parse('$baseUrl$endpoint');
    return _withAuthRetry(requireAuth, () async {
      final requestHeaders = await _buildHeaders(requireAuth, headers);
      return _httpClient.patch(uri, headers: requestHeaders, body: jsonEncode(body));
    });
  }
```

`delete` sits after `postMultipart`/`_getContentTypeFromFileName` in the current file (`:311-348`) — leave its position, just replace its body:

```dart
  /// DELETE request
  Future<http.Response> delete(
    String endpoint, {
    Map<String, dynamic>? body,
    bool requireAuth = false,
    Map<String, String>? headers,
  }) {
    final uri = Uri.parse('$baseUrl$endpoint');
    return _withAuthRetry(requireAuth, () async {
      final requestHeaders = await _buildHeaders(requireAuth, headers);
      return _httpClient.delete(
        uri,
        headers: requestHeaders,
        body: body != null ? jsonEncode(body) : null,
      );
    });
  }
```

Do **not** touch `postMultipart` in this task — that's Task 2. Do not touch `_buildHeaders`, `_ensureValidToken`, `_refreshTokenIfNeeded`, `_handleUnauthorized`, `_getContentTypeFromFileName`, `handleResponse`, `handleListResponse`, `handlePageResponse`, `handleNoContentResponse`, `handleAcceptedResponse`, or `_handleError` — all unchanged.

- [ ] **Step 4: Run the full `api_client_test.dart` suite**

Run: `flutter test test/client/api_client_test.dart`
Expected: PASS — every existing test for `get`/`post`/`put`/`patch`/`delete` (including their 401-retry cases) still passes unchanged, plus the 2 new `postRaw` tests from Step 1.

- [ ] **Step 5: Run the full suite + analyze**

Run: `flutter test && flutter analyze`
Expected: 1365 tests passing (1363 + 2 new), analyze clean. `ApiClient` is consumed by all 8 command/query clients and 5 repositories — this run is the regression net for all of them, since none of their tests mock below the `http.Client` boundary (they go through the real `ApiClient` logic against a mocked `http.Client`, same pattern as `api_client_test.dart`).

- [ ] **Step 6: Commit**

```bash
git add lib/data/client/api_client.dart test/client/api_client_test.dart
git commit -m "refactor: collapse ApiClient's 401-retry boilerplate into _withAuthRetry

get/post/postRaw/put/patch/delete each duplicated the same
proactive-refresh -> attempt -> refresh-on-401 -> retry sequence.
Extracted into one private helper; each method now just builds its
request as a closure. Added the two tests postRaw was missing before
touching it - postMultipart (untested, structurally different) is
handled separately in the next task."
```

---

## Task 2: `postMultipart` via the same core (+ its first tests)

**Context:** `postMultipart` retries by rebuilding the entire `http.MultipartRequest` (a request object can only be sent once), duplicating the same files/fields-construction code between its initial attempt and its retry branch (currently `lib/data/client/api_client.dart:222-293`). `_withAuthRetry`'s `attempt` closure naturally accommodates this — the closure just rebuilds the whole request every time it's invoked, whether that's once or twice.

**Files:**
- Modify: `lib/data/client/api_client.dart`
- Modify: `test/client/api_client_test.dart` (add 2 new tests — `postMultipart` currently has none)

**Interfaces:**
- Consumes: `_withAuthRetry` (Task 1).

- [ ] **Step 1: Write the two missing `postMultipart` tests (characterizing current behavior before touching it)**

Add to `test/client/api_client_test.dart`, in a new `group('postMultipart requests', ...)`:

```dart
    group('postMultipart requests', () {
      test('successful postMultipart without auth', () async {
        when(mockHttpClient.send(any)).thenAnswer((_) async {
          return http.StreamedResponse(
            Stream.value(utf8.encode('{"id": "abc"}')),
            200,
          );
        });

        final response = await apiClient.postMultipart(
          '/upload',
          fileBytes: [1, 2, 3],
          fileName: 'photo.png',
          fieldName: 'file',
        );

        expect(response.statusCode, 200);
        expect(response.body, '{"id": "abc"}');
      });

      test('postMultipart with 401 triggers token refresh and retry',
          () async {
        when(
          mockTokenStorage.isAccessTokenExpired(),
        ).thenAnswer((_) async => false);
        when(
          mockTokenStorage.getAccessToken(),
        ).thenAnswer((_) async => 'old-token');
        when(mockTokenStorage.getTokenType()).thenAnswer((_) async => 'Bearer');
        when(
          mockTokenStorage.getRefreshToken(),
        ).thenAnswer((_) async => 'refresh-token');

        final refreshUri =
            Uri.parse('http://localhost:8083/api/1/auth/refresh');

        var sendCallCount = 0;
        when(mockHttpClient.send(any)).thenAnswer((_) async {
          sendCallCount++;
          if (sendCallCount == 1) {
            return http.StreamedResponse(Stream.value(utf8.encode('Unauthorized')), 401);
          } else {
            return http.StreamedResponse(
              Stream.value(utf8.encode('{"id": "abc"}')),
              200,
            );
          }
        });

        when(
          mockHttpClient.post(
            refreshUri,
            headers: anyNamed('headers'),
            body: anyNamed('body'),
          ),
        ).thenAnswer(
          (_) async => http.Response(
            jsonEncode({
              'accessToken': 'new-token',
              'refreshToken': 'new-refresh-token',
              'tokenType': 'Bearer',
              'expiresIn': 3600,
            }),
            200,
          ),
        );

        when(
          mockTokenStorage.saveTokens(
            accessToken: anyNamed('accessToken'),
            refreshToken: anyNamed('refreshToken'),
            tokenType: anyNamed('tokenType'),
            expiresIn: anyNamed('expiresIn'),
          ),
        ).thenAnswer((_) async => {});

        final response = await apiClient.postMultipart(
          '/upload',
          fileBytes: [1, 2, 3],
          fileName: 'photo.png',
          fieldName: 'file',
          requireAuth: true,
        );

        expect(response.statusCode, 200);
        expect(sendCallCount, 2);
        verify(
          mockTokenStorage.saveTokens(
            accessToken: 'new-token',
            refreshToken: 'new-refresh-token',
            tokenType: 'Bearer',
            expiresIn: 3600,
          ),
        ).called(1);
      });
    });
```

Note: `MockClient` is generated from `@GenerateMocks([http.Client, TokenStorage])` at the top of this file, so `mockHttpClient.send(any)` is already mockable — `http.MultipartRequest.send()` calls through `http.Client.send`, which mockito's generated mock supports without regenerating `api_client_test.mocks.dart`. If `mockHttpClient.send` is not recognized, regenerate mocks: `flutter pub run build_runner build --delete-conflicting-outputs`.

- [ ] **Step 2: Run the new tests against the CURRENT (unrefactored) implementation to confirm they pass**

Run: `flutter test test/client/api_client_test.dart`
Expected: PASS — these two tests characterize `postMultipart`'s existing behavior before any refactor.

- [ ] **Step 3: Refactor `postMultipart` to use `_withAuthRetry`**

Replace the full body of `postMultipart` (currently `lib/data/client/api_client.dart:222-293`) with:

```dart
  /// POST request with multipart/form-data for file uploads
  Future<http.Response> postMultipart(
    String endpoint, {
    required List<int> fileBytes,
    required String fileName,
    required String fieldName,
    bool requireAuth = false,
    Map<String, String>? additionalFields,
  }) {
    final uri = Uri.parse('$baseUrl$endpoint');
    final contentType = _getContentTypeFromFileName(fileName);

    return _withAuthRetry(requireAuth, () async {
      final request = http.MultipartRequest('POST', uri);

      if (requireAuth) {
        final token = await _tokenStorage.getAccessToken();
        if (token != null) {
          request.headers['Authorization'] = 'Bearer $token';
        }
      }

      request.files.add(http.MultipartFile.fromBytes(
        fieldName,
        fileBytes,
        filename: fileName,
        contentType: contentType != null ? MediaType.parse(contentType) : null,
      ));

      if (additionalFields != null) {
        request.fields.addAll(additionalFields);
      }

      final streamedResponse = await request.send();
      return http.Response.fromStream(streamedResponse);
    });
  }
```

Note the hardcoded `'Bearer $token'` (not `_buildHeaders`, which would use the stored `tokenType`) is **preserved exactly** per the Global Constraints — this is a pre-existing inconsistency, not something this task fixes.

`_getContentTypeFromFileName` (currently `:296-309`) is unchanged and unmoved.

- [ ] **Step 4: Run the full `api_client_test.dart` suite**

Run: `flutter test test/client/api_client_test.dart`
Expected: PASS — the 2 new `postMultipart` tests plus everything from Task 1.

- [ ] **Step 5: Run the full suite + analyze**

Run: `flutter test && flutter analyze`
Expected: 1367 tests passing (1365 + 2 new), analyze clean.

- [ ] **Step 6: Commit**

```bash
git add lib/data/client/api_client.dart test/client/api_client_test.dart
git commit -m "refactor: fold postMultipart into _withAuthRetry, add its first tests

postMultipart duplicated its entire request-construction (files,
fields, auth header) between the initial attempt and its 401-retry
branch. Now built once as a closure that _withAuthRetry can invoke
either once or twice. Added the 2 tests this method had none of
before, preserving its pre-existing hardcoded 'Bearer' auth header
(not routed through _buildHeaders) exactly as before."
```

---

## Task 3: Extract `UrlShortenerService` (kill the one raw-HTTP call in the UI layer)

**Context:** `lib/presentation/widgets/trip_detail/trip_share_dialog.dart` calls `package:http` directly against a third-party URL-shortening API (`tinyurl.com`) — the only place in the presentation layer that touches `http` directly instead of going through the data layer. This is unrelated to the app's own backend (no `baseUrl`, no auth), so it doesn't belong in `ApiClient` — it gets its own tiny service, following the same "optional constructor param defaulting to a real instance" testability pattern already used by `ApiClient` itself and every existing `data/services/*.dart` class.

**Files:**
- Create: `lib/data/services/url_shortener_service.dart`
- Test: `test/services/url_shortener_service_test.dart`
- Modify: `lib/presentation/widgets/trip_detail/trip_share_dialog.dart`

**Interfaces:**
- Produces: `UrlShortenerService` with `Future<String?> shorten(String url)` — returns the shortened URL string on success, `null` on any failure (HTTP error, timeout, or exception), matching the dialog's existing "show a generic error and let the user use the long URL" behavior.

- [ ] **Step 1: Write the failing test**

Create `test/services/url_shortener_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wanderer_frontend/data/services/url_shortener_service.dart';

void main() {
  group('UrlShortenerService', () {
    test('returns the shortened URL on success', () async {
      final mockClient = MockClient((request) async {
        expect(
          request.url.toString(),
          'https://tinyurl.com/api-create.php?url=https%3A%2F%2Fexample.com%2Ftrip%2F123',
        );
        return http.Response('https://tinyurl.com/abc123', 200);
      });

      final service = UrlShortenerService(httpClient: mockClient);
      final result = await service.shorten('https://example.com/trip/123');

      expect(result, 'https://tinyurl.com/abc123');
    });

    test('returns null on a non-200 response', () async {
      final mockClient = MockClient((request) async {
        return http.Response('error', 500);
      });

      final service = UrlShortenerService(httpClient: mockClient);
      final result = await service.shorten('https://example.com/trip/123');

      expect(result, isNull);
    });

    test('returns null when the request throws', () async {
      final mockClient = MockClient((request) async {
        throw Exception('network error');
      });

      final service = UrlShortenerService(httpClient: mockClient);
      final result = await service.shorten('https://example.com/trip/123');

      expect(result, isNull);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/url_shortener_service_test.dart`
Expected: FAIL — `url_shortener_service.dart` doesn't exist yet.

- [ ] **Step 3: Implement `UrlShortenerService`**

Create `lib/data/services/url_shortener_service.dart`:

```dart
import 'package:http/http.dart' as http;

/// Shortens URLs via the tinyurl.com public API (no auth, no app backend
/// involved — this is a third-party call, not one of our own endpoints).
class UrlShortenerService {
  final http.Client _httpClient;

  UrlShortenerService({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  /// Returns the shortened URL, or null if shortening fails for any reason
  /// (non-200 response, timeout, network error).
  Future<String?> shorten(String url) async {
    try {
      final response = await _httpClient
          .get(
            Uri.parse(
              'https://tinyurl.com/api-create.php?url=${Uri.encodeComponent(url)}',
            ),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return response.body.trim();
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/services/url_shortener_service_test.dart`
Expected: PASS, all 3 cases green.

- [ ] **Step 5: Rewire `trip_share_dialog.dart`**

Replace the import `import 'package:http/http.dart' as http;` with:

```dart
import 'package:wanderer_frontend/data/services/url_shortener_service.dart';
```

Add a field and replace `_fetchShortUrl` (currently `lib/presentation/widgets/trip_detail/trip_share_dialog.dart:54-82`):

```dart
class _TripShareDialogState extends State<TripShareDialog> {
  late final String _tripUrl;
  final UrlShortenerService _urlShortenerService = UrlShortenerService();
  String? _shortUrl;
  bool _isLoadingShortUrl = true;
  String? _shortUrlError;
```

```dart
  Future<void> _fetchShortUrl() async {
    final shortUrl = await _urlShortenerService.shorten(_tripUrl);
    if (!mounted) return;
    setState(() {
      if (shortUrl != null) {
        _shortUrl = shortUrl;
      } else {
        _shortUrlError = 'Could not shorten URL';
      }
      _isLoadingShortUrl = false;
    });
  }
```

- [ ] **Step 6: Run full suite + analyze**

Run: `flutter test && flutter analyze`
Expected: 1370 tests passing (1367 + 3 new), analyze clean.

- [ ] **Step 7: Commit**

```bash
git add lib/data/services/url_shortener_service.dart test/services/url_shortener_service_test.dart lib/presentation/widgets/trip_detail/trip_share_dialog.dart
git commit -m "refactor: extract UrlShortenerService, remove the last raw HTTP call from the UI layer

trip_share_dialog.dart called package:http directly against a
third-party URL-shortening API - the only presentation-layer file
that touched http directly instead of going through the data layer.
Moved into its own service following the existing
optional-constructor-param testability pattern."
```

---

## Overall verification

- [ ] `flutter analyze` — clean throughout, zero new warnings vs the 1363-test/clean-analyze baseline.
- [ ] `flutter test` — 1370 passing at the end (1363 baseline + 2 postRaw + 2 postMultipart + 3 UrlShortenerService new tests).
- [ ] Manual smoke test: `flutter run` — exercise a login flow (GET/POST auth paths), change a trip's status (postRaw path — e.g. pause/resume a trip), upload a profile photo or trip photo if the app supports it (postMultipart path), delete something (DELETE path), and open a trip's share dialog to confirm the short-link still loads. Behavior should be identical to before this branch — this refactor changes no request shapes, only removes duplication.
- [ ] `git log --oneline` on `refactor/phase-3-apiclient-dedup` shows one commit per task, each independently revertable.
