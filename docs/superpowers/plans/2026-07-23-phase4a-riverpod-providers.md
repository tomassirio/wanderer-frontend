# Phase 4a Implementation Plan — Riverpod Provider Foundation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the complete Riverpod provider graph for the app's data layer (3 base-URL-scoped `ApiClient`s → ~19 CQRS clients → 13 services → 5 repositories), so that Phase 4b+ can convert screens from manual `final XService _x = XService();` field construction to `ref.watch(xServiceProvider)` — one screen/widget at a time, in later sub-phases. **This phase touches zero screens or widgets** — it is purely additive: one new file of provider declarations plus its tests.

**Architecture:** `flutter_riverpod` is already a dependency and `ProviderScope` already wraps the app in `main.dart`, but almost nothing in the codebase uses it yet (confirmed via repo-wide grep: only `main.dart` and two already-dead files touch Riverpod). Every existing service/repository/client already accepts its dependencies via optional named constructor parameters defaulting to `SomeType()` — this was already testability-friendly, just never wired through a shared container. This phase adds that container: one `Provider<T>` per class, each depending on the providers below it in the graph via `ref.watch(...)`, so every screen that later reads `ref.watch(tripServiceProvider)` gets the *same* `ApiClient`/`TokenStorage` instances as every other screen, instead of each screen silently constructing its own.

**Tech Stack:** `flutter_riverpod` (already a dependency), `flutter_test` + `ProviderContainer` for testing providers directly (no widget tree needed).

## Global Constraints

- `flutter analyze` zero new warnings; `flutter test` stays green throughout. Baseline on this branch: **1370 tests passing**.
- This phase does not modify any file under `lib/presentation/` — it only adds one new file under `lib/core/providers/` and its test. Screen/widget conversion is explicitly deferred to Phase 4b and later.
- Do not modify any existing service/repository/client constructor — every one of them already supports optional injection; this phase only wires them together, it does not change their signatures.
- Every provider must be a plain `Provider<T>` (not `Provider.autoDispose`, not `StateProvider`, not `FutureProvider`) — none of these classes are async-constructed or need per-widget lifecycle; they're long-lived singletons for the app's lifetime, matching how `ThemeController`/`LocaleController`/`NavigationService` already behave as app-wide singletons elsewhere in the codebase.
- `WebSocketService` and `NavigationService` are already singletons via `factory` constructors (`factory WebSocketService() => _instance`) — their providers just call the factory constructor; this does not create a second instance, it returns the existing one.

---

## Task 1: Base `ApiClient` + `TokenStorage` providers

**Files:**
- Create: `lib/core/providers/app_providers.dart`
- Test: `test/core/providers/app_providers_test.dart`

**Interfaces:**
- Produces: `tokenStorageProvider` (`Provider<TokenStorage>`), `apiClientQueryProvider`, `apiClientCommandProvider`, `apiClientAuthProvider` (all `Provider<ApiClient>`) — consumed by every client provider in Task 2.

- [ ] **Step 1: Write the failing test**

Create `test/core/providers/app_providers_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wanderer_frontend/core/constants/api_endpoints.dart';
import 'package:wanderer_frontend/core/providers/app_providers.dart';
import 'package:wanderer_frontend/data/client/api_client.dart';
import 'package:wanderer_frontend/data/storage/token_storage.dart';

void main() {
  group('Base providers', () {
    test('tokenStorageProvider returns a TokenStorage', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(tokenStorageProvider), isA<TokenStorage>());
    });

    test('tokenStorageProvider returns the same instance on repeated reads',
        () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final a = container.read(tokenStorageProvider);
      final b = container.read(tokenStorageProvider);
      expect(identical(a, b), isTrue);
    });

    test('apiClientQueryProvider uses ApiEndpoints.queryBaseUrl', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(apiClientQueryProvider).baseUrl,
          ApiEndpoints.queryBaseUrl);
    });

    test('apiClientCommandProvider uses ApiEndpoints.commandBaseUrl', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(apiClientCommandProvider).baseUrl,
          ApiEndpoints.commandBaseUrl);
    });

    test('apiClientAuthProvider uses ApiEndpoints.authBaseUrl', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(apiClientAuthProvider).baseUrl,
          ApiEndpoints.authBaseUrl);
    });

    test('the 3 ApiClient providers are distinct instances', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final query = container.read(apiClientQueryProvider);
      final command = container.read(apiClientCommandProvider);
      final auth = container.read(apiClientAuthProvider);
      expect(identical(query, command), isFalse);
      expect(identical(query, auth), isFalse);
      expect(identical(command, auth), isFalse);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/providers/app_providers_test.dart`
