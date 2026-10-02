import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/presentation/screens/android/android_welcome_screen.dart';
import 'package:wanderer_frontend/presentation/screens/auth_screen.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  final en = AppLocalizations('en');

  Future<void> pump(WidgetTester tester,
      {Size size = const Size(412, 915),
      String language = 'en',
      double textScale = 1,
      bool dark = false}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final locale = ValueNotifier(Locale(language));
    addTearDown(locale.dispose);
    await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
      theme: dark ? WandererTheme.darkTheme() : WandererTheme.lightTheme(),
      builder: (context, child) => L10nScope(
        notifier: locale,
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
              padding: const EdgeInsets.symmetric(vertical: 24)),
          child: child!,
        ),
      ),
      home: const AndroidWelcomeScreen(),
    )));
    await tester.pumpAndSettle();
  }

  testWidgets('swiping walks the three slides', (tester) async {
    await pump(tester);
    expect(find.text(en.welcomeTitle), findsOneWidget);
    await tester.drag(
        find.byKey(const Key('welcome_slides')), const Offset(-400, 0));
    await tester.pumpAndSettle();
    expect(find.text(en.welcomeSlideFriendsTitle), findsOneWidget);
    await tester.drag(
        find.byKey(const Key('welcome_slides')), const Offset(-400, 0));
    await tester.pumpAndSettle();
    expect(find.text(en.welcomeSlideBadgesTitle), findsOneWidget);
  });

  testWidgets('dots jump to a slide', (tester) async {
    await pump(tester);
    await tester.tap(find.bySemanticsLabel(en.welcomeSlideN(3)));
    await tester.pumpAndSettle();
    expect(find.text(en.welcomeSlideBadgesTitle), findsOneWidget);
  });

  testWidgets('sign up with email opens account creation', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('welcome_signup')));
    await tester.pumpAndSettle();
    expect(find.byType(AuthScreen), findsOneWidget);
    expect(find.text('Create your account'), findsOneWidget);
  });

  testWidgets('I have an account opens sign-in', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('welcome_login')));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
  });

  for (final size in [
    const Size(320, 480),
    const Size(390, 844),
    const Size(412, 915),
    const Size(844, 390),
  ]) {
    for (final language in ['en', 'es', 'fr', 'nl']) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('actions stay reachable at $size, $language, x$scale',
            (tester) async {
          await pump(tester,
              size: size,
              language: language,
              textScale: scale,
              dark: scale > 1);
          for (final key in [
            'welcome_google',
            'welcome_signup',
            'welcome_guest',
            'welcome_login'
          ]) {
            expect(find.byKey(Key(key)).hitTestable(), findsOneWidget,
                reason: key);
          }
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
