// filepath: /Users/tomassirio/Workspace/wanderer_frontend/lib/presentation/helpers/trip_plan_map_helper.dart
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/material.dart';
import 'package:wanderer_frontend/data/client/polyline_codec.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/presentation/helpers/web_marker_generator.dart';

/// Helper class for managing Google Maps markers and polylines for trip plans
class TripPlanMapHelper {
  /// Creates markers and polylines from trip plan locations (straight lines fallback)
  /// [onWaypointTap] callback is called when a waypoint marker is tapped, providing the waypoint index
  static TripPlanMapData createMapData(
    TripPlan tripPlan, {
    void Function(int waypointIndex)? onWaypointTap,
  }) {
    final markers = <Marker>{};
    final polylines = <Polyline>{};
    final points = <LatLng>[];

    // Add start location marker
    if (tripPlan.startLocation != null &&
        tripPlan.startLocation!.lat != 0 &&
        tripPlan.startLocation!.lon != 0) {
      final startLatLng = LatLng(
        tripPlan.startLocation!.lat,
        tripPlan.startLocation!.lon,
      );
      markers.add(
        Marker(
          markerId: const MarkerId('start'),
          position: startLatLng,
          icon: WebMarkerGenerator.markerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(title: 'Start'),
        ),
      );
      points.add(startLatLng);
    }

    // Add waypoint markers
    for (int i = 0; i < tripPlan.waypoints.length; i++) {
      final waypoint = tripPlan.waypoints[i];
      if (waypoint.lat != 0 && waypoint.lon != 0) {
        final waypointLatLng = LatLng(waypoint.lat, waypoint.lon);
        markers.add(
          Marker(
            markerId: MarkerId('waypoint_$i'),
            position: waypointLatLng,
            icon: WebMarkerGenerator.markerWithHue(
              BitmapDescriptor.hueOrange,
            ),
            infoWindow: InfoWindow(title: 'Waypoint ${i + 1}'),
            onTap: onWaypointTap != null ? () => onWaypointTap(i) : null,
          ),
        );
        points.add(waypointLatLng);
      }
    }

    // Add end location marker
    if (tripPlan.endLocation != null &&
        tripPlan.endLocation!.lat != 0 &&
        tripPlan.endLocation!.lon != 0) {
      final endLatLng = LatLng(
        tripPlan.endLocation!.lat,
        tripPlan.endLocation!.lon,
      );
      markers.add(
        Marker(
          markerId: const MarkerId('end'),
          position: endLatLng,
          icon: WebMarkerGenerator.markerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(title: 'End'),
        ),
      );
      points.add(endLatLng);
    }

    // Create polyline connecting all points (straight lines - fallback)
    if (points.length >= 2) {
      polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          points: points,
          color: Colors.blue.withOpacity(0.7),
          width: 3,
          patterns: [PatternItem.dash(20), PatternItem.gap(10)],
        ),
      );
    }

    return TripPlanMapData(markers: markers, polylines: polylines);
  }

  /// Creates markers and polylines using backend-provided polyline or straight lines
  /// [onWaypointTap] callback is called when a waypoint marker is tapped, providing the waypoint index
  static TripPlanMapData createMapDataWithDirections(
    TripPlan tripPlan, {
    void Function(int waypointIndex)? onWaypointTap,
  }) {
    final markers = <Marker>{};
    final polylines = <Polyline>{};
    final points = <LatLng>[];

    // Add start location marker
    if (tripPlan.startLocation != null &&
        tripPlan.startLocation!.lat != 0 &&
        tripPlan.startLocation!.lon != 0) {
      final startLatLng = LatLng(
        tripPlan.startLocation!.lat,
        tripPlan.startLocation!.lon,
      );
      markers.add(
        Marker(
          markerId: const MarkerId('start'),
          position: startLatLng,
          icon: WebMarkerGenerator.markerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(title: 'Start'),
        ),
      );
      points.add(startLatLng);
    }

    // Add waypoint markers
    for (int i = 0; i < tripPlan.waypoints.length; i++) {
      final waypoint = tripPlan.waypoints[i];
      if (waypoint.lat != 0 && waypoint.lon != 0) {
        final waypointLatLng = LatLng(waypoint.lat, waypoint.lon);
        markers.add(
          Marker(
            markerId: MarkerId('waypoint_$i'),
            position: waypointLatLng,
            icon: WebMarkerGenerator.markerWithHue(
              BitmapDescriptor.hueOrange,
            ),
            infoWindow: InfoWindow(title: 'Waypoint ${i + 1}'),
            onTap: onWaypointTap != null ? () => onWaypointTap(i) : null,
          ),
        );
        points.add(waypointLatLng);
      }
    }

    // Add end location marker
    if (tripPlan.endLocation != null &&
        tripPlan.endLocation!.lat != 0 &&
        tripPlan.endLocation!.lon != 0) {
      final endLatLng = LatLng(
        tripPlan.endLocation!.lat,
        tripPlan.endLocation!.lon,
      );
      markers.add(
        Marker(
          markerId: const MarkerId('end'),
          position: endLatLng,
          icon: WebMarkerGenerator.markerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(title: 'End'),
        ),
      );
      points.add(endLatLng);
    }

    // Use planned polyline, backend-computed polyline, or fall back to straight lines
    if (points.length >= 2) {
      final polylineStr = tripPlan.plannedPolyline ?? tripPlan.encodedPolyline;
      if (polylineStr != null && polylineStr.isNotEmpty) {
        try {
          final routePoints = PolylineCodec.decode(polylineStr);
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
          // If decoding fails, fall through to straight lines
          _addStraightLinePolyline(polylines, points);
        }
      } else {
        // Fallback: straight lines connecting plan points
        _addStraightLinePolyline(polylines, points);
      }
    }

    return TripPlanMapData(markers: markers, polylines: polylines);
  }

  /// Adds a dashed straight-line polyline connecting plan points.
  /// Used as a fallback when no backend polyline is available.
  static void _addStraightLinePolyline(
    Set<Polyline> polylines,
    List<LatLng> points,
  ) {
    polylines.add(
      Polyline(
        polylineId: const PolylineId('route'),
        points: points,
        color: Colors.blue.withOpacity(0.7),
        width: 3,
        patterns: [PatternItem.dash(20), PatternItem.gap(10)],
      ),
    );
  }

  /// Gets the initial location for the map
  static LatLng getInitialLocation(TripPlan tripPlan) {
    // Try start location first
    if (tripPlan.startLocation != null &&
        tripPlan.startLocation!.lat != 0 &&
        tripPlan.startLocation!.lon != 0) {
      return LatLng(tripPlan.startLocation!.lat, tripPlan.startLocation!.lon);
    }
    // Then try end location
    if (tripPlan.endLocation != null &&
        tripPlan.endLocation!.lat != 0 &&
        tripPlan.endLocation!.lon != 0) {
      return LatLng(tripPlan.endLocation!.lat, tripPlan.endLocation!.lon);
    }
    // Then try first waypoint
    if (tripPlan.waypoints.isNotEmpty &&
        tripPlan.waypoints.first.lat != 0 &&
        tripPlan.waypoints.first.lon != 0) {
      return LatLng(
        tripPlan.waypoints.first.lat,
        tripPlan.waypoints.first.lon,
      );
    }
    // Default to a general location
    return const LatLng(37.7749, -122.4194); // San Francisco
  }

  /// Calculates bounds to fit all markers
  static LatLngBounds? calculateBounds(Set<Marker> markers) {
    if (markers.isEmpty) return null;

    double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;

    for (final marker in markers) {
      if (marker.position.latitude < minLat) minLat = marker.position.latitude;
      if (marker.position.latitude > maxLat) maxLat = marker.position.latitude;
      if (marker.position.longitude < minLng) {
        minLng = marker.position.longitude;
      }
      if (marker.position.longitude > maxLng) {
        maxLng = marker.position.longitude;
      }
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }
}

/// Data class holding map markers and polylines for trip plans
class TripPlanMapData {
  final Set<Marker> markers;
  final Set<Polyline> polylines;

  const TripPlanMapData({
    required this.markers,
    required this.polylines,
  });
}
