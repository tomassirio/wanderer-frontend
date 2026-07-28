import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wanderer_frontend/presentation/state/profile/profile_state.dart';
import 'package:wanderer_frontend/presentation/widgets/profile/profile_sort_dropdown.dart';

void main() {
  group('ProfileSortDropdown Widget', () {
    testWidgets('shows the current sort option label',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfileSortDropdown(
              currentOption: TripSortOption.newestFirst,
              onSelect: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Newest'), findsOneWidget);
    });

    testWidgets(
        'tapping opens a bottom sheet listing every sort option, and selecting one invokes onSelect and closes it',
        (WidgetTester tester) async {
      TripSortOption? selected;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfileSortDropdown(
              currentOption: TripSortOption.newestFirst,
              onSelect: (option) => selected = option,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Newest'));
      await tester.pumpAndSettle();

      expect(find.text('Sort trips by'), findsOneWidget);
      expect(find.text('Name (A-Z)'), findsOneWidget);
      expect(find.text('Oldest'), findsOneWidget);

      await tester.tap(find.text('Name (A-Z)'));
      await tester.pumpAndSettle();

      expect(selected, TripSortOption.nameAsc);
      // Bottom sheet closed after selection.
      expect(find.text('Sort trips by'), findsNothing);
    });
  });
}