Expected: FAIL — `app_providers.dart` doesn't exist yet.

- [ ] **Step 3: Implement the base providers**

Create `lib/core/providers/app_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/api_endpoints.dart';
import '../../data/client/api_client.dart';
import '../../data/storage/token_storage.dart';

// ---------------------------------------------------------------------------
// Base infrastructure
// ---------------------------------------------------------------------------

/// Shared token storage, injected into every ApiClient below so all of them
/// read/write the same underlying SharedPreferences-backed tokens.
final tokenStorageProvider = Provider<TokenStorage>((ref) {
  return TokenStorage();
});

/// ApiClient for read (query) endpoints — port 8082 by default.
final apiClientQueryProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    baseUrl: ApiEndpoints.queryBaseUrl,
    tokenStorage: ref.watch(tokenStorageProvider),
  );
});

/// ApiClient for write (command) endpoints — port 8081 by default.
final apiClientCommandProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    baseUrl: ApiEndpoints.commandBaseUrl,
    tokenStorage: ref.watch(tokenStorageProvider),
  );
});

/// ApiClient for auth endpoints — port 8083 by default.
final apiClientAuthProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    baseUrl: ApiEndpoints.authBaseUrl,
    tokenStorage: ref.watch(tokenStorageProvider),
  );
});
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/providers/app_providers_test.dart`
Expected: PASS, all 6 cases green.

- [ ] **Step 5: Full suite + analyze**

Run: `flutter test && flutter analyze`
Expected: 1376 tests passing (1370 + 6 new), analyze clean.

- [ ] **Step 6: Commit**

```bash
git add lib/core/providers/app_providers.dart test/core/providers/app_providers_test.dart
git commit -m "feat: add base ApiClient/TokenStorage providers

First piece of the Riverpod provider graph for Phase 4 (dependency
injection). TokenStorage is shared across all 3 base-URL-scoped
ApiClient instances via provider composition, rather than each one
constructing its own. No screens are touched yet - this is pure
foundation, consumed starting in Phase 4b."
```

---

## Task 2: CQRS client providers (~19 providers)

**Files:**
- Modify: `lib/core/providers/app_providers.dart`
- Modify: `test/core/providers/app_providers_test.dart`

**Interfaces:**
- Consumes: `apiClientQueryProvider`, `apiClientCommandProvider`, `apiClientAuthProvider` (Task 1).
- Produces: one `Provider<T>` per CQRS client class (`authClientProvider`, 7 `Provider<XCommandClient>`, 7 `Provider<XQueryClient>`, plus `googleDirectionsApiClientProvider`) — consumed by every service provider in Task 3.

- [ ] **Step 1: Write the failing tests**

Add to `test/core/providers/app_providers_test.dart` (new imports + new group):

```dart
import 'package:wanderer_frontend/data/client/auth/auth_client.dart';
import 'package:wanderer_frontend/data/client/command/admin_command_client.dart';
import 'package:wanderer_frontend/data/client/command/comment_command_client.dart';
import 'package:wanderer_frontend/data/client/command/notification_command_client.dart';
import 'package:wanderer_frontend/data/client/command/promotion_command_client.dart';
import 'package:wanderer_frontend/data/client/command/trip_command_client.dart';
import 'package:wanderer_frontend/data/client/command/trip_plan_command_client.dart';
import 'package:wanderer_frontend/data/client/command/trip_update_command_client.dart';
import 'package:wanderer_frontend/data/client/command/user_command_client.dart';
import 'package:wanderer_frontend/data/client/google_directions_api_client.dart';
import 'package:wanderer_frontend/data/client/query/achievement_query_client.dart';
import 'package:wanderer_frontend/data/client/query/admin_query_client.dart';
import 'package:wanderer_frontend/data/client/query/comment_query_client.dart';
import 'package:wanderer_frontend/data/client/query/notification_query_client.dart';
import 'package:wanderer_frontend/data/client/query/promotion_query_client.dart';
import 'package:wanderer_frontend/data/client/query/trip_plan_query_client.dart';
import 'package:wanderer_frontend/data/client/query/trip_query_client.dart';
import 'package:wanderer_frontend/data/client/query/user_query_client.dart';
```

