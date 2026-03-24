import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/data/models/user_models.dart';
import 'package:wanderer_frontend/data/services/user_service.dart';
import 'package:wanderer_frontend/data/services/trip_service.dart';
import 'package:wanderer_frontend/data/services/auth_service.dart';

/// Repository for managing user profile data and operations
class ProfileRepository {
  final UserService _userService;
  final TripService _tripService;
  final AuthService _authService;

  ProfileRepository({
    UserService? userService,
    TripService? tripService,
    AuthService? authService,
  })  : _userService = userService ?? UserService(),
        _tripService = tripService ?? TripService(),
        _authService = authService ?? AuthService();

  /// Gets the current user's profile
  Future<UserProfile> getMyProfile() async {
    return await _userService.getMyProfile();
  }

  /// Gets a specific user's profile by userId
  Future<UserProfile> getUserProfile(String userId) async {
    return await _userService.getUserById(userId);
  }

  /// Updates the current user's profile
  /// Returns the user ID from 202 Accepted response
  Future<String> updateProfile(UpdateProfileRequest request) async {
    return await _userService.updateProfile(request);
  }

  /// Uploads avatar for the current user
  /// Returns the user ID from 202 Accepted response
  Future<String> uploadAvatar(List<int> fileBytes, String fileName) async {
    return await _userService.uploadAvatar(fileBytes, fileName);
  }

  /// Deletes avatar for the current user
  /// Returns the user ID from 202 Accepted response
  Future<String> deleteAvatar() async {
    return await _userService.deleteAvatar();
  }

  /// Gets trips for the current logged-in user (all trips regardless of visibility)
  Future<List<Trip>> getMyTrips() async {
    return await _tripService.getMyTrips();
  }

  /// Gets trips for another user (respects visibility rules)
  Future<List<Trip>> getUserTrips(String userId) async {
    return await _tripService.getUserTrips(userId);
  }

  /// Checks if user is logged in
  Future<bool> isLoggedIn() async {
    return await _authService.isLoggedIn();
  }

  /// Checks if user is admin
  Future<bool> isAdmin() async {
    return await _authService.isAdmin();
  }

  /// Gets the current user's username
  Future<String?> getCurrentUsername() async {
    return await _authService.getCurrentUsername();
  }

  /// Gets the current user's ID
  Future<String?> getCurrentUserId() async {
    return await _authService.getCurrentUserId();
  }

  /// Refreshes user details (displayName, avatarUrl) from the API
  Future<bool> refreshUserDetails() async {
    return await _authService.refreshUserDetails();
  }

  /// Logs out the current user
  Future<void> logout() async {
    await _authService.logout();
  }
}
