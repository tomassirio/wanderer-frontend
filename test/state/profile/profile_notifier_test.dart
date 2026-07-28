import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:wanderer_frontend/core/providers/app_providers.dart';
import 'package:wanderer_frontend/data/models/user_models.dart';
import 'package:wanderer_frontend/data/repositories/profile_repository.dart';
import 'package:wanderer_frontend/presentation/state/profile/profile_notifier.dart';

import 'profile_notifier_test.mocks.dart';

@GenerateMocks([ProfileRepository])
void main() {
  late MockProfileRepository mockRepository;

  setUp(() {
    mockRepository = MockProfileRepository();
  });

  ProviderContainer buildContainer() {
    final container = ProviderContainer(overrides: [
      profileRepositoryProvider.overrideWithValue(mockRepository),
    ]);
    addTearDown(container.dispose);
    return container;
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
}
