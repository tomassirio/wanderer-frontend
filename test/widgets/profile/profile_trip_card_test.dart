import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter_test/flutter_test.dart';
import 'package:wanderer_frontend/core/constants/enums.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/presentation/widgets/profile/profile_trip_card.dart';

Trip _trip() {
  final now = DateTime.now();
  return Trip(
    id: 't1',
    userId: 'me',
    name: 'Weekend in the Alps',
    username: 'me',
    visibility: Visibility.public,
    status: TripStatus.inProgress,
    createdAt: now,
    updatedAt: now,
    commentsCount: 5,
  );
}

void main() {
  group('ProfileTripCard Widget', () {
    testWidgets(
        'renders the trip name, status, comment count and visibility label',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfileTripCard(
              trip: _trip(),
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Weekend in the Alps'), findsOneWidget);
      expect(find.text('Live'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('Public'), findsOneWidget);
      // Trip.thumbnailUrl always resolves to a (fake) URL, so the mini map
      // starts a network fetch; on this first frame it's still showing its
      // loading placeholder (flutter_test's HttpClient never actually
      // completes it deterministically enough to assert the error state).
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('invokes onTap when tapped', (WidgetTester tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfileTripCard(
              trip: _trip(),
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ProfileTripCard));
      await tester.pump();

      expect(tapped, isTrue);
    });
  });
}
