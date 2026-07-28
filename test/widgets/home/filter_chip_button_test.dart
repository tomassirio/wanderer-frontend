import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wanderer_frontend/presentation/widgets/home/filter_chip_button.dart';

void main() {
  group('FilterChipButton Widget', () {
    testWidgets('renders label and icon', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilterChipButton<String>(
              value: null,
              label: 'All Status',
              icon: Icons.all_inclusive,
              iconColor: Colors.grey,
              items: const [
                PopupMenuItem<String>(value: 'a', child: Text('A')),
              ],
              onSelected: (_) {},
            ),
          ),
        ),
      );

      expect(find.byType(FilterChipButton<String>), findsOneWidget);
      expect(find.text('All Status'), findsOneWidget);
      expect(find.byIcon(Icons.all_inclusive), findsOneWidget);
    });

    testWidgets('invokes onSelected when a menu item is chosen',
        (WidgetTester tester) async {
      String? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilterChipButton<String>(
              value: null,
              label: 'All Status',
              icon: Icons.all_inclusive,
              iconColor: Colors.grey,
              items: const [
                PopupMenuItem<String>(value: 'a', child: Text('Option A')),
              ],
              onSelected: (value) => selected = value,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(FilterChipButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Option A'));
      await tester.pumpAndSettle();

      expect(selected, 'a');
    });
  });
}
