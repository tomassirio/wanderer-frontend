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
