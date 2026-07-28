import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/presentation/widgets/home/zero_trips_takeover.dart';

void main() {
  group('ZeroTripsTakeover Widget', () {
    testWidgets('renders the CTA copy and create-trip button',
        (WidgetTester tester) async {
      final l10n = AppLocalizations('en');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ZeroTripsTakeover(
              l10n: l10n,
              onCreateTrip: () {},
            ),
          ),
        ),
      );

      expect(find.byType(ZeroTripsTakeover), findsOneWidget);
      expect(find.text(l10n.trackFirstAdventure), findsOneWidget);
      expect(find.text(l10n.createYourFirstTrip), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, l10n.createTrip),
          findsOneWidget);
    });

    testWidgets('invokes onCreateTrip when the button is tapped',
        (WidgetTester tester) async {
      var createTripCalled = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ZeroTripsTakeover(
              l10n: AppLocalizations('en'),
              onCreateTrip: () => createTripCalled = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(createTripCalled, isTrue);
    });
  });
}
