import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter_test/flutter_test.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/data/models/achievement_models.dart';
import 'package:wanderer_frontend/presentation/widgets/trip_detail/trip_info_card.dart';
import 'package:wanderer_frontend/core/constants/enums.dart';

void main() {
  group('TripInfoCard Widget', () {
    testWidgets('displays trip information correctly', (
      WidgetTester tester,
    ) async {
      final trip = Trip(
        id: 'trip-1',
        userId: 'user-123',
        name: 'Test Trip',
        username: 'testuser',
        visibility: Visibility.public,
        status: TripStatus.inProgress,
        commentsCount: 5,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TripInfoCard(
              trip: trip,
              isCollapsed: false,
              onToggleCollapse: () {},
            ),
          ),
        ),
      );

      expect(find.text('Test Trip'), findsOneWidget);
      expect(find.text('@testuser'), findsOneWidget);
      expect(find.text('5 Comments'), findsOneWidget);
    });

    testWidgets('username is clickable and has correct styling', (
      WidgetTester tester,
    ) async {
      final trip = Trip(
        id: 'trip-1',
        userId: 'user-123',
        name: 'Test Trip',
        username: 'testuser',
        visibility: Visibility.public,
        status: TripStatus.inProgress,
        commentsCount: 5,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TripInfoCard(
              trip: trip,
              isCollapsed: false,
              onToggleCollapse: () {},
            ),
          ),
        ),
      );

      // Find the username text with @ prefix
      final usernameFinder = find.text('@testuser');
      expect(usernameFinder, findsOneWidget);

      // Verify the username has the clickable styling
      final usernameWidget = tester.widget<Text>(usernameFinder);
      expect(usernameWidget.style?.fontWeight, FontWeight.w600);

      // Verify the username is wrapped in an InkWell (making it tappable)
      final inkWellFinder = find.ancestor(
        of: usernameFinder,
        matching: find.byType(InkWell),
      );
      expect(inkWellFinder, findsOneWidget);
    });

    testWidgets('displays trip description when available', (
      WidgetTester tester,
    ) async {
      final trip = Trip(
        id: 'trip-1',
        userId: 'user-123',
        name: 'Test Trip',
        username: 'testuser',
        description: 'This is a test description',
        visibility: Visibility.public,
        status: TripStatus.inProgress,
        commentsCount: 5,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TripInfoCard(
              trip: trip,
              isCollapsed: false,
              onToggleCollapse: () {},
            ),
          ),
        ),
      );

      expect(find.text('This is a test description'), findsOneWidget);
    });

    testWidgets('displays achievement badges when achievements are provided', (
      WidgetTester tester,
    ) async {
      final trip = Trip(
        id: 'trip-1',
        userId: 'user-123',
        name: 'Test Trip',
        username: 'testuser',
        visibility: Visibility.public,
        status: TripStatus.inProgress,
        commentsCount: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final achievements = [
        UserAchievement(
          id: 'ua-1',
          userId: 'user-123',
          achievement: Achievement(
            id: 'a-1',
            type: AchievementType.distanceOneHundredKm,
            name: 'First Century',
            description: 'Walk 100 kilometers in a single trip',
            thresholdValue: 100,
          ),
          tripId: 'trip-1',
          unlockedAt: DateTime.now(),
          valueAchieved: 100.0,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TripInfoCard(
              trip: trip,
              isCollapsed: false,
              onToggleCollapse: () {},
              tripAchievements: achievements,
            ),
          ),
        ),
      );

      expect(find.text('Achievements Earned'), findsOneWidget);
      expect(find.text('100 km'), findsOneWidget);
    });

    testWidgets('displays share/QR button next to status chip', (
      WidgetTester tester,
    ) async {
      final trip = Trip(
        id: 'trip-1',
        userId: 'user-123',
        name: 'Test Trip',
        username: 'testuser',
        visibility: Visibility.public,
        status: TripStatus.inProgress,
        commentsCount: 5,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TripInfoCard(
              trip: trip,
              isCollapsed: false,
              onToggleCollapse: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.qr_code), findsOneWidget);
    });

    testWidgets('tapping share button opens TripShareDialog', (
      WidgetTester tester,
    ) async {
      final trip = Trip(
        id: 'trip-1',
        userId: 'user-123',
        name: 'Test Trip',
        username: 'testuser',
        visibility: Visibility.public,
        status: TripStatus.inProgress,
        commentsCount: 5,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TripInfoCard(
              trip: trip,
              isCollapsed: false,
              onToggleCollapse: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.qr_code));
      await tester.pump();

      expect(find.text('Share Trip'), findsOneWidget);
    });

    testWidgets('tapping achievement badge shows description dialog', (
      WidgetTester tester,
    ) async {
      final trip = Trip(
        id: 'trip-1',
        userId: 'user-123',
        name: 'Test Trip',
        username: 'testuser',
        visibility: Visibility.public,
        status: TripStatus.inProgress,
        commentsCount: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final achievements = [
        UserAchievement(
          id: 'ua-1',
          userId: 'user-123',
          achievement: Achievement(
            id: 'a-1',
            type: AchievementType.distanceOneHundredKm,
            name: 'First Century',
            description: 'Walk 100 kilometers in a single trip',
            thresholdValue: 100,
          ),
          tripId: 'trip-1',
          unlockedAt: DateTime.now(),
          valueAchieved: 100.0,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TripInfoCard(
              trip: trip,
              isCollapsed: false,
              onToggleCollapse: () {},
              tripAchievements: achievements,
            ),
          ),
        ),
      );

      // Tap on the achievement badge
      await tester.tap(find.text('100 km'));
      await tester.pumpAndSettle();

      // Verify the dialog appears with the description
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        find.text('Walk 100 km in a single trip'),
        findsOneWidget,
      );

      // Dismiss dialog
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
    });
  });
}
