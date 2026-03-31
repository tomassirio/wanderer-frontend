import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:wanderer_frontend/data/models/user_models.dart';
import 'package:wanderer_frontend/data/models/responses/page_response.dart';
import 'package:wanderer_frontend/data/services/user_service.dart';
import 'package:wanderer_frontend/data/client/query/user_query_client.dart';
import 'package:wanderer_frontend/data/client/command/user_command_client.dart';

import 'user_service_test.mocks.dart';

@GenerateMocks([UserQueryClient, UserCommandClient])
void main() {
  group('UserService', () {
    late MockUserQueryClient mockUserQueryClient;
    late MockUserCommandClient mockUserCommandClient;
    late UserService userService;

    setUp(() {
      mockUserQueryClient = MockUserQueryClient();
      mockUserCommandClient = MockUserCommandClient();
      userService = UserService(
        userQueryClient: mockUserQueryClient,
        userCommandClient: mockUserCommandClient,
      );
    });

    group('getMyProfile', () {
      test('returns current user profile', () async {
        final mockProfile = createMockUserProfile('user-123', 'testuser');

        when(
          mockUserQueryClient.getCurrentUser(),
        ).thenAnswer((_) async => mockProfile);

        final result = await userService.getMyProfile();

        expect(result.id, 'user-123');
        expect(result.username, 'testuser');
        verify(mockUserQueryClient.getCurrentUser()).called(1);
      });

      test('handles errors when fetching profile', () async {
        when(
          mockUserQueryClient.getCurrentUser(),
        ).thenThrow(Exception('Failed to fetch profile'));

        expect(() => userService.getMyProfile(), throwsException);
      });
    });

    group('getUserById', () {
      test('returns user profile by ID', () async {
        final mockProfile = createMockUserProfile('user-456', 'anotheruser');

        when(
          mockUserQueryClient.getUserById('user-456'),
        ).thenAnswer((_) async => mockProfile);

        final result = await userService.getUserById('user-456');

        expect(result.id, 'user-456');
        expect(result.username, 'anotheruser');
        verify(mockUserQueryClient.getUserById('user-456')).called(1);
      });

      test('handles errors when fetching user by ID', () async {
        when(
          mockUserQueryClient.getUserById(any),
        ).thenThrow(Exception('User not found'));

        expect(() => userService.getUserById('invalid-id'), throwsException);
      });
    });

    group('getUserByUsername', () {
      test('returns user profile by username', () async {
        final mockProfile = createMockUserProfile('user-789', 'johndoe');

        when(
          mockUserQueryClient.getUserByUsername('johndoe'),
        ).thenAnswer((_) async => mockProfile);

        final result = await userService.getUserByUsername('johndoe');

        expect(result.id, 'user-789');
        expect(result.username, 'johndoe');
        verify(mockUserQueryClient.getUserByUsername('johndoe')).called(1);
      });

      test('handles errors when fetching user by username', () async {
        when(
          mockUserQueryClient.getUserByUsername(any),
        ).thenThrow(Exception('User not found'));

        expect(
          () => userService.getUserByUsername('nonexistent'),
          throwsException,
        );
      });
    });

    group('getFriends', () {
      test('returns list of friends', () async {
        final mockFriends = [
          Friendship(userId: 'current-user', friendId: 'friend-1'),
          Friendship(userId: 'current-user', friendId: 'friend-2'),
        ];

        when(
          mockUserQueryClient.getFriends(),
        ).thenAnswer((_) async => _wrapFriendshipPage(mockFriends));

        final result = await userService.getFriends();

        expect(result.content.length, 2);
        expect(result.content[0].friendId, 'friend-1');
        expect(result.content[1].friendId, 'friend-2');
        verify(mockUserQueryClient.getFriends()).called(1);
      });

      test('returns empty list when user has no friends', () async {
        when(mockUserQueryClient.getFriends())
            .thenAnswer((_) async => _wrapFriendshipPage([]));

        final result = await userService.getFriends();

        expect(result.content, isEmpty);
        verify(mockUserQueryClient.getFriends()).called(1);
      });

      test('handles errors when fetching friends', () async {
        when(
          mockUserQueryClient.getFriends(),
        ).thenThrow(Exception('Failed to fetch friends'));

        expect(() => userService.getFriends(), throwsException);
      });
    });

    group('getReceivedFriendRequests', () {
      test('returns list of received friend requests', () async {
        final mockRequests = [
          FriendRequest(
            id: 'req-1',
            senderId: 'user-1',
            receiverId: 'current-user',
            status: FriendRequestStatus.pending,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          FriendRequest(
            id: 'req-2',
            senderId: 'user-2',
            receiverId: 'current-user',
            status: FriendRequestStatus.pending,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ];

        when(
          mockUserQueryClient.getReceivedFriendRequests(),
        ).thenAnswer((_) async => mockRequests);

        final result = await userService.getReceivedFriendRequests();

        expect(result.length, 2);
        verify(mockUserQueryClient.getReceivedFriendRequests()).called(1);
      });

      test('returns empty list when no pending requests', () async {
        when(
          mockUserQueryClient.getReceivedFriendRequests(),
        ).thenAnswer((_) async => []);

        final result = await userService.getReceivedFriendRequests();

        expect(result, isEmpty);
      });

      test('handles errors when fetching received requests', () async {
        when(
          mockUserQueryClient.getReceivedFriendRequests(),
        ).thenThrow(Exception('Failed to fetch requests'));

        expect(() => userService.getReceivedFriendRequests(), throwsException);
      });
    });

    group('getSentFriendRequests', () {
      test('returns list of sent friend requests', () async {
        final mockRequests = [
          FriendRequest(
            id: 'req-3',
            senderId: 'current-user',
            receiverId: 'user-3',
            status: FriendRequestStatus.pending,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          FriendRequest(
            id: 'req-4',
            senderId: 'current-user',
            receiverId: 'user-4',
            status: FriendRequestStatus.pending,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ];

        when(
          mockUserQueryClient.getSentFriendRequests(),
        ).thenAnswer((_) async => mockRequests);

        final result = await userService.getSentFriendRequests();

        expect(result.length, 2);
        verify(mockUserQueryClient.getSentFriendRequests()).called(1);
      });

      test('returns empty list when no sent requests', () async {
        when(
          mockUserQueryClient.getSentFriendRequests(),
        ).thenAnswer((_) async => []);

        final result = await userService.getSentFriendRequests();

        expect(result, isEmpty);
      });

      test('handles errors when fetching sent requests', () async {
        when(
          mockUserQueryClient.getSentFriendRequests(),
        ).thenThrow(Exception('Failed to fetch sent requests'));

        expect(() => userService.getSentFriendRequests(), throwsException);
      });
    });

    group('getFollowing', () {
      test('returns list of users being followed', () async {
        final mockFollowing = [
          UserFollow(
            id: 'follow-1',
            followerId: 'current-user',
            followedId: 'user-5',
            createdAt: DateTime.now(),
          ),
          UserFollow(
            id: 'follow-2',
            followerId: 'current-user',
            followedId: 'user-6',
            createdAt: DateTime.now(),
          ),
        ];

        when(
          mockUserQueryClient.getFollowing(),
        ).thenAnswer((_) async => _wrapUserFollowPage(mockFollowing));

        final result = await userService.getFollowing();

        expect(result.content.length, 2);
        expect(result.content[0].followedId, 'user-5');
        expect(result.content[1].followedId, 'user-6');
        verify(mockUserQueryClient.getFollowing()).called(1);
      });

      test('returns empty list when not following anyone', () async {
        when(mockUserQueryClient.getFollowing())
            .thenAnswer((_) async => _wrapUserFollowPage([]));

        final result = await userService.getFollowing();

        expect(result.content, isEmpty);
      });

      test('handles errors when fetching following list', () async {
        when(
          mockUserQueryClient.getFollowing(),
        ).thenThrow(Exception('Failed to fetch following'));

        expect(() => userService.getFollowing(), throwsException);
      });
    });

    group('getFollowers', () {
      test('returns list of followers', () async {
        final mockFollowers = [
          UserFollow(
            id: 'follow-3',
            followerId: 'user-7',
            followedId: 'current-user',
            createdAt: DateTime.now(),
          ),
          UserFollow(
            id: 'follow-4',
            followerId: 'user-8',
            followedId: 'current-user',
            createdAt: DateTime.now(),
          ),
        ];

        when(
          mockUserQueryClient.getFollowers(),
        ).thenAnswer((_) async => _wrapUserFollowPage(mockFollowers));

        final result = await userService.getFollowers();

        expect(result.content.length, 2);
        expect(result.content[0].followerId, 'user-7');
        expect(result.content[1].followerId, 'user-8');
        verify(mockUserQueryClient.getFollowers()).called(1);
      });

      test('returns empty list when user has no followers', () async {
        when(mockUserQueryClient.getFollowers())
            .thenAnswer((_) async => _wrapUserFollowPage([]));

        final result = await userService.getFollowers();

        expect(result.content, isEmpty);
      });

      test('handles errors when fetching followers', () async {
        when(
          mockUserQueryClient.getFollowers(),
        ).thenThrow(Exception('Failed to fetch followers'));

        expect(() => userService.getFollowers(), throwsException);
      });
    });

    group('sendFriendRequest', () {
      test('sends friend request successfully', () async {
        when(
          mockUserCommandClient.sendFriendRequest('user-123'),
        ).thenAnswer((_) async => 'request-123');

        final result = await userService.sendFriendRequest('user-123');

        expect(result, 'request-123');
        verify(mockUserCommandClient.sendFriendRequest('user-123')).called(1);
      });

      test('handles errors when sending friend request', () async {
        when(
          mockUserCommandClient.sendFriendRequest('user-123'),
        ).thenThrow(Exception('Failed to send request'));

        expect(
          () => userService.sendFriendRequest('user-123'),
          throwsException,
        );
      });

      test('passes correct user ID to command client', () async {
        when(
          mockUserCommandClient.sendFriendRequest('user-456'),
        ).thenAnswer((_) async => 'request-456');

        final result = await userService.sendFriendRequest('user-456');

        expect(result, 'request-456');
        verify(mockUserCommandClient.sendFriendRequest('user-456')).called(1);
      });
    });

    group('acceptFriendRequest', () {
      test('accepts friend request successfully', () async {
        when(
          mockUserCommandClient.acceptFriendRequest('req-123'),
        ).thenAnswer((_) async => 'req-123');

        final result = await userService.acceptFriendRequest('req-123');

        expect(result, 'req-123');
        verify(mockUserCommandClient.acceptFriendRequest('req-123')).called(1);
      });

      test('handles errors when accepting friend request', () async {
        when(
          mockUserCommandClient.acceptFriendRequest('req-123'),
        ).thenThrow(Exception('Failed to accept request'));

        expect(
          () => userService.acceptFriendRequest('req-123'),
          throwsException,
        );
      });

      test('passes correct request ID to command client', () async {
        when(
          mockUserCommandClient.acceptFriendRequest('req-789'),
        ).thenAnswer((_) async => 'req-789');

        final result = await userService.acceptFriendRequest('req-789');

        expect(result, 'req-789');
        verify(mockUserCommandClient.acceptFriendRequest('req-789')).called(1);
      });
    });

    group('deleteFriendRequest', () {
      test('deletes friend request successfully', () async {
        when(
          mockUserCommandClient.deleteFriendRequest('req-123'),
        ).thenAnswer((_) async => 'req-123');

        final result = await userService.deleteFriendRequest('req-123');

        expect(result, 'req-123');
        verify(mockUserCommandClient.deleteFriendRequest('req-123')).called(1);
      });

      test('handles errors when deleting friend request', () async {
        when(
          mockUserCommandClient.deleteFriendRequest('req-123'),
        ).thenThrow(Exception('Failed to delete request'));

        expect(
          () => userService.deleteFriendRequest('req-123'),
          throwsException,
        );
      });

      test('passes correct request ID to command client', () async {
        when(
          mockUserCommandClient.deleteFriendRequest('req-456'),
        ).thenAnswer((_) async => 'req-456');

        final result = await userService.deleteFriendRequest('req-456');

        expect(result, 'req-456');
        verify(mockUserCommandClient.deleteFriendRequest('req-456')).called(1);
      });
    });

    group('followUser', () {
      test('follows user successfully', () async {
        when(
          mockUserCommandClient.followUser('user-123'),
        ).thenAnswer((_) async => 'follow-123');

        final result = await userService.followUser('user-123');

        expect(result, 'follow-123');
        verify(mockUserCommandClient.followUser('user-123')).called(1);
      });

      test('handles errors when following user', () async {
        when(
          mockUserCommandClient.followUser('user-123'),
        ).thenThrow(Exception('Failed to follow user'));

        expect(() => userService.followUser('user-123'), throwsException);
      });

      test('passes correct user ID to command client', () async {
        when(
          mockUserCommandClient.followUser('user-789'),
        ).thenAnswer((_) async => 'follow-789');

        final result = await userService.followUser('user-789');

        expect(result, 'follow-789');
        verify(mockUserCommandClient.followUser('user-789')).called(1);
      });
    });

    group('unfollowUser', () {
      test('unfollows user successfully', () async {
        when(
          mockUserCommandClient.unfollowUser('user-123'),
        ).thenAnswer((_) async => 'user-123');

        final result = await userService.unfollowUser('user-123');

        expect(result, 'user-123');
        verify(mockUserCommandClient.unfollowUser('user-123')).called(1);
      });

      test('handles errors when unfollowing user', () async {
        when(
          mockUserCommandClient.unfollowUser('user-123'),
        ).thenThrow(Exception('Failed to unfollow user'));

        expect(() => userService.unfollowUser('user-123'), throwsException);
      });

      test('passes correct user ID to command client', () async {
        when(
          mockUserCommandClient.unfollowUser('user-456'),
        ).thenAnswer((_) async => 'user-456');

        final result = await userService.unfollowUser('user-456');

        expect(result, 'user-456');
        verify(mockUserCommandClient.unfollowUser('user-456')).called(1);
      });
    });

    group('updateProfile', () {
      test('updates profile successfully', () async {
        final request = UpdateProfileRequest(
          displayName: 'John Doe',
          bio: 'Test bio',
        );

        when(
          mockUserCommandClient.updateProfile(request),
        ).thenAnswer((_) async => 'user-123');

        final result = await userService.updateProfile(request);

        expect(result, 'user-123');
        verify(mockUserCommandClient.updateProfile(request)).called(1);
      });

      test('handles errors when updating profile', () async {
        final request = UpdateProfileRequest(displayName: 'Test');

        when(
          mockUserCommandClient.updateProfile(request),
        ).thenThrow(Exception('Failed to update profile'));

        expect(() => userService.updateProfile(request), throwsException);
      });

      test('passes correct request to command client', () async {
        final request = UpdateProfileRequest(
          displayName: 'Updated Name',
          bio: 'Updated bio',
        );

        when(
          mockUserCommandClient.updateProfile(request),
        ).thenAnswer((_) async => 'user-123');

        await userService.updateProfile(request);

        verify(mockUserCommandClient.updateProfile(request)).called(1);
      });
    });
  });
}

// Helper function
UserProfile createMockUserProfile(String id, String username) {
  return UserProfile(
    id: id,
    username: username,
    email: '$username@example.com',
    createdAt: DateTime.now(),
    followersCount: 0,
    followingCount: 0,
    tripsCount: 0,
  );
}

PageResponse<Friendship> _wrapFriendshipPage(List<Friendship> items) {
  return PageResponse(
    content: items,
    totalElements: items.length,
    totalPages: items.isEmpty ? 0 : 1,
    number: 0,
    size: 20,
    first: true,
    last: true,
  );
}

PageResponse<UserFollow> _wrapUserFollowPage(List<UserFollow> items) {
  return PageResponse(
    content: items,
    totalElements: items.length,
    totalPages: items.isEmpty ? 0 : 1,
    number: 0,
    size: 20,
    first: true,
    last: true,
  );
}
