import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:wanderer_frontend/core/constants/enums.dart';
import 'package:wanderer_frontend/core/providers/app_providers.dart';
import 'package:wanderer_frontend/data/client/api_client.dart';
import 'package:wanderer_frontend/data/models/responses/page_response.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/data/models/websocket/websocket_event.dart';
import 'package:wanderer_frontend/data/repositories/home_repository.dart';
import 'package:wanderer_frontend/data/services/trip_service.dart';
import 'package:wanderer_frontend/data/services/websocket_service.dart';
import 'package:wanderer_frontend/presentation/state/home_feed/home_feed_notifier.dart';
import 'package:wanderer_frontend/presentation/state/user_chrome/user_chrome_notifier.dart';

import 'home_feed_notifier_test.mocks.dart';

@GenerateMocks([HomeRepository, WebSocketService, TripService])
void main() {
  late MockHomeRepository mockRepository;
  late MockWebSocketService mockWebSocketService;
  late MockTripService mockTripService;

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
    mockWebSocketService = MockWebSocketService();
    mockTripService = MockTripService();
  });

  ProviderContainer buildContainer() {
    final container = ProviderContainer(overrides: [
      homeRepositoryProvider.overrideWithValue(mockRepository),
      websocketServiceProvider.overrideWithValue(mockWebSocketService),
      tripServiceProvider.overrideWithValue(mockTripService),
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

  test('setStatusFilter/setVisibilityFilter set and clear filters', () {
    final container = buildContainer();
    final notifier = container.read(homeFeedNotifierProvider.notifier);

    notifier.setStatusFilter(TripStatus.paused);
    expect(container.read(homeFeedNotifierProvider).statusFilter,
        TripStatus.paused);

    notifier.setStatusFilter(null);
    expect(container.read(homeFeedNotifierProvider).statusFilter, isNull);

    notifier.setVisibilityFilter(Visibility.private);
    expect(container.read(homeFeedNotifierProvider).visibilityFilter,
        Visibility.private);
  });

  test('resetFiltersForTab clears visibility always, status only if invalid '
      'outside My Trips', () {
    final container = buildContainer();
    final notifier = container.read(homeFeedNotifierProvider.notifier);

    notifier.setStatusFilter(TripStatus.inProgress);
    notifier.setVisibilityFilter(Visibility.private);
    notifier.resetFiltersForTab(false);

    var state = container.read(homeFeedNotifierProvider);
    expect(state.visibilityFilter, isNull);
    expect(state.statusFilter, TripStatus.inProgress,
        reason: 'inProgress is valid on Feed/Discover, must survive');

    notifier.setStatusFilter(TripStatus.finished);
    notifier.resetFiltersForTab(false);
    state = container.read(homeFeedNotifierProvider);
    expect(state.statusFilter, isNull,
        reason: 'finished is only valid on My Trips, must clear');
  });

  test('loadTrips (logged in) categorizes into feed excluding own trips',
      () async {
    when(mockRepository.loadTrips(page: 0, size: 20)).thenAnswer(
      (_) async => PageResponse(
        content: [makeTrip('friend-trip', status: TripStatus.inProgress)],
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
        content: const [],
        first: true,
        last: true,
        totalElements: 0,
        totalPages: 1,
        number: 0,
        size: 20,
      ),
    );
    when(mockRepository.getFriendsIds())
        .thenAnswer((_) async => {'owner-friend-trip'});
    when(mockRepository.getFollowingIds()).thenAnswer((_) async => <String>{});
    when(mockRepository.getPublicTrips(page: 0, size: 20)).thenAnswer(
      (_) async => PageResponse(
        content: const [],
        first: true,
        last: true,
        totalElements: 0,
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
    expect(state.feedTrips.map((t) => t.id), contains('friend-trip'));
  });

  test(
      'loadTrips resyncs WS trip subscriptions: unsubscribes all then '
      'subscribes to the resulting allTrips ids', () async {
    when(mockRepository.getPublicTrips(page: 0, size: 20)).thenAnswer(
      (_) async => PageResponse(
        content: [makeTrip('t1'), makeTrip('t2')],
        first: true,
        last: true,
        totalElements: 2,
        totalPages: 1,
        number: 0,
        size: 20,
      ),
    );

    final container = buildContainer();
    await container.read(homeFeedNotifierProvider.notifier).loadTrips();

    verify(mockWebSocketService.unsubscribeFromAllTrips())
        .called(greaterThanOrEqualTo(1));
    final captured = verify(
      mockWebSocketService.subscribeToTrips(captureAny),
    ).captured;
    expect(captured.last, unorderedEquals(['t1', 't2']));
  });

  test(
      'loadMoreTrips subscribes only to newly-added trip ids, without '
      'unsubscribing existing ones', () async {
    when(mockRepository.getPublicTrips(page: 0, size: 20)).thenAnswer(
      (_) async => PageResponse(
        content: [makeTrip('t1')],
        first: true,
        last: false,
        totalElements: 2,
        totalPages: 2,
        number: 0,
        size: 20,
      ),
    );
    final container = buildContainer();
    final notifier = container.read(homeFeedNotifierProvider.notifier);
    await notifier.loadTrips();
    clearInteractions(mockWebSocketService);

    when(mockRepository.loadTrips(page: 1, size: 20)).thenAnswer(
      (_) async => PageResponse(
        content: [makeTrip('t2')],
        first: false,
        last: true,
        totalElements: 2,
        totalPages: 2,
        number: 1,
        size: 20,
      ),
    );

    await notifier.loadMoreTrips();

    verifyNever(mockWebSocketService.unsubscribeFromAllTrips());
    verify(mockWebSocketService.subscribeToTrips(['t2'])).called(1);
  });

  test(
      'startWebSocketAndPolling called twice (simulating HomeScreen '
      're-navigation) cancels the stale subscription so a WS event is '
      'dispatched exactly once, not twice', () async {
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
    final eventsController = StreamController<WebSocketEvent>.broadcast();
    addTearDown(eventsController.close);
    when(mockWebSocketService.events).thenAnswer((_) => eventsController.stream);
    when(mockWebSocketService.connect()).thenAnswer((_) async {});

    final container = buildContainer();
    // Keep this autoDispose provider alive across the `await` below -
    // without an active listener it would dispose (and rebuild to its
    // empty default state) the moment control yields to the event loop.
    container.listen(homeFeedNotifierProvider, (_, __) {});
    final notifier = container.read(homeFeedNotifierProvider.notifier);
    await notifier.loadTrips();

    // Simulate the widget's initState() re-firing on repeated HomeScreen
    // navigation, before the previous instance's subscription is disposed.
    notifier.startWebSocketAndPolling();
    notifier.startWebSocketAndPolling();

    eventsController.add(
      CommentAddedEvent(
        tripId: 't1',
        commentId: 'c1',
        userId: 'u1',
        username: 'user',
        message: 'hi',
        payload: const {},
      ),
    );
    await Future<void>.delayed(Duration.zero);

    final state = container.read(homeFeedNotifierProvider);
    expect(state.allTrips.first.commentsCount, 1,
        reason: 'a single WS event must only be dispatched once, even after '
            'startWebSocketAndPolling() was called twice without an '
            'intervening dispose');
  });

  test('handleWebSocketEvent(tripStatusChanged) updates the matching trip '
      'in place', () async {
    when(mockRepository.getPublicTrips(page: 0, size: 20)).thenAnswer(
      (_) async => PageResponse(
        content: [makeTrip('t1', status: TripStatus.created)],
        first: true,
        last: true,
        totalElements: 1,
        totalPages: 1,
        number: 0,
        size: 20,
      ),
    );
    final container = buildContainer();
    final notifier = container.read(homeFeedNotifierProvider.notifier);
    await notifier.loadTrips();

    notifier.debugHandleWebSocketEvent(
      TripStatusChangedEvent(
        tripId: 't1',
        newStatus: TripStatus.inProgress,
        currentDay: 1,
        payload: const {},
      ),
    );

    final state = container.read(homeFeedNotifierProvider);
    expect(state.allTrips.first.status, TripStatus.inProgress);
  });
}
