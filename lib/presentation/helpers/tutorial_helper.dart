import 'package:flutter/material.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/data/storage/onboarding_storage.dart';

export 'package:tutorial_coach_mark/tutorial_coach_mark.dart'
    show ShapeLightFocus, ContentAlign;

/// Central registry of tutorial keys tracked in [OnboardingStorage], so
/// resetting them (e.g. from Settings, for testing) doesn't need to
/// duplicate the raw strings used by each screen.
class TutorialKeys {
  TutorialKeys._();

  static const String home = 'home';
  static const String createTrip = 'create_trip';
  static const String tripDetail = 'trip_detail';

  static const List<String> all = [home, createTrip, tripDetail];
}

/// A single step in a first-time coach-mark tutorial.
class TutorialStep {
  TutorialStep({
    required this.key,
    required this.title,
    required this.description,
    this.shape = ShapeLightFocus.Circle,
    this.radius,
    this.align = ContentAlign.bottom,
  });

  final GlobalKey key;
  final String title;
  final String description;
  final ShapeLightFocus shape;
  final double? radius;
  final ContentAlign align;
}

/// Shows a first-time coach-mark tutorial for [steps], once per device,
/// tracked under [tutorialKey] in [OnboardingStorage]. No-op if the
/// tutorial has already been seen.
Future<void> showFirstTimeTutorial({
  required BuildContext context,
  required String tutorialKey,
  required List<TutorialStep> steps,
}) async {
  if (steps.isEmpty) return;

  final storage = OnboardingStorage();
  if (await storage.hasSeenTutorial(tutorialKey) || !context.mounted) return;

  final targets = steps
      .map(
        (step) => TargetFocus(
          identify: step.key,
          keyTarget: step.key,
          shape: step.shape,
          radius: step.radius,
          contents: [
            TargetContent(
              align: step.align,
              builder: (stepContext, controller) => buildTutorialStepContent(
                context: stepContext,
                title: step.title,
                description: step.description,
                isLast: step == steps.last,
                controller: controller,
              ),
            ),
          ],
        ),
      )
      .toList();

  void markSeen() => storage.markTutorialSeen(tutorialKey);

  TutorialCoachMark(
    targets: targets,
    textSkip: context.l10n.tutorialSkip,
    focusAnimationDuration: const Duration(milliseconds: 200),
    unFocusAnimationDuration: const Duration(milliseconds: 200),
    onSkip: () {
      markSeen();
      return true;
    },
    onFinish: markSeen,
  ).show(context: context);
}

/// Themed content bubble shown for each tutorial step.
Widget buildTutorialStepContent({
  required BuildContext context,
  required String title,
  required String description,
  required bool isLast,
  required TutorialCoachMarkController controller,
}) {
  final l10n = context.l10n;
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          description,
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton(
            onPressed: controller.next,
            child: Text(isLast ? l10n.finish : l10n.tutorialNext),
          ),
        ),
      ],
    ),
  );
}
