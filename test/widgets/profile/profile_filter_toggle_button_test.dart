import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wanderer_frontend/presentation/widgets/profile/profile_filter_toggle_button.dart';

void main() {
  group('ProfileFilterToggleButton Widget', () {
    testWidgets('shows the plain filter icon and no badge when inactive',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfileFilterToggleButton(
              hasActive: false,
              count: 0,
              isPanelOpen: false,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.filter_list_rounded), findsOneWidget);
      expect(find.byIcon(Icons.filter_list_off_rounded), findsNothing);
      expect(find.text('0'), findsNothing);
    });

    testWidgets('shows a count badge when filters are active',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfileFilterToggleButton(
              hasActive: true,
              count: 2,
              isPanelOpen: false,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('2'), findsOneWidget);
    });

    testWidgets(
        'shows the "off" icon when the panel is open, independent of hasActive',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfileFilterToggleButton(
              hasActive: false,
              count: 0,
              isPanelOpen: true,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.filter_list_off_rounded), findsOneWidget);
      expect(find.byIcon(Icons.filter_list_rounded), findsNothing);
    });

    testWidgets('invokes onTap when tapped', (WidgetTester tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfileFilterToggleButton(
              hasActive: false,
              count: 0,
              isPanelOpen: false,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ProfileFilterToggleButton));
      await tester.pump();

      expect(tapped, isTrue);
    });
  });
}
