import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/data/client/polyline_codec.dart';
import 'package:wanderer_frontend/presentation/helpers/dashed_polyline_helper.dart';
import 'package:wanderer_frontend/presentation/helpers/trip_route_helper.dart';
import 'package:wanderer_frontend/presentation/helpers/web_marker_generator.dart';
import 'package:wanderer_frontend/presentation/widgets/trip_detail/custom_planned_info_window.dart';
import 'package:wanderer_frontend/core/constants/enums.dart';

/// Helper class for managing Google Maps markers and polylines for trips
class TripMapHelper {
  /// Creates markers and polylines from trip locations or planned route
  /// When [showPlannedWaypoints] is true and the trip has a planned route,
  /// the planned waypoints and polyline are overlaid on top of trip updates.
  static MapData createMapData(
    Trip trip, {
    void Function(TripLocation)? onMarkerTap,
    void Function(PlannedWaypointInfo)? onPlannedMarkerTap,
    bool showPlannedWaypoints = false,
  }) {
    final markers = <Marker>{};
    final polylines = <Polyline>{};

    // First try actual trip updates/locations
    if (trip.locations != null && trip.locations!.isNotEmpty) {
      // Sort chronologically (oldest first) so Update 1 = first trip update
      final locations = List<TripLocation>.from(trip.locations!)
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      // Assign fallback positions to lifecycle markers without real coordinates
      // so all markers (tripStarted, tripEnded, dayStart, dayEnd) appear on map.
      final mappableLocations = _withLifecycleFallbacks(locations);
      final points = <LatLng>[];

      for (int i = 0; i < mappableLocations.length; i++) {
        final location = mappableLocations[i];
        final position = LatLng(location.latitude, location.longitude);
        points.add(position);

        markers.add(
          Marker(
            markerId: MarkerId(location.id),
            position: position,
            infoWindow: onMarkerTap != null
                ? InfoWindow.noText
                : _buildLocationInfoWindow(location, i),
            onTap: onMarkerTap != null ? () => onMarkerTap(location) : null,
            icon: _getMarkerIcon(location, i, mappableLocations.length),
          ),
        );
      }

      if (points.length > 1) {
        // Prefer planned encoded polyline for road-snapped route
        if (!_tryAddPlannedEncodedPolyline(trip, polylines)) {
          polylines.add(
            Polyline(
              polylineId: const PolylineId('route'),
              points: points,
              color: Colors.blue,
              width: 3,
            ),
          );
        }
      }

      // Overlay planned waypoints if enabled
      if (showPlannedWaypoints && trip.hasPlannedRoute) {
        _addPlannedRouteOverlay(trip, markers, polylines,
            onPlannedMarkerTap: onPlannedMarkerTap);
      }
    }
    // Fall back to planned route from trip plan (only when toggle is on)
    else if (showPlannedWaypoints && trip.hasPlannedRoute) {
      final mapData = _createPlannedRouteMapData(trip,
          onPlannedMarkerTap: onPlannedMarkerTap);
      return mapData;
    }

    return MapData(markers: markers, polylines: polylines);
  }

