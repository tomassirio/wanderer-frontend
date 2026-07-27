import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wanderer_frontend/data/models/domain/trip_plan.dart';
import 'package:wanderer_frontend/presentation/helpers/trip_plan_map_helper.dart';
import 'package:wanderer_frontend/presentation/state/trip_plan_detail/trip_plan_detail_state.dart';

/// Owns [TripPlanDetailState] for one trip plan (keyed by plan id). Replaces
/// TripPlanDetailScreen's former State-held business logic, migrated
/// concern-by-concern (matching the pattern established for
/// TripDetailScreen/TripDetailNotifier).
///
/// autoDispose'd, family-keyed by plan id: TripPlanDetailScreen is pushed via
/// Navigator.push (a fresh State per visit), so this notifier must not
/// outlive the screen that reads it.
class TripPlanDetailNotifier
    extends AutoDisposeFamilyNotifier<TripPlanDetailState, String> {
  @override
  TripPlanDetailState build(String arg) {
    return TripPlanDetailState(tripPlan: TripPlan.empty(id: arg));
  }

  /// Seeds state with the real [TripPlan] the widget was constructed with.
  /// Unconditional — always applies [tripPlan], matching the pre-migration
  /// behavior exactly (`initState()` always assigned `_tripPlan =
  /// widget.tripPlan` with no guard). See TripDetailNotifier.seedInitialTrip's
  /// doc comment for why an attempted "already seeded, skip it" guard
  /// doesn't hold up in general — the same reasoning applies here.
  void seedInitialTripPlan(TripPlan tripPlan) {
    state = state.copyWith(tripPlan: tripPlan);
  }

  /// Recomputes view-mode markers/polylines from the current trip plan,
  /// using the backend-provided polyline when available, falling back to
  /// straight lines. [onWaypointTap] is threaded through unchanged — it
  /// needs a `BuildContext` (shows a bottom sheet), so it stays owned by the
  /// widget and is passed in as a plain function reference; the notifier
  /// itself has no UI concerns.
  void updateViewMapData({void Function(int waypointIndex)? onWaypointTap}) {
    try {
      final mapData = TripPlanMapHelper.createMapDataWithDirections(
        state.tripPlan,
        onWaypointTap: onWaypointTap,
      );
      state = state.copyWith(
        viewMap: state.viewMap.copyWith(
          markers: mapData.markers,
          polylines: mapData.polylines,
        ),
      );
    } catch (e) {
      // Fallback to straight lines if decoding fails.
      final mapData = TripPlanMapHelper.createMapData(
        state.tripPlan,
        onWaypointTap: onWaypointTap,
      );
      state = state.copyWith(
        viewMap: state.viewMap.copyWith(
          markers: mapData.markers,
          polylines: mapData.polylines,
        ),
      );
    }
  }

  void setInfoCollapsed(bool collapsed) {
    state = state.copyWith(
      viewMap: state.viewMap.copyWith(isInfoCollapsed: collapsed),
    );
  }

  /// Transitional setter: applies a [TripPlan] reassignment computed by a
  /// not-yet-migrated call site in `TripPlanDetailScreen` (`_saveChanges()`,
  /// migrated in Task 5). Deleted once that task's own logic can call
  /// `copyWith`/replace `state.tripPlan` directly.
  void applyTripPlanOverride(TripPlan tripPlan) {
    state = state.copyWith(tripPlan: tripPlan);
  }
}

final tripPlanDetailNotifierProvider = NotifierProvider.autoDispose
    .family<TripPlanDetailNotifier, TripPlanDetailState, String>(
  TripPlanDetailNotifier.new,
);
