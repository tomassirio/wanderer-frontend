import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wanderer_frontend/core/theme/theme_controller.dart';
import 'package:wanderer_frontend/data/storage/onboarding_storage.dart';
import 'package:wanderer_frontend/presentation/helpers/tutorial_helper.dart';
import 'package:wanderer_frontend/presentation/screens/settings_screen.dart';

/// Creates a fake JWT token with the given roles in its payload.
String _createFakeJwt({List<String> roles = const []}) {
  final header = base64Url.encode(utf8.encode('{"alg":"HS256","typ":"JWT"}'));
  final payload = base64Url.encode(utf8.encode(jsonEncode({'roles': roles})));
  final signature = base64Url.encode(utf8.encode('fake-signature'));
  return '$header.$payload.$signature';
}

/// Tests run with kIsWeb == false, so they cover the Android layout.
void main() {
  group('SettingsScreen (Android)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    tearDown(() async {
      await ThemeController().setDarkMode(false);
    });

    Widget buildTestWidget() {
      return const ProviderScope(
        child: MaterialApp(home: SettingsScreen()),
      );
    }

    Future<void> scrollTo(WidgetTester tester, Finder finder) async {
      await tester.scrollUntilVisible(finder, 200,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
    }

    testWidgets('renders title and section headers', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('APPEARANCE'), findsOneWidget);
      expect(find.text('ACCOUNT'), findsOneWidget);
      expect(find.text('NOTIFICATIONS'), findsOneWidget);
    });

    testWidgets('renders rows from the canvas', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Theme'), findsOneWidget);
      expect(find.text('Language'), findsOneWidget);
      expect(find.text('Change password'), findsOneWidget);
      expect(find.text('Forgot password'), findsOneWidget);
      expect(find.text('Email me a reset link'), findsOneWidget);
      expect(find.text('Push notifications'), findsOneWidget);

      await scrollTo(tester, find.text('Close account'));
      expect(find.text('HELP'), findsOneWidget);
      expect(find.text('Contact support'), findsOneWidget);
      expect(find.text('Terms of service'), findsOneWidget);
      expect(find.text('Privacy policy'), findsOneWidget);
      expect(find.text('Log out'), findsOneWidget);
    });

    testWidgets('theme selector switches to Dark and Auto', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      expect(ThemeController().themeMode.value, ThemeMode.dark);

      await tester.tap(find.text('Auto'));
      await tester.pumpAndSettle();
      expect(ThemeController().themeMode.value, ThemeMode.system);
    });

    testWidgets('tutorials row only for admins', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
      expect(find.text('Show tutorials again'), findsNothing);
    });

    testWidgets('tapping Show tutorials again clears tutorial flags',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'access_token': _createFakeJwt(roles: ['ADMIN']),
      });
      final storage = OnboardingStorage();
      await storage.markTutorialSeen(TutorialKeys.home);

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();
      await scrollTo(tester, find.text('Show tutorials again'));

      await tester.tap(find.text('Show tutorials again'));
      await tester.pumpAndSettle();

      expect(await storage.hasSeenTutorial(TutorialKeys.home), false);
    });

    testWidgets('Change password opens a sheet; save needs matching fields',
        (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Change password'));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text('Current password'), findsOneWidget);
      expect(find.text('New password'), findsOneWidget);
      expect(find.text('Confirm new password'), findsOneWidget);

      ElevatedButton save() => tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Save new password'));
      expect(save().onPressed, isNull);

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'oldpassword');
      await tester.enterText(fields.at(1), 'Wander2027!');
      await tester.pump();
      expect(find.textContaining('Strong'), findsOneWidget);
      await tester.enterText(fields.at(2), 'Wander2027');
      await tester.pump();
      expect(find.text('New passwords do not match'), findsOneWidget);
      expect(save().onPressed, isNull);

      await tester.enterText(fields.at(2), 'Wander2027!');
      await tester.pump();
      expect(save().onPressed, isNotNull);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Current password'), findsNothing);
    });

    testWidgets('Forgot password opens the reset sheet', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Forgot password'));
      await tester.pumpAndSettle();

      expect(find.text('Forgot your password?'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Send reset link'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Send reset link'), findsNothing);
    });

    testWidgets('Close account sheet needs the confirmation typed',
        (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
      await scrollTo(tester, find.text('Close account'));

      await tester.tap(find.text('Close account'));
      await tester.pumpAndSettle();

      expect(find.text('Close your account?'), findsOneWidget);
      ElevatedButton confirm() => tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Close my account forever'));
      expect(confirm().onPressed, isNull);

      // No username stored in tests, so the sheet falls back to DELETE.
      await tester.enterText(find.byType(TextFormField), 'DELETE');
      await tester.pump();
      expect(confirm().onPressed, isNotNull);

      await tester.tap(find.text('Keep my account'));
      await tester.pumpAndSettle();
      expect(find.text('Close your account?'), findsNothing);
    });
  });
}
