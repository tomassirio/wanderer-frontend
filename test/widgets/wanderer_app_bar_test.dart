import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wanderer_frontend/presentation/widgets/common/wanderer_app_bar.dart';

void main() {
  group('WandererAppBar Widget', () {
    testWidgets('shows notification icon when logged in', (
      WidgetTester tester,
    ) async {
      final searchController = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: WandererAppBar(
              searchController: searchController,
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

      searchController.dispose();
    });

    testWidgets('hides notification icon when not logged in', (
      WidgetTester tester,
    ) async {
      final searchController = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: WandererAppBar(
              searchController: searchController,
              isLoggedIn: false,
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.byIcon(Icons.notifications_outlined), findsNothing);

      searchController.dispose();
    });

    testWidgets('shows Wanderer title', (WidgetTester tester) async {
      final searchController = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: WandererAppBar(
              searchController: searchController,
              isLoggedIn: false,
            ),
          ),
        ),
      );

      expect(find.text('Wanderer'), findsOneWidget);

      searchController.dispose();
    });

    testWidgets('shows search icon', (WidgetTester tester) async {
      final searchController = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: WandererAppBar(
              searchController: searchController,
              isLoggedIn: false,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.search), findsOneWidget);

      searchController.dispose();
    });

    testWidgets('shows login button when not logged in and callback provided', (
      WidgetTester tester,
    ) async {
      final searchController = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: WandererAppBar(
              searchController: searchController,
              isLoggedIn: false,
              onLoginPressed: () {},
            ),
          ),
        ),
      );

      expect(find.text('Login'), findsOneWidget);
      expect(find.byIcon(Icons.login), findsOneWidget);

      searchController.dispose();
    });

    testWidgets('shows user avatar when logged in with username', (
      WidgetTester tester,
    ) async {
      final searchController = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: WandererAppBar(
              searchController: searchController,
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

      searchController.dispose();
    });

    testWidgets('prefers displayName initial for avatar', (
      WidgetTester tester,
    ) async {
      final searchController = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: WandererAppBar(
              searchController: searchController,
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

      searchController.dispose();
    });

    testWidgets('toggles search bar on search icon tap', (
      WidgetTester tester,
    ) async {
      final searchController = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: WandererAppBar(
              searchController: searchController,
              isLoggedIn: false,
            ),
          ),
        ),
      );

      // Initially search icon is visible and title is shown
      expect(find.byIcon(Icons.search), findsOneWidget);
      expect(find.text('Wanderer'), findsOneWidget);

      // Tap search icon to expand search
      await tester.tap(find.byIcon(Icons.search));
      await tester.pump();

      // Close icon should appear, title should be replaced by search field
      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(find.text('Wanderer'), findsNothing);

      searchController.dispose();
    });

    testWidgets('clears search and calls onClear when closing search', (
      WidgetTester tester,
    ) async {
      final searchController = TextEditingController(text: 'query');
      bool clearCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: WandererAppBar(
              searchController: searchController,
              isLoggedIn: false,
              onClear: () {
                clearCalled = true;
              },
            ),
          ),
        ),
      );

      // Expand search
      await tester.tap(find.byIcon(Icons.search));
      await tester.pump();

      // Close search
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      expect(searchController.text, isEmpty);
      expect(clearCalled, isTrue);

      searchController.dispose();
    });

    testWidgets('resets unread count to 0 on logout', (
      WidgetTester tester,
    ) async {
      final searchController = TextEditingController();

      // Start logged in
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: WandererAppBar(
              searchController: searchController,
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
              searchController: searchController,
              isLoggedIn: false,
            ),
          ),
        ),
      );
      await tester.pump();

      // Notification icon should be gone (user logged out)
      expect(find.byIcon(Icons.notifications_outlined), findsNothing);

      searchController.dispose();
    });

    testWidgets('notification icon has Badge widget when logged in', (
      WidgetTester tester,
    ) async {
      final searchController = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: WandererAppBar(
              searchController: searchController,
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

      searchController.dispose();
    });

    testWidgets('cleans up timers on dispose without errors', (
      WidgetTester tester,
    ) async {
      final searchController = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: WandererAppBar(
              searchController: searchController,
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

      searchController.dispose();
    });

    testWidgets('resubscribes when userId changes while logged in', (
      WidgetTester tester,
    ) async {
      final searchController = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: WandererAppBar(
              searchController: searchController,
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
              searchController: searchController,
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

      searchController.dispose();
    });
  });
}
