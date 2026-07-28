import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:wanderer_frontend/core/constants/enums.dart';
import 'package:wanderer_frontend/core/providers/app_providers.dart';
import 'package:wanderer_frontend/data/models/domain/trip.dart';
import 'package:wanderer_frontend/data/models/responses/page_response.dart';
import 'package:wanderer_frontend/data/models/user_models.dart';
import 'package:wanderer_frontend/data/repositories/profile_repository.dart';
import 'package:wanderer_frontend/data/services/user_service.dart';
import 'package:wanderer_frontend/presentation/state/profile/profile_notifier.dart';
import 'package:wanderer_frontend/presentation/state/profile/profile_state.dart';
import 'package:wanderer_frontend/presentation/state/user_chrome/user_chrome_notifier.dart';

import 'profile_notifier_test.mocks.dart';

@GenerateMocks([ProfileRepository, UserService])
void main() {
  late MockProfileRepository mockRepository;
  late MockUserService mockUserService;

  setUp(() {
    mockRepository = MockProfileRepository();
    mockUserService = MockUserService();
  });

  ProviderContainer buildContainer() {
    final container = ProviderContainer(overrides: [
      profileRepositoryProvider.overrideWithValue(mockRepository),
      userServiceProvider.overrideWithValue(mockUserService),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  Trip makeTrip({
    required String id,
    required TripStatus status,
    required DateTime updatedAt,
  }) {
    return Trip(
      id: id,
      userId: 'owner-1',
      username: 'owner',
      name: 'Trip $id',
      status: status,
      visibility: Visibility.public,
      tripModality: TripModality.simple,
      automaticUpdates: false,
      createdAt: updatedAt,
      updatedAt: updatedAt,
    );
  }

  test('loadProfile(own profile, family key null) calls getMyProfile',
      () async {
    when(mockRepository.getMyProfile()).thenAnswer(
      (_) async => UserProfile(
        id: 'me-1',
        username: 'me',
        email: 'me@example.com',
        followersCount: 0,
        followingCount: 0,
        friendsCount: 0,
        tripsCount: 0,
        isFollowing: false,
        createdAt: DateTime(2026, 1, 1),
      ),
    );

    final container = buildContainer();
    await container.read(profileNotifierProvider(null).notifier).loadProfile();

    final state = container.read(profileNotifierProvider(null));
    expect(state.profile?.id, 'me-1');
    expect(state.isLoadingProfile, isFalse);
    verify(mockRepository.getMyProfile()).called(1);
    verifyNever(mockRepository.getUserProfile(any));
  });

  test('loadProfile(viewed profile, family key = userId) calls getUserProfile',
      () async {
    when(mockRepository.getUserProfile('other-1')).thenAnswer(
      (_) async => UserProfile(
        id: 'other-1',
        username: 'other',
        email: 'other@example.com',
        followersCount: 3,
        followingCount: 4,
        friendsCount: 2,
        tripsCount: 1,
        isFollowing: false,
        createdAt: DateTime(2026, 1, 1),
      ),
    );

    final container = buildContainer();
    await container
        .read(profileNotifierProvider('other-1').notifier)
        .loadProfile();

    final state = container.read(profileNotifierProvider('other-1'));
    expect(state.profile?.id, 'other-1');
    verify(mockRepository.getUserProfile('other-1')).called(1);
    verifyNever(mockRepository.getMyProfile());
  });

  test('seedTargetUserId is unconditional - a second call always overwrites',
      () async {
    final container = buildContainer();
    final notifier = container.read(profileNotifierProvider('user-1').notifier);

    notifier.seedTargetUserId('user-1');
    notifier.seedTargetUserId('user-1');

    // No assertion needed beyond "does not throw" - this test exists to
    // document and pin the unconditional-seed requirement; if a future
    // change adds an "already seeded" guard, a more specific state-change
    // test should be added alongside it, not a silent regression here.
    expect(container.read(profileNotifierProvider('user-1')).targetUserId,
        'user-1');
  });

  test('setProfile stores the given profile without calling the repository',
      () async {
    final container = buildContainer();
    final profile = UserProfile(
      id: 'other-1',
      username: 'other',
      email: 'other@example.com',
      followersCount: 0,
      followingCount: 0,
      friendsCount: 0,
      tripsCount: 0,
      isFollowing: false,
      createdAt: DateTime(2026, 1, 1),
    );

    container
        .read(profileNotifierProvider('other-1').notifier)
        .setProfile(profile);

    final state = container.read(profileNotifierProvider('other-1'));
    expect(state.profile?.id, 'other-1');
    verifyNever(mockRepository.getUserProfile(any));
    verifyNever(mockRepository.getMyProfile());
  });

  test(
      'loadSocialCounts(own profile) uses UserService.getFollowers/getFollowing/getFriends',
      () async {
    when(mockUserService.getFollowers(page: 0, size: 1)).thenAnswer(
      (_) async => PageResponse(
          content: [],
          totalElements: 5,
          totalPages: 1,
          number: 0,
          size: 1,
          last: true,
          first: true),
    );
    when(mockUserService.getFollowing(page: 0, size: 1)).thenAnswer(
      (_) async => PageResponse(
          content: [],
          totalElements: 3,
          totalPages: 1,
          number: 0,
          size: 1,
          last: true,
          first: true),
    );
    when(mockUserService.getFriends(page: 0, size: 1)).thenAnswer(
      (_) async => PageResponse(
          content: [],
          totalElements: 2,
          totalPages: 1,
          number: 0,
          size: 1,
          last: true,
          first: true),
    );

    final container = buildContainer();
    await container.read(profileNotifierProvider(null).notifier).loadSocialCounts();

    final state = container.read(profileNotifierProvider(null));
    expect(state.followersCount, 5);
    expect(state.followingCount, 3);
    expect(state.friendsCount, 2);
  });

  test(
      'loadSocialCounts(viewed profile) uses UserService.getUserFollowers/getUserFollowing/getUserFriends',
      () async {
    when(mockUserService.getUserFollowers('other-1', page: 0, size: 1)).thenAnswer(
      (_) async => PageResponse(
          content: [],
          totalElements: 7,
          totalPages: 1,
          number: 0,
          size: 1,
          last: true,
          first: true),
    );
    when(mockUserService.getUserFollowing('other-1', page: 0, size: 1)).thenAnswer(
      (_) async => PageResponse(
          content: [],
          totalElements: 6,
          totalPages: 1,
          number: 0,
          size: 1,
          last: true,
          first: true),
    );
    when(mockUserService.getUserFriends('other-1', page: 0, size: 1)).thenAnswer(
      (_) async => PageResponse(
          content: [],
          totalElements: 1,
          totalPages: 1,
          number: 0,
          size: 1,
          last: true,
          first: true),
    );

    final container = buildContainer();
    await container
        .read(profileNotifierProvider('other-1').notifier)
        .loadSocialCounts();

    final state = container.read(profileNotifierProvider('other-1'));
    expect(state.followersCount, 7);
  });

  test('filteredAndSortedTrips: statusPriority sort matches the single shared comparator',
      () {
    final trips = [
      makeTrip(id: 't1', status: TripStatus.finished, updatedAt: DateTime(2026, 1, 1)),
      makeTrip(id: 't2', status: TripStatus.inProgress, updatedAt: DateTime(2026, 1, 2)),
      makeTrip(id: 't3', status: TripStatus.paused, updatedAt: DateTime(2026, 1, 1)),
    ];
    final state = ProfileState(userTrips: trips, tripSortOption: TripSortOption.statusPriority);

    final sorted = state.filteredAndSortedTrips;

    expect(sorted.map((t) => t.id).toList(), ['t2', 't3', 't1']);
  });

  test('toggleStatusFilter adds then removes a status', () async {
    final container = buildContainer();
    final notifier = container.read(profileNotifierProvider(null).notifier);

    notifier.toggleStatusFilter(TripStatus.paused);
    expect(container.read(profileNotifierProvider(null)).selectedStatusFilters,
        contains(TripStatus.paused));

    notifier.toggleStatusFilter(TripStatus.paused);
    expect(container.read(profileNotifierProvider(null)).selectedStatusFilters,
        isNot(contains(TripStatus.paused)));
  });

  test('loadUserTrips(own profile) calls getMyTrips and populates userTrips',
      () async {
    when(mockRepository.getMyTrips(page: 0, size: 100)).thenAnswer(
      (_) async => PageResponse(
          content: [makeTrip(id: 't1', status: TripStatus.created, updatedAt: DateTime(2026, 1, 1))],
          totalElements: 1,
          totalPages: 1,
          number: 0,
          size: 100,
          last: true,
          first: true),
    );

    final container = buildContainer();
    await container.read(profileNotifierProvider(null).notifier).loadUserTrips();

    final state = container.read(profileNotifierProvider(null));
    expect(state.userTrips.map((t) => t.id).toList(), ['t1']);
    expect(state.isLoadingTrips, isFalse);
    verify(mockRepository.getMyTrips(page: 0, size: 100)).called(1);
  });

  test('loadUserTrips(viewed profile) calls getUserTrips', () async {
    when(mockRepository.getUserTrips('other-1', page: 0, size: 100)).thenAnswer(
      (_) async => PageResponse(
          content: [],
          totalElements: 0,
          totalPages: 0,
          number: 0,
          size: 100,
          last: true,
          first: true),
    );

    final container = buildContainer();
    await container
        .read(profileNotifierProvider('other-1').notifier)
        .loadUserTrips();

    verify(mockRepository.getUserTrips('other-1', page: 0, size: 100)).called(1);
    verifyNever(mockRepository.getMyTrips(page: anyNamed('page'), size: anyNamed('size')));
  });

  test(
      'loadUserTrips(targetUserId set but equal to the logged-in user\'s own '
      'id) still calls getMyTrips, not getUserTrips - the self-view edge '
      'case (e.g. a self-search-result tap or a deep link to one\'s own '
      'profile) must not hide the viewer\'s own private trips behind the '
      'visibility-filtered endpoint', () async {
    when(mockRepository.getMyTrips(page: 0, size: 100)).thenAnswer(
      (_) async => PageResponse(
          content: [makeTrip(id: 't1', status: TripStatus.created, updatedAt: DateTime(2026, 1, 1))],
          totalElements: 1,
          totalPages: 1,
          number: 0,
          size: 100,
          last: true,
          first: true),
    );

    final container = buildContainer();
    container
        .read(userChromeNotifierProvider.notifier)
        .debugSeedForTest(isLoggedIn: true, userId: 'me-1');

    await container
        .read(profileNotifierProvider('me-1').notifier)
        .loadUserTrips();

    final state = container.read(profileNotifierProvider('me-1'));
    expect(state.userTrips.map((t) => t.id).toList(), ['t1']);
    verify(mockRepository.getMyTrips(page: 0, size: 100)).called(1);
    verifyNever(mockRepository.getUserTrips(any,
        page: anyNamed('page'), size: anyNamed('size')));
  });

  test('seedSocialCountsFromProfile stores followers/following without a '
      'network call', () async {
    final container = buildContainer();
    final profile = UserProfile(
      id: 'other-1',
      username: 'other',
      email: 'other@example.com',
      followersCount: 8,
      followingCount: 5,
      friendsCount: 0,
      tripsCount: 0,
      isFollowing: false,
      createdAt: DateTime(2026, 1, 1),
    );

    container
        .read(profileNotifierProvider('other-1').notifier)
        .seedSocialCountsFromProfile(profile);

    final state = container.read(profileNotifierProvider('other-1'));
    expect(state.followersCount, 8);
    expect(state.followingCount, 5);
    verifyNever(mockUserService.getUserFollowers(any,
        page: anyNamed('page'), size: anyNamed('size')));
  });

  test('setSortOption updates tripSortOption', () async {
    final container = buildContainer();
    final notifier = container.read(profileNotifierProvider(null).notifier);

    notifier.setSortOption(TripSortOption.nameAsc);

    expect(container.read(profileNotifierProvider(null)).tripSortOption,
        TripSortOption.nameAsc);
  });

  test('clearStatusFilters empties the filter set', () async {
    final container = buildContainer();
    final notifier = container.read(profileNotifierProvider(null).notifier);
    notifier.toggleStatusFilter(TripStatus.paused);

    notifier.clearStatusFilters();

    expect(container.read(profileNotifierProvider(null)).selectedStatusFilters, isEmpty);
  });

  test('toggleFilterPanel flips showFilterPanel', () async {
    final container = buildContainer();
    final notifier = container.read(profileNotifierProvider(null).notifier);

    notifier.toggleFilterPanel();
    expect(container.read(profileNotifierProvider(null)).showFilterPanel, isTrue);

    notifier.toggleFilterPanel();
    expect(container.read(profileNotifierProvider(null)).showFilterPanel, isFalse);
  });
}
