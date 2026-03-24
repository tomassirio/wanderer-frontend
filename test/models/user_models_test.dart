import 'package:flutter_test/flutter_test.dart';
import 'package:wanderer_frontend/data/models/user_models.dart';

void main() {
  group('UserModels', () {
    group('UserProfile', () {
      test('fromJson parses nested userDetails object', () {
        final json = {
          'id': 'user-123',
          'username': 'johndoe',
          'email': 'john@example.com',
          'userDetails': {
            'displayName': 'John Doe',
            'bio': 'Walking the Camino',
            'avatarUrl': 'https://example.com/avatar.png',
          },
          'followersCount': 10,
          'followingCount': 5,
          'friendsCount': 3,
          'tripsCount': 2,
          'isFollowing': false,
          'createdAt': '2024-01-15T10:30:00Z',
        };

        final profile = UserProfile.fromJson(json);

        expect(profile.id, 'user-123');
        expect(profile.username, 'johndoe');
        expect(profile.displayName, 'John Doe');
        expect(profile.bio, 'Walking the Camino');
        // avatarUrl is now a computed getter based on user ID
        expect(profile.avatarUrl, '/thumbnails/profiles/user-123.png');
      });

      test('fromJson handles null fields in userDetails', () {
        final json = {
          'id': 'user-123',
          'username': 'johndoe',
          'userDetails': {
            'displayName': null,
            'bio': null,
            'avatarUrl': null,
          },
          'createdAt': '2024-01-15T10:30:00Z',
        };

        final profile = UserProfile.fromJson(json);

        expect(profile.displayName, isNull);
        expect(profile.bio, isNull);
        // avatarUrl is now a computed getter based on user ID, never null
        expect(profile.avatarUrl, '/thumbnails/profiles/user-123.png');
      });

      test('fromJson falls back to flat fields when userDetails is absent', () {
        final json = {
          'id': 'user-123',
          'username': 'johndoe',
          'displayName': 'Flat Name',
          'bio': 'Flat Bio',
          'avatarUrl': 'https://example.com/flat.png',
          'createdAt': '2024-01-15T10:30:00Z',
        };

        final profile = UserProfile.fromJson(json);

        expect(profile.displayName, 'Flat Name');
        expect(profile.bio, 'Flat Bio');
        // avatarUrl is now a computed getter based on user ID
        expect(profile.avatarUrl, '/thumbnails/profiles/user-123.png');
      });

      test(
          'fromJson prefers userDetails over flat fields when both are present',
          () {
        final json = {
          'id': 'user-123',
          'username': 'johndoe',
          'displayName': 'Flat Name',
          'bio': 'Flat Bio',
          'userDetails': {
            'displayName': 'Nested Name',
            'bio': 'Nested Bio',
            'avatarUrl': 'https://example.com/nested.png',
          },
          'createdAt': '2024-01-15T10:30:00Z',
        };

        final profile = UserProfile.fromJson(json);

        expect(profile.displayName, 'Nested Name');
        expect(profile.bio, 'Nested Bio');
        // avatarUrl is now a computed getter based on user ID
        expect(profile.avatarUrl, '/thumbnails/profiles/user-123.png');
      });
    });

    group('FriendRequest', () {
      test('fromJson creates FriendRequest from JSON', () {
        final json = {
          'id': 'request-123',
          'senderId': 'user-456',
          'receiverId': 'user-789',
          'status': 'PENDING',
          'createdAt': '2024-01-15T10:30:00Z',
          'updatedAt': '2024-01-15T10:30:00Z',
        };

        final friendRequest = FriendRequest.fromJson(json);

        expect(friendRequest.id, 'request-123');
        expect(friendRequest.senderId, 'user-456');
        expect(friendRequest.receiverId, 'user-789');
        expect(friendRequest.status, FriendRequestStatus.pending);
        expect(friendRequest.createdAt.year, 2024);
        expect(friendRequest.updatedAt.year, 2024);
      });

      test('toJson converts FriendRequest correctly', () {
        final friendRequest = FriendRequest(
          id: 'request-123',
          senderId: 'user-456',
          receiverId: 'user-789',
          status: FriendRequestStatus.accepted,
          createdAt: DateTime.parse('2024-01-15T10:30:00Z'),
          updatedAt: DateTime.parse('2024-01-15T10:30:00Z'),
        );

        final json = friendRequest.toJson();

        expect(json['id'], 'request-123');
        expect(json['senderId'], 'user-456');
        expect(json['receiverId'], 'user-789');
        expect(json['status'], 'ACCEPTED');
        expect(json['createdAt'], '2024-01-15T10:30:00.000Z');
      });

      test('handles different status values', () {
        final pendingJson = {'status': 'PENDING'};
        final acceptedJson = {'status': 'ACCEPTED'};
        final declinedJson = {'status': 'DECLINED'};

        expect(
          FriendRequest.fromJson({
            ...pendingJson,
            'id': '1',
            'senderId': '2',
            'receiverId': '3',
            'createdAt': '2024-01-15T10:30:00Z',
            'updatedAt': '2024-01-15T10:30:00Z'
          }).status,
          FriendRequestStatus.pending,
        );
        expect(
          FriendRequest.fromJson({
            ...acceptedJson,
            'id': '1',
            'senderId': '2',
            'receiverId': '3',
            'createdAt': '2024-01-15T10:30:00Z',
            'updatedAt': '2024-01-15T10:30:00Z'
          }).status,
          FriendRequestStatus.accepted,
        );
        expect(
          FriendRequest.fromJson({
            ...declinedJson,
            'id': '1',
            'senderId': '2',
            'receiverId': '3',
            'createdAt': '2024-01-15T10:30:00Z',
            'updatedAt': '2024-01-15T10:30:00Z'
          }).status,
          FriendRequestStatus.declined,
        );
      });
    });

    group('UserFollow', () {
      test('fromJson creates UserFollow from JSON', () {
        final json = {
          'id': 'follow-123',
          'followerId': 'user-456',
          'followedId': 'user-789',
          'createdAt': '2024-01-15T10:30:00Z',
        };

        final userFollow = UserFollow.fromJson(json);

        expect(userFollow.id, 'follow-123');
        expect(userFollow.followerId, 'user-456');
        expect(userFollow.followedId, 'user-789');
        expect(userFollow.createdAt.year, 2024);
      });

      test('toJson converts UserFollow correctly', () {
        final userFollow = UserFollow(
          id: 'follow-123',
          followerId: 'user-456',
          followedId: 'user-789',
          createdAt: DateTime.parse('2024-01-15T10:30:00Z'),
        );

        final json = userFollow.toJson();

        expect(json['id'], 'follow-123');
        expect(json['followerId'], 'user-456');
        expect(json['followedId'], 'user-789');
        expect(json['createdAt'], '2024-01-15T10:30:00.000Z');
      });
    });

    group('Friendship', () {
      test('fromJson creates Friendship from JSON', () {
        final json = {
          'userId': 'user-123',
          'friendId': 'user-456',
        };

        final friendship = Friendship.fromJson(json);

        expect(friendship.userId, 'user-123');
        expect(friendship.friendId, 'user-456');
      });

      test('toJson converts Friendship correctly', () {
        final friendship = Friendship(
          userId: 'user-123',
          friendId: 'user-456',
        );

        final json = friendship.toJson();

        expect(json['userId'], 'user-123');
        expect(json['friendId'], 'user-456');
      });
    });

    group('FriendRequestRequest', () {
      test('toJson converts FriendRequestRequest correctly', () {
        final request = FriendRequestRequest(receiverId: 'user-123');

        final json = request.toJson();

        expect(json['receiverId'], 'user-123');
      });
    });

    group('UserFollowRequest', () {
      test('toJson converts UserFollowRequest correctly', () {
        final request = UserFollowRequest(followedId: 'user-123');

        final json = request.toJson();

        expect(json['followedId'], 'user-123');
      });
    });

    group('FriendRequestStatus', () {
      test('fromString converts status strings correctly', () {
        expect(
          FriendRequestStatus.fromString('PENDING'),
          FriendRequestStatus.pending,
        );
        expect(
          FriendRequestStatus.fromString('ACCEPTED'),
          FriendRequestStatus.accepted,
        );
        expect(
          FriendRequestStatus.fromString('DECLINED'),
          FriendRequestStatus.declined,
        );
      });

      test('toJson converts status to string correctly', () {
        expect(FriendRequestStatus.pending.toJson(), 'PENDING');
        expect(FriendRequestStatus.accepted.toJson(), 'ACCEPTED');
        expect(FriendRequestStatus.declined.toJson(), 'DECLINED');
      });

      test('handles lowercase status strings', () {
        expect(
          FriendRequestStatus.fromString('pending'),
          FriendRequestStatus.pending,
        );
        expect(
          FriendRequestStatus.fromString('accepted'),
          FriendRequestStatus.accepted,
        );
      });

      test('defaults to pending for unknown status', () {
        expect(
          FriendRequestStatus.fromString('UNKNOWN'),
          FriendRequestStatus.pending,
        );
      });
    });
  });
}
