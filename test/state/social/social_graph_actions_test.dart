import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:wanderer_frontend/data/models/responses/page_response.dart';
import 'package:wanderer_frontend/data/models/user_models.dart';
import 'package:wanderer_frontend/data/services/user_service.dart';
import 'package:wanderer_frontend/presentation/state/social/social_graph_actions.dart';

import 'social_graph_actions_test.mocks.dart';

@GenerateMocks([UserService])
void main() {
  late MockUserService mockUserService;
  late SocialGraphActions actions;
  const targetUserId = 'target-1';

  setUp(() {
    mockUserService = MockUserService();
    actions = SocialGraphActions(mockUserService);
  });

  group('loadStatus', () {
    test('reports following/friends/pending-request when all three are true',
        () async {
      when(mockUserService.getFollowing(page: 0, size: 100)).thenAnswer(
        (_) async => PageResponse<UserFollow>(
          content: [
            UserFollow(
              id: 'follow-1',
              followerId: 'me',
              followedId: targetUserId,
              createdAt: DateTime(2026, 1, 1),
            ),
          ],
          totalElements: 1,
          totalPages: 1,
          number: 0,
          size: 100,
          last: true,
          first: true,
        ),
      );
      when(mockUserService.getFriends(page: 0, size: 100)).thenAnswer(
        (_) async => PageResponse<Friendship>(
          content: [Friendship(userId: 'me', friendId: targetUserId)],
          totalElements: 1,
          totalPages: 1,
          number: 0,
          size: 100,
          last: true,
          first: true,
        ),
      );
      when(mockUserService.getSentFriendRequests()).thenAnswer(
        (_) async => [
          FriendRequest(
            id: 'req-1',
            senderId: 'me',
            receiverId: targetUserId,
            status: FriendRequestStatus.pending,
            createdAt: DateTime(2026, 1, 1),
            updatedAt: DateTime(2026, 1, 1),
          ),
        ],
      );

      final status = await actions.loadStatus(targetUserId);

      expect(status.isFollowing, isTrue);
      expect(status.isAlreadyFriends, isTrue);
      expect(status.hasSentFriendRequest, isTrue);
      expect(status.sentFriendRequestId, 'req-1');
    });

    test('reports all-false when nothing matches the target user', () async {
      when(mockUserService.getFollowing(page: 0, size: 100)).thenAnswer(
        (_) async => PageResponse<UserFollow>(
          content: const [],
          totalElements: 0,
          totalPages: 0,
          number: 0,
          size: 100,
          last: true,
          first: true,
        ),
      );
      when(mockUserService.getFriends(page: 0, size: 100)).thenAnswer(
        (_) async => PageResponse<Friendship>(
          content: const [],
          totalElements: 0,
          totalPages: 0,
          number: 0,
          size: 100,
          last: true,
          first: true,
        ),
      );
      when(mockUserService.getSentFriendRequests())
          .thenAnswer((_) async => []);

      final status = await actions.loadStatus(targetUserId);

      expect(status.isFollowing, isFalse);
      expect(status.isAlreadyFriends, isFalse);
      expect(status.hasSentFriendRequest, isFalse);
      expect(status.sentFriendRequestId, isNull);
    });
  });

  group('toggleFollow', () {
    test('unfollows when currentlyFollowing is true', () async {
      when(mockUserService.unfollowUser(targetUserId))
          .thenAnswer((_) async => 'ok');

      final nowFollowing =
          await actions.toggleFollow(targetUserId, currentlyFollowing: true);

      expect(nowFollowing, isFalse);
      verify(mockUserService.unfollowUser(targetUserId)).called(1);
      verifyNever(mockUserService.followUser(any));
    });

    test('follows when currentlyFollowing is false', () async {
      when(mockUserService.followUser(targetUserId))
          .thenAnswer((_) async => 'ok');

      final nowFollowing =
          await actions.toggleFollow(targetUserId, currentlyFollowing: false);

      expect(nowFollowing, isTrue);
      verify(mockUserService.followUser(targetUserId)).called(1);
    });
  });

  group('toggleFriendRequest', () {
    test('unfriends when already friends', () async {
      when(mockUserService.removeFriend(targetUserId))
          .thenAnswer((_) async => 'ok');

      final result = await actions.toggleFriendRequest(
        targetUserId,
        isAlreadyFriends: true,
        hasSentFriendRequest: false,
        sentFriendRequestId: null,
      );

      expect(result.isAlreadyFriends, isFalse);
      verify(mockUserService.removeFriend(targetUserId)).called(1);
    });

    test('cancels a pending sent request', () async {
      when(mockUserService.deleteFriendRequest('req-1'))
          .thenAnswer((_) async => 'ok');

      final result = await actions.toggleFriendRequest(
        targetUserId,
        isAlreadyFriends: false,
        hasSentFriendRequest: true,
        sentFriendRequestId: 'req-1',
      );

      expect(result.hasSentFriendRequest, isFalse);
      expect(result.sentFriendRequestId, isNull);
      verify(mockUserService.deleteFriendRequest('req-1')).called(1);
    });

    test('sends a new friend request when neither friends nor pending',
        () async {
      when(mockUserService.sendFriendRequest(targetUserId))
          .thenAnswer((_) async => 'req-new');

      final result = await actions.toggleFriendRequest(
        targetUserId,
        isAlreadyFriends: false,
        hasSentFriendRequest: false,
        sentFriendRequestId: null,
      );

      expect(result.hasSentFriendRequest, isTrue);
      expect(result.sentFriendRequestId, 'req-new');
      verify(mockUserService.sendFriendRequest(targetUserId)).called(1);
    });
  });
}
