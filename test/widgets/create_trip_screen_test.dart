import 'package:flutter/material.dart' hide Visibility;
import 'package:wanderer_frontend/core/constants/enums.dart';
import 'package:wanderer_frontend/presentation/widgets/android/new_trip_form.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wanderer_frontend/presentation/screens/create_trip_screen.dart';

void main() {
  group('CreateTripScreen', () {
    testWidgets('automatic updates default on with 15 min interval', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: CreateTripScreen()),
        ),
      );
      await tester.pump();

      final toggle = tester.widget<Switch>(find.byType(Switch));
      expect(toggle.value, isTrue);

      final form = tester.widget<NewTripForm>(find.byType(NewTripForm));
      expect(form.automaticUpdates, isTrue);
      expect(form.intervalMinutes, 15);
      expect(form.visibility, Visibility.public);
    });

    testWidgets('picking an interval and Friends updates the form', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: CreateTripScreen()),
        ),
      );
      await tester.pump();
      final form = tester.widget<NewTripForm>(find.byType(NewTripForm));
      form.onIntervalChanged(30);
      form.onVisibilityChanged(Visibility.protected);
      await tester.pump();
      final updated = tester.widget<NewTripForm>(find.byType(NewTripForm));
      expect(updated.intervalMinutes, 30);
      expect(updated.visibility, Visibility.protected);
    });
  });
}
