import 'dart:math';
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Helper to create dashed polylines that work on both web and mobile.
///
/// The `google_maps_flutter_web` plugin ignores [PatternItem] patterns,
/// so on the web we manually split the route into alternating dash/gap
/// segments to simulate the dashed look.
class DashedPolylineHelper {
  /// Creates a set of polylines that render as a dashed line.
  ///
  /// On **mobile** this returns a single [Polyline] with [PatternItem] patterns.
  /// On **web** it splits [points] into small segments with gaps in between.
  ///
  /// [polylineIdPrefix] – base id for the polyline(s).
  /// [points] – ordered coordinates of the route.
  /// [color] – stroke colour.
  /// [width] – stroke width in logical pixels.
  /// [dashLength] – length of each visible dash in metres (default 200 m).
  /// [gapLength] – length of each gap in metres (default 100 m).
  static Set<Polyline> createDashedPolylines({
    required String polylineIdPrefix,
    required List<LatLng> points,
    required Color color,
    int width = 4,
    double dashLength = 200,
    double gapLength = 100,
    bool geodesic = false,
  }) {
    if (points.length < 2) return {};

    // On mobile the native pattern support works fine.
    if (!kIsWeb) {
      return {
        Polyline(
          polylineId: PolylineId(polylineIdPrefix),
          points: points,
          color: color,
          width: width,
          patterns: [PatternItem.dash(20), PatternItem.gap(10)],
          geodesic: geodesic,
          visible: true,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          jointType: JointType.round,
        ),
      };
    }

    // --- Web: manually create dash segments ---
    return _buildDashSegments(
      polylineIdPrefix: polylineIdPrefix,
      points: points,
      color: color,
      width: width,
      dashLength: dashLength,
      gapLength: gapLength,
      geodesic: geodesic,
    );
  }

  // ───────────────────── private helpers ─────────────────────

  static Set<Polyline> _buildDashSegments({
    required String polylineIdPrefix,
    required List<LatLng> points,
    required Color color,
    required int width,
    required double dashLength,
    required double gapLength,
    required bool geodesic,
  }) {
    final polylines = <Polyline>{};
    int segmentIndex = 0;
    bool drawing = true; // start with a visible dash
    double remaining = dashLength;

    List<LatLng> currentSegment = [points.first];
    LatLng currentPos = points.first;

    for (int i = 1; i < points.length; i++) {
      LatLng nextPoint = points[i];
      double distToNext = _haversineDistance(currentPos, nextPoint);

      while (distToNext > 0.001) {
        // Use small epsilon to avoid floating point errors
        if (distToNext >= remaining) {
          // Move exactly `remaining` metres along currentPos→nextPoint
          final fraction = remaining / distToNext;
          final intermediate = _interpolate(currentPos, nextPoint, fraction);

          if (drawing) {
            currentSegment.add(intermediate);
            polylines.add(
              Polyline(
                polylineId: PolylineId(
                  '${polylineIdPrefix}_seg_$segmentIndex',
                ),
                points: List.of(currentSegment),
                color: color,
                width: width,
                geodesic: geodesic,
                visible: true,
                startCap: Cap.roundCap,
                endCap: Cap.roundCap,
              ),
            );
            segmentIndex++;
          }

          // Switch between dash ↔ gap
          drawing = !drawing;
          remaining = drawing ? dashLength : gapLength;

          // Update position and remaining distance
          currentPos = intermediate;
          distToNext = _haversineDistance(currentPos, nextPoint);
          currentSegment = [currentPos];
        } else {
          // The remaining edge is shorter than `remaining`
          remaining -= distToNext;
          if (drawing) {
            currentSegment.add(nextPoint);
          }
          currentPos = nextPoint;
          distToNext = 0;
        }
      }
    }

    // Flush last segment if it was a dash
    if (drawing && currentSegment.length >= 2) {
      polylines.add(
        Polyline(
          polylineId: PolylineId(
            '${polylineIdPrefix}_seg_$segmentIndex',
          ),
          points: List.of(currentSegment),
          color: color,
          width: width,
          geodesic: geodesic,
          visible: true,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ),
      );
    }

    return polylines;
  }

  /// Linearly interpolate between [a] and [b] by [fraction] (0..1).
  static LatLng _interpolate(LatLng a, LatLng b, double fraction) {
    return LatLng(
      a.latitude + (b.latitude - a.latitude) * fraction,
      a.longitude + (b.longitude - a.longitude) * fraction,
    );
  }

  /// Haversine distance in **metres** between two coordinates.
  static double _haversineDistance(LatLng a, LatLng b) {
    const earthRadius = 6371000.0; // metres
    final dLat = _toRadians(b.latitude - a.latitude);
    final dLng = _toRadians(b.longitude - a.longitude);
    final sinLat = sin(dLat / 2);
    final sinLng = sin(dLng / 2);
    final h = sinLat * sinLat +
        cos(_toRadians(a.latitude)) *
            cos(_toRadians(b.latitude)) *
            sinLng *
            sinLng;
    return 2 * earthRadius * asin(sqrt(h));
  }

  static double _toRadians(double degrees) => degrees * pi / 180;
}
