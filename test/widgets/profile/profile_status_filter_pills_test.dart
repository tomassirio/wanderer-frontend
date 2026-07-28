import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter_test/flutter_test.dart';
import 'package:wanderer_frontend/core/constants/enums.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/presentation/widgets/profile/profile_status_filter_pills.dart';

Trip _trip(String id, TripStatus status) {
  final now = DateTime.now();
  return Trip(
    id: id,
    userId: 'me',
    name: 'Trip $id',
    username: 'user',
    visibility: Visibility.public,
    status: status,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('ProfileStatusFilterPills Widget', () {
    testWidgets('renders one pill per distinct status with its trip count',
        (WidgetTester tester) async {
      final trips = [
        _trip('t1', TripStatus.inProgress),
        _trip('t2', TripStatus.inProgress),
        _trip('t3', TripStatus.finished),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfileStatusFilterPills(
              userTrips: trips,
              selectedStatusFilters: const {},
              onToggleStatus: (_) {},
              onClearAll: () {},
            ),
          ),
        ),
      );

      expect(find.text('Live'), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      // No trips with these statuses -> no pill rendered.
      expect(find.text('Draft'), findsNothing);
      expect(find.text('Paused'), findsNothing);
      // No active filters yet -> no "clear all" row.
      expect(find.text('Clear all filters'), findsNothing);
    });

    testWidgets('tapping a pill invokes onToggleStatus with that status',
        (WidgetTester tester) async {
      TripStatus? toggled;
      final trips = [_trip('t1', TripStatus.inProgress)];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfileStatusFilterPills(
              userTrips: trips,
              selectedStatusFilters: const {},
              onToggleStatus: (status) => toggled = status,
              onClearAll: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.text('Live'));
      await tester.pump();

      expect(toggled, TripStatus.inProgress);
    });

    testWidgets(
        'shows a "clear all filters" row when filters are active, and invokes onClearAll',
        (WidgetTester tester) async {
      var cleared = false;
      final trips = [_trip('t1', TripStatus.inProgress)];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfileStatusFilterPills(
              userTrips: trips,
              selectedStatusFilters: const {TripStatus.inProgress},
              onToggleStatus: (_) {},
              onClearAll: () => cleared = true,
            ),
          ),
        ),
      );

      expect(find.text('Clear all filters'), findsOneWidget);

      await tester.tap(find.text('Clear all filters'));
      await tester.pump();

      expect(cleared, isTrue);
    });
  });
}