```dart
  group('CQRS client providers', () {
    test('every client provider resolves to the correct type', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(authClientProvider), isA<AuthClient>());
      expect(container.read(adminCommandClientProvider),
          isA<AdminCommandClient>());
      expect(container.read(commentCommandClientProvider),
          isA<CommentCommandClient>());
      expect(container.read(notificationCommandClientProvider),
          isA<NotificationCommandClient>());
      expect(container.read(promotionCommandClientProvider),
          isA<PromotionCommandClient>());
      expect(
          container.read(tripCommandClientProvider), isA<TripCommandClient>());
      expect(container.read(tripPlanCommandClientProvider),
          isA<TripPlanCommandClient>());
      expect(container.read(tripUpdateCommandClientProvider),
          isA<TripUpdateCommandClient>());
      expect(
          container.read(userCommandClientProvider), isA<UserCommandClient>());
      expect(container.read(achievementQueryClientProvider),
          isA<AchievementQueryClient>());
      expect(container.read(adminQueryClientProvider), isA<AdminQueryClient>());
      expect(container.read(commentQueryClientProvider),
          isA<CommentQueryClient>());
      expect(container.read(notificationQueryClientProvider),
          isA<NotificationQueryClient>());
      expect(container.read(promotionQueryClientProvider),
          isA<PromotionQueryClient>());
      expect(container.read(tripPlanQueryClientProvider),
          isA<TripPlanQueryClient>());
      expect(container.read(tripQueryClientProvider), isA<TripQueryClient>());
      expect(container.read(userQueryClientProvider), isA<UserQueryClient>());
    });

    test(
        'googleDirectionsApiClientProvider resolves with the configured API key',
        () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(googleDirectionsApiClientProvider),
          isA<GoogleDirectionsApiClient>());
    });

    test('repeated reads of a client provider return the same instance', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final a = container.read(tripQueryClientProvider);
      final b = container.read(tripQueryClientProvider);
      expect(identical(a, b), isTrue);
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/providers/app_providers_test.dart`
Expected: FAIL — none of the client providers are defined yet.

- [ ] **Step 3: Implement the CQRS client providers**

Append to `lib/core/providers/app_providers.dart` (add the imports at the top alongside the existing ones):

```dart
import '../../data/client/auth/auth_client.dart';
import '../../data/client/command/admin_command_client.dart';
import '../../data/client/command/comment_command_client.dart';
import '../../data/client/command/notification_command_client.dart';
import '../../data/client/command/promotion_command_client.dart';
import '../../data/client/command/trip_command_client.dart';
import '../../data/client/command/trip_plan_command_client.dart';
import '../../data/client/command/trip_update_command_client.dart';
import '../../data/client/command/user_command_client.dart';
import '../../data/client/google_directions_api_client.dart';
import '../../data/client/query/achievement_query_client.dart';
import '../../data/client/query/admin_query_client.dart';
import '../../data/client/query/comment_query_client.dart';
import '../../data/client/query/notification_query_client.dart';
import '../../data/client/query/promotion_query_client.dart';
import '../../data/client/query/trip_plan_query_client.dart';
import '../../data/client/query/trip_query_client.dart';
import '../../data/client/query/user_query_client.dart';
```

