import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:wanderer_frontend/core/providers/app_providers.dart';
import 'package:wanderer_frontend/data/repositories/home_repository.dart';
import 'package:wanderer_frontend/presentation/state/user_chrome/user_chrome_notifier.dart';

import 'user_chrome_notifier_test.mocks.dart';

@GenerateMocks([HomeRepository])
void main() {
  late MockHomeRepository mockRepository;

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

  test('build() returns an empty, logged-out default state', () {
    final container = buildContainer();
    final state = container.read(userChromeNotifierProvider);
    expect(state.username, isNull);
    expect(state.userId, isNull);
    expect(state.isLoggedIn, isFalse);
    expect(state.isAdmin, isFalse);
  });

  test('loadUserInfo populates all identity fields when logged in', () async {
    when(mockRepository.getCurrentUsername()).thenAnswer((_) async => 'alice');
    when(mockRepository.getCurrentUserId()).thenAnswer((_) async => 'user-1');
    when(mockRepository.isLoggedIn()).thenAnswer((_) async => true);
    when(mockRepository.isAdmin()).thenAnswer((_) async => false);
    when(mockRepository.refreshUserDetails()).thenAnswer((_) async => true);
    when(mockRepository.getCurrentDisplayName())
        .thenAnswer((_) async => 'Alice Doe');
    when(mockRepository.getCurrentAvatarUrl())
        .thenAnswer((_) async => 'https://example.com/a.png');

    final container = buildContainer();
    await container.read(userChromeNotifierProvider.notifier).loadUserInfo();

    final state = container.read(userChromeNotifierProvider);
    expect(state.username, 'alice');
    expect(state.userId, 'user-1');
    expect(state.displayName, 'Alice Doe');
    expect(state.avatarUrl, 'https://example.com/a.png');
    expect(state.isLoggedIn, isTrue);
    expect(state.isAdmin, isFalse);
    verify(mockRepository.refreshUserDetails()).called(1);
  });

  test('loadUserInfo does not refresh user details when not logged in',
      () async {
    when(mockRepository.getCurrentUsername()).thenAnswer((_) async => null);
    when(mockRepository.getCurrentUserId()).thenAnswer((_) async => null);
    when(mockRepository.isLoggedIn()).thenAnswer((_) async => false);
    when(mockRepository.isAdmin()).thenAnswer((_) async => false);
    when(mockRepository.getCurrentDisplayName()).thenAnswer((_) async => null);
    when(mockRepository.getCurrentAvatarUrl()).thenAnswer((_) async => null);

    final container = buildContainer();
    await container.read(userChromeNotifierProvider.notifier).loadUserInfo();

    verifyNever(mockRepository.refreshUserDetails());
    expect(container.read(userChromeNotifierProvider).isLoggedIn, isFalse);
  });

  test('logout calls the repository and resets state to logged-out defaults',
      () async {
    when(mockRepository.getCurrentUsername()).thenAnswer((_) async => 'alice');
    when(mockRepository.getCurrentUserId()).thenAnswer((_) async => 'user-1');
    when(mockRepository.isLoggedIn()).thenAnswer((_) async => true);
    when(mockRepository.isAdmin()).thenAnswer((_) async => false);
    when(mockRepository.refreshUserDetails()).thenAnswer((_) async => true);
    when(mockRepository.getCurrentDisplayName())
        .thenAnswer((_) async => 'Alice Doe');
    when(mockRepository.getCurrentAvatarUrl())
        .thenAnswer((_) async => 'https://example.com/a.png');
    when(mockRepository.logout()).thenAnswer((_) async {});

    final container = buildContainer();
    final notifier = container.read(userChromeNotifierProvider.notifier);
    await notifier.loadUserInfo();
    expect(container.read(userChromeNotifierProvider).username, 'alice');

    await notifier.logout();

    verify(mockRepository.logout()).called(1);
    final state = container.read(userChromeNotifierProvider);
    expect(state.username, isNull);
    expect(state.isLoggedIn, isFalse);
  });

  test(
      'updateAvatarUrl updates only avatarUrl, leaving other identity '
      'fields untouched', () {
    final container = buildContainer();
    container.read(userChromeNotifierProvider.notifier).updateAvatarUrl(
          'https://example.com/old.png',
        );
    container
        .read(userChromeNotifierProvider.notifier)
        .updateAvatarUrl('https://example.com/new.png');

    final state = container.read(userChromeNotifierProvider);
    expect(state.avatarUrl, 'https://example.com/new.png');
  });

  test(
      'setLoggedOut flips isLoggedIn to false but leaves other identity '
      'fields stale (deliberately, not cleared)', () async {
    when(mockRepository.getCurrentUsername()).thenAnswer((_) async => 'alice');
    when(mockRepository.getCurrentUserId()).thenAnswer((_) async => 'user-1');
    when(mockRepository.isLoggedIn()).thenAnswer((_) async => true);
    when(mockRepository.isAdmin()).thenAnswer((_) async => false);
    when(mockRepository.refreshUserDetails()).thenAnswer((_) async => true);
    when(mockRepository.getCurrentDisplayName())
        .thenAnswer((_) async => 'Alice Doe');
    when(mockRepository.getCurrentAvatarUrl())
        .thenAnswer((_) async => 'https://example.com/a.png');

    final container = buildContainer();
    final notifier = container.read(userChromeNotifierProvider.notifier);
    await notifier.loadUserInfo();

    notifier.setLoggedOut();

    final state = container.read(userChromeNotifierProvider);
    expect(state.isLoggedIn, isFalse);
    expect(state.username, 'alice');
    expect(state.userId, 'user-1');
    expect(state.displayName, 'Alice Doe');
    expect(state.avatarUrl, 'https://example.com/a.png');
  });
}
