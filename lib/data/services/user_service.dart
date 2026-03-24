import '../client/command/user_command_client.dart';
import '../client/query/user_query_client.dart';
import '../models/user_models.dart';

/// Service for user operations
class UserService {
  final UserQueryClient _userQueryClient;
  final UserCommandClient _userCommandClient;

  UserService({
    UserQueryClient? userQueryClient,
    UserCommandClient? userCommandClient,
  })  : _userQueryClient = userQueryClient ?? UserQueryClient(),
        _userCommandClient = userCommandClient ?? UserCommandClient();

  /// Get own profile
  Future<UserProfile> getMyProfile() async {
    return await _userQueryClient.getCurrentUser();
  }

  /// Get user by ID
  Future<UserProfile> getUserById(String userId) async {
    return await _userQueryClient.getUserById(userId);
  }

  /// Get user by username
  Future<UserProfile> getUserByUsername(String username) async {
    return await _userQueryClient.getUserByUsername(username);
  }

  /// Get user's friends list
  /// Returns a list of friendships (userId and friendId pairs)
  Future<List<Friendship>> getFriends() async {
    return await _userQueryClient.getFriends();
  }

  /// Get pending received friend requests
  Future<List<FriendRequest>> getReceivedFriendRequests() async {
    return await _userQueryClient.getReceivedFriendRequests();
  }

  /// Get pending sent friend requests
  Future<List<FriendRequest>> getSentFriendRequests() async {
    return await _userQueryClient.getSentFriendRequests();
  }

  /// Get users that current user follows
  /// Returns a list of follow relationships
  Future<List<UserFollow>> getFollowing() async {
    return await _userQueryClient.getFollowing();
  }

  /// Get users that follow current user
  /// Returns a list of follow relationships
  Future<List<UserFollow>> getFollowers() async {
    return await _userQueryClient.getFollowers();
  }

  /// Get users that a specific user follows
  Future<List<UserFollow>> getUserFollowing(String userId) async {
    return await _userQueryClient.getUserFollowing(userId);
  }

  /// Get users that follow a specific user
  Future<List<UserFollow>> getUserFollowers(String userId) async {
    return await _userQueryClient.getUserFollowers(userId);
  }

  /// Get friends of a specific user
  Future<List<Friendship>> getUserFriends(String userId) async {
    return await _userQueryClient.getUserFriends(userId);
  }

  /// Send a friend request
  /// Returns the request ID immediately. Confirmation will be delivered via WebSocket.
  Future<String> sendFriendRequest(String userId) async {
    return await _userCommandClient.sendFriendRequest(userId);
  }

  /// Accept a friend request
  /// Returns the request ID immediately. Confirmation will be delivered via WebSocket.
  Future<String> acceptFriendRequest(String requestId) async {
    return await _userCommandClient.acceptFriendRequest(requestId);
  }

  /// Delete a friend request (decline if receiver, cancel if sender)
  /// Returns the request ID immediately. Confirmation will be delivered via WebSocket.
  /// - If you sent the request → cancels it (FRIEND_REQUEST_CANCELLED event)
  /// - If you received the request → declines it (FRIEND_REQUEST_DECLINED event)
  Future<String> deleteFriendRequest(String requestId) async {
    return await _userCommandClient.deleteFriendRequest(requestId);
  }

  /// Remove a friend (unfriend)
  /// Returns the ID from the response. Confirmation will be delivered via WebSocket.
  Future<String> removeFriend(String friendId) async {
    return await _userCommandClient.removeFriend(friendId);
  }

  /// Follow a user
  /// Returns the follow ID immediately. Confirmation will be delivered via WebSocket.
  Future<String> followUser(String userId) async {
    return await _userCommandClient.followUser(userId);
  }

  /// Unfollow a user
  /// Returns the ID from the response. Event will be delivered via WebSocket.
  Future<String> unfollowUser(String userId) async {
    return await _userCommandClient.unfollowUser(userId);
  }

  /// Update current user's profile
  /// Returns the user ID from 202 Accepted response
  Future<String> updateProfile(UpdateProfileRequest request) async {
    return await _userCommandClient.updateProfile(request);
  }

  /// Upload avatar for current user
  /// Returns the user ID from 202 Accepted response
  Future<String> uploadAvatar(List<int> fileBytes, String fileName) async {
    return await _userCommandClient.uploadAvatar(fileBytes, fileName);
  }

  /// Delete avatar for current user
  /// Returns the user ID from 202 Accepted response
  Future<String> deleteAvatar() async {
    return await _userCommandClient.deleteAvatar();
  }

  /// Delete own account
  /// Returns the ID from the response. Any authenticated user can delete their own account.
  Future<String> deleteMyAccount() async {
    return await _userCommandClient.deleteMyAccount();
  }
}
