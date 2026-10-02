import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wanderer_frontend/core/constants/api_endpoints.dart';
import 'package:wanderer_frontend/core/constants/enums.dart';
import 'package:wanderer_frontend/core/errors/app_exception.dart';
import 'package:wanderer_frontend/core/providers/app_providers.dart';
import 'package:wanderer_frontend/core/routing/strategies/plan_route_strategy.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/data/models/comment_models.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/data/repositories/auth_repository.dart';
import 'package:wanderer_frontend/data/services/url_shortener_service.dart';
import 'package:wanderer_frontend/presentation/helpers/android_app_links.dart';
import 'package:wanderer_frontend/presentation/screens/android/plan_detail_view.dart';
import 'package:wanderer_frontend/presentation/screens/reset_password_screen.dart';
import 'package:wanderer_frontend/presentation/screens/verify_email_screen.dart';
import 'package:wanderer_frontend/presentation/strategies/trip_detail_layout_strategy.dart';
import 'package:wanderer_frontend/presentation/widgets/android/trip_detail_android_layout.dart';
import 'package:wanderer_frontend/presentation/widgets/mobile_web/app_handoff.dart';
import 'package:wanderer_frontend/presentation/widgets/mobile_web/mobile_web_draft_trip.dart';
import 'package:wanderer_frontend/presentation/widgets/trip_detail/comment_input.dart';
import 'package:wanderer_frontend/presentation/widgets/trip_detail/comments_section.dart';
import 'package:wanderer_frontend/presentation/widgets/trip_detail/trip_share_dialog.dart';
import 'package:wanderer_frontend/presentation/widgets/trip_detail/trip_settings_panel.dart';
import 'package:wanderer_frontend/presentation/widgets/trip_detail/web_trip_detail_layout.dart';
import 'package:wanderer_frontend/presentation/widgets/common/web_sidebar.dart';

class _Shortener extends UrlShortenerService {
  @override
  Future<String?> shorten(String url) async => 'https://example.com/trip';
}