  /// Creates markers and polylines from planned route (from trip plan)
  static MapData _createPlannedRouteMapData(
    Trip trip, {
    void Function(PlannedWaypointInfo)? onPlannedMarkerTap,
  }) {
    final markers = <Marker>{};
    final polylines = <Polyline>{};
    final points = <LatLng>[];

    // Add start location marker (green)
    if (trip.plannedStartLocation != null &&
        trip.plannedStartLocation!.latitude != 0 &&
        trip.plannedStartLocation!.longitude != 0) {
      final startPos = LatLng(
        trip.plannedStartLocation!.latitude,
        trip.plannedStartLocation!.longitude,
      );
      points.add(startPos);
      markers.add(
        Marker(
          markerId: const MarkerId('planned_start'),
          position: startPos,
          infoWindow: onPlannedMarkerTap != null
              ? InfoWindow.noText
              : const InfoWindow(title: 'Planned Start'),
          onTap: onPlannedMarkerTap != null
              ? () => onPlannedMarkerTap(PlannedWaypointInfo(
                    type: PlannedWaypointType.start,
                    position: startPos,
                  ))
              : null,
          icon: _createMarkerWithHue(120.0), // Green
        ),
      );
    }

    // Add waypoint markers (blue - distinct from orange trip updates)
    if (trip.plannedWaypoints != null) {
      for (int i = 0; i < trip.plannedWaypoints!.length; i++) {
        final waypoint = trip.plannedWaypoints![i];
        if (waypoint.latitude != 0 && waypoint.longitude != 0) {
          final waypointPos = LatLng(waypoint.latitude, waypoint.longitude);
          points.add(waypointPos);
          markers.add(
            Marker(
              markerId: MarkerId('planned_waypoint_$i'),
              position: waypointPos,
              infoWindow: onPlannedMarkerTap != null
                  ? InfoWindow.noText
                  : InfoWindow(title: 'Planned Stop ${i + 1}'),
              onTap: onPlannedMarkerTap != null
                  ? () => onPlannedMarkerTap(PlannedWaypointInfo(
                        type: PlannedWaypointType.stop,
                        position: waypointPos,
                        stopIndex: i,
                      ))
                  : null,
              icon: _createMarkerWithHue(240.0), // Blue
            ),
          );
        }
      }
    }

    // Add end location marker (red)
    if (trip.plannedEndLocation != null &&
        trip.plannedEndLocation!.latitude != 0 &&
        trip.plannedEndLocation!.longitude != 0) {
      final endPos = LatLng(
        trip.plannedEndLocation!.latitude,
        trip.plannedEndLocation!.longitude,
      );
      points.add(endPos);
      markers.add(
        Marker(
          markerId: const MarkerId('planned_end'),
          position: endPos,
          infoWindow: onPlannedMarkerTap != null
              ? InfoWindow.noText
              : const InfoWindow(title: 'Planned End'),
          onTap: onPlannedMarkerTap != null
              ? () => onPlannedMarkerTap(PlannedWaypointInfo(
                    type: PlannedWaypointType.end,
                    position: endPos,
                  ))
              : null,
          icon: _createMarkerWithHue(0.0), // Red
        ),
      );
    }

    // Create polyline connecting all planned points
    // Prefer plan's encoded polyline for road-snapped route
    if (trip.plannedEncodedPolyline != null &&
        trip.plannedEncodedPolyline!.isNotEmpty) {
      try {
        final routePoints = PolylineCodec.decode(
          trip.plannedEncodedPolyline!,
        );
        polylines.addAll(
          DashedPolylineHelper.createDashedPolylines(
            polylineIdPrefix: 'planned_route',
            points: routePoints,
            color: Colors.purple.withOpacity(0.7),
            width: 3,
          ),
        );

        // If no markers were added from tripDetails, add start/end from polyline
        if (markers.isEmpty && routePoints.length >= 2) {
          markers.add(
            Marker(
              markerId: const MarkerId('planned_start'),
              position: routePoints.first,
              infoWindow: onPlannedMarkerTap != null
                  ? InfoWindow.noText
                  : const InfoWindow(title: 'Planned Start'),
              onTap: onPlannedMarkerTap != null
                  ? () => onPlannedMarkerTap(PlannedWaypointInfo(
                        type: PlannedWaypointType.start,
                        position: routePoints.first,
                      ))
                  : null,
              icon: _createMarkerWithHue(120.0), // Green
            ),
          );
          markers.add(
            Marker(
              markerId: const MarkerId('planned_end'),
              position: routePoints.last,
              infoWindow: onPlannedMarkerTap != null
                  ? InfoWindow.noText
                  : const InfoWindow(title: 'Planned End'),
              onTap: onPlannedMarkerTap != null
                  ? () => onPlannedMarkerTap(PlannedWaypointInfo(
                        type: PlannedWaypointType.end,
                        position: routePoints.last,
                      ))
                  : null,
              icon: _createMarkerWithHue(0.0), // Red
            ),
          );
        }
      } catch (e) {
        debugPrint(
          'TripMapHelper: Failed to decode planned polyline in fallback, '
          'using straight lines: $e',
        );
        if (points.length >= 2) {
          _addPlannedStraightLinePolyline(polylines, points);
        }
      }
    } else if (points.length >= 2) {
      // Fallback: dashed straight lines
      _addPlannedStraightLinePolyline(polylines, points);
    }

    return MapData(markers: markers, polylines: polylines);
  }