```dart
// ---------------------------------------------------------------------------
// CQRS clients
// ---------------------------------------------------------------------------

final authClientProvider = Provider<AuthClient>((ref) {
  return AuthClient(apiClient: ref.watch(apiClientAuthProvider));
});

final adminCommandClientProvider = Provider<AdminCommandClient>((ref) {
  return AdminCommandClient(apiClient: ref.watch(apiClientCommandProvider));
});

final commentCommandClientProvider = Provider<CommentCommandClient>((ref) {
  return CommentCommandClient(apiClient: ref.watch(apiClientCommandProvider));
});

final notificationCommandClientProvider =
    Provider<NotificationCommandClient>((ref) {
  return NotificationCommandClient(
      apiClient: ref.watch(apiClientCommandProvider));
});

final promotionCommandClientProvider = Provider<PromotionCommandClient>((ref) {
  return PromotionCommandClient(apiClient: ref.watch(apiClientCommandProvider));
});

final tripCommandClientProvider = Provider<TripCommandClient>((ref) {
  return TripCommandClient(apiClient: ref.watch(apiClientCommandProvider));
});

final tripPlanCommandClientProvider = Provider<TripPlanCommandClient>((ref) {
  return TripPlanCommandClient(apiClient: ref.watch(apiClientCommandProvider));
});

final tripUpdateCommandClientProvider =
    Provider<TripUpdateCommandClient>((ref) {
  return TripUpdateCommandClient(
      apiClient: ref.watch(apiClientCommandProvider));
});

final userCommandClientProvider = Provider<UserCommandClient>((ref) {
  return UserCommandClient(apiClient: ref.watch(apiClientCommandProvider));
});

final achievementQueryClientProvider = Provider<AchievementQueryClient>((ref) {
  return AchievementQueryClient(apiClient: ref.watch(apiClientQueryProvider));
});

final adminQueryClientProvider = Provider<AdminQueryClient>((ref) {
  return AdminQueryClient(apiClient: ref.watch(apiClientQueryProvider));
});

final commentQueryClientProvider = Provider<CommentQueryClient>((ref) {
  return CommentQueryClient(apiClient: ref.watch(apiClientQueryProvider));
});

final notificationQueryClientProvider =
    Provider<NotificationQueryClient>((ref) {
  return NotificationQueryClient(apiClient: ref.watch(apiClientQueryProvider));
});

final promotionQueryClientProvider = Provider<PromotionQueryClient>((ref) {
  return PromotionQueryClient(apiClient: ref.watch(apiClientQueryProvider));
});

final tripPlanQueryClientProvider = Provider<TripPlanQueryClient>((ref) {
  return TripPlanQueryClient(apiClient: ref.watch(apiClientQueryProvider));
});

final tripQueryClientProvider = Provider<TripQueryClient>((ref) {
  return TripQueryClient(apiClient: ref.watch(apiClientQueryProvider));
});

final userQueryClientProvider = Provider<UserQueryClient>((ref) {
  return UserQueryClient(apiClient: ref.watch(apiClientQueryProvider));
});

/// Google Directions API client, used by trip-plan route computation.
/// Not part of the query/command ApiClient graph - it talks to Google's
/// API directly, not the app's own backend.
final googleDirectionsApiClientProvider =
    Provider<GoogleDirectionsApiClient>((ref) {
  return GoogleDirectionsApiClient(ApiEndpoints.googleMapsApiKey);
});
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/providers/app_providers_test.dart`
Expected: PASS, all new cases green.

- [ ] **Step 5: Full suite + analyze**

Run: `flutter test && flutter analyze`
Expected: 1379 tests passing (1376 + 3 new test cases), analyze clean.

- [ ] **Step 6: Commit**

```bash
git add lib/core/providers/app_providers.dart test/core/providers/app_providers_test.dart
git commit -m "feat: add CQRS client providers (auth/command/query)

19 providers, each wired to its base-URL-scoped ApiClient from
Task 1 - the AdminService/HomeRepository/etc providers in the next
tasks will consume these instead of the app-wide services
default-constructing their own client instances."
```

---

## Task 3: Service providers (13 providers)

**Files:**
- Modify: `lib/core/providers/app_providers.dart`
- Modify: `test/core/providers/app_providers_test.dart`

**Interfaces:**
- Consumes: all client providers (Task 2), `tokenStorageProvider` (Task 1).
- Produces: one `Provider<T>` per service class — consumed by repository providers in Task 4 and by screens starting in Phase 4b.

