import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:wanderer_frontend/core/providers/app_providers.dart';
import 'package:wanderer_frontend/data/client/google_directions_api_client.dart';
import 'package:wanderer_frontend/data/client/polyline_codec.dart';
import 'package:wanderer_frontend/data/models/domain/trip.dart';
import 'package:wanderer_frontend/data/models/domain/trip_plan.dart';
import 'package:wanderer_frontend/data/models/requests/trip_from_plan_request.dart';
import 'package:wanderer_frontend/data/models/requests/update_trip_plan_request.dart';
import 'package:wanderer_frontend/data/services/trip_plan_service.dart';
import 'package:wanderer_frontend/data/services/trip_service.dart';
import 'package:wanderer_frontend/presentation/helpers/route_polyline_helper.dart';
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
  // `late`, not `late final` — same reasoning as every other injected
  // dependency in this codebase's notifiers: build() can rerun on this
  // instance, and a second assignment to a `late final` field would throw
  // LateInitializationError.
  late GoogleDirectionsApiClient _directionsClient;
  late TripPlanService _tripPlanService;
  late TripService _tripService;

  @override
  TripPlanDetailState build(String arg) {
    _directionsClient = ref.watch(googleDirectionsApiClientProvider);
    _tripPlanService = ref.watch(tripPlanServiceProvider);
    _tripService = ref.watch(tripServiceProvider);
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

  /// Populates the editable location fields from the current trip plan.
  /// Does NOT touch `polylines`/`isComputingRoute` — matching the
  /// pre-migration `_initEditLocations()`'s exact scope.
  void initEditLocations() {
    final plan = state.tripPlan;
    state = state.copyWith(
      editMap: state.editMap.copyWith(
        waypoints: plan.waypoints.map((w) => LatLng(w.lat, w.lon)).toList(),
        startLocation: plan.startLocation != null
            ? LatLng(plan.startLocation!.lat, plan.startLocation!.lon)
            : null,
        endLocation: plan.endLocation != null
            ? LatLng(plan.endLocation!.lat, plan.endLocation!.lon)
            : null,
        clearStartLocation: plan.startLocation == null,
        clearEndLocation: plan.endLocation == null,
        placementMode: EditPlacementMode.waypoint,
        encodedPolyline: plan.plannedPolyline ?? plan.encodedPolyline,
        clearEncodedPolyline:
            plan.plannedPolyline == null && plan.encodedPolyline == null,
      ),
    );
  }

  /// Builds ordered points for the edit-mode polyline: start → waypoints → end.
  List<LatLng> buildEditOrderedPoints() {
    final points = <LatLng>[];
    if (state.editMap.startLocation != null) {
      points.add(state.editMap.startLocation!);
    }
    points.addAll(state.editMap.waypoints);
    if (state.editMap.endLocation != null) {
      points.add(state.editMap.endLocation!);
    }
    return points;
  }

  /// Computes a road-snapped polyline via the Directions API for edit mode,
  /// via the shared [RoutePolylineHelper] (Task 3). On API failure/null,
  /// keeps whatever polyline is already showing (the dashed placeholder set
  /// just above) rather than clearing it — matching both this screen's and
  /// CreateTripPlanScreen's original fallback behavior exactly.
  Future<void> computeEditRoutePolyline() async {
    final points = buildEditOrderedPoints();

    if (points.length < 2) {
      state = state.copyWith(
        editMap:
            state.editMap.copyWith(polylines: {}, clearEncodedPolyline: true),
      );
      return;
    }

    state = state.copyWith(
      editMap: state.editMap.copyWith(
        polylines: RoutePolylineHelper.placeholderPolylines(
          points: points,
          polylineId: 'edit_route',
          color: Colors.blue.withOpacity(0.5),
          width: 3,
        ),
        isComputingRoute: true,
      ),
    );

    final result = await RoutePolylineHelper.computeRoute(
      points: points,
      directionsClient: _directionsClient,
      polylineId: 'edit_route',
      color: Colors.blue,
      width: 5,
    );

    state = state.copyWith(
      editMap: state.editMap.copyWith(
        polylines: result.polylines.isNotEmpty
            ? result.polylines
            : state.editMap.polylines,
        encodedPolyline: result.encodedPolyline,
        clearEncodedPolyline: result.encodedPolyline == null,
        isComputingRoute: false,
      ),
    );
  }

  /// Whether the current edit-map locations still match the original trip
  /// plan (used to decide whether the existing backend polyline can be
  /// reused as-is instead of recomputing).
  bool editLocationsMatchTripPlan() {
    final plan = state.tripPlan;
    final edit = state.editMap;

    if (plan.startLocation != null && edit.startLocation != null) {
      if (edit.startLocation!.latitude != plan.startLocation!.lat ||
          edit.startLocation!.longitude != plan.startLocation!.lon) {
        return false;
      }
    } else if (plan.startLocation != null || edit.startLocation != null) {
      return false;
    }

    if (plan.endLocation != null && edit.endLocation != null) {
      if (edit.endLocation!.latitude != plan.endLocation!.lat ||
          edit.endLocation!.longitude != plan.endLocation!.lon) {
        return false;
      }
    } else if (plan.endLocation != null || edit.endLocation != null) {
      return false;
    }

    if (edit.waypoints.length != plan.waypoints.length) return false;
    for (int i = 0; i < edit.waypoints.length; i++) {
      if (edit.waypoints[i].latitude != plan.waypoints[i].lat ||
          edit.waypoints[i].longitude != plan.waypoints[i].lon) {
        return false;
      }
    }
    return true;
  }

  /// Initializes edit polylines — reuses the existing backend polyline if
  /// locations haven't changed, otherwise computes a new one.
  Future<void> initEditPolylines() async {
    if (editLocationsMatchTripPlan()) {
      final polylineStr =
          state.tripPlan.plannedPolyline ?? state.tripPlan.encodedPolyline;
      if (polylineStr != null && polylineStr.isNotEmpty) {
        try {
          final routePoints = PolylineCodec.decode(polylineStr);
          state = state.copyWith(
            editMap: state.editMap.copyWith(
              polylines: {
                Polyline(
                  polylineId: const PolylineId('edit_route'),
                  points: routePoints,
                  color: Colors.blue,
                  width: 5,
                  geodesic: false,
                  startCap: Cap.roundCap,
                  endCap: Cap.roundCap,
                  jointType: JointType.round,
                ),
              },
              encodedPolyline: polylineStr,
            ),
          );
          return;
        } catch (_) {
          // Fall through to compute.
        }
      }
    }
    await computeEditRoutePolyline();
  }

  /// Called when the user taps the map in edit mode.
  void onEditMapTapped(LatLng location) {
    if (state.editMap.ignoreNextMapTap) {
      state = state.copyWith(
        editMap: state.editMap.copyWith(ignoreNextMapTap: false),
      );
      return;
    }
    // Ignore map taps while a date picker dialog is open (Flutter Web
    // platform view receives the click independently of the dialog overlay).
    if (state.editMap.isPickerOpen) return;

    switch (state.editMap.placementMode) {
      case EditPlacementMode.start:
        final becomesEnd = state.editMap.endLocation == null;
        state = state.copyWith(
          editMap: state.editMap.copyWith(
            startLocation: location,
            placementMode:
                becomesEnd ? EditPlacementMode.end : EditPlacementMode.waypoint,
          ),
        );
        break;
      case EditPlacementMode.end:
        state = state.copyWith(
          editMap: state.editMap.copyWith(
            endLocation: location,
            placementMode: EditPlacementMode.waypoint,
          ),
        );
        break;
      case EditPlacementMode.waypoint:
        state = state.copyWith(
          editMap: state.editMap
              .copyWith(waypoints: [...state.editMap.waypoints, location]),
        );
        break;
    }
    computeEditRoutePolyline();
  }

  void setStartLocation(LatLng location) {
    state = state.copyWith(
        editMap: state.editMap.copyWith(startLocation: location));
    computeEditRoutePolyline();
  }

  void setEndLocation(LatLng location) {
    state =
        state.copyWith(editMap: state.editMap.copyWith(endLocation: location));
    computeEditRoutePolyline();
  }

  void updateWaypointAt(int index, LatLng location) {
    final waypoints = List<LatLng>.from(state.editMap.waypoints);
    waypoints[index] = location;
    state =
        state.copyWith(editMap: state.editMap.copyWith(waypoints: waypoints));
    computeEditRoutePolyline();
  }

  /// Removes the waypoint at [index] and recomputes the route afterward.
  ///
  /// The pre-migration `_showEditMarkerOptions`'s "Remove" bottom-sheet
  /// action did NOT recompute the route after removing a waypoint — a real
  /// bug, confirmed by cross-referencing `CreateTripPlanScreen`'s equivalent
  /// action, which correctly recomputes. Fixed here, per this project's
  /// established precedent of fixing-and-flagging bugs found during a
  /// refactor rather than silently preserving them (see this plan's Global
  /// Constraints).
  void removeWaypointAt(int index) {
    final waypoints = List<LatLng>.from(state.editMap.waypoints)
      ..removeAt(index);
    state =
        state.copyWith(editMap: state.editMap.copyWith(waypoints: waypoints));
    computeEditRoutePolyline();
  }

  /// Reorders a waypoint from [oldIndex] to [newIndex] (accepts
  /// `ReorderableListView.onReorder`'s raw callback values directly — the
  /// `newIndex > oldIndex` adjustment its contract requires is handled
  /// internally) and recomputes the route afterward.
  ///
  /// The pre-migration `ReorderableListView.onReorder` handler did NOT
  /// recompute the route after reordering — the same bug class as
  /// [removeWaypointAt] above, fixed here for the same documented reason.
  void reorderWaypoint(int oldIndex, int newIndex) {
    var adjustedNewIndex = newIndex;
    if (adjustedNewIndex > oldIndex) adjustedNewIndex--;
    final waypoints = List<LatLng>.from(state.editMap.waypoints);
    final item = waypoints.removeAt(oldIndex);
    waypoints.insert(adjustedNewIndex, item);
    state =
        state.copyWith(editMap: state.editMap.copyWith(waypoints: waypoints));
    computeEditRoutePolyline();
  }

  void setIgnoreNextMapTap(bool value) {
    state = state.copyWith(
        editMap: state.editMap.copyWith(ignoreNextMapTap: value));
  }

  void setPickerOpen(bool value) {
    state =
        state.copyWith(editMap: state.editMap.copyWith(isPickerOpen: value));
  }

  /// Resets edit-mode map/route state back to the current trip plan's saved
  /// values — used when the user cancels an in-progress edit. Combines
  /// [initEditLocations]'s field re-seeding with clearing any in-flight
  /// route computation, matching what `_cancelEditing()`'s inline reset
  /// used to do by hand for this portion of its state (the rest — name,
  /// plan type, dates, panel visibility — is metadata/pure-UI concern,
  /// reset separately by Task 5, which migrates `_cancelEditing()` itself).
  void resetEditMapToSavedPlan() {
    initEditLocations();
    state = state.copyWith(
      editMap: state.editMap.copyWith(polylines: {}, isComputingRoute: false),
    );
  }

  /// Seeds metadata fields (plan type, dates) from the trip plan the widget
  /// was constructed with. Unconditional, called once from `initState()`
  /// alongside `seedInitialTripPlan` — kept as its own method (rather than
  /// folded into `seedInitialTripPlan`) so each task that added a seed
  /// concern owns its own seed method, keeping this task independently
  /// revertable without touching Task 2's code.
  void seedMetadataFromPlan(TripPlan tripPlan) {
    state = state.copyWith(
      metadata: state.metadata.copyWith(
        selectedPlanType: tripPlan.planType,
        startDate: tripPlan.startDate,
        endDate: tripPlan.endDate,
        clearStartDate: tripPlan.startDate == null,
        clearEndDate: tripPlan.endDate == null,
      ),
    );
  }

  /// Enters edit mode: seeds edit-map state and metadata fields from the
  /// current trip plan, flips `isEditing` on immediately, then kicks off
  /// route computation in the background. Replaces the two identical
  /// `onEdit` closures that used to be pasted verbatim in `build()` (desktop
  /// and mobile info-card variants) — those set `_isEditing = true`
  /// synchronously inside `setState` while `_initEditPolylines()` ran
  /// unawaited, so the edit screen appeared immediately with route
  /// computation finishing in the background. `initEditPolylines()` must
  /// stay unawaited here for the same reason: awaiting it would block
  /// entering edit mode behind a real network round trip whenever
  /// `editLocationsMatchTripPlan()` is false or there's no cached polyline.
  Future<void> enterEditMode() async {
    initEditLocations();
    seedMetadataFromPlan(state.tripPlan);
    state = state.copyWith(
      metadata: state.metadata.copyWith(isEditing: true),
    );
    initEditPolylines();
  }

  /// Resets metadata to the trip plan's saved values without persisting —
  /// used when the user cancels an in-progress edit. Combines with
  /// [resetEditMapToSavedPlan] for `_cancelEditing()`'s full reset.
  void exitEditModeWithoutSaving() {
    seedMetadataFromPlan(state.tripPlan);
    state = state.copyWith(
      metadata: state.metadata.copyWith(isEditing: false),
    );
  }

  void setSelectedPlanType(String planType) {
    state = state.copyWith(
      metadata: state.metadata.copyWith(selectedPlanType: planType),
    );
  }

  void setDateRange(DateTime start, DateTime end) {
    state = state.copyWith(
      metadata: state.metadata.copyWith(startDate: start, endDate: end),
    );
  }

  /// Persists edited plan metadata and route to the backend, then refetches
  /// the full updated plan. [name] comes from the widget's
  /// `TextEditingController` (never migrated — the controller itself stays
  /// widget-owned, matching every other screen's `TextEditingController`
  /// handling in this codebase).
  Future<void> saveChanges({required String name}) async {
    state = state.copyWith(metadata: state.metadata.copyWith(isLoading: true));
    try {
      String? encodedPolyline = state.editMap.encodedPolyline;
      if (encodedPolyline == null) {
        final points = buildEditOrderedPoints();
        if (points.length >= 2) {
          final result = await _directionsClient.getRoutePolyline(points);
          encodedPolyline = result ?? PolylineCodec.encode(points);
        }
      }

      final request = UpdateTripPlanRequest(
        name: name,
        planType: state.metadata.selectedPlanType,
        startDate: state.metadata.startDate,
        endDate: state.metadata.endDate,
        startLocation: state.editMap.startLocation != null
            ? PlanLocation(
                lat: state.editMap.startLocation!.latitude,
                lon: state.editMap.startLocation!.longitude,
              )
            : state.tripPlan.startLocation,
        endLocation: state.editMap.endLocation != null
            ? PlanLocation(
                lat: state.editMap.endLocation!.latitude,
                lon: state.editMap.endLocation!.longitude,
              )
            : state.tripPlan.endLocation,
        waypoints: state.editMap.waypoints
            .map((w) => PlanLocation(lat: w.latitude, lon: w.longitude))
            .toList(),
        plannedPolyline: encodedPolyline,
      );

      final planId =
          await _tripPlanService.updateTripPlan(state.tripPlan.id, request);
      final updatedPlan = await _tripPlanService.getTripPlanById(planId);

      state = state.copyWith(
        tripPlan: updatedPlan,
        metadata: state.metadata.copyWith(isEditing: false, isLoading: false),
      );
    } catch (e) {
      state =
          state.copyWith(metadata: state.metadata.copyWith(isLoading: false));
      rethrow;
    }
  }

  Future<void> deleteTripPlan() async {
    state = state.copyWith(metadata: state.metadata.copyWith(isLoading: true));
    try {
      await _tripPlanService.deleteTripPlan(state.tripPlan.id);
    } catch (e) {
      state =
          state.copyWith(metadata: state.metadata.copyWith(isLoading: false));
      rethrow;
    }
  }

  Future<Trip> createTripFromPlan(TripFromPlanRequest request) async {
    final tripId =
        await _tripService.createTripFromPlan(state.tripPlan.id, request);
    return _tripService.getTripById(tripId);
  }
}

final tripPlanDetailNotifierProvider = NotifierProvider.autoDispose
    .family<TripPlanDetailNotifier, TripPlanDetailState, String>(
  TripPlanDetailNotifier.new,
);
