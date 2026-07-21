import 'package:shared_preferences/shared_preferences.dart';

/// Tracks first-run onboarding state (e.g. whether a given first-time
/// tutorial has already been shown on this device), keyed by an arbitrary
/// tutorial identifier so multiple independent tutorials can be tracked.
class OnboardingStorage {
  String _keyFor(String tutorialKey) => 'has_seen_tutorial_$tutorialKey';

  Future<bool> hasSeenTutorial(String tutorialKey) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyFor(tutorialKey)) ?? false;
  }

  Future<void> markTutorialSeen(String tutorialKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyFor(tutorialKey), true);
  }

  /// Clears the seen flag for [tutorialKey], so its tutorial shows again.
  Future<void> resetTutorial(String tutorialKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyFor(tutorialKey));
  }
}
