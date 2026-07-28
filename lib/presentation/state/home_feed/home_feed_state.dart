import 'package:wanderer_frontend/core/constants/enums.dart'
    show TripStatus, Visibility;
import 'package:wanderer_frontend/data/models/trip_models.dart';

/// The current user's home feed: trip lists, pagination, and active filters.
/// App-global, not scoped to a single trip/plan id, unlike the previous two
/// screens' family-keyed notifiers - there is exactly one home feed per app
/// session.
class HomeFeedState {
  final List<Trip> allTrips;
  final List<Trip> myTrips;
  final List<Trip> feedTrips;
  final List<Trip> discoverTrips;
  final Set<String> friendIds;
  final Set<String> followingIds;
  final bool isLoading;
  final bool isLoadingMoreTrips;
  final bool hasMoreTrips;
  final int currentTripsPage;
  final String? error;
  final TripStatus? statusFilter;
  final Visibility? visibilityFilter;

  const HomeFeedState({
    this.allTrips = const [],
    this.myTrips = const [],
    this.feedTrips = const [],
    this.discoverTrips = const [],
    this.friendIds = const {},
    this.followingIds = const {},
    this.isLoading = false,
    this.isLoadingMoreTrips = false,
    this.hasMoreTrips = false,
    this.currentTripsPage = 0,
    this.error,
    this.statusFilter,
    this.visibilityFilter,
  });

  HomeFeedState copyWith({
    List<Trip>? allTrips,
    List<Trip>? myTrips,
    List<Trip>? feedTrips,
    List<Trip>? discoverTrips,
    Set<String>? friendIds,
    Set<String>? followingIds,
    bool? isLoading,
    bool? isLoadingMoreTrips,
    bool? hasMoreTrips,
    int? currentTripsPage,
    String? error,
    bool clearError = false,
    TripStatus? statusFilter,
    bool clearStatusFilter = false,
    Visibility? visibilityFilter,
    bool clearVisibilityFilter = false,
  }) {
    return HomeFeedState(
      allTrips: allTrips ?? this.allTrips,
      myTrips: myTrips ?? this.myTrips,
      feedTrips: feedTrips ?? this.feedTrips,
      discoverTrips: discoverTrips ?? this.discoverTrips,
      friendIds: friendIds ?? this.friendIds,
      followingIds: followingIds ?? this.followingIds,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMoreTrips: isLoadingMoreTrips ?? this.isLoadingMoreTrips,
      hasMoreTrips: hasMoreTrips ?? this.hasMoreTrips,
      currentTripsPage: currentTripsPage ?? this.currentTripsPage,
      error: clearError ? null : (error ?? this.error),
      statusFilter:
          clearStatusFilter ? null : (statusFilter ?? this.statusFilter),
      visibilityFilter: clearVisibilityFilter
          ? null
          : (visibilityFilter ?? this.visibilityFilter),
    );
  }

  /// Trips matching the current status/visibility filters. Pure, no
  /// side effects - callers re-derive this on every build via ref.watch,
  /// matching the pre-migration `_getFilteredTrips` exactly.
  List<Trip> filtered(List<Trip> trips) {
    return trips.where((trip) {
      if (statusFilter != null && trip.status != statusFilter) {
        return false;
      }
      if (visibilityFilter != null && trip.visibility != visibilityFilter) {
        return false;
      }
      return true;
    }).toList();
  }
}
