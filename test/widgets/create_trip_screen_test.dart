import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wanderer_frontend/presentation/screens/create_trip_screen.dart';

void main() {
  group('CreateTripScreen', () {
    testWidgets('automatic updates default on with 15 min interval', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: CreateTripScreen()),
      );
      await tester.pump();

      final toggle = tester.widget<Switch>(find.byType(Switch));
      expect(toggle.value, isTrue);

      expect(find.text('Update Interval (min 15 min)'), findsOneWidget);
      final intervalField = tester.widget<TextField>(
        find.byWidgetPredicate(
          (widget) =>
              widget is TextField && widget.decoration?.suffixText == 'min',
        ),
      );
      expect(intervalField.controller?.text, '15');
    });
  });
}
