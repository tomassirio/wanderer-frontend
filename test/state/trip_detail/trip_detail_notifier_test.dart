import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:wanderer_frontend/core/constants/enums.dart';
import 'package:wanderer_frontend/core/providers/app_providers.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/data/repositories/trip_detail_repository.dart';
import 'package:wanderer_frontend/presentation/state/trip_detail/trip_detail_notifier.dart';

import 'trip_detail_notifier_test.mocks.dart';

@GenerateMocks([TripDetailRepository])
void main() {
  late MockTripDetailRepository mockRepository;
  late Trip trip;

  setUp(() {
    mockRepository = MockTripDetailRepository();
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
}
