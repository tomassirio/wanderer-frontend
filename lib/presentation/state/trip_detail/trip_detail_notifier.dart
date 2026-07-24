import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wanderer_frontend/core/providers/app_providers.dart';
import 'package:wanderer_frontend/data/client/query/promotion_query_client.dart';
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

  @override
  TripDetailState build(String arg) {
    _repository = ref.watch(tripDetailRepositoryProvider);
    _promotionQueryClient = ref.watch(promotionQueryClientProvider);
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
}

final tripDetailNotifierProvider = NotifierProvider.autoDispose
    .family<TripDetailNotifier, TripDetailState, String>(
  TripDetailNotifier.new,
);
