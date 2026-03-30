import 'dart:convert';

import '../../../core/constants/api_endpoints.dart';
import '../../models/responses/page_response.dart';
import '../../models/user_models.dart';
import '../api_client.dart';

/// User query client for read operations (Port 8082)
class UserQueryClient {
  final ApiClient _apiClient;

  UserQueryClient({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient(baseUrl: ApiEndpoints.queryBaseUrl);

  /// Get all users with pagination and sorting (Admin only)
  Future<PageResponse<UserProfile>> getAllUsers({
    int page = 0,
    int size = 20,
    String sort = 'username',
    String direction = 'asc',
  }) async {
    final endpoint =
        '${ApiEndpoints.usersAll}?page=$page&size=$size&sort=$sort,$direction';
    final response = await _apiClient.get(
      endpoint,
      requireAuth: true,
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return PageResponse.fromJson(data, UserProfile.fromJson);
    } else {
      throw Exception(
          'API Error (${response.statusCode}): Failed to fetch users');
    }
  }

  /// Get user by ID
  /// Requires authentication (ADMIN, USER)
  Future<UserProfile> getUserById(String userId) async {
    final response = await _apiClient.get(
      ApiEndpoints.userById(userId),
      requireAuth: true,
    );
    return _apiClient.handleResponse(response, UserProfile.fromJson);
  }

  /// Get user by username
  /// No authentication required (Public)
  Future<UserProfile> getUserByUsername(String username) async {
    final response = await _apiClient.get(
      ApiEndpoints.userByUsername(username),
      requireAuth: false,
    );
    return _apiClient.handleResponse(response, UserProfile.fromJson);
  }

  /// Get current authenticated user profile
  /// Requires authentication (USER, ADMIN)
  Future<UserProfile> getCurrentUser() async {
    final response = await _apiClient.get(
      ApiEndpoints.usersMe,
      requireAuth: true,
    );
    return _apiClient.handleResponse(response, UserProfile.fromJson);
  }

  /// Get current user's friends list (paginated)
  /// Requires authentication (USER, ADMIN)
  /// Returns a page of friendships (userId and friendId pairs)
  Future<PageResponse<Friendship>> getFriends({
    int page = 0,
    int size = 20,
    String sort = 'createdAt,desc',
  }) async {
    final endpoint =
        '${ApiEndpoints.usersMeFriends}?page=$page&size=$size&sort=$sort';
    final response = await _apiClient.get(
      endpoint,
      requireAuth: true,
    );
    return _apiClient.handlePageResponse(response, Friendship.fromJson);
  }

  /// Get pending received friend requests
  /// Requires authentication (USER, ADMIN)
  Future<List<FriendRequest>> getReceivedFriendRequests() async {
    final response = await _apiClient.get(
      ApiEndpoints.usersFriendRequestsReceived,
      requireAuth: true,
    );
    return _apiClient.handleListResponse(response, FriendRequest.fromJson);
  }

  /// Get pending sent friend requests
  /// Requires authentication (USER, ADMIN)
  Future<List<FriendRequest>> getSentFriendRequests() async {
    final response = await _apiClient.get(
      ApiEndpoints.usersFriendRequestsSent,
      requireAuth: true,
    );
    return _apiClient.handleListResponse(response, FriendRequest.fromJson);
  }

  /// Get users that current user follows (paginated)
  /// Requires authentication (USER, ADMIN)
  /// Returns a page of follow relationships
  Future<PageResponse<UserFollow>> getFollowing({
    int page = 0,
    int size = 20,
    String sort = 'createdAt,desc',
  }) async {
    final endpoint =
        '${ApiEndpoints.usersMeFollowing}?page=$page&size=$size&sort=$sort';
    final response = await _apiClient.get(
      endpoint,
      requireAuth: true,
    );
    return _apiClient.handlePageResponse(response, UserFollow.fromJson);
  }

  /// Get users that follow current user (paginated)
  /// Requires authentication (USER, ADMIN)
  /// Returns a page of follow relationships
  Future<PageResponse<UserFollow>> getFollowers({
    int page = 0,
    int size = 20,
    String sort = 'createdAt,desc',
  }) async {
    final endpoint =
        '${ApiEndpoints.usersMeFollowers}?page=$page&size=$size&sort=$sort';
    final response = await _apiClient.get(
      endpoint,
      requireAuth: true,
    );
    return _apiClient.handlePageResponse(response, UserFollow.fromJson);
  }

  /// Get users that a specific user follows (paginated)
  /// Requires authentication (USER, ADMIN)
  Future<PageResponse<UserFollow>> getUserFollowing(
    String userId, {
    int page = 0,
    int size = 20,
    String sort = 'createdAt,desc',
  }) async {
    final endpoint =
        '${ApiEndpoints.userFollowing(userId)}?page=$page&size=$size&sort=$sort';
    final response = await _apiClient.get(
      endpoint,
      requireAuth: true,
    );
    return _apiClient.handlePageResponse(response, UserFollow.fromJson);
  }

  /// Get users that follow a specific user (paginated)
  /// Requires authentication (USER, ADMIN)
  Future<PageResponse<UserFollow>> getUserFollowers(
    String userId, {
    int page = 0,
    int size = 20,
    String sort = 'createdAt,desc',
  }) async {
    final endpoint =
        '${ApiEndpoints.userFollowers(userId)}?page=$page&size=$size&sort=$sort';
    final response = await _apiClient.get(
      endpoint,
      requireAuth: true,
    );
    return _apiClient.handlePageResponse(response, UserFollow.fromJson);
  }

  /// Get friends of a specific user (paginated)
  /// Requires authentication (USER, ADMIN)
  Future<PageResponse<Friendship>> getUserFriends(
    String userId, {
    int page = 0,
    int size = 20,
    String sort = 'createdAt,desc',
  }) async {
    final endpoint =
        '${ApiEndpoints.userFriends(userId)}?page=$page&size=$size&sort=$sort';
    final response = await _apiClient.get(
      endpoint,
      requireAuth: true,
    );
    return _apiClient.handlePageResponse(response, Friendship.fromJson);
  }

  /// Get discoverable users (friends of friends and people followed by friends)
  /// Requires authentication (USER, ADMIN)
  Future<PageResponse<UserProfile>> getDiscoverableUsers({
    int page = 0,
    int size = 20,
  }) async {
    final endpoint = '${ApiEndpoints.usersMeDiscover}?page=$page&size=$size';
    final response = await _apiClient.get(
      endpoint,
      requireAuth: true,
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return PageResponse.fromJson(data, UserProfile.fromJson);
    } else {
      throw Exception(
          'API Error (${response.statusCode}): Failed to fetch discoverable users');
    }
  }

  /// Get all users associated with a target user, showing relationship status
  /// from the current user's perspective.
  /// Requires authentication (USER, ADMIN)
  Future<PageResponse<UserRelationship>> getAssociatedUsers(
    String userId, {
    int page = 0,
    int size = 20,
  }) async {
    final endpoint =
        '${ApiEndpoints.userAssociated(userId)}?page=$page&size=$size';
    final response = await _apiClient.get(
      endpoint,
      requireAuth: true,
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return PageResponse.fromJson(data, UserRelationship.fromJson);
    } else {
      throw Exception(
          'API Error (${response.statusCode}): Failed to fetch associated users');
    }
  }
}
