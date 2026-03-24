import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Generates colored map marker icons for the web platform.
///
/// On web, [BitmapDescriptor.defaultMarkerWithHue] does not reliably apply
/// the requested hue — all markers render as the default red pin. This class
/// draws pin-shaped markers on a [Canvas], converts them to PNG bytes, and
/// caches the resulting [BitmapDescriptor] for synchronous reuse.
///
/// Call [init] once at app startup (only does work on web). After that, use
/// [markerWithHue] anywhere you would otherwise call
/// `BitmapDescriptor.defaultMarkerWithHue(hue)`.
class WebMarkerGenerator {
  WebMarkerGenerator._();

  static final Map<double, BitmapDescriptor> _cache = {};
  static bool _initialized = false;

  /// Whether pre-generated markers are ready.
  static bool get isInitialized => _initialized;

  /// All hues used across the app.
  static const List<double> _requiredHues = [
    0.0, // Red   — tripEnded / latest location
    30.0, // Orange — regular updates
    60.0, // Yellow — dayStart
    120.0, // Green  — tripStarted / planned start
    240.0, // Blue   — planned waypoints
    270.0, // Violet — dayEnd
  ];

  /// Pre-generates coloured marker images. No-op on native platforms.
  static Future<void> init() async {
    if (!kIsWeb || _initialized) return;

    for (final hue in _requiredHues) {
      _cache[hue] = await _generateMarker(hue);
    }
    _initialized = true;
    debugPrint('WebMarkerGenerator: cached ${_cache.length} marker hues');
  }

  /// Returns a coloured marker for the given [hue].
  ///
  /// On web this returns a Canvas-drawn pin; on native it falls through to the
  /// default platform marker.
  static BitmapDescriptor markerWithHue(double hue) {
    if (!kIsWeb) {
      return BitmapDescriptor.defaultMarkerWithHue(hue);
    }

    // Exact cache hit
    if (_cache.containsKey(hue)) {
      return _cache[hue]!;
    }

    // Find the closest cached hue (should rarely happen)
    if (_cache.isNotEmpty) {
      final closest = _cache.keys.reduce(
        (a, b) => (a - hue).abs() < (b - hue).abs() ? a : b,
      );
      return _cache[closest]!;
    }

    // Fallback if init() was never called
    return BitmapDescriptor.defaultMarker;
  }

  // ---------------------------------------------------------------------------
  // Canvas drawing
  // ---------------------------------------------------------------------------

  static Future<BitmapDescriptor> _generateMarker(double hue) async {
    const double width = 64;
    const double height = 80;
    const double headRadius = 22.0;
    const double innerRadius = 8.0;
    const double headCenterY = 26.0;

    final color = HSVColor.fromAHSV(1.0, hue.clamp(0, 360), 0.9, 0.9).toColor();
    final darkColor =
        HSVColor.fromAHSV(1.0, hue.clamp(0, 360), 1.0, 0.65).toColor();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width, height));
    final cx = width / 2;

    // Shadow
    canvas.drawCircle(
      Offset(cx + 1.5, headCenterY + 1.5),
      headRadius + 2,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    // Pin body (triangle)
    final pinPath = Path()
      ..moveTo(cx - 15, headCenterY + 14)
      ..lineTo(cx, height - 4)
      ..lineTo(cx + 15, headCenterY + 14)
      ..close();
    canvas.drawPath(pinPath, Paint()..color = darkColor);

    // Head circle
    canvas.drawCircle(
        Offset(cx, headCenterY), headRadius, Paint()..color = color);

    // Border
    canvas.drawCircle(
      Offset(cx, headCenterY),
      headRadius,
      Paint()
        ..color = darkColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );

    // Inner white dot
    canvas.drawCircle(
      Offset(cx, headCenterY),
      innerRadius,
      Paint()..color = Colors.white,
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    if (byteData != null) {
      return BitmapDescriptor.bytes(
        byteData.buffer.asUint8List(),
        width: width / 2, // retina-style: half size for sharpness
        height: height / 2,
      );
    }

    return BitmapDescriptor.defaultMarker;
  }
}
