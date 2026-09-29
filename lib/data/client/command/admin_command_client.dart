import 'dart:convert';

import '../../../core/constants/api_endpoints.dart';
import '../../models/admin_models.dart';
import '../api_client.dart';

/// Client for admin user management write operations (Command service, ADMIN only)
class AdminCommandClient {
  final ApiClient _apiClient;

  AdminCommandClient({ApiClient? apiClient})
      : _apiClient =
            apiClient ?? ApiClient(baseUrl: ApiEndpoints.commandBaseUrl);

  /// Promote a user to admin role
  /// POST /api/1/admin/users/{userId}/promote → 204 No Content
  Future<void> promoteToAdmin(String userId) async {
    final response = await _apiClient.post(
      ApiEndpoints.adminPromoteUser(userId),
      body: {},
      requireAuth: true,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
          'API Error (${response.statusCode}): Failed to promote user');
    }
  }

  /// Demote a user from admin role
  /// DELETE /api/1/admin/users/{userId}/promote → 204 No Content
  Future<void> demoteFromAdmin(String userId) async {
    final response = await _apiClient.delete(
      ApiEndpoints.adminPromoteUser(userId),
      requireAuth: true,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
          'API Error (${response.statusCode}): Failed to demote user');
    }
  }

  /// Delete a user permanently
  /// DELETE /api/1/admin/users/{userId} → 204 No Content
  Future<void> deleteUser(String userId) async {
    final response = await _apiClient.delete(
      ApiEndpoints.adminDeleteUser(userId),
      requireAuth: true,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
          'API Error (${response.statusCode}): Failed to delete user');
    }
  }

  /// Recompute the encoded polyline for a trip
  /// POST /api/1/admin/trips/{tripId}/recompute-polyline → 204 No Content
  Future<void> recomputePolyline(String tripId) async {
    final response = await _apiClient.post(
      ApiEndpoints.adminRecomputePolyline(tripId),
      body: {},
      requireAuth: true,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
          'API Error (${response.statusCode}): Failed to recompute polyline');
    }
  }

  /// Recompute geocoding (city/country) for all trip updates
  /// POST /api/1/admin/trips/{tripId}/recompute-geocoding → 204 No Content
  Future<void> recomputeGeocoding(String tripId) async {
    final response = await _apiClient.post(
      ApiEndpoints.adminRecomputeGeocoding(tripId),
      body: {},
      requireAuth: true,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
          'API Error (${response.statusCode}): Failed to recompute geocoding');
    }
  }

  /// Regenerate map thumbnails for trips missing one
  /// POST /api/1/admin/trips/thumbnails/regenerate-missing → `ThumbnailBackfillResultDTO`
  /// Can take a while (one Google Static Maps call per missing trip, sequential)
  Future<ThumbnailBackfillResult> regenerateMissingThumbnails() async {
    final response = await _apiClient.post(
      ApiEndpoints.adminRegenerateMissingThumbnails,
      body: {},
      requireAuth: true,
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      return ThumbnailBackfillResult.fromJson(data);
    } else {
      throw Exception(
          'API Error (${response.statusCode}): Failed to regenerate missing thumbnails');
    }
  }
}
