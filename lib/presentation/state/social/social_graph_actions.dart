import 'package:wanderer_frontend/data/models/user_models.dart';
import 'package:wanderer_frontend/data/services/user_service.dart';

/// A target user's follow/friend relationship to the current viewer, as
/// computed by [SocialGraphActions.loadStatus].
class SocialGraphStatus {
  final bool isFollowing;
  final bool isAlreadyFriends;
  final bool hasSentFriendRequest;
  final String? sentFriendRequestId;

  const SocialGraphStatus({
    required this.isFollowing,
    required this.isAlreadyFriends,
    required this.hasSentFriendRequest,
    this.sentFriendRequestId,
  });
}

/// Result of [SocialGraphActions.toggleFriendRequest] — the new
/// friend/request state after an unfriend, cancel, or send action.
class FriendRequestResult {
  final bool isAlreadyFriends;
  final bool hasSentFriendRequest;
  final String? sentFriendRequestId;

  const FriendRequestResult({
    required this.isAlreadyFriends,
    required this.hasSentFriendRequest,
    this.sentFriendRequestId,
  });
}

/// Follow/friend-request algorithm shared by `TripDetailNotifier` (relative
/// to a trip's owner) and `ProfileNotifier` (relative to the profile being
/// viewed) — same three-way branch, different target user. Callers own
/// their own error handling: these methods let exceptions propagate
/// (neither existing call site wants a try/catch at this layer).
class SocialGraphActions {
  final UserService _userService;

  SocialGraphActions(this._userService);

  Future<SocialGraphStatus> loadStatus(String targetUserId) async {
    final followingPage =
        await _userService.getFollowing(page: 0, size: 100);
    final isFollowing =
        followingPage.content.any((f) => f.followedId == targetUserId);

    final sentRequests = await _userService.getSentFriendRequests();
    final pendingRequest = sentRequests.cast<FriendRequest?>().firstWhere(
          (r) =>
              r!.receiverId == targetUserId &&
              r.status == FriendRequestStatus.pending,
          orElse: () => null,
        );
    final hasSentRequest = pendingRequest != null;
    final requestId = pendingRequest?.id;

    final friendsPage = await _userService.getFriends(page: 0, size: 100);
    final isAlreadyFriends =
        friendsPage.content.any((f) => f.friendId == targetUserId);

    return SocialGraphStatus(
      isFollowing: isFollowing,
      isAlreadyFriends: isAlreadyFriends,
      hasSentFriendRequest: hasSentRequest,
      sentFriendRequestId: requestId,
    );
  }

  Future<bool> toggleFollow(
    String targetUserId, {
    required bool currentlyFollowing,
  }) async {
    if (currentlyFollowing) {
      await _userService.unfollowUser(targetUserId);
      return false;
    } else {
      await _userService.followUser(targetUserId);
      return true;
    }
  }

  Future<FriendRequestResult> toggleFriendRequest(
    String targetUserId, {
    required bool isAlreadyFriends,
    required bool hasSentFriendRequest,
    required String? sentFriendRequestId,
  }) async {
    if (isAlreadyFriends) {
      await _userService.removeFriend(targetUserId);
      return FriendRequestResult(
        isAlreadyFriends: false,
        hasSentFriendRequest: hasSentFriendRequest,
        sentFriendRequestId: sentFriendRequestId,
      );
    }

    if (hasSentFriendRequest && sentFriendRequestId != null) {
      await _userService.deleteFriendRequest(sentFriendRequestId);
      return const FriendRequestResult(
        isAlreadyFriends: false,
        hasSentFriendRequest: false,
        sentFriendRequestId: null,
      );
    }

    final requestId = await _userService.sendFriendRequest(targetUserId);
    return FriendRequestResult(
      isAlreadyFriends: false,
      hasSentFriendRequest: true,
      sentFriendRequestId: requestId,
    );
  }
}
