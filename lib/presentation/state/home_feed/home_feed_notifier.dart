import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wanderer_frontend/core/constants/enums.dart'
    show TripModality, TripStatus, Visibility;
import 'package:wanderer_frontend/core/providers/app_providers.dart';
import 'package:wanderer_frontend/data/client/api_client.dart';
import 'package:wanderer_frontend/data/models/responses/page_response.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/data/models/websocket/websocket_event.dart';
import 'package:wanderer_frontend/data/repositories/home_repository.dart';
import 'package:wanderer_frontend/data/services/trip_service.dart';
import 'package:wanderer_frontend/data/services/websocket_service.dart';
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
  late WebSocketService _webSocketService;
  late TripService _tripService;
  StreamSubscription<WebSocketEvent>? _wsSubscription;
  Timer? _pollTimer;
  Timer? _debounceTimer;
  String? _subscribedUserId;

  @override
  HomeFeedState build() {
    _repository = ref.watch(homeRepositoryProvider);
    _webSocketService = ref.watch(websocketServiceProvider);
    _tripService = ref.watch(tripServiceProvider);
    ref.onDispose(() {
      _wsSubscription?.cancel();
      _pollTimer?.cancel();
      _debounceTimer?.cancel();
      _webSocketService.unsubscribeFromAllTrips();
    });
    return const HomeFeedState();
  }

  /// Starts WS event listening + periodic polling. Called once from the
  /// widget's initState(), mirroring the exact pre-migration timing (listen
  /// registered before the async connect/userId resolution finishes, so no
  /// early events are missed). Takes no identity parameter - every handler
  /// below reads `_identity` live at the moment it actually needs it.
  void startWebSocketAndPolling() {
    _wsSubscription = _webSocketService.events.listen(_handleWebSocketEvent);
    _webSocketService.connect();
    _startPolling();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      loadTrips();
    });
  }

  /// Ensure the user's WebSocket topic is subscribed so user-scoped events
  /// (e.g. notifications, friend activity) are received on the global stream.
  void ensureUserTopicSubscribed(String userId) {
    if (_subscribedUserId == userId) return;
    _subscribedUserId = userId;
    _webSocketService.connect().then((_) {
      if (_subscribedUserId != userId) return;
      _webSocketService.subscribeToUser(userId);
    });
  }

  /// Debounce the trip list refresh so rapid-fire WS events only trigger
  /// one API call.
  void _debouncedLoadTrips() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 2), () {
      loadTrips();
    });
  }

  void _handleWebSocketEvent(WebSocketEvent event) {
    switch (event.type) {
      case WebSocketEventType.tripStatusChanged:
        _handleTripStatusChanged(event as TripStatusChangedEvent);
        break;
      case WebSocketEventType.commentAdded:
        _handleCommentAdded(event as CommentAddedEvent);
        break;
      case WebSocketEventType.tripUpdated:
      case WebSocketEventType.tripCreated:
      case WebSocketEventType.tripDeleted:
        _debouncedLoadTrips();
        break;
      case WebSocketEventType.userProfileUpdated:
      case WebSocketEventType.userAvatarUploaded:
      case WebSocketEventType.userAvatarDeleted:
        _refreshCurrentUserProfile();
        break;
      default:
        break;
    }
  }

  /// Test-only seam exposing the private WS dispatch method so tests can
  /// simulate an inbound WebSocket event without wiring up a real stream.
  @visibleForTesting
  void debugHandleWebSocketEvent(WebSocketEvent event) {
    _handleWebSocketEvent(event);
  }

  Future<void> _refreshCurrentUserProfile() async {
    final identity = _identity;
    if (!identity.isLoggedIn || identity.userId == null) return;
    try {
      final profile = await _repository.getMyProfile();
      ref.read(userChromeNotifierProvider.notifier).updateAvatarUrl(profile.avatarUrl);
    } catch (e) {
      debugPrint('Failed to refresh user profile: $e');
    }
  }

  void _handleTripStatusChanged(TripStatusChangedEvent event) {
    final tripIndex = state.allTrips.indexWhere((t) => t.id == event.tripId);
    if (tripIndex == -1) return;

    final trip = state.allTrips[tripIndex];
    final updatedTrip = trip.copyWith(
      status: event.newStatus,
      currentDay: event.currentDay ?? trip.currentDay,
    );

    final allTrips = [...state.allTrips];
    allTrips[tripIndex] = updatedTrip;

    final myTrips = [...state.myTrips];
    final myIndex = myTrips.indexWhere((t) => t.id == event.tripId);
    if (myIndex != -1) {
      myTrips[myIndex] = myTrips[myIndex].copyWith(
        status: event.newStatus,
        currentDay: event.currentDay ?? myTrips[myIndex].currentDay,
      );
    }

    state = state.copyWith(allTrips: allTrips, myTrips: myTrips);
    categorizeTrips();

    if (trip.tripModality == TripModality.multiDay && event.currentDay == null) {
      _refreshTripById(event.tripId!);
    }
  }

  /// Re-fetches a single trip by ID and updates it in the local lists.
  Future<void> _refreshTripById(String tripId) async {
    try {
      final updatedTrip = await _tripService.getTripById(tripId);

      final allTrips = [...state.allTrips];
      final allIndex = allTrips.indexWhere((t) => t.id == tripId);
      if (allIndex != -1) allTrips[allIndex] = updatedTrip;

      final myTrips = [...state.myTrips];
      final myIndex = myTrips.indexWhere((t) => t.id == tripId);
      if (myIndex != -1) myTrips[myIndex] = updatedTrip;

      state = state.copyWith(allTrips: allTrips, myTrips: myTrips);
      categorizeTrips();
    } catch (e) {
      debugPrint('Failed to refresh trip $tripId: $e');
    }
  }

  void _handleCommentAdded(CommentAddedEvent event) {
    final tripId = event.tripId;
    if (tripId == null) return;

    final allTrips = [...state.allTrips];
    final allIndex = allTrips.indexWhere((t) => t.id == tripId);
    if (allIndex != -1) {
      allTrips[allIndex] =
          allTrips[allIndex].copyWith(commentsCount: allTrips[allIndex].commentsCount + 1);
    }

    final myTrips = [...state.myTrips];
    final myIndex = myTrips.indexWhere((t) => t.id == tripId);
    if (myIndex != -1) {
      myTrips[myIndex] =
          myTrips[myIndex].copyWith(commentsCount: myTrips[myIndex].commentsCount + 1);
    }

    if (allIndex != -1 || myIndex != -1) {
      state = state.copyWith(allTrips: allTrips, myTrips: myTrips);
      categorizeTrips();
    }
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
        categorizeTrips();
        _resyncTripSubscriptions();
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
        categorizeTrips();
        _resyncTripSubscriptions();
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

    final beforeIds = state.allTrips.map((t) => t.id).toSet();
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
        categorizeTrips();
        _subscribeToNewTrips(beforeIds);
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
        categorizeTrips();
        _subscribeToNewTrips(beforeIds);
      }
    } catch (e) {
      state = state.copyWith(isLoadingMoreTrips: false);
      rethrow;
    }
  }

  /// Re-syncs WebSocket trip-topic subscriptions to exactly the current
  /// `allTrips` list. Mirrors the pre-migration widget's `_loadTrips()`
  /// wrapper (unsubscribe everything, then resubscribe the fresh full
  /// list) - called from `loadTrips()` so every internal caller (manual
  /// pull-to-refresh, the 5-minute poll timer, and the WS-event debounce)
  /// gets the resync automatically, not just widget-driven reloads.
  void _resyncTripSubscriptions() {
    _webSocketService.unsubscribeFromAllTrips();
    _webSocketService.subscribeToTrips(state.allTrips.map((t) => t.id).toList());
  }

  /// Subscribes only to trip topics newly added by a `loadMoreTrips()` page,
  /// leaving existing subscriptions untouched. Mirrors the pre-migration
  /// widget's `_loadMoreTrips()` wrapper, which diffed `allTrips` ids
  /// before/after the fetch rather than unsubscribing everything.
  void _subscribeToNewTrips(Set<String> beforeIds) {
    final newIds = state.allTrips
        .map((t) => t.id)
        .where((id) => !beforeIds.contains(id))
        .toList();
    _webSocketService.subscribeToTrips(newIds);
  }

  /// Public: called both from within this class (loadTrips/loadMoreTrips
  /// and the WS handlers above, all of which mutate state via fresh-list
  /// copyWith calls) and, historically, from the widget - kept public for
  /// external callers that may still want to force a recategorization.
  void categorizeTrips() {
    final currentUserId = _identity.userId;
    final discoverTrips = <Trip>[];

    for (final trip in state.allTrips) {
      final isPublic = trip.visibility == Visibility.public;
      final isActive = trip.status == TripStatus.inProgress ||
          trip.status == TripStatus.resting ||
          trip.status == TripStatus.paused;
      final isPromoted = trip.isPromoted;

      if (isPublic && isActive) {
        discoverTrips.add(trip);
        continue;
      }
      if (isPromoted && trip.status == TripStatus.finished) {
        discoverTrips.add(trip);
        continue;
      }
      if (isPromoted && trip.status == TripStatus.created) {
        discoverTrips.add(trip);
        continue;
      }
    }

    discoverTrips.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (!_identity.isLoggedIn) {
      state = state.copyWith(discoverTrips: discoverTrips, feedTrips: const []);
      return;
    }

    final feedTrips = <Trip>[];
    for (final trip in state.allTrips) {
      final isActive = trip.status == TripStatus.inProgress ||
          trip.status == TripStatus.resting ||
          trip.status == TripStatus.paused;
      if (!isActive) continue;

      final isOwnTrip = trip.userId == currentUserId;
      final isPublic = trip.visibility == Visibility.public;

      if (!isOwnTrip) {
        final isFriend = state.friendIds.contains(trip.userId);
        final isFollowing = state.followingIds.contains(trip.userId);

        if (isFriend || isFollowing) {
          if (isFriend &&
              (isPublic || trip.visibility == Visibility.protected)) {
            feedTrips.add(trip);
          } else if (isFollowing && !isFriend && isPublic) {
            feedTrips.add(trip);
          }
        }
      }
    }

    feedTrips.sort(_compareTripsByPriority);

    state = state.copyWith(feedTrips: feedTrips, discoverTrips: discoverTrips);
  }

  int _compareTripsByPriority(Trip a, Trip b) {
    final aIsLive =
        a.status == TripStatus.inProgress || a.status == TripStatus.resting;
    final bIsLive =
        b.status == TripStatus.inProgress || b.status == TripStatus.resting;
    if (aIsLive != bIsLive) return aIsLive ? -1 : 1;

    final aIsFriend = state.friendIds.contains(a.userId);
    final bIsFriend = state.friendIds.contains(b.userId);
    if (aIsFriend != bIsFriend) return aIsFriend ? -1 : 1;

    return b.createdAt.compareTo(a.createdAt);
  }

  void setStatusFilter(TripStatus? status) {
    state = status == null
        ? state.copyWith(clearStatusFilter: true)
        : state.copyWith(statusFilter: status);
  }

  void setVisibilityFilter(Visibility? visibility) {
    state = visibility == null
        ? state.copyWith(clearVisibilityFilter: true)
        : state.copyWith(visibilityFilter: visibility);
  }

  /// Reset filters when leaving the My Trips tab, matching the
  /// pre-migration `_onTabChanged` exactly: visibility filter always
  /// resets (it only applies to My Trips); status filter resets only if
  /// its current value isn't valid on Feed/Discover.
  void resetFiltersForTab(bool isMyTripsTab) {
    if (isMyTripsTab) return;
    var next = state.copyWith(clearVisibilityFilter: true);
    final status = next.statusFilter;
    if (status != null &&
        status != TripStatus.inProgress &&
        status != TripStatus.resting &&
        status != TripStatus.paused) {
      next = next.copyWith(clearStatusFilter: true);
    }
    state = next;
  }
}

final homeFeedNotifierProvider =
    NotifierProvider.autoDispose<HomeFeedNotifier, HomeFeedState>(
  HomeFeedNotifier.new,
);