void main() {
  late TextEditingController commentController;
  late ScrollController scrollController;
  late _AuthRepository auth;
  var sent = 0;
  var followed = 0;
  var deleted = 0;
  var routeToggled = 0;
  Visibility? selectedVisibility;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    commentController = TextEditingController();
    scrollController = ScrollController();
    auth = _AuthRepository();
    sent = 0;
    followed = 0;
    deleted = 0;
    routeToggled = 0;
    selectedVisibility = null;
  });
  tearDown(() {
    commentController.dispose();
    scrollController.dispose();
  });

  TripDetailLayoutData data(
          {TripStatus status = TripStatus.inProgress,
          bool owner = true,
          bool planned = false}) =>
      TripDetailLayoutData(
        trip: Trip(
          id: 'coastal-walk',
          userId: 'owner',
          username: 'walker',
          name: 'Coastal walk',
          visibility: Visibility.public,
          status: status,
          automaticUpdates: true,
          updateRefresh: 1200,
          currentDay: 3,
          tripModality: TripModality.multiDay,
          accruedDistanceKm: 42.5,
          commentsCount: 20,
          updateCount: status == TripStatus.created ? 0 : 1,
          startDate: status == TripStatus.created ? null : DateTime(2026, 4, 3),
          createdAt: DateTime(2026, 4, 3),
          updatedAt: DateTime(2026, 4, 5),
          plannedStartLocation:
              planned ? PlannedWaypoint(latitude: 52, longitude: 5) : null,
          plannedEndLocation:
              planned ? PlannedWaypoint(latitude: 53, longitude: 6) : null,
        ),
        comments: List.generate(
            20,
            (i) => Comment(
                  id: 'comment-$i',
                  tripId: 'coastal-walk',
                  userId: 'friend',
                  username: 'friend',
                  message: 'Comment $i',
                  createdAt: DateTime(2026, 4, 5),
                  updatedAt: DateTime(2026, 4, 5),
                )),
        replies: const {},
        expandedComments: const {},
        tripUpdates: status == TripStatus.created
            ? []
            : [
                TripLocation(
                    id: 'update',
                    latitude: 52,
                    longitude: 5,
                    timestamp: DateTime(2026, 4, 5, 12),
                    city: 'Utrecht',
                    country: 'Netherlands'),
              ],
        isLoadingComments: false,
        isLoadingUpdates: false,
        isLoggedIn: true,
        isAddingComment: false,
        isTimelineCollapsed: false,
        isCommentsCollapsed: false,
        isTripInfoCollapsed: false,
        isTripUpdateCollapsed: false,
        isTripSettingsCollapsed: false,
        isSendingUpdate: false,
        sortOption: CommentSortOption.latest,
        commentController: commentController,
        scrollController: scrollController,
        currentUserId: owner ? 'owner' : 'visitor',
        onToggleTripInfo: () {},
        onToggleComments: () {},
        onToggleTimeline: () {},
        onToggleTripUpdate: () {},
        onToggleTripSettings: () {},
        onRefreshTimeline: () {},
        onSortChanged: (_) {},
        onReact: (_) {},
        onReactionChipTap: (_, type) {},
        onReply: (_) {},
        onToggleReplies: (_, expanded) {},
        onSendComment: () => sent++,
        onCancelReply: () {},
        onSendTripUpdate: (_) async {},
        onFollowTripOwner: () => followed++,
        onDeleteTrip: owner ? () => deleted++ : null,
        onVisibilityChange:
            owner ? (value) => selectedVisibility = value : null,
        onTogglePlannedWaypoints: () => routeToggled++,
      );

  Future<void> pump(WidgetTester tester, Widget child,
      {Size size = const Size(390, 844), bool dark = false}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        urlShortenerServiceProvider.overrideWithValue(_Shortener()),
      ],
      child: MaterialApp(
        theme: dark ? WandererTheme.darkTheme() : WandererTheme.lightTheme(),
        home: child,
      ),
    ));
    await tester.pumpAndSettle();
  }

  Widget detail(TripDetailLayoutData d) => Scaffold(
        body: TripDetailAndroidLayout(
          mobileWeb: true,
          data: d,
          map: const ColoredBox(color: Colors.green),
          controls: const Text('native lifecycle controls'),
          onLogin: () {},
          onCheckInTap: (_) {},
        ),
      );

  testWidgets('timeline tap focuses the update; whole route clears it',
      (tester) async {
    TripLocation? focused;
    var whole = 0;
    final d = data(owner: false);
    await pump(
        tester,
        StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: TripDetailAndroidLayout(
              mobileWeb: true,
              data: d,
              map: const ColoredBox(color: Colors.green),
              onLogin: () {},
              onCheckInTap: (_) {},
              focusedUpdate: focused,
              onFocusUpdate: (u) => setState(() => focused = u),
              onWholeRoute: () => setState(() {
                whole++;
                focused = null;
              }),
            ),
          ),
        ),
        size: const Size(412, 915));
    expect(find.byKey(const Key('trip_focus_card')), findsNothing);
    // Same sheet as Android: the Timeline tab opens the list.
    await tester.tap(find.text('Timeline · 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Utrecht, Netherlands').first);
    await tester.pumpAndSettle();
    expect(focused?.id, 'update');
    expect(find.byKey(const Key('trip_focus_card')), findsOneWidget);
    await tester.tap(find.byKey(const Key('trip_whole_route')));
    await tester.pumpAndSettle();
    expect(whole, 1);
    expect(find.byKey(const Key('trip_focus_card')), findsNothing);
  });

  test('trip desktop breakpoint includes the navigation rail', () {
    for (final width in [320.0, 719.0, 720.0, 960.0, 1024.0, 1031.0]) {
      expect(WebTripDetailLayout.fitsViewport(width), isFalse,
          reason: '$width must use the Android-style trip sheet');
    }
    expect(WebTripDetailLayout.minWidth + WebSidebar.railWidth, 1032);
    expect(WebTripDetailLayout.fitsViewport(1032), isTrue);
    expect(WebTripDetailLayout.fitsViewport(1200), isTrue);
  });

  for (final width in [390.0, 720.0, 960.0, 1024.0, 1031.0]) {
    testWidgets('compact trip menus stay usable at ${width}px', (tester) async {
      await pump(tester, detail(data(planned: true)), size: Size(width, 1000));
      expect(find.text('Coastal walk').hitTestable(), findsOneWidget);
      expect(find.text('native lifecycle controls'), findsNothing);
      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      final settings =
          tester.widget<TripSettingsPanel>(find.byType(TripSettingsPanel));
      expect(settings.isOwner, isFalse);
      expect(settings.embedded, isTrue);
      await tester.tap(find.byType(Switch));
      expect(routeToggled, 1);
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      expect(deleted, 1);
      expect(find.byType(BottomSheet), findsNothing);
      await tester.tap(find.text('Comments · 20'));
      await tester.pumpAndSettle();
      expect(find.byType(CommentInput), findsOneWidget);
      expect(find.byType(DraggableScrollableSheet), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('owner without a plan still has a browser-safe settings menu',
      (tester) async {
    await pump(tester, detail(data()), size: const Size(1024, 1000));
    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byType(TripSettingsPanel), findsNothing);
    expect(find.byType(MobileWebTrackingCard), findsNWidgets(2));
    expect(find.byIcon(Icons.delete_outline).hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact share uses the native-style dialog at tablet width',
      (tester) async {
    await pump(tester, detail(data()), size: const Size(1024, 1000));
    await tester.tap(find.byIcon(Icons.share_outlined));
    await tester.pumpAndSettle();
    expect(tester.widget<TripShareDialog>(find.byType(TripShareDialog)).compact,
        isTrue);
    expect(find.byType(Dialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('visibility uses a bottom sheet and forwards the selection',
      (tester) async {
    await pump(tester, detail(data()), size: const Size(1024, 1000));
    await tester.tap(find.text('Public'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    await tester.tap(find.text('Private'));
    await tester.pumpAndSettle();
    expect(selectedVisibility, Visibility.private);
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('desktop trip panels fit at their minimum content width',
      (tester) async {
    await pump(
      tester,
      Scaffold(
          body: WebTripDetailLayout(
        data: data(),
        map: const ColoredBox(color: Colors.green),
      )),
      size: const Size(WebTripDetailLayout.minWidth, 1000),
    );
    expect(find.byType(TripDetailAndroidLayout), findsNothing);
    expect(find.text('Coastal walk'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('Android intent targets are encoded and do not use the SSO scheme', () {
    final trip = AndroidAppLinks.intentUri(tripId: 'trip/#? a');
    expect(trip.scheme, 'intent');
    expect(trip.pathSegments, ['trip', 'trip/#? a']);
    expect(trip.fragment, contains('scheme=wanderer-app;'));
    expect(trip.fragment, contains('package=${AndroidAppLinks.packageName};'));
    expect(trip.fragment,
        contains(Uri.encodeComponent(ApiEndpoints.playStoreUrl)));
    expect(AndroidAppLinks.intentUri(planId: 'plan-1').path, '/plan/plan-1');
    expect(
        PlanRouteStrategy().matches(Uri.parse('wanderer-app:///plan/plan-1')),
        isTrue);
    expect(PlanRouteStrategy().matches(Uri.parse('/plan')), isFalse);
  });

  testWidgets('app banner dismisses without navigating', (tester) async {
    await pump(tester, const Scaffold(body: MobileWebAppBanner()));
    expect(find.text('Wanderer for Android'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.text('Wanderer for Android'), findsNothing);
  });

  for (final size in [const Size(320, 480), const Size(390, 844)]) {
    testWidgets('draft handoff has no map or native Start at $size',
        (tester) async {
      await pump(
          tester, MobileWebDraftTrip(data: data(status: TripStatus.created)),
          size: size);
      expect(find.text('Start this trip in the app'), findsOneWidget);
      expect(find.byKey(const Key('trip_start')), findsNothing);
      expect(find.byType(TripDetailAndroidLayout), findsNothing);
      await tester.scrollUntilVisible(find.text('Copy link'), 250,
          scrollable: find.byType(Scrollable).first);
      expect(find.byType(NavigationDestination), findsNWidgets(4));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'web live sheet exposes timeline and app handoff instead of controls',
      (tester) async {
    await pump(tester, detail(data()));
    expect(find.text('native lifecycle controls'), findsNothing);
    expect(find.byType(MobileWebTrackingCard), findsOneWidget);
    expect(find.text('Days'), findsOneWidget);
    expect(find.text('Comments'), findsOneWidget);
    await tester.tap(find.text('Timeline · 1'));
    await tester.pumpAndSettle();
    expect(find.text('Utrecht, Netherlands').hitTestable(), findsOneWidget);
    expect(find.text('Change'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('public trip follow action remains available', (tester) async {
    await pump(tester, detail(data(status: TripStatus.finished, owner: false)));
    await tester.tap(find.text('Follow @walker'));
    expect(followed, 1);
    expect(find.byType(MobileWebTrackingCard), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'mobile comments composer stays above keyboard while list scrolls',
      (tester) async {
    await pump(tester, detail(data()));
    await tester.tap(find.text('Comments · 20'));
    await tester.pumpAndSettle();
    expect(find.byType(DraggableScrollableSheet), findsNothing);
    expect(find.byType(CommentInput), findsOneWidget);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    final input = tester.getRect(find.byType(CommentInput));
    expect(input.bottom, lessThanOrEqualTo(544));
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(CommentInput)), input);
    await tester.enterText(find.byType(TextField), 'Nice walk!');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();
    expect(sent, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('plan detail remains scrollable on a short mobile browser',
      (tester) async {
    await pump(
        tester,
        AndroidPlanDetailView(
          mobileWeb: true,
          plan: TripPlan(
              id: 'p',
              userId: 'owner',
              name: 'Coastal plan',
              planType: 'MULTI_DAY',
              startDate: DateTime(2026, 4, 3),
              endDate: DateTime(2026, 4, 5),
              startLocation: PlanLocation(lat: 52, lon: 5),
              endLocation: PlanLocation(lat: 53, lon: 6),
              createdTimestamp: DateTime(2026)),
          route: const [],
          map: const Placeholder(),
          onBack: () {},
          onDelete: () {},
          onEdit: () {},
          onStart: () {},
          onFocusStop: (_) {},
        ),
        size: const Size(320, 480));
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Start in app'));
    expect(find.text('Start this trip'), findsNothing);
  });

  testWidgets('reset validates password and submits token with new password',
      (tester) async {
    await pump(tester, const ResetPasswordScreen(token: 'reset-token'));
    await tester.enterText(find.byType(TextFormField), 'weak');
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(auth.password, isNull);
    await tester.enterText(find.byType(TextFormField), 'Secure123!');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(auth.token, 'reset-token');
    expect(auth.password, 'Secure123!');
    expect(find.byType(TextFormField), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reset exposes expired-token response and allows retry',
      (tester) async {
    auth.failure =
        const ApiException(statusCode: 400, apiMessage: 'Expired reset token');
    await pump(tester, const ResetPasswordScreen(token: 'expired'));
    await tester.enterText(find.byType(TextFormField), 'Secure123!');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Expired reset token'), findsOneWidget);
    auth.failure = null;
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsNothing);
  });

  testWidgets('mobile verification success waits for app or browser choice',
      (tester) async {
    if (!kIsWeb) return;
    await pump(
        tester, const VerifyEmailScreen(initialToken: 'verification-token'));
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Email confirmed'), findsOneWidget);
    expect(find.text('Open app'), findsOneWidget);
    expect(find.text('Continue in the browser'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _AuthRepository extends AuthRepository {
  String? token;
  String? password;
  ApiException? failure;

  @override
  Future<void> completePasswordReset(String token, String newPassword) async {
    if (failure != null) throw failure!;
    this.token = token;
    password = newPassword;
  }

  @override
  Future<void> verifyEmail(String token) async {}
}
