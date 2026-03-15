import 'package:flutter_test/flutter_test.dart';
import 'package:wanderer_frontend/data/models/domain/notification_type.dart';
import 'package:wanderer_frontend/data/models/domain/notification_dto.dart';

void main() {
  group('NotificationType', () {
    test('toJson returns correct string for all types', () {
      expect(
        NotificationType.friendRequestReceived.toJson(),
        'FRIEND_REQUEST_RECEIVED',
      );
      expect(
        NotificationType.friendRequestAccepted.toJson(),
        'FRIEND_REQUEST_ACCEPTED',
      );
      expect(
        NotificationType.friendRequestDeclined.toJson(),
        'FRIEND_REQUEST_DECLINED',
      );
      expect(NotificationType.commentOnTrip.toJson(), 'COMMENT_ON_TRIP');
      expect(NotificationType.replyToComment.toJson(), 'REPLY_TO_COMMENT');
      expect(NotificationType.commentReaction.toJson(), 'COMMENT_REACTION');
      expect(NotificationType.newFollower.toJson(), 'NEW_FOLLOWER');
      expect(
        NotificationType.achievementUnlocked.toJson(),
        'ACHIEVEMENT_UNLOCKED',
      );
      expect(
        NotificationType.tripStatusChanged.toJson(),
        'TRIP_STATUS_CHANGED',
      );
      expect(NotificationType.tripUpdatePosted.toJson(), 'TRIP_UPDATE_POSTED');
    });

    test('fromJson parses all valid types', () {
      expect(
        NotificationType.fromJson('FRIEND_REQUEST_RECEIVED'),
        NotificationType.friendRequestReceived,
      );
      expect(
        NotificationType.fromJson('FRIEND_REQUEST_ACCEPTED'),
        NotificationType.friendRequestAccepted,
      );
      expect(
        NotificationType.fromJson('FRIEND_REQUEST_DECLINED'),
        NotificationType.friendRequestDeclined,
      );
      expect(
        NotificationType.fromJson('COMMENT_ON_TRIP'),
        NotificationType.commentOnTrip,
      );
      expect(
        NotificationType.fromJson('REPLY_TO_COMMENT'),
        NotificationType.replyToComment,
      );
      expect(
        NotificationType.fromJson('COMMENT_REACTION'),
        NotificationType.commentReaction,
      );
      expect(
        NotificationType.fromJson('NEW_FOLLOWER'),
        NotificationType.newFollower,
      );
      expect(
        NotificationType.fromJson('ACHIEVEMENT_UNLOCKED'),
        NotificationType.achievementUnlocked,
      );
      expect(
        NotificationType.fromJson('TRIP_STATUS_CHANGED'),
        NotificationType.tripStatusChanged,
      );
      expect(
        NotificationType.fromJson('TRIP_UPDATE_POSTED'),
        NotificationType.tripUpdatePosted,
      );
    });

    test('fromJson is case insensitive', () {
      expect(
        NotificationType.fromJson('friend_request_received'),
        NotificationType.friendRequestReceived,
      );
      expect(
        NotificationType.fromJson('Comment_On_Trip'),
        NotificationType.commentOnTrip,
      );
    });

    test('fromJson throws on invalid value', () {
      expect(
        () => NotificationType.fromJson('INVALID_TYPE'),
        throwsArgumentError,
      );
    });

    test('roundtrip: toJson then fromJson returns same value', () {
      for (final type in NotificationType.values) {
        expect(NotificationType.fromJson(type.toJson()), type);
      }
    });
  });

  group('NotificationDto', () {
    test('fromJson creates NotificationDto with all fields', () {
      final json = {
        'id': '550e8400-e29b-41d4-a716-446655440000',
        'recipientId': '7c9e6679-7425-40de-944b-e07fc1f90ae7',
        'actorId': 'f47ac10b-58cc-4372-a567-0e02b2c3d479',
        'type': 'COMMENT_ON_TRIP',
        'referenceId': 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
        'message': 'alice commented on your trip "Camino de Santiago"',
        'read': false,
        'createdAt': '2026-03-14T10:30:00Z',
      };

      final notification = NotificationDto.fromJson(json);

      expect(notification.id, '550e8400-e29b-41d4-a716-446655440000');
      expect(notification.recipientId, '7c9e6679-7425-40de-944b-e07fc1f90ae7');
      expect(notification.actorId, 'f47ac10b-58cc-4372-a567-0e02b2c3d479');
      expect(notification.type, NotificationType.commentOnTrip);
      expect(notification.referenceId, 'a1b2c3d4-e5f6-7890-abcd-ef1234567890');
      expect(
        notification.message,
        'alice commented on your trip "Camino de Santiago"',
      );
      expect(notification.read, false);
      expect(notification.createdAt, DateTime.parse('2026-03-14T10:30:00Z'));
    });

    test('fromJson handles null actorId for system events', () {
      final json = {
        'id': '661f9511-f3ac-52e5-b827-557766551111',
        'recipientId': '7c9e6679-7425-40de-944b-e07fc1f90ae7',
        'actorId': null,
        'type': 'ACHIEVEMENT_UNLOCKED',
        'referenceId': 'aaaa1111-bbbb-cccc-dddd-eeee22223333',
        'message': 'You unlocked the achievement "First Century"!',
        'read': true,
        'createdAt': '2026-03-13T15:00:00Z',
      };

      final notification = NotificationDto.fromJson(json);

      expect(notification.actorId, isNull);
      expect(notification.type, NotificationType.achievementUnlocked);
      expect(notification.read, true);
    });

    test('fromJson handles null referenceId', () {
      final json = {
        'id': 'test-id',
        'recipientId': 'test-recipient',
        'type': 'NEW_FOLLOWER',
        'referenceId': null,
        'message': 'Someone followed you',
        'read': false,
        'createdAt': '2026-03-14T10:30:00Z',
      };

      final notification = NotificationDto.fromJson(json);

      expect(notification.referenceId, isNull);
    });

    test('fromJson uses defaults for missing fields', () {
      final json = <String, dynamic>{
        'type': 'NEW_FOLLOWER',
      };

      final notification = NotificationDto.fromJson(json);

      expect(notification.id, '');
      expect(notification.recipientId, '');
      expect(notification.message, '');
      expect(notification.read, false);
    });

    test('toJson includes all required fields', () {
      final notification = NotificationDto(
        id: 'test-id',
        recipientId: 'test-recipient',
        actorId: 'test-actor',
        type: NotificationType.friendRequestReceived,
        referenceId: 'test-reference',
        message: 'Test message',
        read: false,
        createdAt: DateTime.parse('2026-03-14T10:30:00Z'),
      );

      final json = notification.toJson();

      expect(json['id'], 'test-id');
      expect(json['recipientId'], 'test-recipient');
      expect(json['actorId'], 'test-actor');
      expect(json['type'], 'FRIEND_REQUEST_RECEIVED');
      expect(json['referenceId'], 'test-reference');
      expect(json['message'], 'Test message');
      expect(json['read'], false);
      expect(json.containsKey('createdAt'), true);
    });

    test('toJson excludes null optional fields', () {
      final notification = NotificationDto(
        id: 'test-id',
        recipientId: 'test-recipient',
        type: NotificationType.achievementUnlocked,
        message: 'Achievement!',
        read: true,
        createdAt: DateTime.now(),
      );

      final json = notification.toJson();

      expect(json.containsKey('actorId'), false);
      expect(json.containsKey('referenceId'), false);
    });

    test('toJson includes optional fields when present', () {
      final notification = NotificationDto(
        id: 'test-id',
        recipientId: 'test-recipient',
        actorId: 'actor-id',
        type: NotificationType.commentOnTrip,
        referenceId: 'ref-id',
        message: 'Comment',
        read: false,
        createdAt: DateTime.now(),
      );

      final json = notification.toJson();

      expect(json.containsKey('actorId'), true);
      expect(json.containsKey('referenceId'), true);
    });
  });
}
