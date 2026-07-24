import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:wanderer_frontend/data/models/achievement_models.dart';
import 'package:wanderer_frontend/data/models/comment_models.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/presentation/widgets/trip_detail/comments_section.dart';
import 'package:wanderer_frontend/presentation/widgets/trip_detail/custom_planned_info_window.dart';

/// Current user's identity as known by this screen.
class TripDetailIdentity {
  final String? userId;
  final String? username;
  final String? displayName;
  final String? avatarUrl;
  final bool isLoggedIn;
  final bool isAdmin;

  const TripDetailIdentity({
    this.userId,
    this.username,
    this.displayName,
    this.avatarUrl,
    this.isLoggedIn = false,
    this.isAdmin = false,
  });

  TripDetailIdentity copyWith({
    String? userId,
    String? username,
    String? displayName,
    String? avatarUrl,
    bool? isLoggedIn,
    bool? isAdmin,
  }) {
    return TripDetailIdentity(
      userId: userId ?? this.userId,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      isAdmin: isAdmin ?? this.isAdmin,
    );
  }
}

/// Current user's social relationship with the trip owner.
class TripDetailSocialState {
  final bool isFollowingTripOwner;
  final bool hasSentFriendRequest;
  final bool isAlreadyFriends;
  final String? sentFriendRequestId;

  const TripDetailSocialState({
    this.isFollowingTripOwner = false,
    this.hasSentFriendRequest = false,
    this.isAlreadyFriends = false,
    this.sentFriendRequestId,
  });

  TripDetailSocialState copyWith({
    bool? isFollowingTripOwner,
    bool? hasSentFriendRequest,
    bool? isAlreadyFriends,
    String? sentFriendRequestId,
    bool clearSentFriendRequestId = false,
  }) {
    return TripDetailSocialState(
      isFollowingTripOwner: isFollowingTripOwner ?? this.isFollowingTripOwner,
      hasSentFriendRequest: hasSentFriendRequest ?? this.hasSentFriendRequest,
      isAlreadyFriends: isAlreadyFriends ?? this.isAlreadyFriends,
      sentFriendRequestId: clearSentFriendRequestId
          ? null
          : (sentFriendRequestId ?? this.sentFriendRequestId),
    );
  }
}

/// Trip promotion banner state.
class TripDetailPromotionState {
  final bool isPromoted;
  final String? donationLink;

  const TripDetailPromotionState({this.isPromoted = false, this.donationLink});

  TripDetailPromotionState copyWith({
    bool? isPromoted,
    String? donationLink,
    bool clearDonationLink = false,
  }) {
    return TripDetailPromotionState(
      isPromoted: isPromoted ?? this.isPromoted,
      donationLink:
          clearDonationLink ? null : (donationLink ?? this.donationLink),
    );
  }
}

/// Trip-updates timeline pagination state.
class TripDetailTimelineState {
  final List<TripLocation> tripUpdates;
  final bool isLoadingUpdates;
  final int currentUpdatesPage;
  final bool hasMoreUpdates;
  final bool isLoadingMoreUpdates;

  const TripDetailTimelineState({
    this.tripUpdates = const [],
    this.isLoadingUpdates = false,
    this.currentUpdatesPage = 0,
    this.hasMoreUpdates = false,
    this.isLoadingMoreUpdates = false,
  });

  TripDetailTimelineState copyWith({
    List<TripLocation>? tripUpdates,
    bool? isLoadingUpdates,
    int? currentUpdatesPage,
    bool? hasMoreUpdates,
    bool? isLoadingMoreUpdates,
  }) {
    return TripDetailTimelineState(
      tripUpdates: tripUpdates ?? this.tripUpdates,
      isLoadingUpdates: isLoadingUpdates ?? this.isLoadingUpdates,
      currentUpdatesPage: currentUpdatesPage ?? this.currentUpdatesPage,
      hasMoreUpdates: hasMoreUpdates ?? this.hasMoreUpdates,
      isLoadingMoreUpdates: isLoadingMoreUpdates ?? this.isLoadingMoreUpdates,
    );
  }
}

/// Comment pagination/loading/posting state.
class TripDetailCommentsState {
  final List<Comment> comments;
  final Map<String, List<Comment>> replies;
  final Map<String, bool> expandedComments;
  final int currentCommentPage;
  final bool hasMoreComments;
  final bool isLoadingMoreComments;
  final bool isLoadingComments;
  final bool isAddingComment;
  final String? replyingToCommentId;
  final CommentSortOption sortOption;

  const TripDetailCommentsState({
    this.comments = const [],
    this.replies = const {},
    this.expandedComments = const {},
    this.currentCommentPage = 0,
    this.hasMoreComments = false,
    this.isLoadingMoreComments = false,
    this.isLoadingComments = false,
    this.isAddingComment = false,
    this.replyingToCommentId,
    this.sortOption = CommentSortOption.latest,
  });

