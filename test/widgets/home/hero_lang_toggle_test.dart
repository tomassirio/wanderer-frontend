import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wanderer_frontend/presentation/widgets/home/hero_lang_toggle.dart';

void main() {
  group('HeroLangToggle Widget', () {
    testWidgets('renders the current language flag and popup trigger',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HeroLangToggle(),
          ),
        ),
      );

      expect(find.byType(HeroLangToggle), findsOneWidget);
      expect(find.byType(PopupMenuButton<String>), findsOneWidget);
      expect(find.text('EN'), findsOneWidget);
    });

    testWidgets('opens a popup menu with all supported locales when tapped',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HeroLangToggle(),
          ),
        ),
      );

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();

      expect(find.text('EN'), findsWidgets);
      expect(find.text('ES'), findsOneWidget);
      expect(find.text('FR'), findsOneWidget);
      expect(find.text('NL'), findsOneWidget);
    });
  });
}
