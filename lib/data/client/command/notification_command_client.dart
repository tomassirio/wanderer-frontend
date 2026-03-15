import '../../../core/constants/api_endpoints.dart';
import '../api_client.dart';

/// Notification command client for write operations (Port 8081)
class NotificationCommandClient {
  final ApiClient _apiClient;

  NotificationCommandClient({ApiClient? apiClient})
      : _apiClient =
            apiClient ?? ApiClient(baseUrl: ApiEndpoints.commandBaseUrl);

  /// Mark a single notification as read
  /// Requires authentication (USER, ADMIN)
  /// Returns empty on success (202 Accepted)
  Future<void> markAsRead(String notificationId) async {
    final response = await _apiClient.patch(
      ApiEndpoints.notificationMarkRead(notificationId),
      body: {},
      requireAuth: true,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
          'API Error (${response.statusCode}): Failed to mark notification as read');
    }
  }

  /// Mark all notifications as read for the current user
  /// Requires authentication (USER, ADMIN)
  /// Returns the count of notifications that were marked as read
  Future<int> markAllAsRead() async {
    final response = await _apiClient.patch(
      ApiEndpoints.notificationsMarkAllRead,
      body: {},
      requireAuth: true,
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return int.tryParse(response.body.trim()) ?? 0;
    } else {
      throw Exception(
          'API Error (${response.statusCode}): Failed to mark all notifications as read');
    }
  }
}
