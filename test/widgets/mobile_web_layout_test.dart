import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wanderer_frontend/core/constants/enums.dart' show TripStatus;
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/providers/app_providers.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/data/client/api_client.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/data/repositories/auth_repository.dart';
import 'package:wanderer_frontend/data/storage/token_storage.dart';
import 'package:wanderer_frontend/presentation/helpers/adaptive_layout.dart';
import 'package:wanderer_frontend/presentation/helpers/dialog_helper.dart';
import 'package:wanderer_frontend/presentation/screens/android/android_auth_widgets.dart';
import 'package:wanderer_frontend/presentation/screens/android/android_explore_tab.dart';
import 'package:wanderer_frontend/presentation/screens/android/android_shell.dart';
import 'package:wanderer_frontend/presentation/screens/android/android_welcome_screen.dart';
import 'package:wanderer_frontend/presentation/screens/android/profile_android_view.dart';
import 'package:wanderer_frontend/presentation/screens/auth_screen.dart';
import 'package:wanderer_frontend/presentation/screens/create_trip_screen.dart';
import 'package:wanderer_frontend/presentation/screens/initial_screen.dart';
import 'package:wanderer_frontend/presentation/screens/landing_screen.dart';
import 'package:wanderer_frontend/presentation/screens/profile_screen.dart';
import 'package:wanderer_frontend/presentation/screens/settings_screen.dart';
import 'package:wanderer_frontend/presentation/widgets/android/new_trip_form.dart';
import 'package:wanderer_frontend/presentation/widgets/auth/web_auth_layout.dart';
import 'package:wanderer_frontend/presentation/widgets/common/app_sidebar.dart';
import 'package:wanderer_frontend/presentation/widgets/common/pill.dart';
import 'package:wanderer_frontend/presentation/widgets/common/toasts.dart';
import 'package:wanderer_frontend/presentation/widgets/common/wanderer_scaffold.dart';
import 'package:wanderer_frontend/presentation/widgets/landing/landing_hero.dart';
import 'package:wanderer_frontend/presentation/widgets/trip_plans/trip_from_plan_dialog.dart';

