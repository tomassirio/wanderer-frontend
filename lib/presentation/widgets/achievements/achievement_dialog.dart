import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:wanderer_frontend/core/constants/api_endpoints.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/data/models/achievement_models.dart';
import 'package:wanderer_frontend/presentation/helpers/page_transitions.dart';
import 'package:wanderer_frontend/presentation/helpers/ui_helpers.dart';
import 'package:wanderer_frontend/presentation/screens/create_trip_screen.dart';
import 'package:wanderer_frontend/presentation/widgets/achievements/web_achievements_layout.dart';
import 'package:wanderer_frontend/presentation/widgets/common/pill.dart';
import 'package:wanderer_frontend/presentation/widgets/common/wanderer_dialog.dart';

const _gold = Color(0xFFF5B83D);
const _goldInk = Color(0xFF5B3A00);

/// Localised name of an achievement category ("Getting Started", …).
String achievementCategoryLabel(BuildContext context, String category) {
  final l10n = context.l10n;
  return switch (category) {
    'Getting Started' => l10n.categoryGettingStarted,
    'Distance' => l10n.categoryDistance,
    'Updates' => l10n.categoryUpdates,
    'Duration' => l10n.categoryDuration,
    'Social' => l10n.categorySocial,
    _ => l10n.categoryOther,
  };
}

/// Goal of an achievement with its unit ("100 km", "7 days", …).
String achievementThresholdLabel(BuildContext context, Achievement a) {
  final l10n = context.l10n;
  final type = a.type.toJson();
  final v = a.thresholdValue;
  if (type.startsWith('DISTANCE_')) return l10n.achievementKm(v.toDouble());
  if (type.startsWith('DURATION_')) return l10n.achievementDays(v);
  if (type.startsWith('UPDATES_')) return l10n.achievementUpdatesCount(v);
  if (type.startsWith('FOLLOWERS_')) return l10n.achievementFollowers(v);
  if (type.startsWith('FRIENDS_')) return l10n.achievementFriends(v);
  return '$v';
}

PillTone _categoryTone(String category) => switch (category) {
      'Getting Started' => PillTone.completed,
      'Distance' => PillTone.progress,
      'Updates' => PillTone.promoted,
      'Duration' => PillTone.gold,
      _ => PillTone.neutral,
    };

/// Web achievement detail popup (board "AchievementModal" / "Dialogs").
/// Pass [unlocked] when the user has it; [shareUsername] enables the
/// "Share achievement" button, which copies that user's profile link.
Future<void> showAchievementDialog(
  BuildContext context,
  Achievement achievement, {
  UserAchievement? unlocked,
  String? shareUsername,
}) {
  return WandererDialog.show(
    context,
    builder: (_) => _AchievementDialog(
      achievement: achievement,
      unlocked: unlocked,
      shareUsername: shareUsername,
    ),
  );
}

class _AchievementDialog extends StatelessWidget {
  final Achievement achievement;
  final UserAchievement? unlocked;
  final String? shareUsername;

  const _AchievementDialog({
    required this.achievement,
    required this.unlocked,
    required this.shareUsername,
  });

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    final isUnlocked = unlocked != null;
    final category = achievement.type.category;
    final type = achievement.type.toJson();

    final badge = isUnlocked
        ? Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: _gold,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: _gold.withOpacity(0.35), spreadRadius: 8),
              ],
            ),
            child: const Icon(Icons.emoji_events_outlined,
                size: 38, color: _goldInk),
          )
        : Stack(
            clipBehavior: Clip.none,
            children: [
              CustomPaint(
                painter: DashedCircle(c.label, strokeWidth: 2),
                child: Container(
                  width: 88,
                  height: 88,
                  decoration:
                      BoxDecoration(color: c.surface, shape: BoxShape.circle),
                  child: Icon(Icons.emoji_events_outlined,
                      size: 36, color: c.caption),
                ),
              ),
              Positioned(
                right: -12,
                bottom: 0,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: c.text,
                    shape: BoxShape.circle,
                    border: Border.all(color: c.raised, width: 3),
                  ),
                  child: Icon(Icons.lock, size: 13, color: c.surface),
                ),
              ),
            ],
          );

    final dateLabel = isUnlocked
        ? DateFormat.yMd(Localizations.localeOf(context).toString())
            .format(unlocked!.unlockedAt)
        : null;

    final Widget actions;
    if (!isUnlocked) {
      actions = Row(children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.close),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: () {
              final navigator = Navigator.of(context);
              navigator.pop();
              navigator.push(PageTransitions.slideUp(const CreateTripScreen()));
            },
            child: Text(l10n.startATrip),
          ),
        ),
      ]);
    } else if (shareUsername != null) {
      actions = FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: c.neutralButtonBg,
          foregroundColor: c.neutralButtonFg,
        ),
        onPressed: () {
          Clipboard.setData(ClipboardData(
              text: '${ApiEndpoints.appBaseUrl}/user/'
                  '${Uri.encodeComponent(shareUsername!)}'));
          UiHelpers.showSuccessMessage(
              context, l10n.achievementDialogLinkCopied);
        },
        child: Text(l10n.achievementDialogShare),
      );
    } else {
      actions = OutlinedButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(l10n.close),
      );
    }

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 150,
            decoration: BoxDecoration(
              color: isUnlocked ? c.goldBg : c.raised,
              border: Border(bottom: BorderSide(color: c.lineSoft)),
            ),
            child: Stack(
              children: [
                Center(child: badge),
                Positioned(
                  top: 14,
                  right: 14,
                  child: DialogCloseButton(background: c.surface),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    Pill(achievementCategoryLabel(context, category),
                        tone: _categoryTone(category)),
                    isUnlocked
                        ? Pill(l10n.achievementDialogUnlocked(dateLabel!),
                            tone: PillTone.gold)
                        : Pill(l10n.achievementDialogLocked),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.achievementNameFor(type),
                  textAlign: TextAlign.center,
                  style: WandererTheme.display(26).copyWith(color: c.text),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.achievementDescriptionFor(type),
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(fontSize: 15, height: 1.5, color: c.textMuted),
                ),
                const SizedBox(height: 18),
                if (!isUnlocked) ...[
                  // ponytail: backend has no progress for locked achievements,
                  // so the bar stays empty and only the goal is shown.
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    decoration: BoxDecoration(
                      color: c.raised,
                      borderRadius:
                          BorderRadius.circular(WandererTheme.radiusCard),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(children: [
                          Text(l10n.achievementDialogProgress,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: c.text)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              l10n.goalValue(achievementThresholdLabel(
                                  context, achievement)),
                              textAlign: TextAlign.end,
                              style:
                                  TextStyle(fontSize: 13, color: c.textMuted),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 8),
                        Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: c.neutralBg,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
                actions,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
