import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/presentation/widgets/landing/landing_hero.dart';
import 'package:wanderer_frontend/presentation/widgets/android/android_welcome_artwork.dart';
import 'package:wanderer_frontend/presentation/screens/android/android_welcome_screen.dart';
import 'package:wanderer_frontend/presentation/screens/auth_screen.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pump(WidgetTester tester,
      {Size size = const Size(390, 844),
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

  testWidgets('Account creation is available through login', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('welcome_login')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Create an account'));
    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();
    expect(find.byType(AuthScreen), findsOneWidget);
    expect(find.text('Create your account'), findsOneWidget);
  });

  testWidgets('Sign in opens sign-in with Google on top', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('welcome_login')));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
  });

  testWidgets('uses concise app copy and route artwork with two entry actions',
      (tester) async {
    await pump(tester);
    expect(find.text(AppLocalizations('en').welcomeTitle), findsOneWidget);
    expect(find.text(AppLocalizations('en').welcomeSubtitle), findsOneWidget);
    expect(find.byType(AndroidWelcomeArtwork), findsOneWidget);
    expect(find.byType(LandingProductPreview), findsNothing);
    expect(find.byType(LandingFreeBadge), findsNothing);
    expect(find.text('Log In'), findsOneWidget);
    expect(find.text('Try without logging in'), findsOneWidget);
    expect(find.text('Continue with Google'), findsNothing);
  });

  testWidgets('short screens prioritize copy and actions over artwork',
      (tester) async {
    await pump(tester, size: const Size(320, 480));
    expect(find.byType(AndroidWelcomeArtwork), findsNothing);
    expect(find.text(AppLocalizations('en').welcomeTitle), findsOneWidget);
    expect(
        find.byKey(const Key('welcome_login')).hitTestable(), findsOneWidget);
    expect(
        find.byKey(const Key('welcome_guest')).hitTestable(), findsOneWidget);
  });

  for (final size in [
    const Size(320, 480),
    const Size(390, 844),
    const Size(412, 915),
    const Size(540, 1231),
    const Size(844, 390)
  ]) {
    for (final language in ['en', 'es', 'fr', 'nl']) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('static entry at $size, $language, text scale $scale',
            (tester) async {
          await pump(tester,
              size: size,
              language: language,
              textScale: scale,
              dark: scale > 1);
          final login = find.byKey(const Key('welcome_login'));
          final guest = find.byKey(const Key('welcome_guest'));
          expect(login.hitTestable(), findsOneWidget);
          expect(guest.hitTestable(), findsOneWidget);
          expect(find.byType(Scrollable), findsNothing);
          expect(tester.takeException(), isNull);
          final before = tester.getRect(guest);
          expect(before.bottom, lessThanOrEqualTo(size.height - 24));
          expect(tester.getRect(login).top, greaterThanOrEqualTo(24));
          await tester.drag(
              find.byType(AndroidWelcomeScreen), const Offset(0, -250));
          await tester.pumpAndSettle();
          expect(tester.getRect(guest), before);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
