import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/material.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/data/client/polyline_codec.dart';
import 'package:wanderer_frontend/presentation/helpers/trip_route_helper.dart';

/// Helper class for managing Google Maps markers and polylines for trips
class TripMapHelper {
  /// Creates markers and polylines from trip locations or planned route
  /// When [showPlannedWaypoints] is true and the trip has a planned route,
  /// the planned waypoints and polyline are overlaid on top of trip updates.
  static MapData createMapData(
    Trip trip, {
    void Function(TripLocation)? onMarkerTap,
    bool showPlannedWaypoints = false,
  }) {
    final markers = <Marker>{};
    final polylines = <Polyline>{};

    // First try actual trip updates/locations
    if (trip.locations != null && trip.locations!.isNotEmpty) {
      // Sort chronologically (oldest first) so Update 1 = first trip update
      final locations = List<TripLocation>.from(trip.locations!)
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      // Filter out lifecycle markers with no real location (location: null from backend)
      final mappableLocations = locations
          .where((loc) => !loc.isLifecycleMarker || loc.hasLocation)
          .toList();
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
            icon: i == mappableLocations.length - 1
                ? BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueGreen,
                  )
                : BitmapDescriptor.defaultMarker,
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
        _addPlannedRouteOverlay(trip, markers, polylines);
      }
    }
    // Fall back to planned route from trip plan (only when toggle is on)
    else if (showPlannedWaypoints && trip.hasPlannedRoute) {
      final mapData = _createPlannedRouteMapData(trip);
      return mapData;
    }

    return MapData(markers: markers, polylines: polylines);
  }

  /// Creates markers and polylines from planned route (from trip plan)
  static MapData _createPlannedRouteMapData(Trip trip) {
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
          infoWindow: const InfoWindow(title: 'Planned Start'),
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
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
              infoWindow: InfoWindow(title: 'Planned Stop ${i + 1}'),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueBlue,
              ),
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
          infoWindow: const InfoWindow(title: 'Planned End'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
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
        polylines.add(
          Polyline(
            polylineId: const PolylineId('planned_route'),
            points: routePoints,
            color: Colors.purple.withOpacity(0.7),
            width: 3,
            patterns: [PatternItem.dash(20), PatternItem.gap(10)],
            geodesic: false,
            visible: true,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
            jointType: JointType.round,
          ),
        );

        // If no markers were added from tripDetails, add start/end from polyline
        if (markers.isEmpty && routePoints.length >= 2) {
          markers.add(
            Marker(
              markerId: const MarkerId('planned_start'),
              position: routePoints.first,
              infoWindow: const InfoWindow(title: 'Planned Start'),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueGreen,
              ),
            ),
          );
          markers.add(
            Marker(
              markerId: const MarkerId('planned_end'),
              position: routePoints.last,
              infoWindow: const InfoWindow(title: 'Planned End'),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueRed,
              ),
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
    bool showPlannedWaypoints = false,
  }) {
    final markers = <Marker>{};
    final polylines = <Polyline>{};

    // First try actual trip updates/locations
    if (trip.locations != null && trip.locations!.isNotEmpty) {
      // Sort chronologically (oldest first) so Update 1 = first trip update
      final locations = List<TripLocation>.from(trip.locations!)
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      // Filter out lifecycle markers with no real location (location: null from backend)
      final mappableLocations = locations
          .where((loc) => !loc.isLifecycleMarker || loc.hasLocation)
          .toList();
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
            icon: i == 0
                ? BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueRed, // Start point - red
                  )
                : i == mappableLocations.length - 1
                    ? BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueGreen, // End point - green
                      )
                    : BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueOrange, // Waypoints - orange
                      ),
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
        _addPlannedRouteOverlay(trip, markers, polylines);
      }

      return MapData(markers: markers, polylines: polylines);
    }
    // Fall back to planned route with directions (only when toggle is on)
    else if (showPlannedWaypoints && trip.hasPlannedRoute) {
      return _createPlannedRouteMapDataWithDirections(trip);
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
    Set<Polyline> polylines,
  ) {
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
          infoWindow: const InfoWindow(title: 'Planned Start'),
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
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
              infoWindow: InfoWindow(title: 'Planned Stop ${i + 1}'),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueViolet,
              ),
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
          infoWindow: const InfoWindow(title: 'Planned End'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
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
        polylines.add(
          Polyline(
            polylineId: const PolylineId('planned_route'),
            points: routePoints,
            color: Colors.purple,
            width: 4,
            patterns: [PatternItem.dash(20), PatternItem.gap(10)],
            geodesic: false,
            visible: true,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
            jointType: JointType.round,
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
              infoWindow: const InfoWindow(title: 'Planned Start'),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueGreen,
              ),
            ),
          );
          markers.add(
            Marker(
              markerId: const MarkerId('planned_end'),
              position: routePoints.last,
              infoWindow: const InfoWindow(title: 'Planned End'),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueRed,
              ),
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
    polylines.add(
      Polyline(
        polylineId: const PolylineId('planned_route'),
        points: points,
        color: Colors.purple.withOpacity(0.7),
        width: 3,
        patterns: [PatternItem.dash(20), PatternItem.gap(10)],
        geodesic: false,
        visible: true,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
      ),
    );
  }

  /// Creates planned route map data with straight-line polylines
  static MapData _createPlannedRouteMapDataWithDirections(
    Trip trip,
  ) {
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
          infoWindow: const InfoWindow(title: 'Planned Start'),
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
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
              infoWindow: InfoWindow(title: 'Planned Stop ${i + 1}'),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueBlue,
              ),
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
          infoWindow: const InfoWindow(title: 'Planned End'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
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
        polylines.add(
          Polyline(
            polylineId: const PolylineId('planned_route'),
            points: routePoints,
            color: Colors.purple,
            width: 4,
            patterns: [PatternItem.dash(20), PatternItem.gap(10)],
            geodesic: false,
            visible: true,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
            jointType: JointType.round,
          ),
        );

        // If no markers were added from tripDetails, add start/end from polyline
        if (markers.isEmpty && routePoints.length >= 2) {
          markers.add(
            Marker(
              markerId: const MarkerId('planned_start'),
              position: routePoints.first,
              infoWindow: const InfoWindow(title: 'Planned Start'),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueGreen,
              ),
            ),
          );
          markers.add(
            Marker(
              markerId: const MarkerId('planned_end'),
              position: routePoints.last,
              infoWindow: const InfoWindow(title: 'Planned End'),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueRed,
              ),
            ),
          );
        }
      } catch (e) {
        debugPrint(
          'TripMapHelper: Failed to decode planned polyline in directions, '
          'using straight lines: $e',
        );
        if (points.length >= 2) {
          polylines.add(
            Polyline(
              polylineId: const PolylineId('planned_route'),
              points: points,
              color: Colors.purple,
              width: 4,
              patterns: [PatternItem.dash(20), PatternItem.gap(10)],
              geodesic: false,
              visible: true,
              startCap: Cap.roundCap,
              endCap: Cap.roundCap,
            ),
          );
        }
      }
    } else if (points.length >= 2) {
      debugPrint(
        'TripMapHelper: No encoded polyline for trip ${trip.id}, '
        'using straight lines',
      );
      polylines.add(
        Polyline(
          polylineId: const PolylineId('planned_route'),
          points: points,
          color: Colors.purple,
          width: 4,
          patterns: [PatternItem.dash(20), PatternItem.gap(10)],
          geodesic: false,
          visible: true,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
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

  /// Builds a rich InfoWindow for a location update marker
  static InfoWindow _buildLocationInfoWindow(TripLocation location, int index) {
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

  /// Formats a timestamp for display in a marker InfoWindow
  static String _formatMarkerTimestamp(DateTime timestamp) {
    final local = timestamp.toLocal();
    final day = '${local.day}/${local.month}/${local.year}';
    final time = '${local.hour}:${local.minute.toString().padLeft(2, '0')}';
    return '$day  $time';
  }
}

/// Data class holding map markers and polylines
class MapData {
  final Set<Marker> markers;
  final Set<Polyline> polylines;

  MapData({required this.markers, required this.polylines});
}
