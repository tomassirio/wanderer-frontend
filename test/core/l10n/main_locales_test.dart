import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wanderer_frontend/main.dart' show MyApp;
import 'package:wanderer_frontend/core/l10n/locale_controller.dart';

void main() {
  group('MyApp locale configuration', () {
    testWidgets(
        'MaterialApp supportedLocales should match LocaleController.supportedLocales',
        (WidgetTester tester) async {
      // Build the app
      await tester.pumpWidget(
        const ProviderScope(
          child: MyApp(),
        ),
      );

      // Get all locales from LocaleController
      final expectedLocales = LocaleController.supportedLocales;

      // Verify we have 4 supported locales
      expect(expectedLocales.length, equals(4),
          reason: 'LocaleController.supportedLocales should have 4 locales');

      // Verify all expected language codes are present
      final languageCodes = expectedLocales.map((l) => l.languageCode).toList();
      expect(languageCodes, containsAll(['en', 'es', 'fr', 'nl']),
          reason: 'Should support English, Spanish, French, and Dutch');

      // Verify the MaterialApp is configured with all supported locales
      final materialApp = find.byType(MaterialApp);
      expect(materialApp, findsOneWidget);

      // Get the MaterialApp widget and verify its supportedLocales
      final materialAppWidget = tester.widget<MaterialApp>(materialApp);
      expect(
        materialAppWidget.supportedLocales,
        equals(expectedLocales),
        reason:
            'MaterialApp.supportedLocales should match LocaleController.supportedLocales',
      );
    });

    testWidgets(
        'MyApp should properly render with different locales from LocaleController',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MyApp(),
        ),
      );

      // The app should render without errors
      expect(find.byType(MyApp), findsOneWidget);
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });
}
