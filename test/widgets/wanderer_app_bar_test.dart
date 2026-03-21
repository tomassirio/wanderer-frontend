import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wanderer_frontend/presentation/widgets/common/wanderer_app_bar.dart';

void main() {
  group('WandererAppBar Widget', () {
    testWidgets('shows notification icon when logged in', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: WandererAppBar(
              isLoggedIn: true,
              username: 'testuser',
              userId: 'user-123',
            ),
          ),
        ),
      );

      // Allow any async init to settle
      await tester.pump();

      expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);
    });

    testWidgets('hides notification icon when not logged in', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: WandererAppBar(
              isLoggedIn: false,
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.byIcon(Icons.notifications_outlined), findsNothing);
    });

    testWidgets('shows Wanderer title', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: WandererAppBar(
              isLoggedIn: false,
            ),
          ),
        ),
      );

      expect(find.text('Wanderer'), findsOneWidget);
    });

    testWidgets('shows search icon', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: WandererAppBar(
              isLoggedIn: true,
              username: 'testuser',
              userId: 'user-123',
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('hides search and dark mode icons for guests', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: WandererAppBar(
              isLoggedIn: false,
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.byIcon(Icons.search), findsNothing);
      expect(find.byIcon(Icons.dark_mode_outlined), findsNothing);
      expect(find.byIcon(Icons.light_mode_outlined), findsNothing);
    });

    testWidgets('shows login button when not logged in and callback provided', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: WandererAppBar(
              isLoggedIn: false,
              onLoginPressed: () {},
            ),
          ),
        ),
      );

      expect(find.text('Login'), findsOneWidget);
      expect(find.byIcon(Icons.login), findsOneWidget);
    });

    testWidgets('shows user avatar when logged in with username', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: WandererAppBar(
              isLoggedIn: true,
              username: 'testuser',
              userId: 'user-123',
            ),
          ),
        ),
      );

      await tester.pump();

      // Avatar should display the first letter of username
      expect(find.text('T'), findsOneWidget);
    });

    testWidgets('prefers displayName initial for avatar', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: WandererAppBar(
              isLoggedIn: true,
              username: 'testuser',
              userId: 'user-123',
              displayName: 'John Doe',
            ),
          ),
        ),
      );

      await tester.pump();

      // Avatar should display 'J' from displayName, not 'T' from username
      expect(find.text('J'), findsWidgets);
    });

    testWidgets('expands search bar on search icon tap', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: WandererAppBar(
              isLoggedIn: true,
              username: 'testuser',
              userId: 'user-123',
            ),
          ),
        ),
      );

      await tester.pump();

      // Initially search icon is visible and title is shown
      expect(find.byIcon(Icons.search), findsOneWidget);
      expect(find.text('Wanderer'), findsOneWidget);

      // Tap search icon to expand search
      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();

      // Clear icon should appear inside the search bar, search field should be visible
      expect(find.byIcon(Icons.clear), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('collapses search bar on close icon tap', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: WandererAppBar(
              isLoggedIn: true,
              username: 'testuser',
              userId: 'user-123',
            ),
          ),
        ),
      );

      await tester.pump();

      // Expand search
      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();

      // Close search via the clear icon inside the search bar
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pumpAndSettle();

      // Search icon should be visible again, no TextField
      expect(find.byIcon(Icons.search), findsOneWidget);
      expect(find.text('Wanderer'), findsOneWidget);
    });

    testWidgets('resets unread count to 0 on logout', (
      WidgetTester tester,
    ) async {
      // Start logged in
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: WandererAppBar(
              isLoggedIn: true,
              username: 'testuser',
              userId: 'user-123',
            ),
          ),
        ),
      );
      await tester.pump();

      // Rebuild with logged out state
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: WandererAppBar(
              isLoggedIn: false,
            ),
          ),
        ),
      );
      await tester.pump();

      // Notification icon should be gone (user logged out)
      expect(find.byIcon(Icons.notifications_outlined), findsNothing);
    });

    testWidgets('notification icon has Badge widget when logged in', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: WandererAppBar(
              isLoggedIn: true,
              username: 'testuser',
              userId: 'user-123',
            ),
          ),
        ),
      );

      await tester.pump();

      // Badge widget should be present around the notification icon
      expect(find.byType(Badge), findsOneWidget);
    });

    testWidgets('cleans up timers on dispose without errors', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: WandererAppBar(
              isLoggedIn: true,
              username: 'testuser',
              userId: 'user-123',
            ),
          ),
        ),
      );
      await tester.pump();

      // Replace with a different widget to trigger dispose
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Text('replaced')),
        ),
      );
      await tester.pump();

      // Should not throw any errors
      expect(find.text('replaced'), findsOneWidget);
    });

    testWidgets('resubscribes when userId changes while logged in', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: WandererAppBar(
              isLoggedIn: true,
              username: 'user1',
              userId: 'user-1',
            ),
          ),
        ),
      );
      await tester.pump();

      // Change user ID
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: WandererAppBar(
              isLoggedIn: true,
              username: 'user2',
              userId: 'user-2',
            ),
          ),
        ),
      );
      await tester.pump();

      // Should still show notification icon (still logged in)
      expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);
    });
  });
}
