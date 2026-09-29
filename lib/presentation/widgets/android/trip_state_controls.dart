import 'package:flutter/material.dart';
import 'package:wanderer_frontend/core/constants/enums.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/presentation/widgets/common/pill.dart';
import 'package:wanderer_frontend/presentation/widgets/common/wanderer_sheet.dart';

/// Android trip state buttons (canvas "Trip controls & states"): one orange
/// main action per state; the others are tinted with the colour of the state
/// they lead to. Rest only shows on multi-day trips.
class TripStateControls extends StatelessWidget {
  final TripStatus status;
  final bool isMultiDay;
  final bool isBusy;
  final VoidCallback onStart;
  final VoidCallback onCheckIn;
  final VoidCallback onPause;
  final VoidCallback onRest;
  final VoidCallback onResume;
  final VoidCallback onContinue;
  final VoidCallback onFinish;

  const TripStateControls({
    super.key,
    required this.status,
    required this.isMultiDay,
    this.isBusy = false,
    required this.onStart,
    required this.onCheckIn,
    required this.onPause,
    required this.onRest,
    required this.onResume,
    required this.onContinue,
    required this.onFinish,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = WandererTheme.of(context);
    Widget tinted(TripStatus target, IconData icon, String label,
        VoidCallback onTap, String key) {
      final (bg, fg) = tripStateColors(c, target);
      return Expanded(
        child: TripSheetButton(
          key: Key(key),
          label: label,
          icon: icon,
          background: bg,
          foreground: fg,
          border: fg.withOpacity(0.2),
          onPressed: isBusy ? null : onTap,
        ),
      );
    }

    Widget main(IconData icon, String label, VoidCallback onTap, String key) =>
        TripSheetButton(
          key: Key(key),
          label: label,
          icon: icon,
          background: WandererTheme.trail,
          foreground: Colors.white,
          onPressed: isBusy ? null : onTap,
        );

    final finish = tinted(TripStatus.finished, Icons.flag_outlined,
        l10n.tripFinishAction, onFinish, 'trip_finish');

    final List<Widget> children = switch (status) {
      TripStatus.created => [
          main(Icons.play_arrow_rounded, l10n.tripStartAction, onStart,
              'trip_start'),
        ],
      TripStatus.inProgress => [
          main(Icons.add_location_alt_outlined, l10n.tripCheckIn, onCheckIn,
              'trip_check_in'),
          Row(children: [
            tinted(TripStatus.paused, Icons.pause_rounded, l10n.pause, onPause,
                'trip_pause'),
            if (isMultiDay) ...[
              const SizedBox(width: 8),
              tinted(TripStatus.resting, Icons.nightlight_round,
                  l10n.tripRestAction, onRest, 'trip_rest'),
            ],
            const SizedBox(width: 8),
            tinted(TripStatus.finished, Icons.flag_outlined, l10n.finish,
                onFinish, 'trip_finish'),
          ]),
        ],
      TripStatus.resting => [
          main(Icons.wb_sunny_outlined, l10n.tripContinueAction, onContinue,
              'trip_continue'),
          Row(children: [finish]),
        ],
      TripStatus.paused => [
          main(Icons.play_arrow_rounded, l10n.tripResumeAction, onResume,
              'trip_resume'),
          Row(children: [finish]),
        ],
      TripStatus.finished => const [],
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          children[i],
        ],
      ],
    );
  }
}

/// 52dp, radius 16 button used in the trip sheet.
class TripSheetButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color background;
  final Color foreground;
  final Color? border;
  final VoidCallback? onPressed;

  const TripSheetButton({
    super.key,
    required this.label,
    this.icon,
    required this.background,
    required this.foreground,
    this.border,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          disabledBackgroundColor: background.withOpacity(0.6),
          disabledForegroundColor: foreground.withOpacity(0.6),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: border == null ? BorderSide.none : BorderSide(color: border!),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}

/// Finish asks once, as a bottom sheet (canvas state "5 · Finish?").
Future<bool> showTripFinishSheet(
  BuildContext context, {
  required String tripName,
  String? stats,
}) async {
  final l10n = context.l10n;
  final c = WandererTheme.of(context);
  final result = await showWandererSheet<bool>(
    context,
    builder: (ctx) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Pill(l10n.tripConfirm, tone: PillTone.completed),
        ),
        const SizedBox(height: 14),
        Text(tripName, style: WandererTheme.display(19, color: c.text)),
        const SizedBox(height: 6),
        Text(
          [
            if (stats != null && stats.isNotEmpty) stats,
            l10n.tripFinishConfirmBody
          ].join(' · '),
          style: TextStyle(fontSize: 13, height: 1.45, color: c.textMuted),
        ),
        const SizedBox(height: 16),
        TripSheetButton(
          key: const Key('trip_finish_confirm'),
          label: l10n.tripFinishAction,
          icon: Icons.flag_outlined,
          background: c.forestFg,
          foreground: c.surface,
          onPressed: () => Navigator.pop(ctx, true),
        ),
        const SizedBox(height: 8),
        TripSheetButton(
          label: l10n.tripKeepGoing,
          background: c.surface,
          foreground: c.text,
          border: c.line,
          onPressed: () => Navigator.pop(ctx, false),
        ),
      ],
    ),
  );
  return result == true;
}