  TripDetailCommentsState copyWith({
    List<Comment>? comments,
    Map<String, List<Comment>>? replies,
    Map<String, bool>? expandedComments,
    int? currentCommentPage,
    bool? hasMoreComments,
    bool? isLoadingMoreComments,
    bool? isLoadingComments,
    bool? isAddingComment,
    String? replyingToCommentId,
    bool clearReplyingToCommentId = false,
    CommentSortOption? sortOption,
  }) {
    return TripDetailCommentsState(
      comments: comments ?? this.comments,
      replies: replies ?? this.replies,
      expandedComments: expandedComments ?? this.expandedComments,
      currentCommentPage: currentCommentPage ?? this.currentCommentPage,
      hasMoreComments: hasMoreComments ?? this.hasMoreComments,
      isLoadingMoreComments:
          isLoadingMoreComments ?? this.isLoadingMoreComments,
      isLoadingComments: isLoadingComments ?? this.isLoadingComments,
      isAddingComment: isAddingComment ?? this.isAddingComment,
      replyingToCommentId: clearReplyingToCommentId
          ? null
          : (replyingToCommentId ?? this.replyingToCommentId),
      sortOption: sortOption ?? this.sortOption,
    );
  }
}

/// Map/geolocation/camera state.
class TripDetailMapState {
  final Set<Marker> markers;
  final Set<Polyline> polylines;
  final bool hasInitialMapPosition;
  final bool isMapLoading;
  final bool showPlannedWaypoints;
  final TripLocation? selectedMapLocation;
  final PlannedWaypointInfo? selectedPlannedWaypoint;
  final LatLng? userLocation;
  final DateTime? lastWsCameraUpdate;

  const TripDetailMapState({
    this.markers = const {},
    this.polylines = const {},
    this.hasInitialMapPosition = false,
    this.isMapLoading = true,
    this.showPlannedWaypoints = false,
    this.selectedMapLocation,
    this.selectedPlannedWaypoint,
    this.userLocation,
    this.lastWsCameraUpdate,
  });

  TripDetailMapState copyWith({
    Set<Marker>? markers,
    Set<Polyline>? polylines,
    bool? hasInitialMapPosition,
    bool? isMapLoading,
    bool? showPlannedWaypoints,
    TripLocation? selectedMapLocation,
    PlannedWaypointInfo? selectedPlannedWaypoint,
    LatLng? userLocation,
    DateTime? lastWsCameraUpdate,
    bool clearSelectedMapLocation = false,
    bool clearSelectedPlannedWaypoint = false,
  }) {
    return TripDetailMapState(
      markers: markers ?? this.markers,
      polylines: polylines ?? this.polylines,
      hasInitialMapPosition:
          hasInitialMapPosition ?? this.hasInitialMapPosition,
      isMapLoading: isMapLoading ?? this.isMapLoading,
      showPlannedWaypoints: showPlannedWaypoints ?? this.showPlannedWaypoints,
      selectedMapLocation: clearSelectedMapLocation
          ? null
          : (selectedMapLocation ?? this.selectedMapLocation),
      selectedPlannedWaypoint: clearSelectedPlannedWaypoint
          ? null
          : (selectedPlannedWaypoint ?? this.selectedPlannedWaypoint),
      userLocation: userLocation ?? this.userLocation,
      lastWsCameraUpdate: lastWsCameraUpdate ?? this.lastWsCameraUpdate,
    );
  }
}

/// Trip lifecycle action in-flight flags.
class TripDetailLifecycleState {
  final bool isChangingStatus;
  final bool isChangingSettings;
  final bool isSendingUpdate;

  const TripDetailLifecycleState({
    this.isChangingStatus = false,
    this.isChangingSettings = false,
    this.isSendingUpdate = false,
  });

  TripDetailLifecycleState copyWith({
    bool? isChangingStatus,
    bool? isChangingSettings,
    bool? isSendingUpdate,
  }) {
    return TripDetailLifecycleState(
      isChangingStatus: isChangingStatus ?? this.isChangingStatus,
      isChangingSettings: isChangingSettings ?? this.isChangingSettings,
      isSendingUpdate: isSendingUpdate ?? this.isSendingUpdate,
    );
  }
}

/// Full state backing [TripDetailScreen], owned by [TripDetailNotifier].
class TripDetailState {
  final Trip trip;
  final TripDetailIdentity identity;
  final TripDetailSocialState social;
  final TripDetailPromotionState promotion;
  final List<UserAchievement> tripAchievements;
  final TripDetailTimelineState timeline;
  final TripDetailCommentsState comments;
  final TripDetailMapState map;
  final TripDetailLifecycleState lifecycle;

  const TripDetailState({
    required this.trip,
    this.identity = const TripDetailIdentity(),
    this.social = const TripDetailSocialState(),
    this.promotion = const TripDetailPromotionState(),
    this.tripAchievements = const [],
    this.timeline = const TripDetailTimelineState(),
    this.comments = const TripDetailCommentsState(),
    this.map = const TripDetailMapState(),
    this.lifecycle = const TripDetailLifecycleState(),
  });

  TripDetailState copyWith({
    Trip? trip,
    TripDetailIdentity? identity,
    TripDetailSocialState? social,
    TripDetailPromotionState? promotion,
    List<UserAchievement>? tripAchievements,
    TripDetailTimelineState? timeline,
    TripDetailCommentsState? comments,
    TripDetailMapState? map,
    TripDetailLifecycleState? lifecycle,
  }) {
    return TripDetailState(
      trip: trip ?? this.trip,
      identity: identity ?? this.identity,
      social: social ?? this.social,
      promotion: promotion ?? this.promotion,
      tripAchievements: tripAchievements ?? this.tripAchievements,
      timeline: timeline ?? this.timeline,
      comments: comments ?? this.comments,
      map: map ?? this.map,
      lifecycle: lifecycle ?? this.lifecycle,
    );
  }
}
