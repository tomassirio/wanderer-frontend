import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';

/// Android plan maps (canvas "New plan" / "Plan detail" / "Edit plan"):
/// small stop dots instead of pins and a dashed planned route.
class PlanMapStyle {
  static BitmapDescriptor? _start, _stop, _finish;

  /// Draws the three dot icons once; call before building markers.
  static Future<void> ensureLoaded() async {
    if (_finish != null) return;
    _start = await _dot(WandererTheme.forest, Colors.white, 20, 4);
    _stop = await _dot(Colors.white, WandererTheme.trail, 12, 3);
    _finish = await _dot(WandererTheme.trail, Colors.white, 22, 4);
  }

  static bool get isLoaded => _finish != null;

  static Future<BitmapDescriptor> _dot(
      Color fill, Color ring, double size, double ringWidth) async {
    const scale = 3.0;
    final px = (size + ringWidth * 2) * scale;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final center = Offset(px / 2, px / 2);
    canvas.drawCircle(center, px / 2, Paint()..color = ring);
    canvas.drawCircle(center, size * scale / 2, Paint()..color = fill);
    final image = await recorder.endRecording().toImage(px.ceil(), px.ceil());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List(),
        imagePixelRatio: scale);
  }

  /// Start (green), numbered stops (white/orange ring) and finish (orange).
  /// Marker ids: 'start', 'waypoint_<1-based>', 'end'.
  static Set<Marker> markers({
    LatLng? start,
    List<LatLng> stops = const [],
    LatLng? finish,
    bool draggable = false,
    void Function(String id)? onTap,
    void Function(String id, LatLng pos)? onDragEnd,
  }) {
    Marker m(String id, LatLng p, BitmapDescriptor? icon, int z) => Marker(
          markerId: MarkerId(id),
          position: p,
          icon: icon ?? BitmapDescriptor.defaultMarker,
          anchor: const Offset(0.5, 0.5),
          zIndexInt: z,
          draggable: draggable,
          consumeTapEvents: true,
          onTap: onTap == null ? null : () => onTap(id),
          onDragEnd: onDragEnd == null ? null : (pos) => onDragEnd(id, pos),
        );
    return {
      for (var i = 0; i < stops.length; i++)
        m('waypoint_${i + 1}', stops[i], _stop, 1),
      if (start != null) m('start', start, _start, 2),
      if (finish != null) m('end', finish, _finish, 2),
    };
  }

  /// Dashed orange planned route (native dash pattern on Android).
  static Set<Polyline> route(List<LatLng> points, {String id = 'plan'}) =>
      points.length < 2
          ? {}
          : {
              Polyline(
                polylineId: PolylineId(id),
                points: points,
                color: WandererTheme.trail,
                width: 4,
                patterns: [PatternItem.dash(18), PatternItem.gap(12)],
                jointType: JointType.round,
              ),
            };

  /// Length of [points] in km.
  static double distanceKm(List<LatLng> points) {
    var m = 0.0;
    for (var i = 1; i < points.length; i++) {
      m += Geolocator.distanceBetween(points[i - 1].latitude,
          points[i - 1].longitude, points[i].latitude, points[i].longitude);
    }
    return m / 1000;
  }

  static String coords(LatLng p) =>
      '${p.latitude.toStringAsFixed(4)}, ${p.longitude.toStringAsFixed(4)}';
}
