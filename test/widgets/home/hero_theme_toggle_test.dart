import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/presentation/widgets/home/hero_theme_toggle.dart';

void main() {
  group('HeroThemeToggle Widget', () {
    testWidgets('renders a single icon button', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HeroThemeToggle(l10n: AppLocalizations('en')),
          ),
        ),
      );

      expect(find.byType(HeroThemeToggle), findsOneWidget);
      expect(find.byType(IconButton), findsOneWidget);
    });

    testWidgets('tapping the button does not throw',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HeroThemeToggle(l10n: AppLocalizations('en')),
          ),
        ),
      );

      await tester.tap(find.byType(IconButton));
      await tester.pump();

      expect(find.byType(HeroThemeToggle), findsOneWidget);
    });
  });
}
