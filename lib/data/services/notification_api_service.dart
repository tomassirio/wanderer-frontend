import '../models/notification_models.dart';
import '../models/responses/page_response.dart';
import '../client/clients.dart';

/// Service for notification operations
class NotificationApiService {
  final NotificationQueryClient _notificationQueryClient;
  final NotificationCommandClient _notificationCommandClient;

  NotificationApiService({
    NotificationQueryClient? notificationQueryClient,
    NotificationCommandClient? notificationCommandClient,
  })  : _notificationQueryClient =
            notificationQueryClient ?? NotificationQueryClient(),
        _notificationCommandClient =
            notificationCommandClient ?? NotificationCommandClient();

  // ===== Notification Query Operations =====

  /// Get paginated notifications for the current user
  Future<PageResponse<NotificationDto>> getMyNotifications({
    int page = 0,
    int size = 20,
  }) async {
    return await _notificationQueryClient.getMyNotifications(
      page: page,
      size: size,
    );
  }

  /// Get the count of unread notifications
  Future<int> getUnreadCount() async {
    return await _notificationQueryClient.getUnreadCount();
  }

  // ===== Notification Command Operations =====

  /// Mark a single notification as read
  Future<void> markAsRead(String notificationId) async {
    await _notificationCommandClient.markAsRead(notificationId);
  }

  /// Mark all notifications as read
  /// Returns the count of notifications that were marked as read
  Future<int> markAllAsRead() async {
    return await _notificationCommandClient.markAllAsRead();
  }
}