  /// Creates route polyline using backend-provided encoded polyline or straight lines
  /// When [showPlannedWaypoints] is true and the trip has a planned route,
  /// the planned waypoints and polyline are overlaid on top of trip updates.
  static MapData createMapDataWithDirections(
    Trip trip, {
    void Function(TripLocation)? onMarkerTap,
    void Function(PlannedWaypointInfo)? onPlannedMarkerTap,
    bool showPlannedWaypoints = false,
  }) {
    final markers = <Marker>{};
    final polylines = <Polyline>{};

    // First try actual trip updates/locations
    if (trip.locations != null && trip.locations!.isNotEmpty) {
      // Sort chronologically (oldest first) so Update 1 = first trip update
      final locations = List<TripLocation>.from(trip.locations!)
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      // Assign fallback positions to lifecycle markers without real coordinates
      // so all markers (tripStarted, tripEnded, dayStart, dayEnd) appear on map.
      final mappableLocations = _withLifecycleFallbacks(locations);
      final waypoints = <LatLng>[];

      // Create markers only for updates with actual locations
      for (int i = 0; i < mappableLocations.length; i++) {
        final location = mappableLocations[i];
        final position = LatLng(location.latitude, location.longitude);
        waypoints.add(position);

        markers.add(
          Marker(
            markerId: MarkerId(location.id),
            position: position,
            infoWindow: onMarkerTap != null
                ? InfoWindow.noText
                : _buildLocationInfoWindow(location, i),
            onTap: onMarkerTap != null ? () => onMarkerTap(location) : null,
            icon: _getMarkerIconWithDirections(
                location, i, mappableLocations.length),
          ),
        );
      }

      // Get route: prefer backend-computed polyline, then planned polyline,
      // fallback to straight lines
      if (waypoints.length > 1) {
        // Try backend-provided encoded polyline first (zero API calls)
        if (trip.encodedPolyline != null && trip.encodedPolyline!.isNotEmpty) {
          try {
            final routePoints = PolylineCodec.decode(
              trip.encodedPolyline!,
            );
            TripRouteHelper.cachePolyline(trip.id, trip.encodedPolyline!);

            polylines.add(
              Polyline(
                polylineId: const PolylineId('route'),
                points: routePoints,
                color: Colors.blue,
                width: 5,
                geodesic: false,
                visible: true,
                startCap: Cap.roundCap,
                endCap: Cap.roundCap,
                jointType: JointType.round,
              ),
            );
          } catch (e) {
            // Backend polyline decode failed — try planned polyline
            debugPrint(
              'TripMapHelper: Failed to decode backend polyline, '
              'trying planned polyline: $e',
            );
            if (!_tryAddPlannedEncodedPolyline(trip, polylines)) {
              _addStraightLinePolyline(polylines, waypoints);
            }
          }
        } else if (!_tryAddPlannedEncodedPolyline(trip, polylines)) {
          // No backend polyline and no planned polyline — straight-line fallback
          _addStraightLinePolyline(polylines, waypoints);
        }
      }

      // Overlay planned waypoints if enabled
      if (showPlannedWaypoints && trip.hasPlannedRoute) {
        _addPlannedRouteOverlay(trip, markers, polylines,
            onPlannedMarkerTap: onPlannedMarkerTap);
      }

      return MapData(markers: markers, polylines: polylines);
    }
    // Fall back to planned route with directions (only when toggle is on)
    else if (showPlannedWaypoints && trip.hasPlannedRoute) {
      return _createPlannedRouteMapDataWithDirections(trip,
          onPlannedMarkerTap: onPlannedMarkerTap);
    }

    return MapData(markers: markers, polylines: polylines);
  }

