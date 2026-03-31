import 'package:flutter/foundation.dart';
import 'package:wanderer_frontend/data/models/responses/page_response.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/data/services/trip_service.dart';
import 'package:wanderer_frontend/data/services/auth_service.dart';
import 'package:wanderer_frontend/data/services/user_service.dart';

/// Repository for managing home screen data and operations
class HomeRepository {
  final TripService _tripService;
  final AuthService _authService;
  final UserService _userService;

  HomeRepository({
    TripService? tripService,
    AuthService? authService,
    UserService? userService,
  })  : _tripService = tripService ?? TripService(),
        _authService = authService ?? AuthService(),
        _userService = userService ?? UserService();

  /// Gets the current user's username
  Future<String?> getCurrentUsername() async {
    return await _authService.getCurrentUsername();
  }

  /// Gets the current user's display name
  Future<String?> getCurrentDisplayName() async {
    return await _authService.getCurrentDisplayName();
  }

  /// Gets the current user's avatar URL
  Future<String?> getCurrentAvatarUrl() async {
    return await _authService.getCurrentAvatarUrl();
  }

  /// Refreshes user details (displayName, avatarUrl) from the API
  Future<bool> refreshUserDetails() async {
    return await _authService.refreshUserDetails();
  }

  /// Gets the current user's ID
  Future<String?> getCurrentUserId() async {
    return await _authService.getCurrentUserId();
  }

  /// Checks if user is logged in
  Future<bool> isLoggedIn() async {
    return await _authService.isLoggedIn();
  }

  /// Checks if user is admin
  Future<bool> isAdmin() async {
    return await _authService.isAdmin();
  }

  /// Loads trips based on authentication status (paginated)
  Future<PageResponse<Trip>> loadTrips({
    int page = 0,
    int size = 20,
  }) async {
    final isLoggedIn = await _authService.isLoggedIn();
    final userId = await _authService.getCurrentUserId();

    // Load available trips if logged in, or public trips if not
    if (isLoggedIn && userId != null) {
      return await _tripService.getAvailableTrips(page: page, size: size);
    } else {
      return await _tripService.getPublicTrips(page: page, size: size);
    }
  }

  /// Logs out the current user
  Future<void> logout() async {
    await _authService.logout();
  }

  /// Gets list of friends' user IDs
  Future<Set<String>> getFriendsIds() async {
    try {
      final friendshipsPage = await _userService.getFriends(page: 0, size: 100);
      final userId = await getCurrentUserId();
      if (userId == null) return {};

      return friendshipsPage.content
          .map((f) => f.userId == userId ? f.friendId : f.userId)
          .toSet();
    } catch (e) {
      debugPrint('Error fetching friends: $e');
      return {};
    }
  }

  /// Gets list of users being followed
  Future<Set<String>> getFollowingIds() async {
    try {
      final followingPage = await _userService.getFollowing(page: 0, size: 100);
      return followingPage.content.map((f) => f.followedId).toSet();
    } catch (e) {
      debugPrint('Error fetching following: $e');
      return {};
    }
  }

  /// Gets current user's own trips (paginated)
  Future<PageResponse<Trip>> getMyTrips({
    int page = 0,
    int size = 20,
  }) async {
    try {
      return await _tripService.getMyTrips(page: page, size: size);
    } catch (e) {
      debugPrint('Error fetching my trips: $e');
      return PageResponse(
        content: [],
        totalElements: 0,
        totalPages: 0,
        number: page,
        size: size,
        first: true,
        last: true,
      );
    }
  }

  /// Gets public trips for discovery (paginated)
  Future<PageResponse<Trip>> getPublicTrips({
    int page = 0,
    int size = 20,
  }) async {
    try {
      return await _tripService.getPublicTrips(page: page, size: size);
    } catch (e) {
      debugPrint('Error fetching public trips: $e');
      return PageResponse(
        content: [],
        totalElements: 0,
        totalPages: 0,
        number: page,
        size: size,
        first: true,
        last: true,
      );
    }
  }

  /// Gets current user profile
  Future<dynamic> getMyProfile() async {
    return await _userService.getMyProfile();
  }
}
