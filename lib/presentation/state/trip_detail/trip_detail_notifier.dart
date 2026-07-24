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
  // `late`, not `late final`: build() can run more than once on this same
  // instance — e.g. TripDetailScreen.deactivate()'s explicit
  // ref.invalidate() re-runs build() on the SAME notifier object rather
  // than replacing it, whenever the provider still has an active listener
  // (invalidateSelf() only rebuilds in place; a brand-new instance is
  // only constructed once the element is actually disposed, e.g. via
  // autoDispose after zero listeners for a frame). `late final` would
  // throw LateInitializationError on that second assignment (verified:
  // this crashed the overlapping-listener regression test below before
  // this field was made non-final).
  late TripDetailRepository _repository;

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
  /// Safe to call multiple times — a no-op once [state] already holds a
  /// non-empty [Trip] for this id, whether that's from an earlier call on
  /// this same instance or because [build] re-ran on it (see
  /// `_repository`'s doc for why that can happen on the very instance
  /// that already seeded).
  ///
  /// Still meaningful now that `TripDetailScreen.deactivate()` explicitly
  /// `ref.invalidate`s this provider on teardown (see that method's doc):
  /// this guard is what stays correct, not just harmless, in the narrow
  /// window where a still-alive instance can legitimately be seeded twice
  /// — e.g. if a future caller invokes this more than once against the
  /// same live screen instance. It no longer has to compensate for the
  /// *absence* of disposal (that was the original bug); it's ordinary
  /// idempotency for an already-deterministically-disposed provider.
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
