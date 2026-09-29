import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wanderer_frontend/presentation/widgets/profile/other_user_profile_header.dart';
import 'package:wanderer_frontend/presentation/widgets/profile/web_profile_widgets.dart';

void main() {
  var originTaps = 0;

  Future<void> pumpHeader(
    WidgetTester tester, {
    String originLabel = 'Explore',
    bool isFollowing = false,
    bool isFriend = false,
    bool hasSentRequest = false,
    bool followsYou = false,
  }) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: OtherUserProfileHeader(
              originLabel: originLabel,
              onOriginTap: () => originTaps++,
              avatar: const CircleAvatar(child: Text('T')),
              displayName: 'Tomas',
              username: 'tomassirio8',
              stats: const [
                ProfileStat('Trips', 0),
                ProfileStat('Followers', 0),
                ProfileStat('Following', 0),
                ProfileStat('Friends', 0),
              ],
              isFollowing: isFollowing,
              isFriend: isFriend,
              hasSentRequest: hasSentRequest,
              followsYou: followsYou,
              onFollow: () {},
              onFriend: () {},
            ),
          ),
        ),
      ),
    ));
  }

  testWidgets('breadcrumb, Profile title, pill and actions; no own-only UI',
      (tester) async {
    originTaps = 0;
    await pumpHeader(tester);

    expect(find.text('Explore'), findsOneWidget);
    expect(find.text('/'), findsOneWidget);
    expect(find.text('tomassirio8'), findsOneWidget); // second crumb
    expect(find.text('@tomassirio8'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Not connected'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Follow'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Add friend'), findsOneWidget);
    expect(find.byTooltip('More options'), findsOneWidget);

    expect(find.text('Edit Profile'), findsNothing);
    expect(find.text('New Trip'), findsNothing);
    expect(find.textContaining('-'), findsNothing); // no UUID

    await tester.tap(find.text('Explore'));
    expect(originTaps, 1);
  });

  testWidgets('first crumb shows the origin section', (tester) async {
    await pumpHeader(tester, originLabel: 'Friends');
    expect(find.text('Friends'), findsWidgets); // crumb + stat label
    expect(find.text('Explore'), findsNothing);
  });

  testWidgets('relationship pill follows friend > sent > follows you',
      (tester) async {
    await pumpHeader(tester, followsYou: true);
    expect(find.text('Follows you'), findsOneWidget);

    await pumpHeader(tester, followsYou: true, hasSentRequest: true);
    expect(find.text('Request sent'), findsNWidgets(2)); // pill + button
    expect(find.text('Follows you'), findsNothing);

    await pumpHeader(tester, isFriend: true, hasSentRequest: true);
    expect(find.text('Friend'), findsNWidgets(2)); // pill + button
  });

  testWidgets(
      'following state shows Following button; More options has no Follow duplicate',
      (tester) async {
    await pumpHeader(tester, isFollowing: true, isFriend: true);
    expect(find.widgetWithText(ElevatedButton, 'Following'), findsOneWidget);

    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
    expect(find.text('Unfollow'), findsNothing);
    expect(find.text('Follow'), findsNothing);
    expect(find.text('Unfriend'), findsOneWidget);
  });

  testWidgets('empty state names the user', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: PublicTripsEmptyState(username: 'tomassirio8')),
    ));
    expect(
        find.text('tomassirio8 hasn’t shared any trips yet'), findsOneWidget);
    expect(find.textContaining('Follow them to get a notification'),
        findsOneWidget);
  });
}
