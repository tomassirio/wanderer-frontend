import 'package:flutter_test/flutter_test.dart';
import 'package:wanderer_frontend/data/models/notification_models.dart';
import 'package:wanderer_frontend/data/models/responses/page_response.dart';
import 'package:wanderer_frontend/data/services/notification_api_service.dart';
import 'package:wanderer_frontend/data/client/clients.dart';

void main() {
  group('NotificationApiService', () {
    late MockNotificationQueryClient mockQueryClient;
    late MockNotificationCommandClient mockCommandClient;
    late NotificationApiService service;

    setUp(() {
      mockQueryClient = MockNotificationQueryClient();
      mockCommandClient = MockNotificationCommandClient();
      service = NotificationApiService(
        notificationQueryClient: mockQueryClient,
        notificationCommandClient: mockCommandClient,
      );
    });

    group('getMyNotifications', () {
      test('returns paginated notifications', () async {
        mockQueryClient.mockPage = PageResponse(
          content: [
            NotificationDto(
              id: 'notif-1',
              recipientId: 'user-1',
              actorId: 'user-2',
              type: NotificationType.friendRequestReceived,
              referenceId: 'req-1',
              message: 'alice sent you a friend request',
              read: false,
              createdAt: DateTime.parse('2026-03-14T10:30:00Z'),
            ),
          ],
          totalElements: 1,
          totalPages: 1,
          number: 0,
          size: 20,
          first: true,
          last: true,
        );

        final result = await service.getMyNotifications();

        expect(result.content.length, 1);
        expect(result.content[0].id, 'notif-1');
        expect(mockQueryClient.getMyNotificationsCalled, true);
      });

      test('passes pagination parameters', () async {
        mockQueryClient.mockPage = PageResponse(
          content: [],
          totalElements: 0,
          totalPages: 0,
          number: 2,
          size: 10,
          first: false,
          last: true,
        );

        await service.getMyNotifications(page: 2, size: 10);

        expect(mockQueryClient.lastPage, 2);
        expect(mockQueryClient.lastSize, 10);
      });

      test('passes through errors', () async {
        mockQueryClient.shouldThrowError = true;

        expect(
          () => service.getMyNotifications(),
          throwsException,
        );
      });
    });

    group('getUnreadCount', () {
      test('returns unread count', () async {
        mockQueryClient.mockUnreadCount = 7;

        final result = await service.getUnreadCount();

        expect(result, 7);
        expect(mockQueryClient.getUnreadCountCalled, true);
      });

      test('returns zero', () async {
        mockQueryClient.mockUnreadCount = 0;

        final result = await service.getUnreadCount();

        expect(result, 0);
      });

      test('passes through errors', () async {
        mockQueryClient.shouldThrowError = true;

        expect(
          () => service.getUnreadCount(),
          throwsException,
        );
      });
    });

    group('markAsRead', () {
      test('marks notification as read', () async {
        await service.markAsRead('notif-123');

        expect(mockCommandClient.markAsReadCalled, true);
        expect(mockCommandClient.lastNotificationId, 'notif-123');
      });

      test('passes through errors', () async {
        mockCommandClient.shouldThrowError = true;

        expect(
          () => service.markAsRead('notif-123'),
          throwsException,
        );
      });
    });

    group('markAllAsRead', () {
      test('marks all as read and returns count', () async {
        mockCommandClient.mockMarkAllCount = 12;

        final result = await service.markAllAsRead();

        expect(result, 12);
        expect(mockCommandClient.markAllAsReadCalled, true);
      });

      test('returns zero when no unread', () async {
        mockCommandClient.mockMarkAllCount = 0;

        final result = await service.markAllAsRead();

        expect(result, 0);
      });

      test('passes through errors', () async {
        mockCommandClient.shouldThrowError = true;

        expect(
          () => service.markAllAsRead(),
          throwsException,
        );
      });
    });

    group('NotificationApiService initialization', () {
      test('creates with provided clients', () {
        final s = NotificationApiService(
          notificationQueryClient: mockQueryClient,
          notificationCommandClient: mockCommandClient,
        );
        expect(s, isNotNull);
      });

      test('creates with default clients when not provided', () {
        final s = NotificationApiService();
        expect(s, isNotNull);
      });
    });
  });
}

// Mock NotificationQueryClient
class MockNotificationQueryClient extends NotificationQueryClient {
  PageResponse<NotificationDto>? mockPage;
  int mockUnreadCount = 0;
  bool getMyNotificationsCalled = false;
  bool getUnreadCountCalled = false;
  bool shouldThrowError = false;
  int? lastPage;
  int? lastSize;

  @override
  Future<PageResponse<NotificationDto>> getMyNotifications({
    int page = 0,
    int size = 20,
    String sort = 'createdAt,desc',
  }) async {
    getMyNotificationsCalled = true;
    lastPage = page;
    lastSize = size;
    if (shouldThrowError) throw Exception('Failed to fetch notifications');
    return mockPage!;
  }

  @override
  Future<int> getUnreadCount() async {
    getUnreadCountCalled = true;
    if (shouldThrowError) throw Exception('Failed to fetch unread count');
    return mockUnreadCount;
  }
}

// Mock NotificationCommandClient
class MockNotificationCommandClient extends NotificationCommandClient {
  bool markAsReadCalled = false;
  bool markAllAsReadCalled = false;
  String? lastNotificationId;
  int mockMarkAllCount = 0;
  bool shouldThrowError = false;

  @override
  Future<void> markAsRead(String notificationId) async {
    markAsReadCalled = true;
    lastNotificationId = notificationId;
    if (shouldThrowError) throw Exception('Failed to mark as read');
  }

  @override
  Future<int> markAllAsRead() async {
    markAllAsReadCalled = true;
    if (shouldThrowError) throw Exception('Failed to mark all as read');
    return mockMarkAllCount;
  }
}