void main() {
  late _SessionStorage storage;
  late _AuthRepository auth;
  late _OfflineApiClient api;

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'has_seen_tutorial_create_trip': true,
    });
    PackageInfo.setMockInitialValues(
      appName: 'Wanderer',
      packageName: 'app.wanderer',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
    storage = _SessionStorage();
    auth = _AuthRepository(storage);
    api = _OfflineApiClient();
  });

  Future<void> pump(WidgetTester tester, Widget screen,
      {Size size = const Size(390, 844), bool dark = false}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(Toasts.clear);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        tokenStorageProvider.overrideWithValue(storage),
        authRepositoryProvider.overrideWithValue(auth),
        apiClientQueryProvider.overrideWithValue(api),
        apiClientCommandProvider.overrideWithValue(api),
        apiClientAuthProvider.overrideWithValue(api),
      ],
      child: MaterialApp(
        theme: dark ? WandererTheme.darkTheme() : WandererTheme.lightTheme(),
        builder: (_, child) => ToastHost(child: child!),
        home: screen,
      ),
    ));
    await tester.pumpAndSettle();
  }

  for (final width in [320.0, 390.0, 600.0, 719.0, 720.0, 1200.0]) {
    testWidgets('layout and sidebar agree at ${width}px', (tester) async {
      bool? desktop;
      bool? sidebar;
      await pump(
        tester,
        Builder(builder: (context) {
          desktop = AdaptiveLayout.usesDesktopLayout(context);
          sidebar = WandererScaffold.hasPersistentSidebar(context);
          return const SizedBox();
        }),
        size: Size(width, 844),
      );
      expect(desktop, kIsWeb && width >= 720);
      expect(sidebar, desktop);
    });
  }

  for (final dark in [false, true]) {
    testWidgets(
        'phone entry chooses browser landing or Android welcome (dark: $dark)',
        (tester) async {
      await pump(tester, const InitialScreen(), dark: dark);
      expect(find.byType(AndroidWelcomeScreen),
          kIsWeb ? findsNothing : findsOneWidget);
      expect(
          find.byType(LandingScreen), kIsWeb ? findsOneWidget : findsNothing);
      expect(
          find.text(kIsWeb
              ? 'Every trip, tracked live and shared with your people.'
              : AppLocalizations('en').welcomeTitle),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('short phone welcome offers login without overflow',
      (tester) async {
    await pump(tester, const InitialScreen(), size: const Size(320, 480));
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.byKey(const Key('welcome_login')));
    await tester.tap(find.byKey(const Key('welcome_login')));
    await tester.pumpAndSettle();
    expect(find.byType(AndroidAuthForm), findsOneWidget);
  });

  testWidgets('entry responds to desktop and phone resize', (tester) async {
    await pump(tester, const InitialScreen());
    tester.view.physicalSize = const Size(1200, 900);
    await tester.pumpAndSettle();
    expect(find.byType(LandingScreen), kIsWeb ? findsOneWidget : findsNothing);
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    expect(find.byType(AndroidWelcomeScreen),
        kIsWeb ? findsNothing : findsOneWidget);
    expect(find.byType(LandingScreen), kIsWeb ? findsOneWidget : findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('guest exploration uses the Android explore screen',
      (tester) async {
    await pump(tester, const InitialScreen());
    final guest = kIsWeb
        ? find.text(AppLocalizations('en').explorePublicTrips)
        : find.byKey(const Key('welcome_guest'));
    await tester.ensureVisible(guest);
    await tester.tap(guest);
    await tester.pumpAndSettle();
    expect(find.byType(AndroidExploreTab), findsOneWidget);
  });

  testWidgets('phone login replaces welcome with four-tab shell',
      (tester) async {
    await pump(tester, const InitialScreen());
    await tester.ensureVisible(find.byKey(const Key('welcome_login')));
    await tester.tap(find.byKey(const Key('welcome_login')));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'traveler');
    await tester.enterText(fields.at(1), 'password123');
    await tester.ensureVisible(find.text('Sign In').last);
    await tester.tap(find.text('Sign In').last);
    await tester.pumpAndSettle();

    expect(auth.loginCount, 1);
    expect(find.byType(AndroidShell), findsOneWidget);
    expect(find.byType(AuthScreen), findsNothing);
    expect(find.byType(NavigationDestination), findsNWidgets(4));
    expect(find.byType(AppSidebar), findsNothing);
    await tester.tap(find.byType(NavigationDestination).at(1));
    await tester.pumpAndSettle();
    expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        AndroidTab.trips.index);
    await tester.tap(find.byIcon(Icons.add).last);
    await tester.pumpAndSettle();
    expect(find.text('Trip plan'), findsOneWidget);
    expect(find.text('Trip'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'direct login route uses mobile form and preserves input on resize',
      (tester) async {
    await pump(tester, const AuthScreen());
    expect(find.byType(AndroidAuthForm), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'traveler');
    tester.view.physicalSize = const Size(1200, 900);
    await tester.pumpAndSettle();
    expect(find.byType(WebAuthLayout), kIsWeb ? findsOneWidget : findsNothing);
    expect(find.text('traveler'), findsOneWidget);
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    expect(find.byType(AndroidAuthForm), findsOneWidget);
    expect(find.text('traveler'), findsOneWidget);
  });

  for (final width in [320.0, 390.0, 540.0, 720.0, 1200.0]) {
    testWidgets('web landing shares desktop content at ${width}px',
        (tester) async {
      await pump(tester, const LandingScreen(), size: Size(width, 844));
      expect(find.byType(LandingHeadline), findsOneWidget);
      expect(find.byType(LandingProductPreview), findsOneWidget);
      expect(find.text(AppLocalizations('en').landingHeroSub), findsOneWidget);
      expect(find.text(AppLocalizations('en').landingFeatureSocialTitle),
          findsOneWidget);
      expect(find.text(AppLocalizations('en').featuredTrips), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (width < 720) {
        await tester.ensureVisible(find.text('Log In'));
        await tester.tap(find.text('Log In'));
        await tester.pumpAndSettle();
        expect(find.byType(AndroidAuthForm), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });
  }

  testWidgets('new trip uses Android form without browser auto check-in',
      (tester) async {
    await pump(tester, const CreateTripScreen());
    expect(find.byType(NewTripForm), findsOneWidget);
    expect(find.text('Auto check-in'), kIsWeb ? findsNothing : findsOneWidget);
    expect(find.byType(AppSidebar), findsNothing);
  });

  testWidgets('profile route reuses the Android view', (tester) async {
    await pump(tester, const ProfileScreen(userId: 'traveler'));
    expect(find.byType(ProfileAndroidView), findsOneWidget);
    expect(find.byType(AppSidebar), findsNothing);
  });

  testWidgets('phone settings omit unsupported browser push controls',
      (tester) async {
    await pump(tester, const SettingsScreen());
    expect(find.text('APPEARANCE'), findsOneWidget);
    expect(find.text('Push notifications'),
        kIsWeb ? findsNothing : findsOneWidget);
    await tester.tap(find.text('Change password'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
  });

  testWidgets('logout uses the Android confirmation sheet', (tester) async {
    await pump(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => DialogHelper.showLogoutConfirmation(context),
            child: const Text('logout'),
          ),
        ));
    await tester.tap(find.text('logout'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('plan start uses Android sheet with manual browser check-ins',
      (tester) async {
    TripFromPlanRequest? result;
    await pump(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await TripFromPlanDialog.show(
              context,
              planName: 'Coastal walk',
              planType: 'SIMPLE',
            ),
            child: const Text('start'),
          ),
        ));
    await tester.tap(find.text('start'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byType(Switch), kIsWeb ? findsNothing : findsOneWidget);
    await tester.tap(find.text('Start trip now'));
    await tester.pumpAndSettle();
    expect(result, isNotNull);
    expect(result!.automaticUpdates, isNull);
  });

  testWidgets('status pills use Android paused and resting tones on phones',
      (tester) async {
    await pump(
        tester,
        Builder(
          builder: (context) => Column(children: [
            Pill.status(context, TripStatus.paused),
            Pill.status(context, TripStatus.resting),
          ]),
        ));
    final pills = tester.widgetList<Pill>(find.byType(Pill)).toList();
    expect(pills[0].tone, PillTone.paused);
    expect(pills[1].tone, PillTone.resting);
  });
}

class _SessionStorage extends TokenStorage {
  bool loggedIn = false;

  @override
  Future<bool> isLoggedIn() async => loggedIn;

  @override
  Future<bool> isAccessTokenExpired() async => false;
}

class _AuthRepository extends AuthRepository {
  final _SessionStorage storage;
  int loginCount = 0;

  _AuthRepository(this.storage);

  @override
  Future<void> login(String identifier, String password) async {
    loginCount++;
    storage.loggedIn = true;
  }
}

/// Keep layout/navigation tests deterministic and offline, including error UI.
class _OfflineApiClient extends ApiClient {
  _OfflineApiClient() : super(baseUrl: 'https://example.invalid');

  @override
  Future<http.Response> get(String endpoint,
          {bool requireAuth = false, Map<String, String>? headers}) async =>
      http.Response('{"message":"Offline layout test"}', 503);
}
