import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter_test/flutter_test.dart';
import 'package:wanderer_frontend/core/constants/enums.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/presentation/widgets/home/enhanced_trip_card.dart';
import 'package:wanderer_frontend/presentation/widgets/home/trip_grid.dart';

Trip _trip(String id, String userId) {
  final now = DateTime.now();
  return Trip(
    id: id,
    userId: userId,
    name: 'Trip $id',
    username: 'user-$userId',
    visibility: Visibility.public,
    status: TripStatus.inProgress,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('TripGrid Widget', () {
    testWidgets('renders nothing for an empty trip list',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TripGrid(
              trips: const [],
              currentUserId: 'me',
              friendIds: const {},
              followingIds: const {},
              onTripTap: (_) {},
              onDeleteTrip: (_) {},
            ),
          ),
        ),
      );

      expect(find.byType(TripGrid), findsOneWidget);
      expect(find.byType(EnhancedTripCard), findsNothing);
    });

    testWidgets('renders one EnhancedTripCard per trip and forwards taps',
        (WidgetTester tester) async {
      Trip? tapped;
      final trips = [_trip('t1', 'me'), _trip('t2', 'other')];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TripGrid(
              trips: trips,
              currentUserId: 'me',
              friendIds: const {},
              followingIds: const {},
              onTripTap: (trip) => tapped = trip,
              onDeleteTrip: (_) {},
            ),
          ),
        ),
      );

      expect(find.byType(EnhancedTripCard), findsNWidgets(2));

      await tester.tap(find.byKey(const ValueKey('t1')));
      await tester.pump();

      expect(tapped?.id, 't1');
    });
  });
}
