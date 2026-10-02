import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:wanderer_frontend/core/constants/enums.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/presentation/helpers/trip_map_helper.dart';
import 'package:wanderer_frontend/presentation/helpers/update_markers.dart';
import 'package:wanderer_frontend/presentation/widgets/common/pill.dart';

/// Android trip map look (canvas AndroidLive / "Map markers"): update
/// markers by kind ([UpdateMarkers]), a haloed dot on the latest spot while
/// live, and the tracked route solid in the trip's colour.
/// Planned routes keep their dashed pattern from [TripMapHelper].
class TripMapDots {
  TripMapDots._();

  static final Map<String, BitmapDescriptor> _cache = {};

  /// Route colour: live blue while moving, trail orange otherwise.
  static Color routeColor(WandererColors c, TripStatus status) =>
      status == TripStatus.inProgress
          ? tripStateColors(c, status).$2
          : WandererTheme.trail;

  /// Restyles [data] built by [TripMapHelper]. Markers that aren't trip
  /// check-ins (planned start/stops/end) are drawn as small hollow dots.
  static Future<MapData> restyle(
      MapData data, Trip trip, WandererColors c) async {
    final route = routeColor(c, trip.status);
    final byId = {
      for (final l in [...?trip.locations]) l.id: l
    };
    final latestLocation = byId.values.isEmpty
        ? null
        : byId.values
            .reduce((a, b) => a.timestamp.isAfter(b.timestamp) ? a : b);
    final live = trip.status == TripStatus.inProgress;

    final planned =
        await _dot(fill: Colors.white, ring: c.restingFg, radius: 4.5);
    final latest =
        await _dot(fill: route, ring: Colors.white, radius: 10, halo: route);

    final markers = data.markers.map((m) {
      final id = m.markerId.value;
      if (id.startsWith('planned_')) {
        return m.copyWith(
            iconParam: planned, anchorParam: const Offset(0.5, 0.5));
      }
      final location = byId[id];
      if (location == null) return m;
      final kind = updateKind(location);
      // While live, the latest check-in is the "you are here" dot.
      final here = live && location == latestLocation && !kind.isKeyMoment;
      return m.copyWith(
        iconParam: here ? latest : UpdateMarkers.icon(kind),
        anchorParam: const Offset(0.5, 0.5),
        zIndexIntParam: here ? 2 : (kind.isKeyMoment ? 1 : 0),
      );
    }).toSet();

    final polylines = data.polylines.map((p) {
      if (p.polylineId.value.startsWith('planned_')) {
        return p.copyWith(colorParam: c.restingFg.withOpacity(0.8));
      }
      return p.copyWith(colorParam: route, widthParam: 5);
    }).toSet();

    return MapData(markers: markers, polylines: polylines);
  }

  static Future<BitmapDescriptor> _dot({
    required Color fill,
    required Color ring,
    required double radius,
    Color? halo,
  }) async {
    final key = '${fill.value}-${ring.value}-$radius-${halo?.value}';
    final cached = _cache[key];
    if (cached != null) return cached;

    const scale = 3.0; // draw at 3x for sharpness, display at 1x
    final outer = halo != null ? radius * 2.2 : radius + 2;
    final size = outer * 2 * scale;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final center = Offset(size / 2, size / 2);
    if (halo != null) {
      canvas.drawCircle(
          center, outer * scale, Paint()..color = halo.withOpacity(0.18));
    }
    final stroke = (radius >= 8 ? 3.0 : 2.5) * scale;
    canvas.drawCircle(center, radius * scale, Paint()..color = fill);
    canvas.drawCircle(
      center,
      radius * scale,
      Paint()
        ..color = ring
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    final image =
        await recorder.endRecording().toImage(size.ceil(), size.ceil());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final icon = bytes == null
        ? BitmapDescriptor.defaultMarker
        : BitmapDescriptor.bytes(bytes.buffer.asUint8List(),
            width: size / scale, height: size / scale);
    return _cache[key] = icon;
  }
}