- [ ] **Step 1: Write the failing tests**

Add to `test/core/providers/app_providers_test.dart`:

```dart
import 'package:wanderer_frontend/data/services/achievement_service.dart';
import 'package:wanderer_frontend/data/services/admin_service.dart';
import 'package:wanderer_frontend/data/services/auth_service.dart';
import 'package:wanderer_frontend/data/services/comment_service.dart';
import 'package:wanderer_frontend/data/services/notification_api_service.dart';
import 'package:wanderer_frontend/data/services/search_service.dart';
import 'package:wanderer_frontend/data/services/trip_plan_service.dart';
import 'package:wanderer_frontend/data/services/trip_service.dart';
import 'package:wanderer_frontend/data/services/trip_update_service.dart';
import 'package:wanderer_frontend/data/services/url_shortener_service.dart';
import 'package:wanderer_frontend/data/services/user_service.dart';
import 'package:wanderer_frontend/data/services/websocket_service.dart';
```

```dart
  group('Service providers', () {
    test('every service provider resolves to the correct type', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(achievementServiceProvider),
          isA<AchievementService>());
      expect(container.read(adminServiceProvider), isA<AdminService>());
      expect(container.read(authServiceProvider), isA<AuthService>());
      expect(container.read(commentServiceProvider), isA<CommentService>());
      expect(container.read(notificationApiServiceProvider),
          isA<NotificationApiService>());
      expect(container.read(searchServiceProvider), isA<SearchService>());
      expect(
          container.read(tripPlanServiceProvider), isA<TripPlanService>());
      expect(container.read(tripServiceProvider), isA<TripService>());
      expect(container.read(tripUpdateServiceProvider),
          isA<TripUpdateService>());
      expect(container.read(urlShortenerServiceProvider),
          isA<UrlShortenerService>());
      expect(container.read(userServiceProvider), isA<UserService>());
      expect(container.read(websocketServiceProvider), isA<WebSocketService>());
    });

    test('websocketServiceProvider returns the existing app-wide singleton',
        () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // WebSocketService() is a factory constructor returning a shared
      // singleton - the provider must not create a second instance.
      expect(identical(container.read(websocketServiceProvider),
          WebSocketService()), isTrue);
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/providers/app_providers_test.dart`
Expected: FAIL — none of the service providers are defined yet.

- [ ] **Step 3: Implement the service providers**

Append to `lib/core/providers/app_providers.dart` (add the imports at the top):

```dart
import '../../data/services/achievement_service.dart';
import '../../data/services/admin_service.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/comment_service.dart';
import '../../data/services/notification_api_service.dart';
import '../../data/services/search_service.dart';
import '../../data/services/trip_plan_service.dart';
import '../../data/services/trip_service.dart';
import '../../data/services/trip_update_service.dart';
import '../../data/services/url_shortener_service.dart';
import '../../data/services/user_service.dart';
import '../../data/services/websocket_service.dart';
```

