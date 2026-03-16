import 'package:wanderer_frontend/data/models/comment_models.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/data/models/domain/location_update_result.dart';
import 'package:wanderer_frontend/data/models/responses/page_response.dart';
import 'package:wanderer_frontend/data/services/comment_service.dart';
import 'package:wanderer_frontend/data/services/trip_service.dart';
import 'package:wanderer_frontend/data/services/trip_update_service.dart';
import 'package:wanderer_frontend/data/services/auth_service.dart';
import 'package:wanderer_frontend/core/constants/enums.dart';

/// Repository for managing trip detail data and operations
class TripDetailRepository {
  final TripService _tripService;
  final CommentService _commentService;
  final AuthService _authService;
  final TripUpdateService _tripUpdateService;

  TripDetailRepository({
    TripService? tripService,
    CommentService? commentService,
    AuthService? authService,
    TripUpdateService? tripUpdateService,
  })  : _tripService = tripService ?? TripService(),
        _commentService = commentService ?? CommentService(),
        _authService = authService ?? AuthService(),
        _tripUpdateService = tripUpdateService ?? TripUpdateService();

  /// Loads top-level comments for a trip via API (paginated).
  /// The backend returns only top-level comments (replies are nested within
  /// each comment's [Comment.replies] field), so [totalElements] and
  /// [totalPages] already reflect the top-level count. The client-side
  /// [parentCommentId] filter is a safety guard for any orphaned items.
  Future<PageResponse<Comment>> loadComments(
    String tripId, {
    int page = 0,
    int size = 20,
  }) async {
    final pageResponse = await _commentService.getCommentsByTripId(
      tripId,
      page: page,
      size: size,
    );
    final topLevel =
        pageResponse.content.where((c) => c.parentCommentId == null).toList();
    return PageResponse(
      content: topLevel,
      totalElements: pageResponse.totalElements,
      totalPages: pageResponse.totalPages,
      number: pageResponse.number,
      size: pageResponse.size,
      first: pageResponse.first,
      last: pageResponse.last,
    );
  }

  /// Gets full trip data by ID
  Future<Trip> getTripById(String tripId) async {
    return await _tripService.getTripById(tripId);
  }

  /// Loads replies for a specific comment via API
  Future<List<Comment>> loadReplies(String commentId) async {
    return await _commentService.getRepliesByCommentId(commentId);
  }

  /// Loads reactions for a comment from the comment object itself
  /// Note: Reactions are stored as a `Map<String, int>` in the comment model (reaction type -> count)
  /// This method returns an empty list as reactions are already embedded in the comment
  Future<List<Reaction>> loadReactions(Comment comment) async {
    // Reactions are already part of the comment object as a map
    // Return empty list since the UI should use comment.reactions map directly
    return [];
  }

  /// Adds a new top-level comment
  /// Returns the comment ID. Full comment data will be delivered via WebSocket.
  Future<String> addComment(String tripId, String message) async {
    return await _commentService.addComment(
      tripId,
      CreateCommentRequest(message: message),
    );
  }

  /// Adds a reply to a comment
  /// Uses parentCommentId in the request body to create a reply
  /// Returns the comment ID. Full comment data will be delivered via WebSocket.
  Future<String> addReply(
    String tripId,
    String parentCommentId,
    String message,
  ) async {
    return await _commentService.addComment(
      tripId,
      CreateCommentRequest(message: message, parentCommentId: parentCommentId),
    );
  }

  /// Adds a reaction to a comment
  Future<void> addReaction(String commentId, ReactionType reactionType) async {
    final request = AddReactionRequest(reactionType: reactionType);
    await _commentService.addReaction(commentId, request);
  }

  /// Removes a reaction from a comment
  Future<void> removeReaction(
      String commentId, ReactionType reactionType) async {
    final request = AddReactionRequest(reactionType: reactionType);
    await _commentService.removeReaction(commentId, request);
  }

  /// Changes the status of a trip
  /// Returns the trip ID. Full trip data will be delivered via WebSocket.
  Future<String> changeTripStatus(String tripId, TripStatus newStatus) async {
    final request = ChangeStatusRequest(status: newStatus);
    return await _tripService.changeStatus(tripId, request);
  }

  /// Changes the visibility of a trip
  /// Returns the trip ID. Full trip data will be delivered via WebSocket.
  Future<String> changeTripVisibility(
      String tripId, Visibility newVisibility) async {
    final request = ChangeVisibilityRequest(visibility: newVisibility);
    return await _tripService.changeVisibility(tripId, request);
  }

  /// Toggles the day state for MULTI_DAY trips.
  /// IN_PROGRESS → RESTING (end day), RESTING → IN_PROGRESS (start next day).
  /// Returns the trip ID. Full trip data will be delivered via WebSocket.
  Future<String> toggleDay(String tripId) async {
    return await _tripService.toggleDay(tripId);
  }

  /// Changes the automatic update settings of a trip
  /// Returns the trip ID. Full trip data will be delivered via WebSocket.
  Future<String> changeTripSettings(
    String tripId,
    bool automaticUpdates,
    int? updateRefresh, {
    TripModality? tripModality,
  }) async {
    final request = ChangeTripSettingsRequest(
      automaticUpdates: automaticUpdates,
      updateRefresh: updateRefresh,
      tripModality: tripModality,
    );
    return await _tripService.changeSettings(tripId, request);
  }

  /// Deletes a trip
  /// Returns the trip ID. Deletion will be confirmed via WebSocket.
  Future<String> deleteTrip(String tripId) async {
    return await _tripService.deleteTrip(tripId);
  }

  /// Checks if user is logged in
  Future<bool> isLoggedIn() async {
    return await _authService.isLoggedIn();
  }

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

  /// Checks if current user is admin
  Future<bool> isAdmin() async {
    return await _authService.isAdmin();
  }

  /// Logs out the current user
  Future<void> logout() async {
    await _authService.logout();
  }

  /// Loads lightweight trip update locations for map + timeline via API
  /// Uses the /locations endpoint which returns all points without heavy fields
  /// City and country are now populated by the backend via reverse geocoding
  Future<List<TripLocation>> loadTripUpdates(String tripId) {
    return _tripService.getTripUpdateLocations(tripId);
  }

  /// Sends a manual trip update with current location and battery
  /// Returns a [LocationUpdateResult] indicating success or failure reason.
  Future<LocationUpdateResult> sendTripUpdate(
    String tripId, {
    String? message,
  }) async {
    return await _tripUpdateService.sendUpdate(
      tripId: tripId,
      message: message,
      isAutomatic: false,
    );
  }
}
