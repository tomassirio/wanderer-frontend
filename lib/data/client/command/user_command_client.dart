import '../../../core/constants/api_endpoints.dart';
import '../../models/user_models.dart';
import '../api_client.dart';

/// User command client for write operations (Port 8081)
class UserCommandClient {
  final ApiClient _apiClient;

  UserCommandClient({ApiClient? apiClient})
      : _apiClient =
            apiClient ?? ApiClient(baseUrl: ApiEndpoints.commandBaseUrl);

  /// Create new user
  /// Requires authentication (ADMIN)
  Future<UserProfile> createUser(Map<String, dynamic> userData) async {
    final response = await _apiClient.post(
      ApiEndpoints.usersCreate,
      body: userData,
      requireAuth: true,
    );
    return _apiClient.handleResponse(response, UserProfile.fromJson);
  }

  /// Send a friend request
  /// Requires authentication (USER, ADMIN)
  /// Returns the request ID immediately. Full data will be delivered via WebSocket.
  Future<String> sendFriendRequest(String userId) async {
    final response = await _apiClient.post(
      ApiEndpoints.usersFriendRequests,
      body: {'receiverId': userId},
      requireAuth: true,
    );
    return _apiClient.handleAcceptedResponse(response);
  }

  /// Accept a friend request
  /// Requires authentication (USER, ADMIN)
  /// Returns the request ID immediately. Confirmation will be delivered via WebSocket.
  Future<String> acceptFriendRequest(String requestId) async {
    final response = await _apiClient.post(
      ApiEndpoints.usersFriendRequestAccept(requestId),
      body: {},
      requireAuth: true,
    );
    return _apiClient.handleAcceptedResponse(response);
  }

  /// Delete a friend request (decline if receiver, cancel if sender)
  /// Requires authentication (USER, ADMIN)
  /// Returns the request ID immediately. Confirmation will be delivered via WebSocket.
  /// - If you sent the request → cancels it (FRIEND_REQUEST_CANCELLED event)
  /// - If you received the request → declines it (FRIEND_REQUEST_DECLINED event)
  Future<String> deleteFriendRequest(String requestId) async {
    final response = await _apiClient.delete(
      ApiEndpoints.usersFriendRequestDelete(requestId),
      requireAuth: true,
    );
    return _apiClient.handleAcceptedResponse(response);
  }

  /// Remove a friend (unfriend)
  /// Requires authentication (USER, ADMIN)
  /// Returns the ID from the response. Confirmation will be delivered via WebSocket.
  Future<String> removeFriend(String friendId) async {
    final response = await _apiClient.delete(
      ApiEndpoints.usersRemoveFriend(friendId),
      requireAuth: true,
    );
    return _apiClient.handleAcceptedResponse(response);
  }

  /// Follow a user
  /// Requires authentication (USER, ADMIN)
  /// Returns the follow ID immediately. Confirmation will be delivered via WebSocket.
  Future<String> followUser(String userId) async {
    final response = await _apiClient.post(
      ApiEndpoints.usersFollows,
      body: {'followedId': userId},
      requireAuth: true,
    );
    return _apiClient.handleAcceptedResponse(response);
  }

  /// Unfollow a user
  /// Requires authentication (USER, ADMIN)
  /// Returns the ID from the response. Confirmation will be delivered via WebSocket.
  Future<String> unfollowUser(String followedId) async {
    final response = await _apiClient.delete(
      ApiEndpoints.usersUnfollow(followedId),
      requireAuth: true,
    );
    return _apiClient.handleAcceptedResponse(response);
  }

  /// Update current user's profile
  /// Requires authentication (USER, ADMIN)
  /// Returns the user ID from 202 Accepted response
  Future<String> updateProfile(UpdateProfileRequest request) async {
    final response = await _apiClient.patch(
      ApiEndpoints.usersUpdate,
      body: request.toJson(),
      requireAuth: true,
    );
    return _apiClient.handleAcceptedResponse(response);
  }

  /// Upload avatar for current user
  /// Requires authentication (USER, ADMIN)
  /// Returns the user ID from 202 Accepted response
  Future<String> uploadAvatar(List<int> fileBytes, String fileName) async {
    final response = await _apiClient.postMultipart(
      ApiEndpoints.usersAvatarUpload,
      fileBytes: fileBytes,
      fileName: fileName,
      fieldName: 'file',
      requireAuth: true,
    );
    return _apiClient.handleAcceptedResponse(response);
  }

  /// Delete avatar for current user
  /// Requires authentication (USER, ADMIN)
  /// Returns the user ID from 202 Accepted response
  Future<String> deleteAvatar() async {
    final response = await _apiClient.delete(
      ApiEndpoints.usersAvatarDelete,
      requireAuth: true,
    );
    return _apiClient.handleAcceptedResponse(response);
  }

  /// Delete own account
  /// Requires authentication (USER, ADMIN)
  /// DELETE /api/1/users/me → 202 Accepted
  Future<String> deleteMyAccount() async {
    final response = await _apiClient.delete(
      ApiEndpoints.usersDeleteMe,
      requireAuth: true,
    );
    return _apiClient.handleAcceptedResponse(response);
  }
}
