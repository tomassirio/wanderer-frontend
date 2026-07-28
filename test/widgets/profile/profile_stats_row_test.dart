import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wanderer_frontend/presentation/widgets/profile/profile_stats_row.dart';

void main() {
  group('ProfileStatsRow Widget', () {
    testWidgets('renders the trips/followers/following/friends counts',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfileStatsRow(
              tripsCount: 3,
              followersCount: 12,
              followingCount: 7,
              friendsCount: 4,
              isViewingOwnProfile: true,
              onFollowersFollowingFriendsTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('3'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.text('Trips'), findsOneWidget);
      expect(find.text('Followers'), findsOneWidget);
      expect(find.text('Following'), findsOneWidget);
      expect(find.text('Friends'), findsOneWidget);
    });

    testWidgets(
        'tapping the followers card invokes the callback when viewing own profile',
        (WidgetTester tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfileStatsRow(
              tripsCount: 3,
              followersCount: 12,
              followingCount: 7,
              friendsCount: 4,
              isViewingOwnProfile: true,
              onFollowersFollowingFriendsTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Followers'));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets(
        'the followers/following/friends cards are not tappable when viewing someone else\'s profile',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfileStatsRow(
              tripsCount: 3,
              followersCount: 12,
              followingCount: 7,
              friendsCount: 4,
              isViewingOwnProfile: false,
              onFollowersFollowingFriendsTap: () {},
            ),
          ),
        ),
      );

      expect(find.byType(InkWell), findsNothing);
    });
  });
}
