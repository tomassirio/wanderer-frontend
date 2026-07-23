import 'package:flutter_test/flutter_test.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/l10n/translation_loader.dart';
import 'package:wanderer_frontend/presentation/helpers/date_format_helper.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await TranslationLoader.instance.load();
  });

  group('DateFormatHelper.formatRelativeDate', () {
    final l10n = AppLocalizations('en');

    test('just now for a date seconds ago', () {
      final date = DateTime.now();
      expect(DateFormatHelper.formatRelativeDate(l10n, date), l10n.justNow);
    });

    test('minutes ago for a date under an hour old', () {
      final date = DateTime.now().subtract(const Duration(minutes: 5));
      expect(DateFormatHelper.formatRelativeDate(l10n, date),
          l10n.minutesAgo(5));
    });

    test('hours ago for a date under a day old', () {
      final date = DateTime.now().subtract(const Duration(hours: 3));
      expect(DateFormatHelper.formatRelativeDate(l10n, date),
          l10n.hoursAgo(3));
    });

    test('days ago for a date under a week old', () {
      final date = DateTime.now().subtract(const Duration(days: 3));
      expect(DateFormatHelper.formatRelativeDate(l10n, date),
          l10n.daysAgo(3));
    });

    test('weeks ago for a date under a month old', () {
      final date = DateTime.now().subtract(const Duration(days: 14));
      expect(DateFormatHelper.formatRelativeDate(l10n, date),
          l10n.weeksAgo(2));
    });

    test('months ago for a date under a year old', () {
      final date = DateTime.now().subtract(const Duration(days: 60));
      expect(DateFormatHelper.formatRelativeDate(l10n, date),
          l10n.monthsAgo(2));
    });

    test('absolute date for anything over a year old', () {
      final date = DateTime(2020, 3, 15);
      expect(
          DateFormatHelper.formatRelativeDate(l10n, date), 'Mar 15, 2020');
    });
  });
}
