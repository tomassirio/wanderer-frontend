import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:wanderer_frontend/data/models/domain/trip_plan.dart';

/// The type of point the user wants to place next on the map in edit mode.
/// Was a private, file-local `_EditPlacementMode` enum on the widget before
/// this migration — made public so both the notifier and the widget can
/// reference it (a mechanical, zero-behavior-change rename).
enum EditPlacementMode { start, end, waypoint }

/// View-mode map rendering state (markers/polylines shown when NOT editing).
class TripPlanDetailViewMapState {
  final Set<Marker> markers;
  final Set<Polyline> polylines;
  final bool isInfoCollapsed;

  const TripPlanDetailViewMapState({
    this.markers = const {},
    this.polylines = const {},
    this.isInfoCollapsed = false,
  });

  TripPlanDetailViewMapState copyWith({
    Set<Marker>? markers,
    Set<Polyline>? polylines,
    bool? isInfoCollapsed,
  }) {
    return TripPlanDetailViewMapState(
      markers: markers ?? this.markers,
      polylines: polylines ?? this.polylines,
      isInfoCollapsed: isInfoCollapsed ?? this.isInfoCollapsed,
    );
  }
}

/// Edit-mode map/route/waypoint-editing state. Populated by Task 4.
class TripPlanDetailEditMapState {
  final List<LatLng> waypoints;
  final LatLng? startLocation;
  final LatLng? endLocation;
  final EditPlacementMode placementMode;
  final Set<Polyline> polylines;
  final String? encodedPolyline;
  final bool isComputingRoute;
  final bool ignoreNextMapTap;
  final bool isPickerOpen;

  const TripPlanDetailEditMapState({
    this.waypoints = const [],
    this.startLocation,
    this.endLocation,
    this.placementMode = EditPlacementMode.waypoint,
    this.polylines = const {},
    this.encodedPolyline,
    this.isComputingRoute = false,
    this.ignoreNextMapTap = false,
    this.isPickerOpen = false,
  });

  TripPlanDetailEditMapState copyWith({
    List<LatLng>? waypoints,
    LatLng? startLocation,
    LatLng? endLocation,
    EditPlacementMode? placementMode,
    Set<Polyline>? polylines,
    String? encodedPolyline,
    bool? isComputingRoute,
    bool? ignoreNextMapTap,
    bool? isPickerOpen,
    bool clearStartLocation = false,
    bool clearEndLocation = false,
    bool clearEncodedPolyline = false,
  }) {
    return TripPlanDetailEditMapState(
      waypoints: waypoints ?? this.waypoints,
      startLocation:
          clearStartLocation ? null : (startLocation ?? this.startLocation),
      endLocation: clearEndLocation ? null : (endLocation ?? this.endLocation),
      placementMode: placementMode ?? this.placementMode,
      polylines: polylines ?? this.polylines,
      encodedPolyline: clearEncodedPolyline
          ? null
          : (encodedPolyline ?? this.encodedPolyline),
      isComputingRoute: isComputingRoute ?? this.isComputingRoute,
      ignoreNextMapTap: ignoreNextMapTap ?? this.ignoreNextMapTap,
      isPickerOpen: isPickerOpen ?? this.isPickerOpen,
    );
  }
}

/// Plan metadata editing + save/delete lifecycle flags. Populated by Task 5.
class TripPlanDetailMetadataState {
  final bool isEditing;
  final bool isLoading;
  final String selectedPlanType;
  final DateTime? startDate;
  final DateTime? endDate;

  const TripPlanDetailMetadataState({
    this.isEditing = false,
    this.isLoading = false,
    this.selectedPlanType = 'SIMPLE',
    this.startDate,
    this.endDate,
  });

  TripPlanDetailMetadataState copyWith({
    bool? isEditing,
    bool? isLoading,
    String? selectedPlanType,
    DateTime? startDate,
    DateTime? endDate,
    bool clearStartDate = false,
    bool clearEndDate = false,
  }) {
    return TripPlanDetailMetadataState(
      isEditing: isEditing ?? this.isEditing,
      isLoading: isLoading ?? this.isLoading,
      selectedPlanType: selectedPlanType ?? this.selectedPlanType,
      startDate: clearStartDate ? null : (startDate ?? this.startDate),
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
    );
  }
}

/// Full state backing [TripPlanDetailScreen], owned by [TripPlanDetailNotifier].
class TripPlanDetailState {
  final TripPlan tripPlan;
  final TripPlanDetailViewMapState viewMap;
  final TripPlanDetailEditMapState editMap;
  final TripPlanDetailMetadataState metadata;

  const TripPlanDetailState({
    required this.tripPlan,
    this.viewMap = const TripPlanDetailViewMapState(),
    this.editMap = const TripPlanDetailEditMapState(),
    this.metadata = const TripPlanDetailMetadataState(),
  });

  TripPlanDetailState copyWith({
    TripPlan? tripPlan,
    TripPlanDetailViewMapState? viewMap,
    TripPlanDetailEditMapState? editMap,
    TripPlanDetailMetadataState? metadata,
  }) {
    return TripPlanDetailState(
      tripPlan: tripPlan ?? this.tripPlan,
      viewMap: viewMap ?? this.viewMap,
      editMap: editMap ?? this.editMap,
      metadata: metadata ?? this.metadata,
    );
  }
}
