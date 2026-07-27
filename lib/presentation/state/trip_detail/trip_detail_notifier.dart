import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:wanderer_frontend/core/constants/enums.dart';
import 'package:wanderer_frontend/core/providers/app_providers.dart';
import 'package:wanderer_frontend/data/client/query/promotion_query_client.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/data/models/user_models.dart';
import 'package:wanderer_frontend/data/models/comment_models.dart';
import 'package:wanderer_frontend/data/repositories/trip_detail_repository.dart';
import 'package:wanderer_frontend/data/services/achievement_service.dart';
import 'package:wanderer_frontend/data/services/user_service.dart';
import 'package:wanderer_frontend/presentation/state/trip_detail/trip_detail_state.dart';
import 'package:wanderer_frontend/presentation/widgets/trip_detail/custom_planned_info_window.dart';

/// Owns [TripDetailState] for one trip (keyed by trip id). Replaces the
/// screen's former `State`-held business logic, migrated concern-by-concern.
///
/// `autoDispose`d: `TripDetailScreen` is pushed via `Navigator.push` (a
/// fresh `State` per visit), so this notifier must not outlive the screen
/// that reads it — otherwise a previously-visited trip's stale data (and
/// identity) would leak into a later visit instead of a fresh instance
/// being built. Riverpod disposes the per-tripId instance once nothing is
/// watching it anymore (i.e. once the screen for that trip id is popped).
class TripDetailNotifier
    extends AutoDisposeFamilyNotifier<TripDetailState, String> {
  // `late`, not `late final`: build() can run more than once on this same
  // instance — any caller-triggered `ref.invalidate`/`invalidateSelf()` on
  // a still-listened provider rebuilds it in place rather than replacing
  // it (a brand-new instance is only constructed once the element is
  // actually disposed, e.g. via autoDispose after zero listeners for a
  // frame). `late final` would throw LateInitializationError on that
  // second assignment.
  late TripDetailRepository _repository;
  // `late`, not `late final` — same reasoning as `_repository` above:
  // build() can rerun on this instance, and a second assignment to a
  // `late final` field would throw LateInitializationError.
  late PromotionQueryClient _promotionQueryClient;
  late AchievementService _achievementService;
  late UserService _userService;
  Timer? _achievementRefreshTimer;

  @override
  TripDetailState build(String arg) {
    _repository = ref.watch(tripDetailRepositoryProvider);
    _promotionQueryClient = ref.watch(promotionQueryClientProvider);
    _achievementService = ref.watch(achievementServiceProvider);
    _userService = ref.watch(userServiceProvider);
    ref.onDispose(() {
      _achievementRefreshTimer?.cancel();
    });
    // A placeholder Trip is required to satisfy TripDetailState's
    // non-nullable `trip` field before the real widget.trip is available;
    // the widget calls seedInitialTrip() with the real Trip immediately
    // after reading this provider for the first time (see Task 1, Step 8).
    return TripDetailState(trip: Trip.empty(id: arg));
  }

  /// Seeds state with the real [Trip] the widget was constructed with.
  /// Unconditional — always applies [trip], even if this provider instance
  /// is being reused (e.g. a rapid re-navigation to the same trip id landed
  /// on a not-yet-disposed instance from the previous screen). This matches
  /// the pre-migration behavior exactly: `initState()` always assigned
  /// `_trip = widget.trip` with no guard, because each screen used to own
  /// an independent field. There is deliberately no "already seeded, skip
  /// it" check here — a guard would have to decide whether the existing
  /// state or the new [trip] is "more correct" when both are legitimate,
  /// and no such guard can be correct in general (see the removed guard's
  /// history in git blame for why an attempted one didn't hold up).
  /// Whichever screen instance's `initState()` runs `seedInitialTrip` last
  /// wins, exactly as whichever instance's constructor ran last used to
  /// win when this was a plain field.
  void seedInitialTrip(Trip trip) {
    state = state.copyWith(trip: trip);
  }

  /// Transitional setter: applies a [Trip] mutation computed by a
  /// not-yet-migrated `setState` call site in `TripDetailScreen`. Each call
  /// site is deleted when the later task that owns its concern migrates the
  /// mutation into a proper notifier method (see Task 1 brief, Step 9).
  void applyTripOverride(Trip trip) {
    state = state.copyWith(trip: trip);
  }

  Future<void> checkLoginStatus() async {
    final isLoggedIn = await _repository.isLoggedIn();
    state = state.copyWith(
      identity: state.identity.copyWith(isLoggedIn: isLoggedIn),
    );
  }

  Future<void> loadUserInfo() async {
    final username = await _repository.getCurrentUsername();
    final userId = await _repository.getCurrentUserId();
    final isAdmin = await _repository.isAdmin();

    if (userId != null) {
      await _repository.refreshUserDetails();
    }

    final displayName = await _repository.getCurrentDisplayName();
    final avatarUrl = await _repository.getCurrentAvatarUrl();

    state = state.copyWith(
      identity: state.identity.copyWith(
        username: username,
        userId: userId,
        displayName: displayName,
        avatarUrl: avatarUrl,
        isAdmin: isAdmin,
      ),
    );
  }

  Future<void> loadPromotionInfo() async {
    try {
      final promotion =
          await _promotionQueryClient.getTripPromotion(state.trip.id);
      state = state.copyWith(
        promotion: state.promotion.copyWith(
          isPromoted: true,
          donationLink: promotion.donationLink,
        ),
      );
    } catch (e) {
      // Trip is not promoted — this is expected for most trips.
      state = state.copyWith(
        promotion: state.promotion
            .copyWith(isPromoted: false, clearDonationLink: true),
      );
    }
  }

  Future<void> loadTripAchievements() async {
    try {
      final achievements =
          await _achievementService.getTripAchievements(state.trip.id);
      state = state.copyWith(tripAchievements: achievements);
    } catch (e) {
      // Silently fail — achievements are optional.
    }
  }

  /// Debounce achievement refresh so rapid-fire trip updates don't
  /// hammer the API. Waits 3 seconds after the last trigger.
  void debouncedAchievementRefresh() {
    _achievementRefreshTimer?.cancel();
    _achievementRefreshTimer = Timer(const Duration(seconds: 3), () {
      loadTripAchievements();
    });
  }

  /// Test-only seam for setting up social state preconditions without a
  /// full loadSocialStatus() round trip.
  @visibleForTesting
  void debugSetSocialForTest(TripDetailSocialState social) {
    state = state.copyWith(social: social);
  }

  /// Load the current user's social relationship with the trip owner.
  Future<void> loadSocialStatus() async {
    try {
      final followingPage = await _userService.getFollowing(page: 0, size: 100);
      final isFollowing =
          followingPage.content.any((f) => f.followedId == state.trip.userId);

      final sentRequests = await _userService.getSentFriendRequests();
      final pendingRequest = sentRequests.cast<FriendRequest?>().firstWhere(
            (r) =>
                r!.receiverId == state.trip.userId &&
                r.status == FriendRequestStatus.pending,
            orElse: () => null,
          );
      final hasSentRequest = pendingRequest != null;
      final requestId = pendingRequest?.id;

      final friendsPage = await _userService.getFriends(page: 0, size: 100);
      final isAlreadyFriends =
          friendsPage.content.any((f) => f.friendId == state.trip.userId);

      state = state.copyWith(
        social: TripDetailSocialState(
          isFollowingTripOwner: isFollowing,
          hasSentFriendRequest: hasSentRequest,
          sentFriendRequestId: requestId,
          isAlreadyFriends: isAlreadyFriends,
        ),
      );
    } catch (e) {
      // Silently fail - social features are optional.
    }
  }

  Future<void> followTripOwner() async {
    if (state.social.isFollowingTripOwner) {
      await _userService.unfollowUser(state.trip.userId);
      state = state.copyWith(
        social: state.social.copyWith(isFollowingTripOwner: false),
      );
    } else {
      await _userService.followUser(state.trip.userId);
      state = state.copyWith(
        social: state.social.copyWith(isFollowingTripOwner: true),
      );
    }
  }

  Future<void> sendFriendRequestToTripOwner() async {
    if (state.social.isAlreadyFriends) {
      await _userService.removeFriend(state.trip.userId);
      state = state.copyWith(social: state.social.copyWith(isAlreadyFriends: false));
      return;
    }

    if (state.social.hasSentFriendRequest && state.social.sentFriendRequestId != null) {
      await _userService.deleteFriendRequest(state.social.sentFriendRequestId!);
      state = state.copyWith(
        social: state.social.copyWith(
          hasSentFriendRequest: false,
          clearSentFriendRequestId: true,
        ),
      );
      return;
    }

    final requestId = await _userService.sendFriendRequest(state.trip.userId);
    state = state.copyWith(
      social: state.social.copyWith(
        hasSentFriendRequest: true,
        sentFriendRequestId: requestId,
      ),
    );
  }

  /// Transitional setter: applies a [TripDetailTimelineState] mutation
  /// computed by a not-yet-migrated `setState` call site in
  /// `TripDetailScreen` (WebSocket handlers, migrated in Task 9a/9b). Same
  /// pattern as [applyTripOverride] (see Task 1 brief, Step 9).
  void applyTimelineOverride(TripDetailTimelineState timeline) {
    state = state.copyWith(timeline: timeline);
  }

  /// Test-only seam for setting up timeline state preconditions without a
  /// full loadTripUpdates()/loadMoreTripUpdates() round trip.
  @visibleForTesting
  void debugSeedTimelineForTest(TripDetailTimelineState timeline) {
    state = state.copyWith(timeline: timeline);
  }

  Future<void> loadTripUpdates({int retryCount = 0}) async {
    state = state.copyWith(
      timeline:
          state.timeline.copyWith(isLoadingUpdates: true, currentUpdatesPage: 0),
    );

    try {
      final pageResponse = await _repository.loadTripUpdates(
        state.trip.id,
        page: 0,
        size: 50,
      );
      // Preserve WebSocket-added entries that the CQRS query model may not
      // have propagated yet, so the timeline doesn't temporarily lose the
      // most recent updates.
      final apiIds = pageResponse.content.map((l) => l.id).toSet();
      final wsOnlyUpdates = state.timeline.tripUpdates
          .where((u) => u.id.startsWith('ws_') && !apiIds.contains(u.id))
          .toList();
      state = state.copyWith(
        timeline: state.timeline.copyWith(
          tripUpdates: [...wsOnlyUpdates, ...pageResponse.content],
          hasMoreUpdates: !pageResponse.last,
          isLoadingUpdates: false,
        ),
      );
    } catch (e) {
      state = state.copyWith(
        timeline: state.timeline.copyWith(isLoadingUpdates: false),
      );

      // Retry with exponential back-off if we haven't exhausted retries.
      if (retryCount < 3) {
        final delay = Duration(seconds: 2 << retryCount); // 2s, 4s, 8s
        await Future.delayed(delay);
        await loadTripUpdates(retryCount: retryCount + 1);
      } else {
        rethrow;
      }
    }
  }

  Future<void> loadMoreTripUpdates() async {
    if (state.timeline.isLoadingMoreUpdates || !state.timeline.hasMoreUpdates) {
      return;
    }

    state = state.copyWith(
      timeline: state.timeline.copyWith(isLoadingMoreUpdates: true),
    );

    try {
      final nextPage = state.timeline.currentUpdatesPage + 1;
      final pageResponse = await _repository.loadTripUpdates(
        state.trip.id,
        page: nextPage,
        size: 50,
      );
      state = state.copyWith(
        timeline: state.timeline.copyWith(
          tripUpdates: [...state.timeline.tripUpdates, ...pageResponse.content],
          currentUpdatesPage: nextPage,
          hasMoreUpdates: !pageResponse.last,
          isLoadingMoreUpdates: false,
        ),
      );

      // Update the trip's locations with the newly loaded older locations
      // so the polyline extends further back in time.
      final updatedLocations = <TripLocation>[
        ...(state.trip.locations ?? []),
        ...pageResponse.content,
      ];
      final seen = <String>{};
      final deduped = updatedLocations.where((l) => seen.add(l.id)).toList();
      state = state.copyWith(trip: state.trip.copyWith(locations: deduped));
    } catch (e) {
      state = state.copyWith(
        timeline: state.timeline.copyWith(isLoadingMoreUpdates: false),
      );
      rethrow;
    }
  }

  /// Transitional setter: applies a [TripDetailCommentsState] mutation
  /// computed by a not-yet-migrated `setState` call site in
  /// `TripDetailScreen` (the `_handleCommentAdded`/`_handleCommentReaction`
  /// WebSocket handlers). Same pattern as [applyTripOverride]/
  /// [applyTimelineOverride] (see Task 1 brief, Step 9).
  void applyCommentsOverride(TripDetailCommentsState comments) {
    state = state.copyWith(comments: comments);
  }

  /// Test-only seam for setting up comments state preconditions without a
  /// full loadComments()/loadReplies() round trip.
  @visibleForTesting
  void debugSeedCommentsForTest(TripDetailCommentsState comments) {
    state = state.copyWith(comments: comments);
  }

  void _sortComments(List<Comment> comments, CommentSortOption option) {
    switch (option) {
      case CommentSortOption.latest:
        comments.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case CommentSortOption.oldest:
        comments.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case CommentSortOption.mostReplies:
        comments.sort((a, b) => b.responsesCount.compareTo(a.responsesCount));
        break;
      case CommentSortOption.mostReactions:
        comments.sort((a, b) => b.reactionsCount.compareTo(a.reactionsCount));
        break;
    }
  }

  Future<void> loadComments() async {
    state = state.copyWith(
      comments:
          state.comments.copyWith(isLoadingComments: true, currentCommentPage: 0),
    );
    try {
      final pageResponse = await _repository.loadComments(state.trip.id, page: 0, size: 20);
      final sorted = List<Comment>.from(pageResponse.content);
      _sortComments(sorted, state.comments.sortOption);
      state = state.copyWith(
        comments: state.comments.copyWith(
          comments: sorted,
          hasMoreComments: !pageResponse.last,
          isLoadingComments: false,
        ),
      );
    } catch (e) {
      state = state.copyWith(comments: state.comments.copyWith(isLoadingComments: false));
      rethrow;
    }
  }

  Future<void> loadMoreComments() async {
    if (state.comments.isLoadingMoreComments || !state.comments.hasMoreComments) return;
    state = state.copyWith(comments: state.comments.copyWith(isLoadingMoreComments: true));
    try {
      final nextPage = state.comments.currentCommentPage + 1;
      final pageResponse = await _repository.loadComments(state.trip.id, page: nextPage, size: 20);
      state = state.copyWith(
        comments: state.comments.copyWith(
          comments: [...state.comments.comments, ...pageResponse.content],
          currentCommentPage: nextPage,
          hasMoreComments: !pageResponse.last,
          isLoadingMoreComments: false,
        ),
      );
    } catch (e) {
      state = state.copyWith(comments: state.comments.copyWith(isLoadingMoreComments: false));
      rethrow;
    }
  }

  void changeSortOption(CommentSortOption option) {
    final sorted = List<Comment>.from(state.comments.comments);
    _sortComments(sorted, option);
    state = state.copyWith(
      comments: state.comments.copyWith(comments: sorted, sortOption: option),
    );
  }

  Future<void> loadReplies(String commentId) async {
    final comment = state.comments.comments.firstWhere((c) => c.id == commentId);
    if (comment.replies != null) {
      state = state.copyWith(
        comments: state.comments.copyWith(
          replies: {...state.comments.replies, commentId: comment.replies!},
          expandedComments: {...state.comments.expandedComments, commentId: true},
        ),
      );
      return;
    }

    final replies = await _repository.loadReplies(commentId);
    state = state.copyWith(
      comments: state.comments.copyWith(
        replies: {...state.comments.replies, commentId: replies},
        expandedComments: {...state.comments.expandedComments, commentId: true},
      ),
    );
  }

  void setReplyingTo(String? commentId) {
    state = state.copyWith(
      comments: commentId == null
          ? state.comments.copyWith(clearReplyingToCommentId: true)
          : state.comments.copyWith(replyingToCommentId: commentId),
    );
  }

  Future<void> toggleRepliesExpanded(String commentId, bool isExpanded) async {
    if (isExpanded) {
      state = state.copyWith(
        comments: state.comments.copyWith(
          expandedComments: {...state.comments.expandedComments, commentId: false},
        ),
      );
    } else {
      await loadReplies(commentId);
    }
  }

  Future<void> addComment(
    String message, {
    required String? currentUserId,
    required String? currentUsername,
    required String? currentAvatarUrl,
  }) async {
    state = state.copyWith(comments: state.comments.copyWith(isAddingComment: true));
    try {
      final replyingTo = state.comments.replyingToCommentId;
      if (replyingTo != null) {
        final commentId = await _repository.addReply(state.trip.id, replyingTo, message);
        final optimisticReply = Comment(
          id: commentId,
          tripId: state.trip.id,
          userId: currentUserId ?? '',
          username: currentUsername ?? 'You',
          userAvatarUrl: currentAvatarUrl,
          message: message,
          parentCommentId: replyingTo,
          individualReactions: const [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final existingReplies = state.comments.replies[replyingTo] ?? [];
        if (!existingReplies.any((c) => c.id == commentId)) {
          final updatedReplies = {
            ...state.comments.replies,
            replyingTo: [...existingReplies, optimisticReply],
          };
          final comments = List<Comment>.from(state.comments.comments);
          final parentIndex = comments.indexWhere((c) => c.id == replyingTo);
          if (parentIndex != -1) {
            final parent = comments[parentIndex];
            comments[parentIndex] = Comment(
              id: parent.id,
              tripId: parent.tripId,
              userId: parent.userId,
              username: parent.username,
              userAvatarUrl: parent.userAvatarUrl,
              message: parent.message,
              parentCommentId: parent.parentCommentId,
              reactions: parent.reactions,
              individualReactions: parent.individualReactions,
              replies: parent.replies,
              reactionsCount: parent.reactionsCount,
              responsesCount: parent.responsesCount + 1,
              createdAt: parent.createdAt,
              updatedAt: parent.updatedAt,
            );
          }
          state = state.copyWith(
            comments: state.comments.copyWith(
              replies: updatedReplies,
              comments: comments,
              expandedComments: {...state.comments.expandedComments, replyingTo: true},
              clearReplyingToCommentId: true,
            ),
          );
        } else {
          // Duplicate reply id (effectively unreachable in practice): still
          // reset the reply UI state, matching pre-migration behavior.
          state = state.copyWith(
            comments: state.comments.copyWith(
              expandedComments: {...state.comments.expandedComments, replyingTo: true},
              clearReplyingToCommentId: true,
            ),
          );
        }
      } else {
        final commentId = await _repository.addComment(state.trip.id, message);
        final optimisticComment = Comment(
          id: commentId,
          tripId: state.trip.id,
          userId: currentUserId ?? '',
          username: currentUsername ?? 'You',
          userAvatarUrl: currentAvatarUrl,
          message: message,
          individualReactions: const [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        if (!state.comments.comments.any((c) => c.id == commentId)) {
          final comments = [optimisticComment, ...state.comments.comments];
          _sortComments(comments, state.comments.sortOption);
          state = state.copyWith(comments: state.comments.copyWith(comments: comments));
        }
      }
    } finally {
      state = state.copyWith(comments: state.comments.copyWith(isAddingComment: false));
    }
  }

  ReactionType? getUserReaction(String commentId, String? currentUserId) {
    Comment? found = state.comments.comments
        .cast<Comment?>()
        .firstWhere((c) => c?.id == commentId, orElse: () => null);
    if (found == null) {
      for (final replies in state.comments.replies.values) {
        found = replies.cast<Comment?>().firstWhere((c) => c?.id == commentId, orElse: () => null);
        if (found != null) break;
      }
    }
    if (found == null || found.individualReactions == null) return null;

    final userReaction = found.individualReactions!
        .cast<Reaction?>()
        .firstWhere((r) => r?.userId == currentUserId, orElse: () => null);
    return userReaction?.reactionType;
  }

  void _replaceCommentOrReply(String commentId, Comment Function(Comment) update) {
    final commentIndex = state.comments.comments.indexWhere((c) => c.id == commentId);
    if (commentIndex != -1) {
      final comments = List<Comment>.from(state.comments.comments);
      comments[commentIndex] = update(comments[commentIndex]);
      state = state.copyWith(comments: state.comments.copyWith(comments: comments));
      return;
    }
    for (final parentId in state.comments.replies.keys) {
      final replies = state.comments.replies[parentId]!;
      final replyIndex = replies.indexWhere((c) => c.id == commentId);
      if (replyIndex != -1) {
        final updatedReplies = List<Comment>.from(replies);
        updatedReplies[replyIndex] = update(updatedReplies[replyIndex]);
        state = state.copyWith(
          comments: state.comments.copyWith(
            replies: {...state.comments.replies, parentId: updatedReplies},
          ),
        );
        return;
      }
    }
  }

  Future<void> handleReactionClick(
    String commentId,
    ReactionType type, {
    required String? currentUserId,
    required String? currentUsername,
  }) async {
    final currentReaction = getUserReaction(commentId, currentUserId);
    final newReaction = currentReaction == type ? null : type;

    _replaceCommentOrReply(
      commentId,
      (comment) => applyReactionChange(
        comment: comment,
        userId: currentUserId ?? '',
        username: currentUsername ?? '',
        oldReaction: currentReaction,
        newReaction: newReaction,
      ),
    );

    try {
      if (currentReaction == type) {
        await _repository.removeReaction(commentId, type);
      } else {
        await _repository.addReaction(commentId, type);
      }
    } catch (e) {
      // Revert by applying the reverse change.
      _replaceCommentOrReply(
        commentId,
        (comment) => applyReactionChange(
          comment: comment,
          userId: currentUserId ?? '',
          username: currentUsername ?? '',
          oldReaction: newReaction,
          newReaction: currentReaction,
        ),
      );
      rethrow;
    }
  }

  static const Duration _wsCameraGuardDuration = Duration(seconds: 10);
  static const int _maxRefreshRetries = 3;

  /// Whether a WebSocket event recently animated the camera, meaning
  /// API-refresh-driven animations should be suppressed to avoid the map
  /// jumping back to a stale position (CQRS eventual consistency).
  bool get isWsCameraGuardActive {
    final last = state.map.lastWsCameraUpdate;
    if (last == null) return false;
    return DateTime.now().difference(last) < _wsCameraGuardDuration;
  }

  /// Records that a WebSocket event just animated the map camera, arming
  /// [isWsCameraGuardActive] for [_wsCameraGuardDuration]. Transitional:
  /// called directly by not-yet-migrated WebSocket handlers on the widget
  /// (Task 9a/9b), same pattern as [applyTripOverride]/[applyTimelineOverride]/
  /// [applyCommentsOverride].
  void markWsCameraUpdate() {
    state = state.copyWith(map: state.map.copyWith(lastWsCameraUpdate: DateTime.now()));
  }

  void setUserLocation(LatLng location) {
    state = state.copyWith(map: state.map.copyWith(userLocation: location));
  }

  void setShowPlannedWaypoints(bool show) {
    state = state.copyWith(map: state.map.copyWith(showPlannedWaypoints: show));
  }

  void setMapMarkersAndPolylines(Set<Marker> markers, Set<Polyline> polylines) {
    state = state.copyWith(map: state.map.copyWith(markers: markers, polylines: polylines));
  }

  void selectMapLocation(TripLocation location) {
    state = state.copyWith(
      map: state.map.copyWith(
        selectedMapLocation: location,
        clearSelectedPlannedWaypoint: true,
      ),
    );
  }

  void selectPlannedWaypoint(PlannedWaypointInfo waypoint) {
    state = state.copyWith(
      map: state.map.copyWith(
        selectedPlannedWaypoint: waypoint,
        clearSelectedMapLocation: true,
      ),
    );
  }

  void clearMapSelection() {
    state = state.copyWith(
      map: state.map.copyWith(
        clearSelectedMapLocation: true,
        clearSelectedPlannedWaypoint: true,
      ),
    );
  }

  void setMapLoading(bool loading) {
    state = state.copyWith(map: state.map.copyWith(isMapLoading: loading));
  }

  void markInitialMapPositionSet() {
    state = state.copyWith(map: state.map.copyWith(hasInitialMapPosition: true));
  }

  /// Refreshes full trip data from the backend.
  ///
  /// When the API call fails (e.g. 500), retries up to [_maxRefreshRetries]
  /// times with exponential back-off (2s, 4s, 8s), matching the pre-migration
  /// `_refreshTripData` behavior exactly. Between retries, whatever trip data
  /// is already in state stays there so the map isn't left blank.
  Future<void> refreshTripData({int retryCount = 0}) async {
    try {
      final updatedTrip = await _repository.getTripById(state.trip.id);
      // Merge locally-applied WebSocket locations that may not yet appear
      // in the CQRS query model. This prevents the map from temporarily
      // losing newly added markers when the backend is still propagating.
      final apiLocationIds = (updatedTrip.locations ?? []).map((l) => l.id).toSet();
      final wsOnlyLocations = (state.trip.locations ?? [])
          .where((l) => l.id.startsWith('ws_') && !apiLocationIds.contains(l.id))
          .toList();
      final mergedLocations = <TripLocation>[
        ...updatedTrip.locations ?? [],
        ...wsOnlyLocations,
      ];

      state = state.copyWith(
        trip: updatedTrip.copyWith(
          // Preserve automaticUpdates / updateRefresh when the backend query
          // model hasn't propagated them yet (CQRS eventual consistency).
          automaticUpdates: updatedTrip.automaticUpdates || state.trip.automaticUpdates,
          updateRefresh: updatedTrip.updateRefresh ?? state.trip.updateRefresh,
          locations: mergedLocations,
        ),
      );
    } catch (e) {
      // Retry with exponential back-off if we haven't exhausted retries.
      if (retryCount < _maxRefreshRetries) {
        final delay = Duration(seconds: 2 << retryCount); // 2s, 4s, 8s
        await Future.delayed(delay);
        await refreshTripData(retryCount: retryCount + 1);
      } else {
        rethrow;
      }
    }
  }
}

final tripDetailNotifierProvider = NotifierProvider.autoDispose
    .family<TripDetailNotifier, TripDetailState, String>(
  TripDetailNotifier.new,
);

/// Applies a reaction change to [comment]'s reaction map/individual-reaction
/// list and returns the updated comment. Shared by the optimistic user-click
/// path (TripDetailNotifier.handleReactionClick) and the WebSocket-driven
/// path (the WS reaction handler, wired in a later task) — the WS path additionally
/// needs [skipIfDuplicate] since the same event can arrive from both the
/// trip-specific and global WebSocket streams.
Comment applyReactionChange({
  required Comment comment,
  required String userId,
  required String username,
  ReactionType? oldReaction,
  ReactionType? newReaction,
  bool skipIfDuplicate = false,
}) {
  final updatedReactions = Map<String, int>.from(comment.reactions ?? {});
  final updatedIndividualReactions =
      List<Reaction>.from(comment.individualReactions ?? []);

  if (skipIfDuplicate) {
    final hasOldReaction = oldReaction != null &&
        updatedIndividualReactions
            .any((r) => r.userId == userId && r.reactionType == oldReaction);
    final hasNewReaction = newReaction != null &&
        updatedIndividualReactions
            .any((r) => r.userId == userId && r.reactionType == newReaction);
    if (newReaction != null && hasNewReaction) {
      return comment; // Re-delivered ADDED or REPLACED event.
    }
    if (newReaction == null && oldReaction != null && !hasOldReaction) {
      return comment; // Re-delivered REMOVED event.
    }
  }

  if (oldReaction != null) {
    updatedIndividualReactions.removeWhere((r) => r.userId == userId);
    final oldCount = updatedReactions[oldReaction.toJson()] ?? 0;
    if (oldCount > 1) {
      updatedReactions[oldReaction.toJson()] = oldCount - 1;
    } else {
      updatedReactions.remove(oldReaction.toJson());
    }
  }

  if (newReaction != null) {
    updatedIndividualReactions.add(Reaction(
      userId: userId,
      username: username,
      reactionType: newReaction,
      timestamp: DateTime.now(),
    ));
    updatedReactions[newReaction.toJson()] =
        (updatedReactions[newReaction.toJson()] ?? 0) + 1;
  }

  final newReactionsCount =
      updatedReactions.values.fold(0, (sum, count) => sum + count);

  return Comment(
    id: comment.id,
    tripId: comment.tripId,
    userId: comment.userId,
    username: comment.username,
    userAvatarUrl: comment.userAvatarUrl,
    message: comment.message,
    parentCommentId: comment.parentCommentId,
    reactions: updatedReactions.isEmpty ? null : updatedReactions,
    individualReactions:
        updatedIndividualReactions.isEmpty ? null : updatedIndividualReactions,
    replies: comment.replies,
    reactionsCount: newReactionsCount,
    responsesCount: comment.responsesCount,
    createdAt: comment.createdAt,
    updatedAt: comment.updatedAt,
  );
}
