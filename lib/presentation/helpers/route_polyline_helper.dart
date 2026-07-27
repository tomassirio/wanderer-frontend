import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:wanderer_frontend/data/client/google_directions_api_client.dart';
import 'package:wanderer_frontend/data/client/polyline_codec.dart';
import 'package:wanderer_frontend/presentation/helpers/dashed_polyline_helper.dart';

/// Result of a route-polyline computation: the final polyline set to render
/// (empty if the API call failed/returned null — the caller decides whether
/// to keep an existing placeholder polyline visible in that case) and the
/// encoded polyline string to persist.
class RoutePolylineResult {
  final Set<Polyline> polylines;
  final String? encodedPolyline;

  const RoutePolylineResult({
    required this.polylines,
    required this.encodedPolyline,
  });
}

/// Computes a road-snapped polyline via the Directions API, consolidating
/// the "ordered points -> getRouteWithPoints -> straight-line fallback"
/// pipeline previously duplicated between TripPlanDetailScreen's
/// `_computeEditRoutePolyline` and CreateTripPlanScreen's
/// `_computeRoutePolyline`. Callers show [placeholderPolylines] (a dashed
/// straight line) immediately while [computeRoute] is in flight.
class RoutePolylineHelper {
  /// Immediate dashed straight-line placeholder to show while [computeRoute]
  /// resolves. Returns an empty set for fewer than 2 points (nothing to draw).
  static Set<Polyline> placeholderPolylines({
    required List<LatLng> points,
    required String polylineId,
    required Color color,
    required int width,
  }) {
    if (points.length < 2) return {};
    return DashedPolylineHelper.createDashedPolylines(
      polylineIdPrefix: polylineId,
      points: points,
      color: color,
      width: width,
    );
  }

  /// Computes the final route: tries the Directions API first, falls back
  /// to a straight-line polyline (`PolylineCodec.encode`) if the API call
  /// fails or returns null. Never throws — API failures are caught and
  /// produce the fallback result, matching both screens' original
  /// catch-and-fallback behavior. Returns an empty polyline set (not the
  /// fallback's own straight line) when the API fails — callers that want
  /// to keep an existing dashed placeholder visible on failure should check
  /// `result.polylines.isEmpty` and retain their own prior polylines in that
  /// case, exactly matching both screens' original behavior of leaving the
  /// dashed placeholder in place when the API call doesn't succeed.
  static Future<RoutePolylineResult> computeRoute({
    required List<LatLng> points,
    required GoogleDirectionsApiClient directionsClient,
    required String polylineId,
    required Color color,
    required int width,
  }) async {
    if (points.length < 2) {
      return const RoutePolylineResult(polylines: {}, encodedPolyline: null);
    }

    try {
      final result = await directionsClient.getRouteWithPoints(points);
      if (result != null) {
        return RoutePolylineResult(
          polylines: {
            Polyline(
              polylineId: PolylineId(polylineId),
              points: result.routePoints,
              color: color,
              width: width,
              geodesic: false,
              startCap: Cap.roundCap,
              endCap: Cap.roundCap,
              jointType: JointType.round,
            ),
          },
          encodedPolyline: result.encodedPolyline,
        );
      }
      return RoutePolylineResult(
        polylines: const {},
        encodedPolyline: PolylineCodec.encode(points),
      );
    } catch (e) {
      return RoutePolylineResult(
        polylines: const {},
        encodedPolyline: PolylineCodec.encode(points),
      );
    }
  }
}
