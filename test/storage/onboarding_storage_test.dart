import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wanderer_frontend/data/storage/onboarding_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OnboardingStorage', () {
    late OnboardingStorage onboardingStorage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      onboardingStorage = OnboardingStorage();
    });

    test('defaults to not having seen a tutorial', () async {
      expect(await onboardingStorage.hasSeenTutorial('home'), false);
    });

    test('returns true after marking a tutorial seen', () async {
      await onboardingStorage.markTutorialSeen('home');

      expect(await onboardingStorage.hasSeenTutorial('home'), true);
    });

    test('persists across a fresh SharedPreferences read', () async {
      await onboardingStorage.markTutorialSeen('home');

      final freshInstance = OnboardingStorage();
      expect(await freshInstance.hasSeenTutorial('home'), true);
    });

    test('tracks each tutorial key independently', () async {
      await onboardingStorage.markTutorialSeen('create_trip');

      expect(await onboardingStorage.hasSeenTutorial('create_trip'), true);
      expect(await onboardingStorage.hasSeenTutorial('trip_detail'), false);
      expect(await onboardingStorage.hasSeenTutorial('home'), false);
    });

    test('returns false after resetting a seen tutorial', () async {
      await onboardingStorage.markTutorialSeen('home');
      await onboardingStorage.resetTutorial('home');

      expect(await onboardingStorage.hasSeenTutorial('home'), false);
    });

    test('resetting one tutorial key does not affect others', () async {
      await onboardingStorage.markTutorialSeen('home');
      await onboardingStorage.markTutorialSeen('create_trip');

      await onboardingStorage.resetTutorial('home');

      expect(await onboardingStorage.hasSeenTutorial('home'), false);
      expect(await onboardingStorage.hasSeenTutorial('create_trip'), true);
    });
  });
}
