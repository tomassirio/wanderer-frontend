import 'dart:convert';

import '../../../core/constants/api_endpoints.dart';
import '../../models/notification_models.dart';
import '../../models/responses/page_response.dart';
import '../api_client.dart';

/// Notification query client for read operations (Port 8082)
class NotificationQueryClient {
  final ApiClient _apiClient;

  NotificationQueryClient({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient(baseUrl: ApiEndpoints.queryBaseUrl);

  /// Get paginated notifications for the current user
  /// Requires authentication (USER, ADMIN)
  Future<PageResponse<NotificationDto>> getMyNotifications({
    int page = 0,
    int size = 20,
    String sort = 'createdAt,desc',
  }) async {
    final endpoint =
        '${ApiEndpoints.notificationsMe}?page=$page&size=$size&sort=$sort';
    final response = await _apiClient.get(
      endpoint,
      requireAuth: true,
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return PageResponse.fromJson(data, NotificationDto.fromJson);
    } else {
      throw Exception(
          'API Error (${response.statusCode}): Failed to fetch notifications');
    }
  }

  /// Get the count of unread notifications for the current user
  /// Requires authentication (USER, ADMIN)
  Future<int> getUnreadCount() async {
    final response = await _apiClient.get(
      ApiEndpoints.notificationsUnreadCount,
      requireAuth: true,
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return int.tryParse(response.body.trim()) ?? 0;
    } else {
      throw Exception(
          'API Error (${response.statusCode}): Failed to fetch unread count');
    }
  }
}
