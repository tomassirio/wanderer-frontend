import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/data/models/comment_models.dart';
import 'package:wanderer_frontend/data/repositories/trip_detail_repository.dart';
import 'trip_detail_state.dart';

/// Combined state for the trip detail screen
class TripDetailScreenState {
  final TripDetailDataState data;
  final TripDetailLoadingState loading;
  final TripDetailPanelState panels;
  final TripDetailPaginationState pagination;
  final TripDetailMapState map;

  const TripDetailScreenState({
    required this.data,
    this.loading = const TripDetailLoadingState(),
    this.panels = const TripDetailPanelState(),
    this.pagination = const TripDetailPaginationState(),
    this.map = const TripDetailMapState(),
  });

  TripDetailScreenState copyWith({
    TripDetailDataState? data,
    TripDetailLoadingState? loading,
    TripDetailPanelState? panels,
    TripDetailPaginationState? pagination,
    TripDetailMapState? map,
  }) {
    return TripDetailScreenState(
      data: data ?? this.data,
      loading: loading ?? this.loading,
      panels: panels ?? this.panels,
      pagination: pagination ?? this.pagination,
      map: map ?? this.map,
    );
  }
}

/// State notifier for trip detail screen
class TripDetailNotifier extends StateNotifier<TripDetailScreenState> {
  final TripDetailRepository _repository;
  final String tripId;

  TripDetailNotifier(this._repository, Trip initialTrip, this.tripId)
      : super(TripDetailScreenState(
          data: TripDetailDataState(trip: initialTrip),
        ));

  /// Update the trip data
  void updateTrip(Trip trip) {
    state = state.copyWith(
      data: state.data.copyWith(trip: trip),
    );
  }

  /// Add a new trip update to the list
  void addTripUpdate(TripLocation update) {
    final updatedList = [update, ...state.data.tripUpdates];
    state = state.copyWith(
      data: state.data.copyWith(tripUpdates: updatedList),
    );
  }

  /// Update trip polyline
  void updatePolyline(String encodedPolyline) {
    state = state.copyWith(
      data: state.data.copyWith(
        trip: state.data.trip.copyWith(encodedPolyline: encodedPolyline),
      ),
    );
  }

  /// Set loading state
  void setLoading(TripDetailLoadingState loading) {
    state = state.copyWith(loading: loading);
  }

  /// Toggle panel collapse state
  void toggleTimelineCollapsed() {
    state = state.copyWith(
      panels: state.panels.copyWith(
        isTimelineCollapsed: !state.panels.isTimelineCollapsed,
      ),
    );
  }

  void toggleCommentsCollapsed() {
    state = state.copyWith(
      panels: state.panels.copyWith(
        isCommentsCollapsed: !state.panels.isCommentsCollapsed,
      ),
    );
  }

  void toggleTripInfoCollapsed() {
    state = state.copyWith(
      panels: state.panels.copyWith(
        isTripInfoCollapsed: !state.panels.isTripInfoCollapsed,
      ),
    );
  }

  void toggleTripUpdateCollapsed() {
    state = state.copyWith(
      panels: state.panels.copyWith(
        isTripUpdateCollapsed: !state.panels.isTripUpdateCollapsed,
      ),
    );
  }

  void toggleTripSettingsCollapsed() {
    state = state.copyWith(
      panels: state.panels.copyWith(
        isTripSettingsCollapsed: !state.panels.isTripSettingsCollapsed,
      ),
    );
  }

  void collapseAllPanels() {
    state = state.copyWith(
      panels: const TripDetailPanelState(
        isTimelineCollapsed: true,
        isCommentsCollapsed: true,
        isTripInfoCollapsed: true,
        isTripUpdateCollapsed: true,
        isTripSettingsCollapsed: true,
      ),
    );
  }

  /// Toggle planned waypoints visibility
  void togglePlannedWaypoints() {
    state = state.copyWith(
      map: state.map.copyWith(
        showPlannedWaypoints: !state.map.showPlannedWaypoints,
      ),
    );
  }

  /// Set selected map location
  void selectMapLocation(TripLocation? location) {
    state = state.copyWith(
      map: state.map.copyWith(
        selectedMapLocation: location,
        clearSelectedMapLocation: location == null,
      ),
    );
  }

  /// Set selected planned waypoint
  void selectPlannedWaypoint(PlannedWaypointInfo? waypoint) {
    state = state.copyWith(
      map: state.map.copyWith(
        selectedPlannedWaypoint: waypoint,
        clearSelectedPlannedWaypoint: waypoint == null,
      ),
    );
  }

  /// Set comments with pagination info
  void setComments(List<Comment> comments, bool hasMore, int page) {
    state = state.copyWith(
      data: state.data.copyWith(comments: comments),
      pagination: state.pagination.copyWith(
        currentCommentPage: page,
        hasMoreComments: hasMore,
      ),
    );
  }

  /// Load more comments
  Future<void> loadMoreComments() async {
    if (state.loading.isLoadingMoreComments ||
        !state.pagination.hasMoreComments) {
      return;
    }

    state = state.copyWith(
      loading: state.loading.copyWith(isLoadingMoreComments: true),
    );

    try {
      final nextPage = state.pagination.currentCommentPage + 1;
      final pageResponse =
          await _repository.loadComments(tripId, page: nextPage, size: 20);
      final hasMore = !pageResponse.last;

      final allComments = [...state.data.comments, ...pageResponse.content];

      state = state.copyWith(
        data: state.data.copyWith(comments: allComments),
        pagination: state.pagination.copyWith(
          currentCommentPage: nextPage,
          hasMoreComments: hasMore,
        ),
        loading: state.loading.copyWith(isLoadingMoreComments: false),
      );
    } catch (e) {
      state = state.copyWith(
        loading: state.loading.copyWith(isLoadingMoreComments: false),
      );
      rethrow;
    }
  }

  /// Load more trip updates
  Future<void> loadMoreUpdates() async {
    if (state.loading.isLoadingMoreUpdates ||
        !state.pagination.hasMoreUpdates) {
      return;
    }

    state = state.copyWith(
      loading: state.loading.copyWith(isLoadingMoreUpdates: true),
    );

    try {
      final nextPage = state.pagination.currentUpdatesPage + 1;
      final pageResponse =
          await _repository.loadTripUpdates(tripId, page: nextPage, size: 50);
      final hasMore = !pageResponse.last;

      final allUpdates = [...state.data.tripUpdates, ...pageResponse.content];

      state = state.copyWith(
        data: state.data.copyWith(tripUpdates: allUpdates),
        pagination: state.pagination.copyWith(
          currentUpdatesPage: nextPage,
          hasMoreUpdates: hasMore,
        ),
        loading: state.loading.copyWith(isLoadingMoreUpdates: false),
      );
    } catch (e) {
      state = state.copyWith(
        loading: state.loading.copyWith(isLoadingMoreUpdates: false),
      );
      rethrow;
    }
  }
}

/// Provider for trip detail state
final tripDetailProvider = StateNotifierProvider.family<TripDetailNotifier,
    TripDetailScreenState, Trip>((ref, initialTrip) {
  final repository = TripDetailRepository();
  return TripDetailNotifier(repository, initialTrip, initialTrip.id);
});
