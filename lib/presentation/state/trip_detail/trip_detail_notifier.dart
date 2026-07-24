import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wanderer_frontend/core/providers/app_providers.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/data/repositories/trip_detail_repository.dart';
import 'package:wanderer_frontend/presentation/state/trip_detail/trip_detail_state.dart';

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
  late final TripDetailRepository _repository;

  @override
  TripDetailState build(String arg) {
    _repository = ref.watch(tripDetailRepositoryProvider);
    // A placeholder Trip is required to satisfy TripDetailState's
    // non-nullable `trip` field before the real widget.trip is available;
    // the widget calls seedInitialTrip() with the real Trip immediately
    // after reading this provider for the first time (see Task 1, Step 8).
    return TripDetailState(trip: Trip.empty(id: arg));
  }

  /// Seeds state with the real [Trip] the widget was constructed with.
  /// Safe to call multiple times — a no-op after the first call for a given
  /// trip id, since [build] only runs once per family key.
  void seedInitialTrip(Trip trip) {
    if (state.trip.id == trip.id && state.trip.name.isNotEmpty) return;
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
}

final tripDetailNotifierProvider = NotifierProvider.autoDispose
    .family<TripDetailNotifier, TripDetailState, String>(
  TripDetailNotifier.new,
);
