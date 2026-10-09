import 'package:flutter_test/flutter_test.dart';
import 'package:wanderer_frontend/core/constants/enums.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/data/models/websocket/websocket_event.dart';

void main() {
  group('WebSocketEvent - Friend & Follower Events', () {
    group('UserFollowedEvent', () {
      test('fromJson creates UserFollowedEvent from JSON', () {
        final json = {
          'type': 'USER_FOLLOWED',
          'payload': {'followerId': 'user-123', 'followedId': 'user-456'},
          'timestamp': '2024-01-15T10:30:00Z',
        };

        final event = UserFollowedEvent.fromJson(json);

        expect(event.type, WebSocketEventType.userFollowed);
        expect(event.followerId, 'user-123');
        expect(event.followedId, 'user-456');
        expect(event.timestamp.year, 2024);
      });

      test('handles missing timestamp', () {
        final json = {
          'payload': {'followerId': 'user-123', 'followedId': 'user-456'},
        };

        final event = UserFollowedEvent.fromJson(json);

        expect(event.followerId, 'user-123');
        expect(event.followedId, 'user-456');
      });
    });

    group('UserUnfollowedEvent', () {
      test('fromJson creates UserUnfollowedEvent from JSON', () {
        final json = {
          'type': 'USER_UNFOLLOWED',
          'payload': {'followerId': 'user-123', 'followedId': 'user-456'},
          'timestamp': '2024-01-15T10:30:00Z',
        };

        final event = UserUnfollowedEvent.fromJson(json);

        expect(event.type, WebSocketEventType.userUnfollowed);
        expect(event.followerId, 'user-123');
        expect(event.followedId, 'user-456');
      });
    });

    group('FriendRequestSentEvent', () {
      test('fromJson creates FriendRequestSentEvent from JSON', () {
        final json = {
          'type': 'FRIEND_REQUEST_SENT',
          'payload': {
            'requestId': 'request-123',
            'senderId': 'user-456',
            'receiverId': 'user-789',
          },
          'timestamp': '2024-01-15T10:30:00Z',
        };

        final event = FriendRequestSentEvent.fromJson(json);

        expect(event.type, WebSocketEventType.friendRequestSent);
        expect(event.requestId, 'request-123');
        expect(event.senderId, 'user-456');
        expect(event.receiverId, 'user-789');
      });

      test('handles id field as fallback for requestId', () {
        final json = {
          'payload': {
            'id': 'request-123',
            'senderId': 'user-456',
            'receiverId': 'user-789',
          },
        };

        final event = FriendRequestSentEvent.fromJson(json);

        expect(event.requestId, 'request-123');
      });
    });

    group('FriendRequestAcceptedEvent', () {
      test('fromJson creates FriendRequestAcceptedEvent from JSON', () {
        final json = {
          'type': 'FRIEND_REQUEST_ACCEPTED',
          'payload': {
            'requestId': 'request-123',
            'senderId': 'user-456',
            'receiverId': 'user-789',
          },
          'timestamp': '2024-01-15T10:30:00Z',
        };

        final event = FriendRequestAcceptedEvent.fromJson(json);

        expect(event.type, WebSocketEventType.friendRequestAccepted);
        expect(event.requestId, 'request-123');
        expect(event.senderId, 'user-456');
        expect(event.receiverId, 'user-789');
      });
    });

    group('FriendRequestDeclinedEvent', () {
      test('fromJson creates FriendRequestDeclinedEvent from JSON', () {
        final json = {
          'type': 'FRIEND_REQUEST_DECLINED',
          'payload': {
            'requestId': 'request-123',
            'senderId': 'user-456',
            'receiverId': 'user-789',
          },
          'timestamp': '2024-01-15T10:30:00Z',
        };

        final event = FriendRequestDeclinedEvent.fromJson(json);

        expect(event.type, WebSocketEventType.friendRequestDeclined);
        expect(event.requestId, 'request-123');
        expect(event.senderId, 'user-456');
        expect(event.receiverId, 'user-789');
      });
    });

    group('WebSocketEvent.parseEventType', () {
      test('parses friend and follower event types correctly', () {
        expect(
          WebSocketEvent.parseEventType('USER_FOLLOWED'),
          WebSocketEventType.userFollowed,
        );
        expect(
          WebSocketEvent.parseEventType('USER_UNFOLLOWED'),
          WebSocketEventType.userUnfollowed,
        );
        expect(
          WebSocketEvent.parseEventType('FRIEND_REQUEST_SENT'),
          WebSocketEventType.friendRequestSent,
        );
        expect(
          WebSocketEvent.parseEventType('FRIEND_REQUEST_ACCEPTED'),
          WebSocketEventType.friendRequestAccepted,
        );
        expect(
          WebSocketEvent.parseEventType('FRIEND_REQUEST_DECLINED'),
          WebSocketEventType.friendRequestDeclined,
        );
        expect(
          WebSocketEvent.parseEventType('FRIENDSHIP_CREATED'),
          WebSocketEventType.friendshipCreated,
        );
        expect(
          WebSocketEvent.parseEventType('FRIENDSHIP_REMOVED'),
          WebSocketEventType.friendshipRemoved,
        );
      });

      test('handles lowercase event types', () {
        expect(
          WebSocketEvent.parseEventType('user_followed'),
          WebSocketEventType.userFollowed,
        );
      });

      test('returns unknown for invalid event types', () {
        expect(
          WebSocketEvent.parseEventType('INVALID_EVENT'),
          WebSocketEventType.unknown,
        );
      });
    });
  });

  group('WebSocketEvent - Notification Events', () {
    group('NotificationCreatedEvent', () {
      test('fromJson creates event with all fields', () {
        final json = {
          'type': 'NOTIFICATION_CREATED',
          'payload': {
            'id': 'notif-123',
            'recipientId': 'user-456',
            'actorId': 'user-789',
            'type': 'FRIEND_REQUEST_RECEIVED',
            'referenceId': 'req-001',
            'message': 'Alice sent you a friend request',
          },
          'timestamp': '2024-06-01T12:00:00Z',
        };

        final event = NotificationCreatedEvent.fromJson(json);

        expect(event.type, WebSocketEventType.notificationCreated);
        expect(event.notificationId, 'notif-123');
        expect(event.recipientId, 'user-456');
        expect(event.actorId, 'user-789');
        expect(event.notificationType, 'FRIEND_REQUEST_RECEIVED');
        expect(event.referenceId, 'req-001');
        expect(event.message, 'Alice sent you a friend request');
        expect(event.timestamp.year, 2024);
      });

      test('fromJson handles nullable fields', () {
        final json = {
          'type': 'NOTIFICATION_CREATED',
          'payload': {
            'id': 'notif-abc',
            'recipientId': 'user-456',
            'type': 'ACHIEVEMENT_UNLOCKED',
            'message': 'You unlocked Explorer!',
          },
        };

        final event = NotificationCreatedEvent.fromJson(json);

        expect(event.notificationId, 'notif-abc');
        expect(event.recipientId, 'user-456');
        expect(event.actorId, isNull);
        expect(event.notificationType, 'ACHIEVEMENT_UNLOCKED');
        expect(event.referenceId, isNull);
        expect(event.message, 'You unlocked Explorer!');
      });

      test(
        'fromJson defaults to empty strings for missing required fields',
        () {
          final json = <String, dynamic>{
            'type': 'NOTIFICATION_CREATED',
            'payload': <String, dynamic>{},
          };

          final event = NotificationCreatedEvent.fromJson(json);

          expect(event.notificationId, '');
          expect(event.recipientId, '');
          expect(event.notificationType, '');
          expect(event.message, '');
        },
      );

      test('fromJson uses notificationId fallback key', () {
        final json = {
          'type': 'NOTIFICATION_CREATED',
          'payload': {
            'notificationId': 'notif-fallback',
            'recipientId': 'user-1',
            'type': 'NEW_FOLLOWER',
            'message': 'Bob started following you',
          },
        };

        final event = NotificationCreatedEvent.fromJson(json);

        expect(event.notificationId, 'notif-fallback');
      });
    });

    group('parseEventType', () {
      test('parses NOTIFICATION_CREATED', () {
        expect(
          WebSocketEvent.parseEventType('NOTIFICATION_CREATED'),
          WebSocketEventType.notificationCreated,
        );
      });
    });
  });

  group('WebSocketEvent - Live track events', () {
    test('parses TRACK_UPDATED and TRIP_UPDATE_ENRICHED types', () {
      expect(WebSocketEvent.parseEventType('TRACK_UPDATED'),
          WebSocketEventType.trackUpdated);
      expect(WebSocketEvent.parseEventType('TRIP_UPDATE_ENRICHED'),
          WebSocketEventType.tripUpdateEnriched);
    });

    test('TrackUpdatedEvent.fromJson reads points and distance', () {
      final event = TrackUpdatedEvent.fromJson({
        'type': 'TRACK_UPDATED',
        'payload': {
          'tripId': 'trip-1',
          'points': [
            {'lat': 52.09, 'lon': 5.12, 'recordedAt': '2026-10-08T09:15:02Z'},
            {'lat': 52.1, 'lon': 5.13, 'recordedAt': '2026-10-08T09:15:12Z'},
          ],
          'distanceKm': 3.4,
        },
      });

      expect(event.tripId, 'trip-1');
      expect(event.distanceKm, 3.4);
      expect(event.points, hasLength(2));
      expect(event.points.first.tripId, 'trip-1');
      expect(event.points.first.lat, 52.09);
      expect(event.points.first.lon, 5.12);
      expect(
          event.points.last.recordedAt, DateTime.utc(2026, 10, 8, 9, 15, 12));
    });

    test('TrackUpdatedEvent.fromJson tolerates missing points', () {
      final event = TrackUpdatedEvent.fromJson({
        'payload': {'tripId': 'trip-1'},
      });
      expect(event.points, isEmpty);
      expect(event.distanceKm, isNull);
    });

    test('TripUpdateEnrichedEvent fills place and weather of its check-in', () {
      final event = TripUpdateEnrichedEvent.fromJson({
        'type': 'TRIP_UPDATE_ENRICHED',
        'payload': {
          'tripId': 'trip-1',
          'tripUpdateId': 'u-1',
          'city': 'Utrecht',
          'country': 'Netherlands',
          'temperatureCelsius': 14.5,
          'weatherCondition': 'CLOUDY',
        },
      });
      TripLocation update(String id) => TripLocation(
          id: id,
          latitude: 52,
          longitude: 5,
          timestamp: DateTime.utc(2026, 10, 8));

      final enriched = event.applyTo(update('u-1'));
      expect(enriched.city, 'Utrecht');
      expect(enriched.country, 'Netherlands');
      expect(enriched.temperatureCelsius, 14.5);
      expect(enriched.weatherCondition, WeatherCondition.cloudy);

      final other = update('u-2');
      expect(event.applyTo(other), same(other));
    });

    test('TripUpdatedEvent uses the payload tripUpdateId and timestamp', () {
      final event = TripUpdatedEvent.fromJson({
        'type': 'TRIP_UPDATED',
        'timestamp': '2026-10-08T10:00:00Z',
        'payload': {
          'tripId': 'trip-1',
          'tripUpdateId': 'u-1',
          'latitude': 52.0,
          'longitude': 5.0,
          'timestamp': '2026-10-08T09:30:00Z',
        },
      });

      expect(event.tripUpdateId, 'u-1');
      // Captured offline at 09:30, sent at 10:00.
      expect(event.timestamp, DateTime.utc(2026, 10, 8, 9, 30));
    });

    test('TripUpdatedEvent from an older backend has no tripUpdateId', () {
      final event = TripUpdatedEvent.fromJson({
        'type': 'TRIP_UPDATED',
        'timestamp': '2026-10-08T10:00:00Z',
        'payload': {'tripId': 'trip-1', 'latitude': 52.0, 'longitude': 5.0},
      });

      expect(event.tripUpdateId, isNull);
      expect(event.timestamp, DateTime.utc(2026, 10, 8, 10));
    });
  });
}