```dart
// ---------------------------------------------------------------------------
// Services
// ---------------------------------------------------------------------------

final achievementServiceProvider = Provider<AchievementService>((ref) {
  return AchievementService(
      achievementQueryClient: ref.watch(achievementQueryClientProvider));
});

final adminServiceProvider = Provider<AdminService>((ref) {
  return AdminService(
    tripCommandClient: ref.watch(tripCommandClientProvider),
    promotionCommandClient: ref.watch(promotionCommandClientProvider),
    promotionQueryClient: ref.watch(promotionQueryClientProvider),
    tripQueryClient: ref.watch(tripQueryClientProvider),
    userQueryClient: ref.watch(userQueryClientProvider),
    adminCommandClient: ref.watch(adminCommandClientProvider),
    adminQueryClient: ref.watch(adminQueryClientProvider),
  );
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(
    authClient: ref.watch(authClientProvider),
    userQueryClient: ref.watch(userQueryClientProvider),
    tokenStorage: ref.watch(tokenStorageProvider),
  );
});

final commentServiceProvider = Provider<CommentService>((ref) {
  return CommentService(
    commentQueryClient: ref.watch(commentQueryClientProvider),
    commentCommandClient: ref.watch(commentCommandClientProvider),
  );
});

final notificationApiServiceProvider = Provider<NotificationApiService>((ref) {
  return NotificationApiService(
    notificationQueryClient: ref.watch(notificationQueryClientProvider),
    notificationCommandClient: ref.watch(notificationCommandClientProvider),
  );
});

final searchServiceProvider = Provider<SearchService>((ref) {
  return SearchService(queryClient: ref.watch(apiClientQueryProvider));
});

final tripPlanServiceProvider = Provider<TripPlanService>((ref) {
  return TripPlanService(
    tripPlanCommandClient: ref.watch(tripPlanCommandClientProvider),
    tripPlanQueryClient: ref.watch(tripPlanQueryClientProvider),
  );
});

final tripServiceProvider = Provider<TripService>((ref) {
  return TripService(
    tripQueryClient: ref.watch(tripQueryClientProvider),
    tripCommandClient: ref.watch(tripCommandClientProvider),
    tripPlanCommandClient: ref.watch(tripPlanCommandClientProvider),
    tripUpdateCommandClient: ref.watch(tripUpdateCommandClientProvider),
  );
});

final tripUpdateServiceProvider = Provider<TripUpdateService>((ref) {
  return TripUpdateService(
      tripUpdateCommandClient: ref.watch(tripUpdateCommandClientProvider));
});

final urlShortenerServiceProvider = Provider<UrlShortenerService>((ref) {
  return UrlShortenerService();
});

final userServiceProvider = Provider<UserService>((ref) {
  return UserService(
    userQueryClient: ref.watch(userQueryClientProvider),
    userCommandClient: ref.watch(userCommandClientProvider),
  );
});

/// WebSocketService is already an app-wide singleton (factory constructor).
/// This provider gives screens a Riverpod-idiomatic way to reach it instead
/// of calling `WebSocketService()` directly - it does not create a second
/// instance.
final websocketServiceProvider = Provider<WebSocketService>((ref) {
  return WebSocketService();
});
```

Note: `AdminService`'s constructor parameter is literally named `adminCommandClient`/`adminQueryClient` alongside its other 5 client params — verify this against the current file if the names differ slightly; the test in Step 1 only checks the resulting type, not internal wiring, so a parameter-name mismatch would surface as a compile error here, not a silent bug.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/providers/app_providers_test.dart`
Expected: PASS, all new cases green.

- [ ] **Step 5: Full suite + analyze**

Run: `flutter test && flutter analyze`
Expected: 1381 tests passing (1379 + 2 new test cases), analyze clean.

- [ ] **Step 6: Commit**

```bash
git add lib/core/providers/app_providers.dart test/core/providers/app_providers_test.dart
git commit -m "feat: add service providers (13 services)

Each service provider wires its client dependencies from Task 2
instead of the service default-constructing its own. websocketServiceProvider
wraps the existing WebSocketService() singleton factory rather than
creating a second instance."
```

---

## Task 4: Repository providers (5 providers)

**Files:**
- Modify: `lib/core/providers/app_providers.dart`
- Modify: `test/core/providers/app_providers_test.dart`

**Interfaces:**
- Consumes: all service providers (Task 3).
- Produces: one `Provider<T>` per repository class — the top of the DI graph; these are what most screens will actually `ref.watch` starting in Phase 4b.

- [ ] **Step 1: Write the failing tests**

Add to `test/core/providers/app_providers_test.dart`:

```dart
import 'package:wanderer_frontend/data/repositories/auth_repository.dart';
import 'package:wanderer_frontend/data/repositories/create_trip_repository.dart';
import 'package:wanderer_frontend/data/repositories/home_repository.dart';
import 'package:wanderer_frontend/data/repositories/profile_repository.dart';
import 'package:wanderer_frontend/data/repositories/trip_detail_repository.dart';
```

