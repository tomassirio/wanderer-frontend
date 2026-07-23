import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/api_endpoints.dart';
import '../../data/client/api_client.dart';
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
