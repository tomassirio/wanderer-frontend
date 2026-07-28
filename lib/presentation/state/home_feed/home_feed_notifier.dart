import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wanderer_frontend/core/constants/enums.dart'
    show TripStatus, Visibility;
import 'package:wanderer_frontend/core/providers/app_providers.dart';
import 'package:wanderer_frontend/data/client/api_client.dart';
import 'package:wanderer_frontend/data/models/responses/page_response.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/data/repositories/home_repository.dart';
import 'package:wanderer_frontend/presentation/state/home_feed/home_feed_state.dart';
import 'package:wanderer_frontend/presentation/state/user_chrome/user_chrome_notifier.dart';
import 'package:wanderer_frontend/presentation/state/user_chrome/user_chrome_state.dart';

const int _tripsPageSize = 20;

/// App-global home feed: trip data loading and pagination. Plain,
/// non-family, autoDispose - unlike TripDetailNotifier/TripPlanDetailNotifier
/// (family-keyed by trip/plan id), there's exactly one home feed per app
/// session, so there's no natural per-instance key to family on.
class HomeFeedNotifier extends AutoDisposeNotifier<HomeFeedState> {
  late HomeRepository _repository;

  @override
  HomeFeedState build() {
    _repository = ref.watch(homeRepositoryProvider);
    return const HomeFeedState();
  }

  /// Reads identity LIVE at call time rather than accepting it as a
  /// parameter — the pre-migration widget read its own `_isLoggedIn`/
  /// `_userId` instance fields fresh on every call (including from timers
  /// and WS callbacks fired long after any triggering event). A parameter
  /// captured once (e.g. at subscribe time, before identity has even
  /// loaded) would silently go stale for the notifier's whole lifetime —
  /// the exact class of bug `trip_detail_screen.dart`'s Task 1 needed 3
  /// review rounds to eliminate. Read live here instead, every time.
  UserChromeState get _identity => ref.read(userChromeNotifierProvider);

  Future<void> loadTrips() async {
    final isLoggedIn = _identity.isLoggedIn;
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      currentTripsPage: 0,
    );

    try {
      if (isLoggedIn) {
        // Load user-specific data AND public trips so the Discover tab
        // includes all public trips, not just those from the user's network.
        final results = await Future.wait([
          _repository.loadTrips(page: 0, size: _tripsPageSize),
          _repository.getMyTrips(page: 0, size: _tripsPageSize),
          _repository.getFriendsIds(),
          _repository.getFollowingIds(),
          _repository.getPublicTrips(page: 0, size: _tripsPageSize),
        ]);

        final availablePage = results[0] as PageResponse<Trip>;
        final myTripsPage = results[1] as PageResponse<Trip>;
        final publicPage = results[4] as PageResponse<Trip>;

        // Merge available trips with public trips (deduplicate by ID).
        // Available trips take priority since they may contain richer data
        // (e.g. protected trips from friends).
        final merged = <String, Trip>{};
        for (final t in availablePage.content) {
          merged[t.id] = t;
        }
        for (final t in publicPage.content) {
          merged.putIfAbsent(t.id, () => t);
        }

        state = state.copyWith(
          allTrips: merged.values.toList(),
          hasMoreTrips: !availablePage.last || !publicPage.last,
          myTrips: myTripsPage.content,
          friendIds: results[2] as Set<String>,
          followingIds: results[3] as Set<String>,
          isLoading: false,
        );
        _categorizeTrips();
      } else {
        // Not logged in, only show public trips.
        final tripsPage =
            await _repository.getPublicTrips(page: 0, size: _tripsPageSize);
        final trips = tripsPage.content;

        // Merge with previously known active trips that the backend may not
        // return (e.g. RESTING trips are active but the /trips/public
        // endpoint might exclude them). We keep any trip from the old list
        // whose status is still "active" (in_progress, resting, paused) and
        // public, as long as it is not already present in the fresh
        // response.
        final freshIds = trips.map((t) => t.id).toSet();
        final preservedTrips = state.allTrips.where((t) {
          if (freshIds.contains(t.id)) {
            return false;
          }
          final isActive = t.status == TripStatus.inProgress ||
              t.status == TripStatus.resting ||
              t.status == TripStatus.paused;
          final isPublic = t.visibility == Visibility.public;
          return isActive && isPublic;
        }).toList();

        state = state.copyWith(
          allTrips: [...trips, ...preservedTrips],
          hasMoreTrips: !tripsPage.last,
          myTrips: const [],
          friendIds: const {},
          followingIds: const {},
          isLoading: false,
        );
        _categorizeTrips();
      }
    } on AuthenticationRedirectException {
      // Token expired or user not authenticated - treat as guest. Only
      // isLoggedIn flips; other identity fields are deliberately left
      // stale, matching this app's exact pre-existing behavior (a known,
      // tracked, NOT-fixed issue - not something this refactor introduces
      // or should silently repair).
      ref.read(userChromeNotifierProvider.notifier).setLoggedOut();
      state = state.copyWith(isLoading: false);
      await loadTrips(); // reads the just-flipped isLoggedIn=false live
      return;
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> loadMoreTrips() async {
    if (state.isLoadingMoreTrips || !state.hasMoreTrips) {
      return;
    }

    state = state.copyWith(isLoadingMoreTrips: true);

    try {
      final nextPage = state.currentTripsPage + 1;
      final isLoggedIn = _identity.isLoggedIn;

      if (isLoggedIn) {
        // Fetch both available and public trips to keep Discover populated.
        final results = await Future.wait([
          _repository.loadTrips(page: nextPage, size: _tripsPageSize),
          _repository.getPublicTrips(page: nextPage, size: _tripsPageSize),
        ]);

        final availablePage = results[0];
        final publicPage = results[1];

        // Merge new pages (deduplicate against existing + each other).
        final existingIds = state.allTrips.map((t) => t.id).toSet();
        final newTrips = <String, Trip>{};
        for (final t in availablePage.content) {
          if (!existingIds.contains(t.id)) {
            newTrips[t.id] = t;
          }
        }
        for (final t in publicPage.content) {
          if (!existingIds.contains(t.id)) {
            newTrips.putIfAbsent(t.id, () => t);
          }
        }

        state = state.copyWith(
          allTrips: [...state.allTrips, ...newTrips.values],
          currentTripsPage: nextPage,
          hasMoreTrips: !availablePage.last || !publicPage.last,
          isLoadingMoreTrips: false,
        );
        _categorizeTrips();
      } else {
        final tripsPage = await _repository.loadTrips(
          page: nextPage,
          size: _tripsPageSize,
        );

        state = state.copyWith(
          allTrips: [...state.allTrips, ...tripsPage.content],
          currentTripsPage: nextPage,
          hasMoreTrips: !tripsPage.last,
          isLoadingMoreTrips: false,
        );
        _categorizeTrips();
      }
    } catch (e) {
      state = state.copyWith(isLoadingMoreTrips: false);
      rethrow;
    }
  }

  /// Placeholder for Task 3, which fills this in with the real
  /// categorization logic (feedTrips/discoverTrips). Left as a no-op here
  /// so Task 2's tests (which don't exercise feed/discover categorization)
  /// stay green; Task 3 replaces this body entirely.
  void _categorizeTrips() {}
}

final homeFeedNotifierProvider =
    NotifierProvider.autoDispose<HomeFeedNotifier, HomeFeedState>(
  HomeFeedNotifier.new,
);
