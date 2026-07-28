import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wanderer_frontend/core/providers/app_providers.dart';
import 'package:wanderer_frontend/data/client/api_client.dart';
import 'package:wanderer_frontend/data/models/user_models.dart';
import 'package:wanderer_frontend/data/repositories/profile_repository.dart';
import 'package:wanderer_frontend/presentation/state/profile/profile_state.dart';

/// Owns [ProfileState] for one viewed profile (family-keyed by the viewed
/// user's id; `null` means "my own profile"). Replaces
/// `ProfileScreen`'s former `State`-held business logic, migrated
/// concern-by-concern. Distinct from and never conflated with
/// `UserChromeNotifier` (the viewer's OWN identity, app-global) - this
/// notifier is about whichever profile is currently being displayed, which
/// may belong to any user.
///
/// `autoDispose`d + family-keyed to match the per-screen-visit lifetime the
/// old `State` fields had, exactly like `TripDetailNotifier`/
/// `TripPlanDetailNotifier`.
class ProfileNotifier extends AutoDisposeFamilyNotifier<ProfileState, String?> {
  late ProfileRepository _repository;

  @override
  ProfileState build(String? arg) {
    _repository = ref.watch(profileRepositoryProvider);
    return ProfileState(targetUserId: arg);
  }

  /// Seeds the target user id. Unconditional - always applies [userId],
  /// with no "already seeded, skip" guard. See `TripDetailNotifier`'s
  /// `seedInitialTrip` history for why a guard here would be actively
  /// wrong, not just unnecessary: this notifier's family key already IS
  /// the target user id, so the only reason to call this again is a
  /// legitimate re-seed, and a guard could silently discard it.
  void seedTargetUserId(String? userId) {
    state = state.copyWith(targetUserId: userId);
  }

  Future<void> loadProfile() async {
    state = state.copyWith(isLoadingProfile: true, clearError: true);

    try {
      final profile = state.targetUserId != null
          ? await _repository.getUserProfile(state.targetUserId!)
          : await _repository.getMyProfile();

      state = state.copyWith(profile: profile, isLoadingProfile: false);
    } on AuthenticationRedirectException {
      // User is being redirected to login - don't show error.
      state = state.copyWith(isLoadingProfile: false);
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        isLoadingProfile: false,
      );
    }
  }

  /// Directly stores [profile] without calling the repository. Used by
  /// callers that already have a freshly fetched/updated [UserProfile] in
  /// hand (websocket profile-updated refresh, post-edit optimistic update)
  /// and just need it recorded - unlike [loadProfile], no network call
  /// happens here.
  void setProfile(UserProfile profile) {
    state = state.copyWith(profile: profile);
  }
}

final profileNotifierProvider =
    NotifierProvider.autoDispose.family<ProfileNotifier, ProfileState, String?>(
  ProfileNotifier.new,
);