  /// Tries to add a road-snapped polyline from the trip's planned encoded polyline.
  /// Returns true if the polyline was successfully decoded and added.
  static bool _tryAddPlannedEncodedPolyline(
    Trip trip,
    Set<Polyline> polylines,
  ) {
    if (trip.plannedEncodedPolyline == null ||
        trip.plannedEncodedPolyline!.isEmpty) {
      return false;
    }
    try {
      final routePoints = PolylineCodec.decode(
        trip.plannedEncodedPolyline!,
      );
      polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          points: routePoints,
          color: Colors.blue,
          width: 5,
          geodesic: false,
          visible: true,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          jointType: JointType.round,
        ),
      );
      return true;
    } catch (e) {
      debugPrint(
        'TripMapHelper: Failed to decode planned polyline: $e',
      );
      return false;
    }
  }

  /// Adds a straight-line polyline connecting the waypoints.
  /// Used as a fallback when no backend polyline is available.
  static void _addStraightLinePolyline(
    Set<Polyline> polylines,
    List<LatLng> waypoints,
  ) {
    polylines.add(
      Polyline(
        polylineId: const PolylineId('route'),
        points: waypoints,
        color: Colors.red,
        width: 4,
        geodesic: false,
        visible: true,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
      ),
    );
  }

  /// Adds planned route markers and polyline as an overlay on existing map data.
  /// Uses the plan's encoded polyline when available for road-snapped routing,
  /// otherwise falls back to straight lines between planned waypoints.
  static void _addPlannedRouteOverlay(
    Trip trip,
    Set<Marker> markers,
    Set<Polyline> polylines, {
    void Function(PlannedWaypointInfo)? onPlannedMarkerTap,
  }) {
    final points = <LatLng>[];

    // Add planned start marker (green with cyan hue to differentiate)
    if (trip.plannedStartLocation != null &&
        trip.plannedStartLocation!.latitude != 0 &&
        trip.plannedStartLocation!.longitude != 0) {
      final startPos = LatLng(
        trip.plannedStartLocation!.latitude,
        trip.plannedStartLocation!.longitude,
      );
      points.add(startPos);
      markers.add(
        Marker(
          markerId: const MarkerId('planned_start'),
          position: startPos,
          infoWindow: onPlannedMarkerTap != null
              ? InfoWindow.noText
              : const InfoWindow(title: 'Planned Start'),
          onTap: onPlannedMarkerTap != null
              ? () => onPlannedMarkerTap(PlannedWaypointInfo(
                    type: PlannedWaypointType.start,
                    position: startPos,
                  ))
              : null,
          icon: _createMarkerWithHue(120.0), // Green
        ),
      );
    }

    // Add planned waypoint markers (violet/blue)
    if (trip.plannedWaypoints != null) {
      for (int i = 0; i < trip.plannedWaypoints!.length; i++) {
        final waypoint = trip.plannedWaypoints![i];
        if (waypoint.latitude != 0 && waypoint.longitude != 0) {
          final waypointPos = LatLng(waypoint.latitude, waypoint.longitude);
          points.add(waypointPos);
          markers.add(
            Marker(
              markerId: MarkerId('planned_waypoint_$i'),
              position: waypointPos,
              infoWindow: onPlannedMarkerTap != null
                  ? InfoWindow.noText
                  : InfoWindow(title: 'Planned Stop ${i + 1}'),
              onTap: onPlannedMarkerTap != null
                  ? () => onPlannedMarkerTap(PlannedWaypointInfo(
                        type: PlannedWaypointType.stop,
                        position: waypointPos,
                        stopIndex: i,
                      ))
                  : null,
              icon: _createMarkerWithHue(270.0), // Violet
            ),
          );
        }
      }
    }

    // Add planned end marker (red)
    if (trip.plannedEndLocation != null &&
        trip.plannedEndLocation!.latitude != 0 &&
        trip.plannedEndLocation!.longitude != 0) {
      final endPos = LatLng(
        trip.plannedEndLocation!.latitude,
        trip.plannedEndLocation!.longitude,
      );
      points.add(endPos);
      markers.add(
        Marker(
          markerId: const MarkerId('planned_end'),
          position: endPos,
          infoWindow: onPlannedMarkerTap != null
              ? InfoWindow.noText
              : const InfoWindow(title: 'Planned End'),
          onTap: onPlannedMarkerTap != null
              ? () => onPlannedMarkerTap(PlannedWaypointInfo(
                    type: PlannedWaypointType.end,
                    position: endPos,
                  ))
              : null,
          icon: _createMarkerWithHue(0.0), // Red
        ),
      );
    }

    // Add planned route polyline
    if (trip.plannedEncodedPolyline != null &&
        trip.plannedEncodedPolyline!.isNotEmpty) {
      // Prefer the plan's encoded polyline for road-snapped route
      try {
        final routePoints = PolylineCodec.decode(
          trip.plannedEncodedPolyline!,
        );
        polylines.addAll(
          DashedPolylineHelper.createDashedPolylines(
            polylineIdPrefix: 'planned_route',
            points: routePoints,
            color: Colors.purple,
            width: 4,
          ),
        );

        // If no markers were added from tripDetails, add start/end from polyline
        if (markers
                .where((m) => m.markerId.value.startsWith('planned_'))
                .isEmpty &&
            routePoints.length >= 2) {
          markers.add(
            Marker(
              markerId: const MarkerId('planned_start'),
              position: routePoints.first,
              infoWindow: onPlannedMarkerTap != null
                  ? InfoWindow.noText
                  : const InfoWindow(title: 'Planned Start'),
              onTap: onPlannedMarkerTap != null
                  ? () => onPlannedMarkerTap(PlannedWaypointInfo(
                        type: PlannedWaypointType.start,
                        position: routePoints.first,
                      ))
                  : null,
              icon: _createMarkerWithHue(120.0), // Green
            ),
          );
          markers.add(
            Marker(
              markerId: const MarkerId('planned_end'),
              position: routePoints.last,
              infoWindow: onPlannedMarkerTap != null
                  ? InfoWindow.noText
                  : const InfoWindow(title: 'Planned End'),
              onTap: onPlannedMarkerTap != null
                  ? () => onPlannedMarkerTap(PlannedWaypointInfo(
                        type: PlannedWaypointType.end,
                        position: routePoints.last,
                      ))
                  : null,
              icon: _createMarkerWithHue(0.0), // Red
            ),
          );
        }
      } catch (e) {
        debugPrint(
          'TripMapHelper: Failed to decode planned polyline, '
          'falling back to straight lines: $e',
        );
        if (points.length >= 2) {
          _addPlannedStraightLinePolyline(polylines, points);
        }
      }
    } else if (points.length >= 2) {
      // Fallback: straight dashed lines between planned waypoints
      _addPlannedStraightLinePolyline(polylines, points);
    }
  }

  /// Adds a dashed straight-line polyline for the planned route overlay.
  static void _addPlannedStraightLinePolyline(
    Set<Polyline> polylines,
    List<LatLng> points,
  ) {
    polylines.addAll(
      DashedPolylineHelper.createDashedPolylines(
        polylineIdPrefix: 'planned_route',
        points: points,
        color: Colors.purple.withOpacity(0.7),
        width: 3,
      ),
    );
  }

  /// Creates planned route map data with straight-line polylines
  static MapData _createPlannedRouteMapDataWithDirections(
    Trip trip, {
    void Function(PlannedWaypointInfo)? onPlannedMarkerTap,
  }) {
    final markers = <Marker>{};
    final polylines = <Polyline>{};
    final points = <LatLng>[];

    // Add start location marker (green)
    if (trip.plannedStartLocation != null &&
        trip.plannedStartLocation!.latitude != 0 &&
        trip.plannedStartLocation!.longitude != 0) {
      final startPos = LatLng(
        trip.plannedStartLocation!.latitude,
        trip.plannedStartLocation!.longitude,
      );
      points.add(startPos);
      markers.add(
        Marker(
          markerId: const MarkerId('planned_start'),
          position: startPos,
          infoWindow: onPlannedMarkerTap != null
              ? InfoWindow.noText
              : const InfoWindow(title: 'Planned Start'),
          onTap: onPlannedMarkerTap != null
              ? () => onPlannedMarkerTap(PlannedWaypointInfo(
                    type: PlannedWaypointType.start,
                    position: startPos,
                  ))
              : null,
          icon: _createMarkerWithHue(120.0), // Green
        ),
      );
    }

    // Add waypoint markers (blue - distinct from orange trip updates)
    if (trip.plannedWaypoints != null) {
      for (int i = 0; i < trip.plannedWaypoints!.length; i++) {
        final waypoint = trip.plannedWaypoints![i];
        if (waypoint.latitude != 0 && waypoint.longitude != 0) {
          final waypointPos = LatLng(waypoint.latitude, waypoint.longitude);
          points.add(waypointPos);
          markers.add(
            Marker(
              markerId: MarkerId('planned_waypoint_$i'),
              position: waypointPos,
              infoWindow: onPlannedMarkerTap != null
                  ? InfoWindow.noText
                  : InfoWindow(title: 'Planned Stop ${i + 1}'),
              onTap: onPlannedMarkerTap != null
                  ? () => onPlannedMarkerTap(PlannedWaypointInfo(
                        type: PlannedWaypointType.stop,
                        position: waypointPos,
                        stopIndex: i,
                      ))
                  : null,
              icon: _createMarkerWithHue(240.0), // Blue
            ),
          );
        }
      }
    }

    // Add end location marker (red)
    if (trip.plannedEndLocation != null &&
        trip.plannedEndLocation!.latitude != 0 &&
        trip.plannedEndLocation!.longitude != 0) {
      final endPos = LatLng(
        trip.plannedEndLocation!.latitude,
        trip.plannedEndLocation!.longitude,
      );
      points.add(endPos);
      markers.add(
        Marker(
          markerId: const MarkerId('planned_end'),
          position: endPos,
          infoWindow: onPlannedMarkerTap != null
              ? InfoWindow.noText
              : const InfoWindow(title: 'Planned End'),
          onTap: onPlannedMarkerTap != null
              ? () => onPlannedMarkerTap(PlannedWaypointInfo(
                    type: PlannedWaypointType.end,
                    position: endPos,
                  ))
              : null,
          icon: _createMarkerWithHue(0.0), // Red
        ),
      );
    }

    // Create polyline for planned route - prefer encoded polyline
    if (trip.plannedEncodedPolyline != null &&
        trip.plannedEncodedPolyline!.isNotEmpty) {
      debugPrint(
        'TripMapHelper: Creating planned route for trip ${trip.id}. '
        'plannedEncodedPolyline exists: true, '
        'is not empty: true',
      );
      try {
        final routePoints = PolylineCodec.decode(
          trip.plannedEncodedPolyline!,
        );
        debugPrint(
          'TripMapHelper: Successfully decoded planned polyline '
          'with ${routePoints.length} points',
        );
        polylines.addAll(
          DashedPolylineHelper.createDashedPolylines(
            polylineIdPrefix: 'planned_route',
            points: routePoints,
            color: Colors.purple,
            width: 4,
          ),
        );

        // If no markers were added from tripDetails, add start/end from polyline
        if (markers.isEmpty && routePoints.length >= 2) {
          markers.add(
            Marker(
              markerId: const MarkerId('planned_start'),
              position: routePoints.first,
              infoWindow: onPlannedMarkerTap != null
                  ? InfoWindow.noText
                  : const InfoWindow(title: 'Planned Start'),
              onTap: onPlannedMarkerTap != null
                  ? () => onPlannedMarkerTap(PlannedWaypointInfo(
                        type: PlannedWaypointType.start,
                        position: routePoints.first,
                      ))
                  : null,
              icon: _createMarkerWithHue(120.0), // Green
            ),
          );
          markers.add(
            Marker(
              markerId: const MarkerId('planned_end'),
              position: routePoints.last,
              infoWindow: onPlannedMarkerTap != null
                  ? InfoWindow.noText
                  : const InfoWindow(title: 'Planned End'),
              onTap: onPlannedMarkerTap != null
                  ? () => onPlannedMarkerTap(PlannedWaypointInfo(
                        type: PlannedWaypointType.end,
                        position: routePoints.last,
                      ))
                  : null,
              icon: _createMarkerWithHue(0.0), // Red
            ),
          );
        }
      } catch (e) {
        debugPrint(
          'TripMapHelper: Failed to decode planned polyline in directions, '
          'using straight lines: $e',
        );
        if (points.length >= 2) {
          polylines.addAll(
            DashedPolylineHelper.createDashedPolylines(
              polylineIdPrefix: 'planned_route',
              points: points,
              color: Colors.purple,
              width: 4,
            ),
          );
        }
      }
    } else if (points.length >= 2) {
      debugPrint(
        'TripMapHelper: No encoded polyline for trip ${trip.id}, '
        'using straight lines',
      );
      polylines.addAll(
        DashedPolylineHelper.createDashedPolylines(
          polylineIdPrefix: 'planned_route',
          points: points,
          color: Colors.purple,
          width: 4,
        ),
      );
    }

    return MapData(markers: markers, polylines: polylines);
  }

  /// Gets the initial location for the map (latest location or planned start).
  ///
  /// When [userLocation] is provided it is used as the last fallback before the
  /// hardcoded NYC default so that freshly-created trips without any location
  /// data centre on the user's actual position.
  static LatLng getInitialLocation(Trip trip, {LatLng? userLocation}) {
    // First try actual trip locations (skip lifecycle markers with no real coords)
    if (trip.locations != null && trip.locations!.isNotEmpty) {
      // Find the last location that has real coordinates
      final validLocations = trip.locations!
          .where((loc) => !loc.isLifecycleMarker || loc.hasLocation)
          .toList();
      if (validLocations.isNotEmpty) {
        return LatLng(
          validLocations.last.latitude,
          validLocations.last.longitude,
        );
      }
    }
    // Then try planned start location
    if (trip.plannedStartLocation != null &&
        trip.plannedStartLocation!.latitude != 0 &&
        trip.plannedStartLocation!.longitude != 0) {
      return LatLng(
        trip.plannedStartLocation!.latitude,
        trip.plannedStartLocation!.longitude,
      );
    }
    // Then try planned end location
    if (trip.plannedEndLocation != null &&
        trip.plannedEndLocation!.latitude != 0 &&
        trip.plannedEndLocation!.longitude != 0) {
      return LatLng(
        trip.plannedEndLocation!.latitude,
        trip.plannedEndLocation!.longitude,
      );
    }
    // Then try first planned waypoint
    if (trip.plannedWaypoints != null && trip.plannedWaypoints!.isNotEmpty) {
      final wp = trip.plannedWaypoints!.first;
      if (wp.latitude != 0 && wp.longitude != 0) {
        return LatLng(wp.latitude, wp.longitude);
      }
    }
    // Then try decoding the planned encoded polyline
    if (trip.plannedEncodedPolyline != null &&
        trip.plannedEncodedPolyline!.isNotEmpty) {
      try {
        final routePoints = PolylineCodec.decode(
          trip.plannedEncodedPolyline!,
        );
        if (routePoints.isNotEmpty) {
          return routePoints.first;
        }
      } catch (_) {
        // Ignore decode errors, fall through to default
      }
    }
    // Then try the user's current device location
    if (userLocation != null) {
      return userLocation;
    }
    return const LatLng(40.7128, -74.0060); // Default to NYC
  }

  /// Gets the appropriate zoom level based on whether trip has locations.
  ///
  /// When [userLocation] is provided and the trip has no locations or planned
  /// route, uses a closer zoom so the map centres meaningfully on the user
  /// instead of showing a continent-level view.
  static double getInitialZoom(Trip trip, {LatLng? userLocation}) {
    if (trip.locations != null && trip.locations!.isNotEmpty) {
      return 12;
    }
    if (trip.hasPlannedRoute) {
      return 10;
    }
    if (userLocation != null) {
      return 14;
    }
    return 4;
  }

  /// Filters sorted locations, keeping all lifecycle markers (tripStarted,
  /// tripEnded, dayStart, dayEnd) even when they lack real coordinates by
  /// assigning them the nearest real position as a fallback.
  static List<TripLocation> _withLifecycleFallbacks(
    List<TripLocation> sorted,
  ) {
    final realLocations = sorted.where((loc) => loc.hasLocation).toList();
    if (realLocations.isEmpty) {
      // No real locations to use as fallback — keep only those with coords
      return sorted
          .where((loc) => !loc.isLifecycleMarker || loc.hasLocation)
          .toList();
    }

    final firstReal = realLocations.first;
    final lastReal = realLocations.last;
    final result = <TripLocation>[];

    for (int i = 0; i < sorted.length; i++) {
      final loc = sorted[i];
      if (!loc.isLifecycleMarker) {
        // Regular update — always keep
        result.add(loc);
      } else if (loc.hasLocation) {
        // Lifecycle marker with real coordinates — keep as-is
        result.add(loc);
      } else {
        // Lifecycle marker without location — find the best fallback
        final fallback =
            _findNearestRealLocation(sorted, i, firstReal, lastReal);
        result.add(loc.copyWith(
          latitude: fallback.latitude,
          longitude: fallback.longitude,
          city: loc.city ?? fallback.city,
          country: loc.country ?? fallback.country,
        ));
      }
    }
    return result;
  }

  /// Finds the nearest real location to use as a fallback position.
  /// For tripStarted → first real; for tripEnded → last real.
  /// For dayStart/dayEnd → nearest preceding or following real location.
  static TripLocation _findNearestRealLocation(
    List<TripLocation> sorted,
    int index,
    TripLocation firstReal,
    TripLocation lastReal,
  ) {
    final loc = sorted[index];
    if (loc.updateType == TripUpdateType.tripStarted) return firstReal;
    if (loc.updateType == TripUpdateType.tripEnded) return lastReal;

    // For day markers, look for the nearest real location (prefer preceding)
    // Search backward first
    for (int j = index - 1; j >= 0; j--) {
      if (sorted[j].hasLocation) return sorted[j];
    }
    // Then forward
    for (int j = index + 1; j < sorted.length; j++) {
      if (sorted[j].hasLocation) return sorted[j];
    }
    return firstReal; // Ultimate fallback
  }

  /// Builds a rich InfoWindow for a location update marker
  static InfoWindow _buildLocationInfoWindow(TripLocation location, int index) {
    // Lifecycle labels for lifecycle markers
    final lifecycleLabel = _lifecycleInfoLabel(location.updateType);
    if (lifecycleLabel != null) {
      final titleParts = <String>[lifecycleLabel];
      titleParts.add(_formatMarkerTimestamp(location.timestamp));
      final title = titleParts.join('  ·  ');
      final snippetParts = <String>[location.displayLocation];
      if (location.message != null && location.message!.isNotEmpty) {
        snippetParts.add(location.message!);
      }
      return InfoWindow(title: title, snippet: snippetParts.join('\n'));
    }

    // Title: date/time + battery
    final titleParts = <String>[];
    titleParts.add(_formatMarkerTimestamp(location.timestamp));
    if (location.battery != null) {
      titleParts.add('🔋 ${location.battery}%');
    }
    final title = titleParts.join('  ·  ');

    // Snippet: location + message
    final snippetParts = <String>[];
    snippetParts.add(location.displayLocation);
    if (location.message != null && location.message!.isNotEmpty) {
      snippetParts.add(location.message!);
    }
    final snippet = snippetParts.join('\n');

    return InfoWindow(
      title: title,
      snippet: snippet,
    );
  }

  /// Returns a label prefix for lifecycle markers, or null for regular updates.
  static String? _lifecycleInfoLabel(TripUpdateType type) {
    switch (type) {
      case TripUpdateType.tripStarted:
        return '🚩 Trip Started';
      case TripUpdateType.tripEnded:
        return '🏁 Trip Ended';
      case TripUpdateType.dayStart:
        return '☀️ Day Started';
      case TripUpdateType.dayEnd:
        return '🌙 Day Ended';
      case TripUpdateType.regular:
        return null;
    }
  }

  /// Formats a timestamp for display in a marker InfoWindow
  static String _formatMarkerTimestamp(DateTime timestamp) {
    final local = timestamp.toLocal();
    final day = '${local.day}/${local.month}/${local.year}';
    final time = '${local.hour}:${local.minute.toString().padLeft(2, '0')}';
    return '$day  $time';
  }

  /// Creates a marker icon with the specified hue, using the appropriate
  /// method for the current platform (web vs native).
  static BitmapDescriptor _createMarkerWithHue(double hue) {
    return WebMarkerGenerator.markerWithHue(hue);
  }

  /// Gets the appropriate marker icon for a location based on its type
  static BitmapDescriptor _getMarkerIcon(
    TripLocation location,
    int index,
    int totalLocations,
  ) {
    // On web, use numeric hue values for better compatibility
    if (kIsWeb) {
      return _getWebMarkerIcon(location, index, totalLocations);
    }

    // Check for lifecycle markers first
    switch (location.updateType) {
      case TripUpdateType.tripStarted:
        return _createMarkerWithHue(BitmapDescriptor.hueGreen);
      case TripUpdateType.tripEnded:
        return _createMarkerWithHue(BitmapDescriptor.hueRed);
      case TripUpdateType.dayStart:
        return _createMarkerWithHue(BitmapDescriptor.hueYellow);
      case TripUpdateType.dayEnd:
        return _createMarkerWithHue(BitmapDescriptor.hueViolet);
      case TripUpdateType.regular:
        // For regular updates, use red for last (most recent) location
        if (index == totalLocations - 1) {
          return _createMarkerWithHue(BitmapDescriptor.hueRed);
        }
        return _createMarkerWithHue(BitmapDescriptor.hueOrange);
    }
  }

  /// Gets marker icon for web platform using numeric hue values
  static BitmapDescriptor _getWebMarkerIcon(
    TripLocation location,
    int index,
    int totalLocations,
  ) {
    double hue;
    String colorName;

    switch (location.updateType) {
      case TripUpdateType.tripStarted:
        hue = 120.0;
        colorName = 'GREEN';
        break;
      case TripUpdateType.tripEnded:
        hue = 0.0;
        colorName = 'RED';
        break;
      case TripUpdateType.dayStart:
        hue = 60.0;
        colorName = 'YELLOW';
        break;
      case TripUpdateType.dayEnd:
        hue = 270.0;
        colorName = 'VIOLET';
        break;
      case TripUpdateType.regular:
        if (index == totalLocations - 1) {
          hue = 0.0;
          colorName = 'RED (latest)';
        } else {
          hue = 30.0;
          colorName = 'ORANGE (previous)';
        }
        break;
    }

    debugPrint(
        'WEB: Marker for ${location.updateType} at index $index/$totalLocations -> $colorName (hue: $hue)');
    return WebMarkerGenerator.markerWithHue(hue);
  }

  /// Gets the appropriate marker icon for a location with directions mode
  static BitmapDescriptor _getMarkerIconWithDirections(
    TripLocation location,
    int index,
    int totalLocations,
  ) {
    // On web, use numeric hue values for better compatibility
    if (kIsWeb) {
      return _getWebMarkerIconWithDirections(location, index, totalLocations);
    }

    // Check for lifecycle markers first
    switch (location.updateType) {
      case TripUpdateType.tripStarted:
        return _createMarkerWithHue(BitmapDescriptor.hueGreen);
      case TripUpdateType.tripEnded:
        return _createMarkerWithHue(BitmapDescriptor.hueRed);
      case TripUpdateType.dayStart:
        return _createMarkerWithHue(BitmapDescriptor.hueYellow);
      case TripUpdateType.dayEnd:
        return _createMarkerWithHue(BitmapDescriptor.hueViolet);
      case TripUpdateType.regular:
        // For regular updates in directions mode:
        // - Last (most recent) = red
        // - Previous = orange
        if (index == totalLocations - 1) {
          return _createMarkerWithHue(BitmapDescriptor.hueRed);
        }
        return _createMarkerWithHue(BitmapDescriptor.hueOrange);
    }
  }

  /// Gets marker icon for web platform with directions mode using numeric hue values
  static BitmapDescriptor _getWebMarkerIconWithDirections(
    TripLocation location,
    int index,
    int totalLocations,
  ) {
    double hue;
    String colorName;

    switch (location.updateType) {
      case TripUpdateType.tripStarted:
        hue = 120.0;
        colorName = 'GREEN';
        break;
      case TripUpdateType.tripEnded:
        hue = 0.0;
        colorName = 'RED';
        break;
      case TripUpdateType.dayStart:
        hue = 60.0;
        colorName = 'YELLOW';
        break;
      case TripUpdateType.dayEnd:
        hue = 270.0;
        colorName = 'VIOLET';
        break;
      case TripUpdateType.regular:
        if (index == totalLocations - 1) {
          hue = 0.0;
          colorName = 'RED (latest)';
        } else {
          hue = 30.0;
          colorName = 'ORANGE (previous)';
        }
        break;
    }

    debugPrint(
        'WEB-DIR: Marker for ${location.updateType} at index $index/$totalLocations -> $colorName (hue: $hue)');
    return WebMarkerGenerator.markerWithHue(hue);
  }
}

/// Data class holding map markers and polylines
class MapData {
  final Set<Marker> markers;
  final Set<Polyline> polylines;

  MapData({required this.markers, required this.polylines});
}
