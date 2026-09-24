import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/data/models/achievement_models.dart';

/// Summary card: trophy, "X of N unlocked", next locked achievement, progress
/// bar and the page's one orange action.
class AchievementsSummaryCard extends StatelessWidget {
  final int unlocked;
  final int total;
  final Achievement? nextUp;
  final VoidCallback onStartTrip;

  const AchievementsSummaryCard({
    super.key,
    required this.unlocked,
    required this.total,
    required this.nextUp,
    required this.onStartTrip,
  });

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    final narrow = MediaQuery.sizeOf(context).width < 900;

    final next = nextUp == null
        ? Text(l10n.achievementsAllUnlocked,
            style: TextStyle(fontSize: 14, color: c.textMuted))
        : Text.rich(
            TextSpan(
              style: TextStyle(fontSize: 14, color: c.textMuted),
              children: [
                TextSpan(text: '${l10n.achievementsNextUp} '),
                TextSpan(
                  text: l10n.achievementNameFor(nextUp!.type.toJson()),
                  style: TextStyle(fontWeight: FontWeight.w700, color: c.text),
                ),
                TextSpan(
                    text:
                        ' — ${l10n.achievementDescriptionFor(nextUp!.type.toJson())}'),
              ],
            ),
          );

    final title = Text(l10n.achievementsUnlockedOf(unlocked, total),
        style: WandererTheme.display(24));

    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (narrow) ...[title, const SizedBox(height: 4), next],
        if (!narrow)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              title,
              const SizedBox(width: 16),
              Expanded(
                child: Align(alignment: Alignment.centerRight, child: next),
              ),
            ],
          ),
        const SizedBox(height: 10),
        _Bar(
          value: total > 0 ? unlocked / total : 0,
          height: 10,
          fill: WandererTheme.trail,
        ),
      ],
    );

    final button = ElevatedButton(
      onPressed: onStartTrip,
      child: Text(l10n.startATrip),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      decoration: WandererTheme.cardDecoration(context),
      child: narrow
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const _Trophy(),
                  const SizedBox(width: 16),
                  Expanded(child: info),
                ]),
                const SizedBox(height: 16),
                button,
              ],
            )
          : Row(children: [
              const _Trophy(),
              const SizedBox(width: 28),
              Expanded(child: info),
              const SizedBox(width: 28),
              button,
            ]),
    );
  }
}

class _Trophy extends StatelessWidget {
  const _Trophy();

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: c.goldBg,
        borderRadius: BorderRadius.circular(WandererTheme.radiusPanel),
      ),
      child: Icon(Icons.emoji_events_outlined, size: 30, color: c.goldFg),
    );
  }
}

/// One category: coloured dot, name, "done / total" pill and a grid of cards.
class AchievementCategorySection extends StatelessWidget {
  final String label;
  final Color color;
  final List<Achievement> achievements;
  final bool Function(Achievement) isUnlocked;
  final String Function(Achievement) hintFor;
  final void Function(Achievement) onTap;
  final bool showCount;

  const AchievementCategorySection({
    super.key,
    required this.label,
    required this.color,
    required this.achievements,
    required this.isUnlocked,
    required this.hintFor,
    required this.onTap,
    required this.showCount,
  });

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    final done = achievements.where(isUnlocked).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Text(label,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700, color: c.text)),
          if (showCount) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                color: c.surface,
                border: Border.all(color: c.line),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text('$done / ${achievements.length}',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: c.textMuted)),
            ),
          ],
        ]),
        const SizedBox(height: 14),
        LayoutBuilder(builder: (context, constraints) {
          final w = constraints.maxWidth;
          final cols = w >= 900
              ? 7
              : w >= 560
                  ? 4
                  : 2;
          final rows = <Widget>[];
          for (var i = 0; i < achievements.length; i += cols) {
            final slice = achievements.sublist(
                i, math.min(i + cols, achievements.length));
            rows.add(IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var j = 0; j < cols; j++) ...[
                    if (j > 0) const SizedBox(width: 12),
                    Expanded(
                      child: j < slice.length
                          ? _AchievementCard(
                              achievement: slice[j],
                              unlocked: isUnlocked(slice[j]),
                              hint: hintFor(slice[j]),
                              onTap: () => onTap(slice[j]),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ));
          }
          return Column(
            children: [
              for (var r = 0; r < rows.length; r++) ...[
                if (r > 0) const SizedBox(height: 12),
                rows[r],
              ],
            ],
          );
        }),
      ],
    );
  }
}

class _AchievementCard extends StatelessWidget {
  final Achievement achievement;
  final bool unlocked;
  final String hint;
  final VoidCallback onTap;

  const _AchievementCard({
    required this.achievement,
    required this.unlocked,
    required this.hint,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    final name = context.l10n.achievementNameFor(achievement.type.toJson());

    final icon = unlocked
        ? Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: c.goldFg, shape: BoxShape.circle),
            child: Icon(Icons.emoji_events, size: 20, color: c.surface),
          )
        : CustomPaint(
            painter: DashedCircle(c.line),
            child: Container(
              width: 44,
              height: 44,
              decoration:
                  BoxDecoration(color: c.ground, shape: BoxShape.circle),
              child: Icon(Icons.lock_outline, size: 18, color: c.caption),
            ),
          );

    return Material(
      color: c.surface,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: c.line),
        borderRadius: BorderRadius.circular(WandererTheme.radiusCard),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 14),
          child: Column(
            children: [
              icon,
              const SizedBox(height: 8),
              Text(name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: c.text)),
              const SizedBox(height: 8),
              Text(hint,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: c.textMuted)),
              const Spacer(),
              const SizedBox(height: 8),
              _Bar(value: unlocked ? 1 : 0, height: 4, fill: c.goldFg),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final double value;
  final double height;
  final Color fill;

  const _Bar({required this.value, required this.height, required this.fill});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        value: value,
        minHeight: height,
        backgroundColor: WandererTheme.of(context).lineSoft,
        valueColor: AlwaysStoppedAnimation(fill),
      ),
    );
  }
}

/// Dashed ring painted around a locked achievement badge.
class DashedCircle extends CustomPainter {
  final Color color;
  final double strokeWidth;
  const DashedCircle(this.color, {this.strokeWidth = 1});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final rect = Offset.zero & size;
    const dashes = 20;
    const sweep = 2 * math.pi / dashes;
    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(
          rect.deflate(strokeWidth / 2), i * sweep, sweep * 0.55, false, paint);
    }
  }

  @override
  bool shouldRepaint(DashedCircle old) =>
      old.color != color || old.strokeWidth != strokeWidth;
}
