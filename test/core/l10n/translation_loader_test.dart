import 'package:flutter_test/flutter_test.dart';
import 'package:wanderer_frontend/core/l10n/translation_loader.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await TranslationLoader.instance.load();
  });

  group('TranslationLoader', () {
    test('loads all four supported locales', () {
      expect(TranslationLoader.instance.isLoaded, isTrue);
    });

    test('returns a flat string for a known key', () {
      expect(TranslationLoader.instance.string('en', 'trips'), 'Trips');
      expect(TranslationLoader.instance.string('es', 'trips'), 'Viajes');
      expect(TranslationLoader.instance.string('fr', 'trips'), 'Voyages');
      expect(TranslationLoader.instance.string('nl', 'trips'), 'Reizen');
    });

    test('falls back to English for an unknown locale', () {
      expect(TranslationLoader.instance.string('xx', 'trips'), 'Trips');
    });

    test('falls back to the key itself for an unknown key', () {
      expect(TranslationLoader.instance.string('en', 'doesNotExist'),
          'doesNotExist');
    });

    test('reads a nested achievement name', () {
      expect(
        TranslationLoader.instance
            .nested('en', 'achievementNames', 'FIRST_TRIP'),
        'First Trip',
      );
      expect(
        TranslationLoader.instance
            .nested('fr', 'achievementNames', 'FIRST_TRIP'),
        'Premier Voyage',
      );
    });

    test('load() is idempotent', () async {
      await TranslationLoader.instance.load();
      expect(TranslationLoader.instance.isLoaded, isTrue);
    });
  });

  group('TranslationTemplate', () {
    test('substitutes a single placeholder', () {
      expect(
        TranslationTemplate.format('{n} minutes ago', {'n': 5}),
        '5 minutes ago',
      );
    });

    test('substitutes multiple placeholders', () {
      expect(
        TranslationTemplate.format(
            'Achievements ({unlocked}/{total})', {'unlocked': 3, 'total': 10}),
        'Achievements (3/10)',
      );
    });

    test('plural() picks the singular form for count == 1', () {
      final result = TranslationTemplate.plural(
          TranslationLoader.instance, 'en', 'tripCountLabel', 1, {'count': 1});
      expect(result, '1 trip');
    });

    test('plural() picks the other form for count != 1', () {
      final result = TranslationTemplate.plural(
          TranslationLoader.instance, 'en', 'tripCountLabel', 3, {'count': 3});
      expect(result, '3 trips');
    });
  });
}
