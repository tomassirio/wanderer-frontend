import 'package:flutter/foundation.dart';
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

  /// Loads trips based on authentication status
  Future<List<Trip>> loadTrips() async {
    final isLoggedIn = await _authService.isLoggedIn();
    final userId = await _authService.getCurrentUserId();

    // Load public trips if not logged in, or user's trips if logged in
    if (isLoggedIn && userId != null) {
      final page = await _tripService.getAvailableTrips();
      return page.content;
    } else {
      final page = await _tripService.getPublicTrips();
      return page.content;
    }
  }

  /// Logs out the current user
  Future<void> logout() async {
    await _authService.logout();
  }

  /// Gets list of friends' user IDs
  Future<Set<String>> getFriendsIds() async {
    try {
      final friendships = await _userService.getFriends();
      final userId = await getCurrentUserId();
      if (userId == null) return {};

      return friendships
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
      final following = await _userService.getFollowing();
      return following.map((f) => f.followedId).toSet();
    } catch (e) {
      debugPrint('Error fetching following: $e');
      return {};
    }
  }

  /// Gets current user's own trips
  Future<List<Trip>> getMyTrips() async {
    try {
      return await _tripService.getMyTrips();
    } catch (e) {
      debugPrint('Error fetching my trips: $e');
      return [];
    }
  }

  /// Gets public trips for discovery
  Future<List<Trip>> getPublicTrips() async {
    try {
      final page = await _tripService.getPublicTrips();
      return page.content;
    } catch (e) {
      debugPrint('Error fetching public trips: $e');
      return [];
    }
  }
}
