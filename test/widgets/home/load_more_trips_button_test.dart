import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wanderer_frontend/presentation/widgets/home/load_more_trips_button.dart';

void main() {
  group('LoadMoreTripsButton Widget', () {
    testWidgets('shows a text button and calls onLoadMore when tapped',
        (WidgetTester tester) async {
      var loadMoreCalled = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoadMoreTripsButton(
              isLoading: false,
              onLoadMore: () => loadMoreCalled = true,
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(TextButton), findsOneWidget);

      await tester.tap(find.byType(TextButton));
      await tester.pump();

      expect(loadMoreCalled, isTrue);
    });

    testWidgets('shows a spinner instead of the button while loading',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoadMoreTripsButton(
              isLoading: true,
              onLoadMore: () {},
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(TextButton), findsNothing);
    });
  });
}
