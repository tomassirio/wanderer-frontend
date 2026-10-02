import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wanderer_frontend/core/constants/enums.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/providers/app_providers.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/data/models/achievement_models.dart';
import 'package:wanderer_frontend/data/models/domain/user_follow.dart';
import 'package:wanderer_frontend/data/models/domain/user_profile.dart';
import 'package:wanderer_frontend/data/models/notification_models.dart';
import 'package:wanderer_frontend/data/models/responses/page_response.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/data/repositories/home_repository.dart';
import 'package:wanderer_frontend/data/services/achievement_service.dart';
import 'package:wanderer_frontend/data/services/notification_api_service.dart';
import 'package:wanderer_frontend/data/services/user_service.dart';
import 'package:wanderer_frontend/presentation/screens/android/android_home_tab.dart';

PageResponse<T> _page<T>(List<T> items) => PageResponse(
    content: items,
    totalElements: items.length,
    totalPages: 1,
    number: 0,
    size: items.length,
    first: true,
    last: true);

Trip _trip(String id, TripStatus status, {String user = 'me', double? km}) =>
    Trip(
      id: id,
      userId: user,
      name: 'Trip $id',
      username: user,
      visibility: Visibility.public,
      status: status,
      accruedDistanceKm: km,
      startDate: DateTime.now().subtract(const Duration(days: 3)),
      endDate: status == TripStatus.finished ? DateTime.now() : null,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

class _Home extends Fake implements HomeRepository {
  final List<Trip> mine;
  _Home(this.mine);
  @override
  Future<PageResponse<Trip>> getMyTrips({int page = 0, int size = 20}) async =>
      _page(mine);
  @override
  Future<Set<String>> getFriendsIds() async => {'f'};
  @override
  Future<PageResponse<Trip>> loadTrips({int page = 0, int size = 20}) async =>
      _page([_trip('p1', TripStatus.inProgress, user: 'stranger')]);
}

class _Users extends Fake implements UserService {
  @override
  Future<bool> hasProfilePhoto(String userId) async => true;
  @override
  Future<PageResponse<UserFollow>> getFollowing(
          {int page = 0, int size = 20}) async =>
      _page(const <UserFollow>[]);
  @override
  Future<UserProfile> getMyProfile() async => UserProfile(
      id: 'me',
      username: 'ana',
      email: 'a@b.c',
      displayName: 'Ana Ruiz',
      followersCount: 0,
      followingCount: 0,
      tripsCount: 0,
      createdAt: DateTime.now());
}

class _Badges extends Fake implements AchievementService {
  @override
  Future<List<Achievement>> getAllAchievements() async => [
        Achievement(
            id: 'd2200',
            type: AchievementType.distanceTwentyTwoHundredKm,
            name: '2200 km',
            description: '',
            thresholdValue: 2200),
      ];
  @override
  Future<List<UserAchievement>> getMyAchievements() async => const [];
}

class _Notifications extends Fake implements NotificationApiService {
  @override
  Future<int> getUnreadCount() async => 0;
  @override
  Future<PageResponse<NotificationDto>> getMyNotifications(
          {int page = 0, int size = 10}) async =>
      _page([
        NotificationDto(
            id: 'n1',
            recipientId: 'me',
            actorId: 'f',
            type: NotificationType.commentOnTrip,
            referenceId: 't1',
            message: 'julia commented on "Trip t1"',
            read: false,
            createdAt: DateTime.now()),
      ]);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  final en = AppLocalizations('en');

  Future<void> pump(WidgetTester tester, List<Trip> trips) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final locale = ValueNotifier(const Locale('en'));
    addTearDown(locale.dispose);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        homeRepositoryProvider.overrideWithValue(_Home(trips)),
        userServiceProvider.overrideWithValue(_Users()),
        achievementServiceProvider.overrideWithValue(_Badges()),
        notificationApiServiceProvider.overrideWithValue(_Notifications()),
      ],
      child: MaterialApp(
        theme: WandererTheme.lightTheme(),
        builder: (context, child) => L10nScope(notifier: locale, child: child!),
        home: const AndroidHomeTab(),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> scrollTo(WidgetTester tester, String text) =>
      tester.scrollUntilVisible(find.text(text), 200,
          scrollable: find.byType(Scrollable).first);

  testWidgets('brand-new user gets the checklist and a first-trip CTA',
      (tester) async {
    await pump(tester, const []);
    expect(find.text(en.homeWelcomeNew('Ana')), findsOneWidget);
    expect(find.text(en.homeGetStarted), findsOneWidget);
    expect(find.byKey(const Key('home_first_trip')), findsOneWidget);
    await scrollTo(tester, en.homeInvite);
    expect(find.text(en.homeFirstBadge), findsOneWidget);
  });

  testWidgets('no trip running: start / plan, recent trips, friends, badge',
      (tester) async {
    await pump(tester, [_trip('t1', TripStatus.finished, km: 2115)]);
    expect(find.byKey(const Key('home_start_trip')), findsOneWidget);
    expect(find.byKey(const Key('home_plan_trip')), findsOneWidget);
    await scrollTo(tester, en.homeRecentTrips);
    await scrollTo(tester, en.homeFriendsLately);
    await scrollTo(tester, en.homeNextBadge);
    expect(find.text(en.homeToGo('85 km')), findsOneWidget);
    await scrollTo(tester, en.homeTrending);
  });

  testWidgets('trip running: live card first, then the same feed below',
      (tester) async {
    await pump(tester, [
      _trip('t2', TripStatus.inProgress),
      _trip('t1', TripStatus.finished, km: 100),
    ]);
    expect(find.text(en.homeSubtitleLive), findsOneWidget);
    expect(find.byKey(const Key('home_start_trip')), findsNothing);
    await scrollTo(tester, en.homeRecentTrips);
    await scrollTo(tester, en.homeFriendsLately);
    await scrollTo(tester, en.homeNextBadge);
  });

  testWidgets('new account with a trip keeps the checklist, ticked; X hides',
      (tester) async {
    await pump(tester, [_trip('t1', TripStatus.finished, km: 10)]);
    expect(find.text(en.homeGetStarted), findsOneWidget);
    // Account, photo, first trip and friend done; notifications off.
    expect(find.text(en.homeStepsOf(4, 5)), findsOneWidget);
    await tester.tap(find.byKey(const Key('home_checklist_close')));
    await tester.pumpAndSettle();
    expect(find.text(en.homeGetStarted), findsNothing);
  });

}
