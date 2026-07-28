import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wanderer_frontend/presentation/widgets/profile/profile_action_buttons.dart';

void main() {
  group('ProfileActionButtons Widget', () {
    testWidgets(
        'shows only an edit button and invokes onEdit when viewing own profile',
        (WidgetTester tester) async {
      var editTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfileActionButtons(
              isViewingOwnProfile: true,
              isFollowingUser: false,
              isAlreadyFriends: false,
              hasSentFriendRequest: false,
              onEdit: () => editTapped = true,
              onFollow: () {},
              onSendFriendRequest: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.edit), findsOneWidget);
      expect(find.byIcon(Icons.person_add), findsNothing);

      await tester.tap(find.byIcon(Icons.edit));
      await tester.pump();

      expect(editTapped, isTrue);
    });

    testWidgets(
        'shows follow and friend-request buttons when viewing another profile',
        (WidgetTester tester) async {
      var followTapped = false;
      var friendRequestTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfileActionButtons(
              isViewingOwnProfile: false,
              isFollowingUser: false,
              isAlreadyFriends: false,
              hasSentFriendRequest: false,
              onEdit: () {},
              onFollow: () => followTapped = true,
              onSendFriendRequest: () => friendRequestTapped = true,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.edit), findsNothing);
      expect(find.byIcon(Icons.person_add), findsOneWidget);
      expect(find.byIcon(Icons.person_add_alt), findsOneWidget);

      await tester.tap(find.byIcon(Icons.person_add));
      await tester.pump();
      expect(followTapped, isTrue);

      await tester.tap(find.byIcon(Icons.person_add_alt));
      await tester.pump();
      expect(friendRequestTapped, isTrue);
    });

    testWidgets('shows the already-following/already-friends icon variants',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfileActionButtons(
              isViewingOwnProfile: false,
              isFollowingUser: true,
              isAlreadyFriends: true,
              hasSentFriendRequest: false,
              onEdit: () {},
              onFollow: () {},
              onSendFriendRequest: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.person_remove), findsOneWidget);
      expect(find.byIcon(Icons.people), findsOneWidget);
    });
  });
}
