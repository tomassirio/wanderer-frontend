import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/data/models/comment_models.dart';

/// Core trip data state
class TripDetailDataState {
  final Trip trip;
  final List<TripLocation> tripUpdates;
  final List<Comment> comments;
  final Map<String, List<Comment>> replies;

  const TripDetailDataState({
    required this.trip,
    this.tripUpdates = const [],
    this.comments = const [],
    this.replies = const {},
  });

  TripDetailDataState copyWith({
    Trip? trip,
    List<TripLocation>? tripUpdates,
    List<Comment>? comments,
    Map<String, List<Comment>>? replies,
  }) {
    return TripDetailDataState(
      trip: trip ?? this.trip,
      tripUpdates: tripUpdates ?? this.tripUpdates,
      comments: comments ?? this.comments,
      replies: replies ?? this.replies,
    );
  }
}

/// Loading states for async operations
class TripDetailLoadingState {
  final bool isLoadingUpdates;
  final bool isLoadingComments;
  final bool isLoadingMoreComments;
  final bool isLoadingMoreUpdates;
  final bool isAddingComment;
  final bool isChangingStatus;
  final bool isChangingSettings;
  final bool isSendingUpdate;
  final bool isMapLoading;

  const TripDetailLoadingState({
    this.isLoadingUpdates = false,
    this.isLoadingComments = false,
    this.isLoadingMoreComments = false,
    this.isLoadingMoreUpdates = false,
    this.isAddingComment = false,
    this.isChangingStatus = false,
    this.isChangingSettings = false,
    this.isSendingUpdate = false,
    this.isMapLoading = true,
  });

  TripDetailLoadingState copyWith({
    bool? isLoadingUpdates,
    bool? isLoadingComments,
    bool? isLoadingMoreComments,
    bool? isLoadingMoreUpdates,
    bool? isAddingComment,
    bool? isChangingStatus,
    bool? isChangingSettings,
    bool? isSendingUpdate,
    bool? isMapLoading,
  }) {
    return TripDetailLoadingState(
      isLoadingUpdates: isLoadingUpdates ?? this.isLoadingUpdates,
      isLoadingComments: isLoadingComments ?? this.isLoadingComments,
      isLoadingMoreComments:
          isLoadingMoreComments ?? this.isLoadingMoreComments,
      isLoadingMoreUpdates: isLoadingMoreUpdates ?? this.isLoadingMoreUpdates,
      isAddingComment: isAddingComment ?? this.isAddingComment,
      isChangingStatus: isChangingStatus ?? this.isChangingStatus,
      isChangingSettings: isChangingSettings ?? this.isChangingSettings,
      isSendingUpdate: isSendingUpdate ?? this.isSendingUpdate,
      isMapLoading: isMapLoading ?? this.isMapLoading,
    );
  }
}

/// UI panel collapse/expand states
class TripDetailPanelState {
  final bool isTimelineCollapsed;
  final bool isCommentsCollapsed;
  final bool isTripInfoCollapsed;
  final bool isTripUpdateCollapsed;
  final bool isTripSettingsCollapsed;

  const TripDetailPanelState({
    this.isTimelineCollapsed = false,
    this.isCommentsCollapsed = false,
    this.isTripInfoCollapsed = false,
    this.isTripUpdateCollapsed = true,
    this.isTripSettingsCollapsed = true,
  });

  TripDetailPanelState copyWith({
    bool? isTimelineCollapsed,
    bool? isCommentsCollapsed,
    bool? isTripInfoCollapsed,
    bool? isTripUpdateCollapsed,
    bool? isTripSettingsCollapsed,
  }) {
    return TripDetailPanelState(
      isTimelineCollapsed: isTimelineCollapsed ?? this.isTimelineCollapsed,
      isCommentsCollapsed: isCommentsCollapsed ?? this.isCommentsCollapsed,
      isTripInfoCollapsed: isTripInfoCollapsed ?? this.isTripInfoCollapsed,
      isTripUpdateCollapsed:
          isTripUpdateCollapsed ?? this.isTripUpdateCollapsed,
      isTripSettingsCollapsed:
          isTripSettingsCollapsed ?? this.isTripSettingsCollapsed,
    );
  }
}

/// Pagination state for comments and updates
class TripDetailPaginationState {
  final int currentCommentPage;
  final bool hasMoreComments;
  final int currentUpdatesPage;
  final bool hasMoreUpdates;

  const TripDetailPaginationState({
    this.currentCommentPage = 0,
    this.hasMoreComments = false,
    this.currentUpdatesPage = 0,
    this.hasMoreUpdates = false,
  });

  TripDetailPaginationState copyWith({
    int? currentCommentPage,
    bool? hasMoreComments,
    int? currentUpdatesPage,
    bool? hasMoreUpdates,
  }) {
    return TripDetailPaginationState(
      currentCommentPage: currentCommentPage ?? this.currentCommentPage,
      hasMoreComments: hasMoreComments ?? this.hasMoreComments,
      currentUpdatesPage: currentUpdatesPage ?? this.currentUpdatesPage,
      hasMoreUpdates: hasMoreUpdates ?? this.hasMoreUpdates,
    );
  }
}

/// Map-specific state
class TripDetailMapState {
  final bool showPlannedWaypoints;
  final TripLocation? selectedMapLocation;
  final PlannedWaypointInfo? selectedPlannedWaypoint;
  final bool isHoveringOverPanel;

  const TripDetailMapState({
    this.showPlannedWaypoints = false,
    this.selectedMapLocation,
    this.selectedPlannedWaypoint,
    this.isHoveringOverPanel = false,
  });

  TripDetailMapState copyWith({
    bool? showPlannedWaypoints,
    TripLocation? selectedMapLocation,
    PlannedWaypointInfo? selectedPlannedWaypoint,
    bool? isHoveringOverPanel,
    bool clearSelectedMapLocation = false,
    bool clearSelectedPlannedWaypoint = false,
  }) {
    return TripDetailMapState(
      showPlannedWaypoints: showPlannedWaypoints ?? this.showPlannedWaypoints,
      selectedMapLocation: clearSelectedMapLocation
          ? null
          : (selectedMapLocation ?? this.selectedMapLocation),
      selectedPlannedWaypoint: clearSelectedPlannedWaypoint
          ? null
          : (selectedPlannedWaypoint ?? this.selectedPlannedWaypoint),
      isHoveringOverPanel: isHoveringOverPanel ?? this.isHoveringOverPanel,
    );
  }
}

/// PlannedWaypointInfo placeholder - define if not already existing
class PlannedWaypointInfo {
  final int index;
  final double lat;
  final double lon;

  const PlannedWaypointInfo({
    required this.index,
    required this.lat,
    required this.lon,
  });
}
