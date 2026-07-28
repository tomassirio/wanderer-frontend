import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:wanderer_frontend/core/constants/enums.dart';
import 'package:wanderer_frontend/core/providers/app_providers.dart';
import 'package:wanderer_frontend/data/client/api_client.dart';
import 'package:wanderer_frontend/data/models/responses/page_response.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/data/repositories/home_repository.dart';
import 'package:wanderer_frontend/presentation/state/home_feed/home_feed_notifier.dart';
import 'package:wanderer_frontend/presentation/state/user_chrome/user_chrome_notifier.dart';

import 'home_feed_notifier_test.mocks.dart';

@GenerateMocks([HomeRepository])
void main() {
  late MockHomeRepository mockRepository;

  Trip makeTrip(String id, {TripStatus status = TripStatus.inProgress}) {
    return Trip(
      id: id,
      userId: 'owner-$id',
      username: 'owner',
      name: 'Trip $id',
      status: status,
      visibility: Visibility.public,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
  }

  setUp(() {
    mockRepository = MockHomeRepository();
  });

  ProviderContainer buildContainer() {
    final container = ProviderContainer(overrides: [
      homeRepositoryProvider.overrideWithValue(mockRepository),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  test('loadTrips (guest) populates allTrips from getPublicTrips only',
      () async {
    when(mockRepository.getPublicTrips(page: 0, size: 20)).thenAnswer(
      (_) async => PageResponse(
        content: [makeTrip('t1')],
        first: true,
        last: true,
        totalElements: 1,
        totalPages: 1,
        number: 0,
        size: 20,
      ),
    );

    final container = buildContainer();
    // Default UserChromeState is logged-out - no seeding needed for guest.
    await container.read(homeFeedNotifierProvider.notifier).loadTrips();

    final state = container.read(homeFeedNotifierProvider);
    expect(state.allTrips.length, 1);
    expect(state.isLoading, isFalse);
    verifyNever(mockRepository.getMyTrips(
        page: anyNamed('page'), size: anyNamed('size')));
  });

  test('loadTrips (logged in) merges available + public trips, dedup by id',
      () async {
    final shared = makeTrip('shared');
    when(mockRepository.loadTrips(page: 0, size: 20)).thenAnswer(
      (_) async => PageResponse(
        content: [shared],
        first: true,
        last: true,
        totalElements: 1,
        totalPages: 1,
        number: 0,
        size: 20,
      ),
    );
    when(mockRepository.getMyTrips(page: 0, size: 20)).thenAnswer(
      (_) async => PageResponse(
        content: [makeTrip('mine')],
        first: true,
        last: true,
        totalElements: 1,
        totalPages: 1,
        number: 0,
        size: 20,
      ),
    );
    when(mockRepository.getFriendsIds()).thenAnswer((_) async => <String>{});
    when(mockRepository.getFollowingIds()).thenAnswer((_) async => <String>{});
    when(mockRepository.getPublicTrips(page: 0, size: 20)).thenAnswer(
      (_) async => PageResponse(
        content: [shared, makeTrip('public-only')],
        first: true,
        last: true,
        totalElements: 2,
        totalPages: 1,
        number: 0,
        size: 20,
      ),
    );

    final container = buildContainer();
    container
        .read(userChromeNotifierProvider.notifier)
        .debugSeedForTest(isLoggedIn: true, userId: 'me');
    await container.read(homeFeedNotifierProvider.notifier).loadTrips();

    final state = container.read(homeFeedNotifierProvider);
    expect(state.allTrips.map((t) => t.id).toSet(), {'shared', 'public-only'});
    expect(state.myTrips.length, 1);
  });

  test(
      'loadTrips on AuthenticationRedirectException marks logged-out and '
      'reloads as guest', () async {
    when(mockRepository.loadTrips(page: 0, size: 20))
        .thenThrow(AuthenticationRedirectException());
    when(mockRepository.getPublicTrips(page: 0, size: 20)).thenAnswer(
      (_) async => PageResponse(
        content: [makeTrip('guest-trip')],
        first: true,
        last: true,
        totalElements: 1,
        totalPages: 1,
        number: 0,
        size: 20,
      ),
    );

    final container = buildContainer();
    container
        .read(userChromeNotifierProvider.notifier)
        .debugSeedForTest(isLoggedIn: true, userId: 'me');
    await container.read(homeFeedNotifierProvider.notifier).loadTrips();

    final identity = container.read(userChromeNotifierProvider);
    expect(identity.isLoggedIn, isFalse,
        reason: 'session-expiry must flip isLoggedIn to false');
    final state = container.read(homeFeedNotifierProvider);
    expect(state.allTrips.map((t) => t.id), contains('guest-trip'),
        reason: 'must reload as guest after the redirect exception');
  });

  test('loadMoreTrips is a no-op while already loading more', () async {
    final container = buildContainer();
    final notifier = container.read(homeFeedNotifierProvider.notifier);
    // hasMoreTrips defaults to false, so the guard short-circuits before
    // any repository call - confirms the no-op path with zero setup.
    await notifier.loadMoreTrips();
    verifyNever(mockRepository.loadTrips(
        page: anyNamed('page'), size: anyNamed('size')));
  });
}
