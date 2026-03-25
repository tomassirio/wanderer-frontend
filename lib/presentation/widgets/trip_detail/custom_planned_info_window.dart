import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';

/// The type of a planned waypoint marker.
enum PlannedWaypointType { start, stop, end }

/// Lightweight data class carrying info about a selected planned waypoint.
class PlannedWaypointInfo {
  final PlannedWaypointType type;
  final LatLng position;

  /// 0-based index for stops (ignored for start/end).
  final int stopIndex;

  const PlannedWaypointInfo({
    required this.type,
    required this.position,
    this.stopIndex = 0,
  });

  String get label {
    switch (type) {
      case PlannedWaypointType.start:
        return 'Planned Start';
      case PlannedWaypointType.end:
        return 'Planned End';
      case PlannedWaypointType.stop:
        return 'Planned Stop ${stopIndex + 1}';
    }
  }

  IconData get icon {
    switch (type) {
      case PlannedWaypointType.start:
        return Icons.trip_origin;
      case PlannedWaypointType.end:
        return Icons.place;
      case PlannedWaypointType.stop:
        return Icons.more_horiz;
    }
  }

  Color get accentColor {
    switch (type) {
      case PlannedWaypointType.start:
        return WandererTheme.mapMarkerStart;
      case PlannedWaypointType.end:
        return WandererTheme.mapMarkerEnd;
      case PlannedWaypointType.stop:
        return const Color(0xFF5C6BC0); // Indigo/blue for waypoints
    }
  }
}

/// A styled info window bubble for planned waypoints, matching the look of
/// [CustomInfoWindow] used for trip updates.
class CustomPlannedInfoWindow extends StatelessWidget {
  final PlannedWaypointInfo waypoint;
  final VoidCallback onClose;

  const CustomPlannedInfoWindow({
    super.key,
    required this.waypoint,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final accent = waypoint.accentColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF2C2C2C) : Colors.white;

    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 260),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withOpacity(0.5), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: accent.withOpacity(isDark ? 0.4 : 0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Colored accent bar at top
            Container(
              height: 4,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
            ),
            // Label row with icon
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: Row(
                children: [
                  Icon(waypoint.icon, size: 16, color: accent),
                  const SizedBox(width: 6),
                  Text(
                    waypoint.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: accent,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            // Coordinates title row
            _buildTitleRow(),
            const SizedBox(height: 6),
            // Divider
            Builder(builder: (ctx) {
              final isDark = Theme.of(ctx).brightness == Brightness.dark;
              return Divider(
                height: 1,
                thickness: 0.5,
                color: isDark
                    ? Colors.white.withOpacity(0.12)
                    : Colors.grey.shade200,
                indent: 14,
                endIndent: 14,
              );
            }),
            const SizedBox(height: 8),
            // Coordinates detail row
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 14,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.5),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${waypoint.position.latitude.toStringAsFixed(4)}, '
                    '${waypoint.position.longitude.toStringAsFixed(4)}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleRow() {
    return Builder(builder: (context) {
      final onSurface = Theme.of(context).colorScheme.onSurface;
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 6, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                waypoint.label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: onSurface,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            GestureDetector(
              onTap: onClose,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.close,
                  size: 18,
                  color: onSurface.withOpacity(0.5),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}