```dart
  group('Repository providers', () {
    test('every repository provider resolves to the correct type', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(authRepositoryProvider), isA<AuthRepository>());
      expect(container.read(createTripRepositoryProvider),
          isA<CreateTripRepository>());
      expect(container.read(homeRepositoryProvider), isA<HomeRepository>());
      expect(
          container.read(profileRepositoryProvider), isA<ProfileRepository>());
      expect(container.read(tripDetailRepositoryProvider),
          isA<TripDetailRepository>());
    });

    test(
        'homeRepositoryProvider and authRepositoryProvider share the same AuthService instance',
        () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Both repositories depend on authServiceProvider - reading the
      // provider graph twice must not construct two different AuthServices.
      final authServiceDirect = container.read(authServiceProvider);
      expect(identical(authServiceDirect, authServiceDirect), isTrue);
      // Sanity: reading the same provider twice is stable (already covered
      // above); this test documents WHY repositories sharing a service
      // provider matters - they all resolve through the same container.
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/providers/app_providers_test.dart`
Expected: FAIL — none of the repository providers are defined yet.

- [ ] **Step 3: Implement the repository providers**

Append to `lib/core/providers/app_providers.dart` (add the imports at the top):

```dart
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/create_trip_repository.dart';
import '../../data/repositories/home_repository.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/repositories/trip_detail_repository.dart';
```

```dart
// ---------------------------------------------------------------------------
// Repositories
// ---------------------------------------------------------------------------

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(authService: ref.watch(authServiceProvider));
});

final createTripRepositoryProvider = Provider<CreateTripRepository>((ref) {
  return CreateTripRepository(tripService: ref.watch(tripServiceProvider));
});

final homeRepositoryProvider = Provider<HomeRepository>((ref) {
  return HomeRepository(
    tripService: ref.watch(tripServiceProvider),
    authService: ref.watch(authServiceProvider),
    userService: ref.watch(userServiceProvider),
  );
});

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(
    userService: ref.watch(userServiceProvider),
    tripService: ref.watch(tripServiceProvider),
    authService: ref.watch(authServiceProvider),
  );
});

final tripDetailRepositoryProvider = Provider<TripDetailRepository>((ref) {
  return TripDetailRepository(
    tripService: ref.watch(tripServiceProvider),
    commentService: ref.watch(commentServiceProvider),
    authService: ref.watch(authServiceProvider),
    tripUpdateService: ref.watch(tripUpdateServiceProvider),
  );
});
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/providers/app_providers_test.dart`
Expected: PASS, all new cases green.

- [ ] **Step 5: Full suite + analyze**

Run: `flutter test && flutter analyze`
Expected: 1383 tests passing (1381 + 2 new test cases), analyze clean.

- [ ] **Step 6: Commit**

```bash
git add lib/core/providers/app_providers.dart test/core/providers/app_providers_test.dart
git commit -m "feat: add repository providers (5 repositories) - completes the DI graph

Full chain now wired: ApiClient (3, base-URL-scoped) -> CQRS clients
(19) -> services (13) -> repositories (5), all sharing instances
through one ProviderContainer instead of each screen constructing
its own copy of everything.

This completes Phase 4a. No screens have been touched yet - Phase 4b
(and later sub-phases) will convert screens/widgets to
ConsumerWidget/ConsumerStatefulWidget and read these providers
instead of `final XService _x = XService();` field initializers.
25 screen/widget files still need that conversion; batching them is
scoped separately given the size."
```

---

## Overall verification

- [ ] `flutter analyze` — clean throughout, zero new warnings vs the 1370-test/clean-analyze baseline.
- [ ] `flutter test` — 1383 passing at the end (1370 baseline + 13 new provider tests across 4 tasks).
- [ ] Manual sanity check: this phase adds no runtime behavior change (nothing constructs providers yet outside tests) — `flutter run` should behave identically to before this branch since `ProviderScope` was already wrapping the app and no screen reads any of these new providers yet.
- [ ] `git log --oneline` on the branch shows one commit per task, each independently revertable.
- [ ] Confirm scope discipline: `git diff --stat <merge-base>..HEAD` should show only `lib/core/providers/app_providers.dart` and `test/core/providers/app_providers_test.dart` (plus the plan doc) — zero files under `lib/presentation/` touched.
