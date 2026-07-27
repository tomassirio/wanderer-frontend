import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wanderer_frontend/core/providers/app_providers.dart';
import 'package:wanderer_frontend/data/repositories/home_repository.dart';
import 'package:wanderer_frontend/presentation/state/user_chrome/user_chrome_state.dart';

/// App-global identity/auth-chrome state. NOT family-keyed or autoDispose'd
/// — identity is a single, app-lifetime concept, not scoped to one screen.
/// First consumer: `TripPlanDetailScreen`. Designed to be reused by
/// `home_screen.dart`/`profile_screen.dart`/`create_trip_plan_screen.dart`
/// when they get their own extraction passes (not part of this plan).
class UserChromeNotifier extends Notifier<UserChromeState> {
  late HomeRepository _repository;

  @override
  UserChromeState build() {
    _repository = ref.watch(homeRepositoryProvider);
    return const UserChromeState();
  }

  Future<void> loadUserInfo() async {
    final username = await _repository.getCurrentUsername();
    final userId = await _repository.getCurrentUserId();
    final isLoggedIn = await _repository.isLoggedIn();
    final isAdmin = await _repository.isAdmin();

    if (isLoggedIn) {
      await _repository.refreshUserDetails();
    }

    final displayName = await _repository.getCurrentDisplayName();
    final avatarUrl = await _repository.getCurrentAvatarUrl();

    state = state.copyWith(
      username: username,
      userId: userId,
      displayName: displayName,
      avatarUrl: avatarUrl,
      isLoggedIn: isLoggedIn,
      isAdmin: isAdmin,
    );
  }

  /// Logs out and resets to logged-out defaults. The reset is necessary
  /// (not just belt-and-suspenders) because this notifier is NOT
  /// autoDispose'd — it persists across the whole app session, unlike the
  /// old per-screen `State` fields that used to vanish for free whenever
  /// the screen holding them was replaced after logout.
  Future<void> logout() async {
    await _repository.logout();
    state = const UserChromeState();
  }
}

final userChromeNotifierProvider =
    NotifierProvider<UserChromeNotifier, UserChromeState>(
  UserChromeNotifier.new,
);
