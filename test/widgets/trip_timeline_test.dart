import 'package:flutter_test/flutter_test.dart';
import 'package:wanderer_frontend/core/constants/enums.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/presentation/widgets/trip_detail/trip_timeline.dart';
import 'package:flutter/material.dart';

void main() {
  group('TripTimeline Widget', () {
    testWidgets('shows loading indicator when isLoading is true', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TripTimeline(updates: [], isLoading: true, onRefresh: () {}),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows empty state when no updates', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TripTimeline(updates: [], isLoading: false, onRefresh: () {}),
          ),
        ),
      );

      expect(find.text('No updates yet'), findsOneWidget);
      expect(find.byIcon(Icons.timeline), findsOneWidget);
    });

    testWidgets('displays trip updates in timeline', (
      WidgetTester tester,
    ) async {
      final updates = [
        TripLocation(
          id: 'update-1',
          latitude: 40.7128,
          longitude: -74.0060,
          timestamp: DateTime(2024, 1, 1, 10, 0),
        ),
        TripLocation(
          id: 'update-2',
          latitude: 40.7580,
          longitude: -73.9855,
          timestamp: DateTime(2024, 1, 1, 12, 0),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TripTimeline(
              updates: updates,
              isLoading: false,
              onRefresh: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.location_on), findsNWidgets(2));
    });

    testWidgets('timeline shows correct number of elements', (
      WidgetTester tester,
    ) async {
      final updates = [
        TripLocation(
          id: 'update-1',
          latitude: 40.7128,
          longitude: -74.0060,
          timestamp: DateTime(2024, 1, 1, 10, 0),
        ),
        TripLocation(
          id: 'update-2',
          latitude: 40.7580,
          longitude: -73.9855,
          timestamp: DateTime(2024, 1, 1, 12, 0),
        ),
        TripLocation(
          id: 'update-3',
          latitude: 40.7489,
          longitude: -73.9680,
          timestamp: DateTime(2024, 1, 1, 14, 0),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TripTimeline(
              updates: updates,
              isLoading: false,
              onRefresh: () {},
            ),
          ),
        ),
      );

      // Find timeline indicators (circles)
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.decoration is BoxDecoration &&
              (widget.decoration as BoxDecoration).shape == BoxShape.circle,
        ),
        findsNWidgets(3),
      );
    });

    testWidgets('renders day start marker with sun icon and label', (
      WidgetTester tester,
    ) async {
      final updates = [
        TripLocation(
          id: 'day-start-1',
          latitude: 42.8805,
          longitude: -8.5457,
          timestamp: DateTime(2026, 3, 3, 8, 0),
          updateType: TripUpdateType.dayStart,
          city: 'León',
          country: 'Spain',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TripTimeline(
              updates: updates,
              isLoading: false,
              onRefresh: () {},
            ),
          ),
        ),
      );

      // Lifecycle label should be shown
      expect(find.text('Day Start'), findsOneWidget);
      expect(find.byIcon(Icons.wb_sunny_rounded), findsAtLeastNWidgets(1));
      // Location should still show
      expect(find.text('León, Spain'), findsOneWidget);
    });

    testWidgets('renders day end marker with moon icon and label', (
      WidgetTester tester,
    ) async {
      final updates = [
        TripLocation(
          id: 'day-end-1',
          latitude: 42.8805,
          longitude: -8.5457,
          timestamp: DateTime(2026, 3, 3, 20, 0),
          updateType: TripUpdateType.dayEnd,
          message: 'Good night!',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TripTimeline(
              updates: updates,
              isLoading: false,
              onRefresh: () {},
            ),
          ),
        ),
      );

      // Message replaces the generic label at the top
      expect(find.text('Good night!'), findsOneWidget);
      expect(find.text('Day End'), findsNothing);
      expect(find.byIcon(Icons.nightlight_round), findsAtLeastNWidgets(1));
    });

    testWidgets('renders mixed regular and day marker entries', (
      WidgetTester tester,
    ) async {
      final updates = [
        TripLocation(
          id: 'update-1',
          latitude: 42.8805,
          longitude: -8.5457,
          timestamp: DateTime(2026, 3, 3, 10, 0),
        ),
        TripLocation(
          id: 'day-end-1',
          latitude: 42.8805,
          longitude: -8.5457,
          timestamp: DateTime(2026, 3, 3, 20, 0),
          updateType: TripUpdateType.dayEnd,
        ),
        TripLocation(
          id: 'day-start-2',
          latitude: 42.8805,
          longitude: -8.5457,
          timestamp: DateTime(2026, 3, 4, 8, 0),
          updateType: TripUpdateType.dayStart,
        ),
        TripLocation(
          id: 'update-2',
          latitude: 42.8805,
          longitude: -8.5457,
          timestamp: DateTime(2026, 3, 4, 12, 0),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TripTimeline(
              updates: updates,
              isLoading: false,
              onRefresh: () {},
            ),
          ),
        ),
      );

      // Should show day marker labels
      expect(find.text('Day End'), findsOneWidget);
      expect(find.text('Day Start'), findsOneWidget);
      // Regular entries show location_on icons
      expect(find.byIcon(Icons.location_on), findsAtLeastNWidgets(2));
    });

    testWidgets('day marker does not show regular location row', (
      WidgetTester tester,
    ) async {
      final updates = [
        TripLocation(
          id: 'day-start-1',
          latitude: 42.8805,
          longitude: -8.5457,
          timestamp: DateTime(2026, 3, 3, 8, 0),
          updateType: TripUpdateType.dayStart,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TripTimeline(
              updates: updates,
              isLoading: false,
              onRefresh: () {},
            ),
          ),
        ),
      );

      // Day marker should show label
      expect(find.text('Day Start'), findsOneWidget);
      // Should not show full coordinate display location
      expect(find.text('42.8805, -8.5457'), findsNothing);
    });

    testWidgets('renders trip started marker with flag icon and label', (
      WidgetTester tester,
    ) async {
      final updates = [
        TripLocation(
          id: 'trip-started-1',
          latitude: 42.8805,
          longitude: -8.5457,
          timestamp: DateTime(2026, 3, 1, 10, 0),
          updateType: TripUpdateType.tripStarted,
          city: 'Madrid',
          country: 'Spain',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TripTimeline(
              updates: updates,
              isLoading: false,
              onRefresh: () {},
            ),
          ),
        ),
      );

      expect(find.text('Trip Started'), findsOneWidget);
      expect(find.byIcon(Icons.flag_rounded), findsAtLeastNWidgets(1));
      expect(find.text('Madrid, Spain'), findsOneWidget);
    });

    testWidgets('renders trip ended marker with score icon and label', (
      WidgetTester tester,
    ) async {
      final updates = [
        TripLocation(
          id: 'trip-ended-1',
          latitude: 42.8805,
          longitude: -8.5457,
          timestamp: DateTime(2026, 3, 10, 18, 0),
          updateType: TripUpdateType.tripEnded,
          message: 'What a journey!',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TripTimeline(
              updates: updates,
              isLoading: false,
              onRefresh: () {},
            ),
          ),
        ),
      );

      // Message replaces the generic label at the top
      expect(find.text('What a journey!'), findsOneWidget);
      expect(find.text('Trip Ended'), findsNothing);
      expect(find.byIcon(Icons.sports_score_rounded), findsAtLeastNWidgets(1));
    });
  });
}
