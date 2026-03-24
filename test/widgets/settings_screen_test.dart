import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wanderer_frontend/core/theme/theme_controller.dart';
import 'package:wanderer_frontend/presentation/screens/settings_screen.dart';

void main() {
  group('SettingsScreen', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    tearDown(() async {
      // Reset theme to light after each test to prevent state leakage
      await ThemeController().setDarkMode(false);
    });

    Widget buildTestWidget() {
      return const MaterialApp(home: SettingsScreen());
    }

    testWidgets('renders app bar with Settings title', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('renders Account section header', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.text('ACCOUNT'), findsOneWidget);
    });

    testWidgets('renders Change Password option', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.text('Change Password'), findsOneWidget);
      expect(find.text('Update your current password'), findsOneWidget);
    });

    testWidgets('renders Reset Password option', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.text('Reset Password'), findsOneWidget);
      expect(
        find.text('Send a password reset link to your email'),
        findsOneWidget,
      );
    });

    testWidgets('renders Notifications section header', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.text('NOTIFICATIONS'), findsOneWidget);
    });

    testWidgets('renders Push Notifications option', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Push Notifications'), findsOneWidget);
      expect(
        find.textContaining('Receive alerts for friend requests'),
        findsOneWidget,
      );
      expect(find.byType(Switch), findsNWidgets(2));
    });

    testWidgets('renders Support section header', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.text('SUPPORT'), findsOneWidget);
    });

    testWidgets('renders Contact Support option', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.text('Contact Support'), findsOneWidget);
      expect(find.text('Get help via email'), findsOneWidget);
    });

    testWidgets('renders Terms of Service option', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());

      await tester.scrollUntilVisible(
        find.text('Terms of Service'),
        200,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();

      expect(find.text('Terms of Service'), findsOneWidget);
      expect(find.text('Read our terms and conditions'), findsOneWidget);
    });

    testWidgets('renders Privacy Policy option', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());

      await tester.scrollUntilVisible(
        find.text('Privacy Policy'),
        200,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();

      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(find.text('Review our privacy practices'), findsOneWidget);
    });

    testWidgets('renders About section with App Version', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());

      // Scroll down to make About section visible
      await tester.scrollUntilVisible(
        find.text('App Version'),
        200,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();

      expect(find.text('ABOUT'), findsOneWidget);
      expect(find.text('App Version'), findsOneWidget);
    });

    testWidgets('renders Danger Zone section with Close Account', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());

      // Scroll down to make Danger Zone visible
      await tester.scrollUntilVisible(
        find.text('Close Account'),
        200,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();

      expect(find.text('DANGER ZONE'), findsOneWidget);
      expect(find.text('Close Account'), findsOneWidget);
      expect(
        find.text('Permanently delete your account and all data'),
        findsOneWidget,
      );
    });

    testWidgets('renders Account section icons', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());

      // Appearance icon (dark mode)
      expect(find.byIcon(Icons.dark_mode_outlined), findsOneWidget);

      // Account icons
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      expect(find.byIcon(Icons.email_outlined), findsOneWidget);

      // Notifications icon
      expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);

      // Support icons require scrolling since the Appearance section pushed them down
      await tester.scrollUntilVisible(
        find.byIcon(Icons.privacy_tip_outlined),
        200,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.help_outline), findsOneWidget);
      expect(find.byIcon(Icons.description_outlined), findsOneWidget);
      expect(find.byIcon(Icons.privacy_tip_outlined), findsOneWidget);
    });

    testWidgets('renders Danger Zone icon after scrolling', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());

      await tester.scrollUntilVisible(
        find.byIcon(Icons.delete_forever),
        200,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.delete_forever), findsOneWidget);
    });

    testWidgets('tapping Change Password shows dialog', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());

      await tester.tap(find.text('Change Password'));
      await tester.pumpAndSettle();

      expect(find.text('Current Password'), findsOneWidget);
      expect(find.text('New Password'), findsOneWidget);
      expect(find.text('Confirm New Password'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Change'), findsOneWidget);
    });

    testWidgets('tapping Reset Password shows dialog', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());

      await tester.tap(find.text('Reset Password'));
      await tester.pumpAndSettle();

      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Send Reset Link'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('tapping Close Account shows first confirmation dialog', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());

      // Scroll down to Close Account
      await tester.scrollUntilVisible(
        find.text('Close Account'),
        200,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Close Account'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('permanently delete your account'),
        findsOneWidget,
      );
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
    });

    testWidgets('Close Account shows second confirmation after first', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());

      // Scroll down to Close Account
      await tester.scrollUntilVisible(
        find.text('Close Account'),
        200,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Close Account'));
      await tester.pumpAndSettle();

      // Tap Continue on first dialog
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Second dialog should appear
      expect(find.text('Confirm Account Deletion'), findsOneWidget);
      expect(find.text('Type DELETE'), findsOneWidget);
      expect(find.text('Delete My Account'), findsOneWidget);
    });

    testWidgets('Cancel on Change Password dialog dismisses it', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());

      await tester.tap(find.text('Change Password'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Dialog should be dismissed
      expect(find.text('Current Password'), findsNothing);
    });

    testWidgets('Cancel on Reset Password dialog dismisses it', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());

      await tester.tap(find.text('Reset Password'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Dialog should be dismissed
      expect(find.text('Send Reset Link'), findsNothing);
    });

    testWidgets('Cancel on Close Account first dialog dismisses it', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());

      // Scroll down to Close Account
      await tester.scrollUntilVisible(
        find.text('Close Account'),
        200,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Close Account'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Dialog should be dismissed
      expect(
        find.textContaining('permanently delete your account'),
        findsNothing,
      );
    });

    testWidgets('App Version has no chevron_right trailing icon', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());

      // Scroll to App Version
      await tester.scrollUntilVisible(
        find.text('App Version'),
        200,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();

      // Find the ListTile for App Version and verify it has no trailing
      final appVersionTile = find.widgetWithText(ListTile, 'App Version');
      expect(appVersionTile, findsOneWidget);

      final listTile = tester.widget<ListTile>(appVersionTile);
      expect(listTile.trailing, isNull);
    });

    testWidgets('renders Appearance section header', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.text('APPEARANCE'), findsOneWidget);
    });

    testWidgets('renders Dark Mode toggle option', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.text('Dark Mode'), findsOneWidget);
      expect(find.text('Switch between light and dark theme'), findsOneWidget);
    });

    testWidgets('Dark Mode switch starts off when preference is unset', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());

      final switchFinder = find.byType(Switch).first;
      final switchWidget = tester.widget<Switch>(switchFinder);
      expect(switchWidget.value, isFalse);
    });

    testWidgets('Dark Mode switch starts on when preference is set to dark', (
      WidgetTester tester,
    ) async {
      // Pre-set the dark mode preference
      SharedPreferences.setMockInitialValues({'dark_mode_enabled': true});
      await ThemeController().initialize();

      await tester.pumpWidget(buildTestWidget());

      final switchFinder = find.byType(Switch).first;
      final switchWidget = tester.widget<Switch>(switchFinder);
      expect(switchWidget.value, isTrue);
    });

    testWidgets('toggling Dark Mode switch updates state', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());

      final switchFinder = find.byType(Switch).first;
      expect(tester.widget<Switch>(switchFinder).value, isFalse);

      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(tester.widget<Switch>(switchFinder).value, isTrue);
      expect(ThemeController().isDarkMode, isTrue);
    });
  });
}
