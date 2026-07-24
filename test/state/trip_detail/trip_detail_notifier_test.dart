import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:wanderer_frontend/core/constants/enums.dart';
import 'package:wanderer_frontend/core/providers/app_providers.dart';
import 'package:wanderer_frontend/data/client/query/promotion_query_client.dart';
import 'package:wanderer_frontend/data/models/responses/page_response.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/data/models/user_models.dart';
import 'package:wanderer_frontend/data/repositories/trip_detail_repository.dart';
import 'package:wanderer_frontend/data/services/achievement_service.dart';
import 'package:wanderer_frontend/data/services/user_service.dart';
import 'package:wanderer_frontend/presentation/state/trip_detail/trip_detail_notifier.dart';
import 'package:wanderer_frontend/presentation/state/trip_detail/trip_detail_state.dart';

import 'trip_detail_notifier_test.mocks.dart';

@GenerateMocks(
    [TripDetailRepository, PromotionQueryClient, AchievementService, UserService])
void main() {
  late MockTripDetailRepository mockRepository;
  late MockPromotionQueryClient mockPromotionClient;
  late MockAchievementService mockAchievementService;
  late MockUserService mockUserService;
  late Trip trip;

  setUp(() {
    mockRepository = MockTripDetailRepository();
    mockPromotionClient = MockPromotionQueryClient();
    mockAchievementService = MockAchievementService();
    mockUserService = MockUserService();
    trip = Trip(
      id: 'trip-1',
      userId: 'owner-1',
      username: 'owner',
      name: 'Test Trip',
      status: TripStatus.created,
      visibility: Visibility.public,
      tripModality: TripModality.simple,
      automaticUpdates: false,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
  });

  ProviderContainer buildContainer() {
    final container = ProviderContainer(overrides: [
      tripDetailRepositoryProvider.overrideWithValue(mockRepository),
      promotionQueryClientProvider.overrideWithValue(mockPromotionClient),
      achievementServiceProvider.overrideWithValue(mockAchievementService),
      userServiceProvider.overrideWithValue(mockUserService),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  test('build() seeds state with the trip passed at construction', () {
    final container = buildContainer();
    final notifier =
        container.read(tripDetailNotifierProvider(trip.id).notifier);
    notifier.seedInitialTrip(trip);
    final state = container.read(tripDetailNotifierProvider(trip.id));
    expect(state.trip.id, 'trip-1');
    expect(state.identity.userId, isNull);
    expect(state.identity.isLoggedIn, isFalse);
  });

  test(
      'is autoDispose: once nothing watches a tripId, the next visit gets '
      'a fresh notifier instead of the stale cached one', () async {
    final container = buildContainer();

    // First "screen visit": subscribe (as the widget's ref.watch would),
    // seed the real trip, and confirm it stuck.
    final sub = container.listen(
      tripDetailNotifierProvider(trip.id),
      (previous, next) {},
    );
    container
        .read(tripDetailNotifierProvider(trip.id).notifier)
        .seedInitialTrip(trip);
    expect(
      container.read(tripDetailNotifierProvider(trip.id)).trip.name,
      'Test Trip',
    );

    // Screen is popped: the widget's watch goes away and nothing else
    // reads this tripId's provider — it should become eligible for
    // disposal, matching the old field's per-screen-instance lifetime.
    sub.close();
    await container.pump();

    // Next "screen visit" for the same tripId (e.g. re-fetched elsewhere
    // in the app with a different Trip value): must build a fresh
    // notifier, not resurrect the old cached state.
    final freshState = container.read(tripDetailNotifierProvider(trip.id));
    expect(
      freshState.trip.name,
      isEmpty,
      reason: 'expected a fresh build() placeholder, not the previous '
          'visit\'s stale cached trip',
    );
  });

  test(
      'seedInitialTrip always applies its argument, even when the '
      'provider instance is reused (e.g. a rapid re-navigation to the '
      'same trip id lands on a not-yet-disposed instance from the '
      'previous screen, since Flutter keeps a popped route\'s State — and '
      'its ref.watch subscription — mounted for the entire pop transition, '
      'not just until autoDispose\'s scheduled teardown runs) — there is '
      'no guard that could silently discard a newer value', () async {
    final container = buildContainer();

    // Old screen's ref.watch — stays open, exactly as it would during a
    // pop transition still in flight.
    final oldScreenSub = container.listen(
      tripDetailNotifierProvider(trip.id),
      (previous, next) {},
    );
    container
        .read(tripDetailNotifierProvider(trip.id).notifier)
        .seedInitialTrip(trip);
    expect(
      container.read(tripDetailNotifierProvider(trip.id)).trip.name,
      'Test Trip',
    );

    // A different Trip value for the same id, as if re-fetched elsewhere
    // and handed to a brand-new screen instance for the same trip, while
    // the old screen's subscription (and therefore this same provider
    // instance) is still alive.
    final rushedRevisitTrip = trip.copyWith(name: 'Rushed Revisit Trip');
    container
        .read(tripDetailNotifierProvider(trip.id).notifier)
        .seedInitialTrip(rushedRevisitTrip);

    expect(
      container.read(tripDetailNotifierProvider(trip.id)).trip.name,
      'Rushed Revisit Trip',
      reason: 'seedInitialTrip must apply the latest call\'s trip '
          'unconditionally, matching the pre-migration behavior where '
          'each screen\'s own initState() always won',
    );

    oldScreenSub.close();
  });

  test('checkLoginStatus sets identity.isLoggedIn from the repository',
      () async {
    when(mockRepository.isLoggedIn()).thenAnswer((_) async => true);
    final container = buildContainer();
    final notifier =
        container.read(tripDetailNotifierProvider(trip.id).notifier);
    notifier.seedInitialTrip(trip);

    await notifier.checkLoginStatus();

    final state = container.read(tripDetailNotifierProvider(trip.id));
    expect(state.identity.isLoggedIn, isTrue);
  });

  test('loadUserInfo populates identity fields from the repository', () async {
    when(mockRepository.getCurrentUsername()).thenAnswer((_) async => 'me');
    when(mockRepository.getCurrentUserId()).thenAnswer((_) async => 'user-9');
    when(mockRepository.isAdmin()).thenAnswer((_) async => false);
    when(mockRepository.refreshUserDetails()).thenAnswer((_) async => true);
    when(mockRepository.getCurrentDisplayName())
        .thenAnswer((_) async => 'Me Display');
    when(mockRepository.getCurrentAvatarUrl())
        .thenAnswer((_) async => 'https://example.com/a.png');

    final container = buildContainer();
    final notifier =
        container.read(tripDetailNotifierProvider(trip.id).notifier);
    notifier.seedInitialTrip(trip);

    await notifier.loadUserInfo();

    final state = container.read(tripDetailNotifierProvider(trip.id));
    expect(state.identity.username, 'me');
    expect(state.identity.userId, 'user-9');
    expect(state.identity.displayName, 'Me Display');
    expect(state.identity.avatarUrl, 'https://example.com/a.png');
    expect(state.identity.isAdmin, isFalse);
  });

  test('loadUserInfo does not call refreshUserDetails when userId is null',
      () async {
    when(mockRepository.getCurrentUsername()).thenAnswer((_) async => null);
    when(mockRepository.getCurrentUserId()).thenAnswer((_) async => null);
    when(mockRepository.isAdmin()).thenAnswer((_) async => false);
    when(mockRepository.getCurrentDisplayName()).thenAnswer((_) async => null);
    when(mockRepository.getCurrentAvatarUrl()).thenAnswer((_) async => null);

    final container = buildContainer();
    final notifier =
        container.read(tripDetailNotifierProvider(trip.id).notifier);
    notifier.seedInitialTrip(trip);

    await notifier.loadUserInfo();

    verifyNever(mockRepository.refreshUserDetails());
  });

  test('loadPromotionInfo sets isPromoted and donationLink on success',
      () async {
    when(mockPromotionClient.getTripPromotion('trip-1')).thenAnswer(
      (_) async => TripPromotion(
        tripId: 'trip-1',
        donationLink: 'https://example.com/donate',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
    );
    final container = buildContainer();
    final notifier =
        container.read(tripDetailNotifierProvider(trip.id).notifier);
    notifier.seedInitialTrip(trip);

    await notifier.loadPromotionInfo();

    final state = container.read(tripDetailNotifierProvider(trip.id));
    expect(state.promotion.isPromoted, isTrue);
    expect(state.promotion.donationLink, 'https://example.com/donate');
  });

  test('loadPromotionInfo clears promotion state when the client throws',
      () async {
    when(mockPromotionClient.getTripPromotion('trip-1'))
        .thenThrow(Exception('404 not promoted'));
    final container = buildContainer();
    final notifier =
        container.read(tripDetailNotifierProvider(trip.id).notifier);
    notifier.seedInitialTrip(trip);

    await notifier.loadPromotionInfo();

    final state = container.read(tripDetailNotifierProvider(trip.id));
    expect(state.promotion.isPromoted, isFalse);
    expect(state.promotion.donationLink, isNull);
  });

  test('loadTripAchievements populates tripAchievements from the service',
      () async {
    when(mockAchievementService.getTripAchievements('trip-1'))
        .thenAnswer((_) async => []);
    final container = buildContainer();
    final notifier =
        container.read(tripDetailNotifierProvider(trip.id).notifier);
    notifier.seedInitialTrip(trip);

    await notifier.loadTripAchievements();

    verify(mockAchievementService.getTripAchievements('trip-1')).called(1);
  });

  test('loadTripAchievements silently no-ops when the service throws',
      () async {
    when(mockAchievementService.getTripAchievements('trip-1'))
        .thenThrow(Exception('network error'));
    final container = buildContainer();
    final notifier =
        container.read(tripDetailNotifierProvider(trip.id).notifier);
    notifier.seedInitialTrip(trip);

    await notifier.loadTripAchievements(); // must not throw

    final state = container.read(tripDetailNotifierProvider(trip.id));
    expect(state.tripAchievements, isEmpty);
  });

  test('debouncedAchievementRefresh only calls the service once after the delay',
      () async {
    when(mockAchievementService.getTripAchievements('trip-1'))
        .thenAnswer((_) async => []);
    final container = buildContainer();
    // Keep the autoDispose notifier alive for the duration of the debounce
    // timer, mirroring the widget's persistent ref.watch subscription — a
    // bare container.read() here would let the provider (and its timer) get
    // disposed before the Timer fires.
    final sub = container.listen(
      tripDetailNotifierProvider(trip.id),
      (previous, next) {},
    );
    final notifier =
        container.read(tripDetailNotifierProvider(trip.id).notifier);
    notifier.seedInitialTrip(trip);

    notifier.debouncedAchievementRefresh();
    notifier.debouncedAchievementRefresh(); // re-arms, should not double-fire
    notifier.debouncedAchievementRefresh();

    await Future.delayed(const Duration(seconds: 4));

    verify(mockAchievementService.getTripAchievements('trip-1')).called(1);
    sub.close();
  }, timeout: const Timeout(Duration(seconds: 10)));

  test('loadSocialStatus computes isFollowing/hasSentRequest/isAlreadyFriends',
      () async {
    when(mockUserService.getFollowing(page: 0, size: 100)).thenAnswer(
      (_) async => PageResponse<UserFollow>(
        content: [
          UserFollow(
            id: 'follow-1',
            followerId: 'me',
            followedId: 'owner-1',
            createdAt: DateTime(2026, 1, 1),
          ),
        ],
        totalElements: 1,
        totalPages: 1,
        number: 0,
        size: 100,
        first: true,
        last: true,
      ),
    );
    when(mockUserService.getSentFriendRequests()).thenAnswer((_) async => [
          FriendRequest(
            id: 'req-1',
            senderId: 'me',
            receiverId: 'owner-1',
            status: FriendRequestStatus.pending,
            createdAt: DateTime(2026, 1, 1),
            updatedAt: DateTime(2026, 1, 1),
          ),
        ]);
    when(mockUserService.getFriends(page: 0, size: 100)).thenAnswer(
      (_) async => PageResponse<Friendship>(
        content: <Friendship>[],
        totalElements: 0,
        totalPages: 0,
        number: 0,
        size: 100,
        first: true,
        last: true,
      ),
    );

    final container = buildContainer();
    final notifier =
        container.read(tripDetailNotifierProvider(trip.id).notifier);
    notifier.seedInitialTrip(trip);

    await notifier.loadSocialStatus();

    final state = container.read(tripDetailNotifierProvider(trip.id));
    expect(state.social.isFollowingTripOwner, isTrue);
    expect(state.social.hasSentFriendRequest, isTrue);
    expect(state.social.sentFriendRequestId, 'req-1');
    expect(state.social.isAlreadyFriends, isFalse);
  });

  test('followTripOwner(unfollow: true) calls unfollowUser and clears the flag',
      () async {
    when(mockUserService.unfollowUser('owner-1')).thenAnswer((_) async => 'ok');
    final container = buildContainer();
    final notifier =
        container.read(tripDetailNotifierProvider(trip.id).notifier);
    notifier.seedInitialTrip(trip);
    notifier.debugSetSocialForTest(
      const TripDetailSocialState(isFollowingTripOwner: true),
    );

    await notifier.followTripOwner();

    verify(mockUserService.unfollowUser('owner-1')).called(1);
    expect(
      container.read(tripDetailNotifierProvider(trip.id)).social.isFollowingTripOwner,
      isFalse,
    );
  });

  test('followTripOwner(unfollow: false) calls followUser and sets the flag',
      () async {
    when(mockUserService.followUser('owner-1')).thenAnswer((_) async => 'ok');
    final container = buildContainer();
    final notifier =
        container.read(tripDetailNotifierProvider(trip.id).notifier);
    notifier.seedInitialTrip(trip);

    await notifier.followTripOwner();

    verify(mockUserService.followUser('owner-1')).called(1);
    expect(
      container.read(tripDetailNotifierProvider(trip.id)).social.isFollowingTripOwner,
      isTrue,
    );
  });

  test('sendFriendRequestToTripOwner sends a new request when none is pending',
      () async {
    when(mockUserService.sendFriendRequest('owner-1'))
        .thenAnswer((_) async => 'req-9');
    final container = buildContainer();
    final notifier =
        container.read(tripDetailNotifierProvider(trip.id).notifier);
    notifier.seedInitialTrip(trip);

    await notifier.sendFriendRequestToTripOwner();

    final state = container.read(tripDetailNotifierProvider(trip.id));
    expect(state.social.hasSentFriendRequest, isTrue);
    expect(state.social.sentFriendRequestId, 'req-9');
  });

  test(
      'sendFriendRequestToTripOwner removes friend and clears the flag '
      'when already friends', () async {
    when(mockUserService.removeFriend('owner-1')).thenAnswer((_) async => 'ok');
    final container = buildContainer();
    final notifier =
        container.read(tripDetailNotifierProvider(trip.id).notifier);
    notifier.seedInitialTrip(trip);
    notifier.debugSetSocialForTest(
      const TripDetailSocialState(isAlreadyFriends: true),
    );

    await notifier.sendFriendRequestToTripOwner();

    verify(mockUserService.removeFriend('owner-1')).called(1);
    expect(
      container.read(tripDetailNotifierProvider(trip.id)).social.isAlreadyFriends,
      isFalse,
    );
  });

  test(
      'sendFriendRequestToTripOwner cancels the pending request when one '
      'exists', () async {
    when(mockUserService.deleteFriendRequest('req-1'))
        .thenAnswer((_) async => 'ok');
    final container = buildContainer();
    final notifier =
        container.read(tripDetailNotifierProvider(trip.id).notifier);
    notifier.seedInitialTrip(trip);
    notifier.debugSetSocialForTest(
      const TripDetailSocialState(
        hasSentFriendRequest: true,
        sentFriendRequestId: 'req-1',
      ),
    );

    await notifier.sendFriendRequestToTripOwner();

    verify(mockUserService.deleteFriendRequest('req-1')).called(1);
    final state = container.read(tripDetailNotifierProvider(trip.id));
    expect(state.social.hasSentFriendRequest, isFalse);
    expect(state.social.sentFriendRequestId, isNull);
  });
}
