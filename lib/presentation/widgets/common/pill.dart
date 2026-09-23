import 'package:flutter/material.dart';
import 'package:wanderer_frontend/core/constants/enums.dart' show TripStatus;
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';

/// Colour pairs for [Pill]: status is always a pill (style guide rule 3).
/// Resolved per theme via [WandererColors].
enum PillTone {
  completed,
  progress,
  promoted,
  gold,
  neutral,

  /// Pill over maps and images (white in light mode, Night in dark).
  onImage;

  (Color, Color) colors(WandererColors c) => switch (this) {
        PillTone.completed => (c.forestBg, c.forestFg),
        PillTone.progress => (c.skyBg, c.skyFg),
        PillTone.promoted => (c.trailSoftBg, c.trailSoftFg),
        PillTone.gold => (c.goldBg, c.goldFg),
        PillTone.neutral => (c.neutralBg, c.neutralFg),
        PillTone.onImage => (c.overlayPillBg, c.text),
      };
}

/// Rounded status/label badge from the web style guide.
class Pill extends StatelessWidget {
  final String label;
  final PillTone tone;
  final IconData? icon;

  /// Text colour taken from another tone (e.g. green text on an image pill).
  final PillTone? foregroundTone;

  const Pill(this.label,
      {super.key,
      this.tone = PillTone.neutral,
      this.icon,
      this.foregroundTone});

  /// Pill for a trip's status (green completed, blue in progress, …).
  factory Pill.status(BuildContext context, TripStatus status,
      {bool onImage = false}) {
    final l10n = context.l10n;
    final (label, tone, icon) = switch (status) {
      TripStatus.finished => (l10n.completed, PillTone.completed, Icons.check),
      TripStatus.inProgress => (l10n.live, PillTone.progress, null),
      TripStatus.paused => (l10n.paused, PillTone.gold, Icons.pause),
      TripStatus.resting => (
          l10n.resting,
          PillTone.neutral,
          Icons.nightlight_round
        ),
      TripStatus.created => (l10n.draft, PillTone.neutral, Icons.schedule),
    };
    return Pill(
      label,
      tone: onImage ? PillTone.onImage : tone,
      foregroundTone: onImage ? tone : null,
      icon: icon,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    final (bg, toneFg) = tone.colors(c);
    final fg = foregroundTone?.colors(c).$2 ?? toneFg;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
