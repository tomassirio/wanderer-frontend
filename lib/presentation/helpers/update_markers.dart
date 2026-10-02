import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:wanderer_frontend/core/constants/enums.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/data/services/trip_update_service.dart';

/// Sent by the background schedule (it carries the placeholder message).
bool isAutoCheckIn(TripLocation u) =>
    u.updateType == TripUpdateType.regular &&
    u.message == TripUpdateService.automaticUpdateMessage;

/// The six kinds of update on the map, in the timeline and in notifications
/// (canvas: "Map markers"). Each has its own colour and, for the key
/// moments, an icon, so they read without telling colours apart.
enum UpdateKind {
  tripStarted,
  dayStarted,
  checkIn,
  autoCheckIn,
  dayEnded,
  tripFinished;

  /// Start, days and finish stand out; check-ins stay small (a long trip
  /// can have hundreds of automatic ones).
  bool get isKeyMoment => this != checkIn && this != autoCheckIn;

  Color get color => switch (this) {
        tripStarted => const Color(0xFF2F6B4F),
        dayStarted => const Color(0xFFD19A12),
        checkIn || autoCheckIn => const Color(0xFF2F5C8A),
        dayEnded => const Color(0xFF5B4B8A),
        tripFinished => const Color(0xFFB42318),
      };

  IconData? get icon => switch (this) {
        tripStarted => Icons.flag_outlined,
        dayStarted => Icons.wb_sunny_outlined,
        dayEnded => Icons.dark_mode_outlined,
        tripFinished => Icons.sports_score,
        checkIn || autoCheckIn => null,
      };
}

UpdateKind updateKind(TripLocation u) => switch (u.updateType) {
      TripUpdateType.tripStarted => UpdateKind.tripStarted,
      TripUpdateType.dayStart => UpdateKind.dayStarted,
      TripUpdateType.dayEnd => UpdateKind.dayEnded,
      TripUpdateType.tripEnded => UpdateKind.tripFinished,
      TripUpdateType.regular =>
        isAutoCheckIn(u) ? UpdateKind.autoCheckIn : UpdateKind.checkIn,
    };

/// Timeline dot in the marker's look: 18dp for key moments, 14dp for
/// check-ins, auto check-ins hollow.
class UpdateDot extends StatelessWidget {
  final UpdateKind kind;
  const UpdateDot(this.kind, {super.key});

  @override
  Widget build(BuildContext context) {
    final size = kind.isKeyMoment ? 18.0 : 14.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: kind == UpdateKind.autoCheckIn ? Colors.white : kind.color,
        border: Border.all(color: kind.color, width: 3),
      ),
    );
  }
}

/// Map marker bitmaps for every [UpdateKind] plus the selection ring,
/// drawn once at start-up ([init]) so map code can stay synchronous.
class UpdateMarkers {
  UpdateMarkers._();

  static final Map<UpdateKind, BitmapDescriptor> _icons = {};
  static BitmapDescriptor? _ring;

  /// Logical radius of the selection ring bitmap (centre-anchored).
  static const double ringRadius = 40;

  static Future<void> init() async {
    if (_icons.isNotEmpty) return;
    for (final k in UpdateKind.values) {
      _icons[k] = await _draw(radius: _outer(k), paint: (c) => _paint(c, k));
    }
    _ring = await _draw(radius: ringRadius, paint: _paintRing);
  }

  /// Icon for [kind]; the platform pin until [init] has run.
  static BitmapDescriptor icon(UpdateKind kind) =>
      _icons[kind] ?? BitmapDescriptor.defaultMarker;

  static BitmapDescriptor get ring => _ring ?? BitmapDescriptor.defaultMarker;

  static double _outer(UpdateKind k) =>
      (k.isKeyMoment ? 16 : (k == UpdateKind.checkIn ? 9 : 7)) + 2;

  static void _paint(Canvas canvas, UpdateKind k) {
    final r = _outer(k) - 2;
    final fill = Paint()
      ..color = k == UpdateKind.autoCheckIn ? Colors.white : k.color;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = k == UpdateKind.autoCheckIn ? k.color : Colors.white;
    canvas.drawCircle(Offset.zero, r, fill);
    canvas.drawCircle(Offset.zero, r, ring);
    final glyph = _glyph(k);
    if (glyph == null) return;
    // Canvas icons are 24-unit strokes scaled to 0.75 around the centre.
    canvas.save();
    canvas.scale(0.75);
    canvas.translate(-12, -12);
    canvas.drawPath(
      glyph,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.white,
    );
    canvas.restore();
  }

  static void _paintRing(Canvas canvas) {
    const ink = Color(0xFF1B1A17);
    canvas.drawCircle(
        Offset.zero,
        28,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = ink);
    canvas.drawCircle(
        Offset.zero,
        38,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = ink.withValues(alpha: 0.35));
  }

  /// Canvas SVG icons (24×24): flag, sun, moon, checkered flag.
  static Path? _glyph(UpdateKind k) => switch (k) {
        UpdateKind.tripStarted => Path()
          ..moveTo(6, 21)
          ..lineTo(6, 4)
          ..lineTo(16, 4)
          ..lineTo(14, 7)
          ..lineTo(16, 10)
          ..lineTo(6, 10),
        UpdateKind.dayStarted => () {
            final p = Path()
              ..addOval(
                  Rect.fromCircle(center: const Offset(12, 12), radius: 4));
            void ray(double x1, double y1, double x2, double y2) => p
              ..moveTo(x1, y1)
              ..lineTo(x2, y2);
            ray(12, 3, 12, 5);
            ray(12, 19, 12, 21);
            ray(4.2, 4.2, 5.6, 5.6);
            ray(18.4, 18.4, 19.8, 19.8);
            ray(3, 12, 5, 12);
            ray(19, 12, 21, 12);
            ray(4.2, 19.8, 5.6, 18.4);
            ray(18.4, 5.6, 19.8, 4.2);
            return p;
          }(),
        UpdateKind.dayEnded => Path()
          ..moveTo(20, 14.5)
          ..arcToPoint(const Offset(9.5, 4),
              radius: const Radius.circular(8), largeArc: true)
          ..arcToPoint(const Offset(20, 14.5),
              radius: const Radius.circular(6.5), clockwise: false)
          ..close(),
        UpdateKind.tripFinished => Path()
          ..moveTo(6, 21)
          ..lineTo(6, 4)
          ..lineTo(18, 4)
          ..lineTo(18, 11)
          ..lineTo(6, 11)
          ..moveTo(10, 4)
          ..lineTo(10, 11)
          ..moveTo(14, 4)
          ..lineTo(14, 11)
          ..moveTo(6, 7.5)
          ..lineTo(18, 7.5),
        UpdateKind.checkIn || UpdateKind.autoCheckIn => null,
      };

  static Future<BitmapDescriptor> _draw(
      {required double radius, required void Function(Canvas) paint}) async {
    const scale = 3.0; // draw at 3x for sharpness, display at 1x
    final size = (radius * 2 * scale).ceil();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)
      ..translate(size / 2, size / 2)
      ..scale(scale);
    paint(canvas);
    final image = await recorder.endRecording().toImage(size, size);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) return BitmapDescriptor.defaultMarker;
    return BitmapDescriptor.bytes(bytes.buffer.asUint8List(),
        width: size / scale, height: size / scale);
  }
}
