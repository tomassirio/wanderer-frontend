import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wanderer_frontend/core/constants/enums.dart';
import 'package:wanderer_frontend/core/providers/app_providers.dart';
import 'package:wanderer_frontend/data/client/api_client.dart';
import 'package:wanderer_frontend/data/models/user_models.dart';
import 'package:wanderer_frontend/data/repositories/profile_repository.dart';
import 'package:wanderer_frontend/data/services/user_service.dart';
import 'package:wanderer_frontend/presentation/state/profile/profile_state.dart';
import 'package:wanderer_frontend/presentation/state/user_chrome/user_chrome_notifier.dart';

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
  late UserService _userService;

  @override
  ProfileState build(String? arg) {
    _repository = ref.watch(profileRepositoryProvider);
    _userService = ref.watch(userServiceProvider);
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

  /// Seeds follower/following counts synchronously from an already-fetched
  /// [UserProfile], before the (slower) dedicated
  /// [loadSocialCounts]/network round trip resolves - matching the
  /// pre-migration `_loadProfile`'s synchronous `_followersCount`/
  /// `_followingCount` seed (from the just-fetched profile response) in the
  /// viewed-profile-loading path, so stat cards don't flash `0` while
  /// waiting. No network call, mirroring [setProfile]'s shape.
  void seedSocialCountsFromProfile(UserProfile profile) {
    state = state.copyWith(
      followersCount: profile.followersCount,
      followingCount: profile.followingCount,
    );
  }

  /// True when the profile currently displayed is the logged-in viewer's
  /// own - either no id was passed (`targetUserId == null`), or an id was
  /// passed but happens to match the viewer's own id (e.g. a self-search-
  /// result tap, or a deep link to one's own profile - see
  /// `search_screen.dart`/`user_deep_link_screen.dart`, which construct
  /// `ProfileScreen(userId: ...)` with no guard against that). Mirrors
  /// `ProfileScreen`'s pre-migration `_isViewingOwnProfile` getter exactly.
  /// Reads `UserChromeNotifier` live via `ref.read` at call time rather than
  /// a captured parameter, matching `HomeFeedNotifier`'s `_identity` getter
  /// pattern.
  bool get _isOwnProfile {
    final targetUserId = state.targetUserId;
    return targetUserId == null ||
        targetUserId == ref.read(userChromeNotifierProvider).userId;
  }

  /// Loads follower/following/friends counts, split by own-vs-viewed-profile
  /// target (mirrored via [ProfileState.targetUserId]) rather than two
  /// near-duplicate methods as in the pre-migration `_loadSocialCounts`/
  /// `_loadUserSocialCounts`.
  Future<void> loadSocialCounts() async {
    try {
      final results = state.targetUserId != null
          ? await Future.wait([
              _userService.getUserFollowers(state.targetUserId!, page: 0, size: 1),
              _userService.getUserFollowing(state.targetUserId!, page: 0, size: 1),
              _userService.getUserFriends(state.targetUserId!, page: 0, size: 1),
            ])
          : await Future.wait([
              _userService.getFollowers(page: 0, size: 1),
              _userService.getFollowing(page: 0, size: 1),
              _userService.getFriends(page: 0, size: 1),
            ]);

      state = state.copyWith(
        followersCount: results[0].totalElements,
        followingCount: results[1].totalElements,
        friendsCount: results[2].totalElements,
      );
    } catch (e) {
      // Silently fail - use profile counts as fallback, matching the
      // pre-migration behavior exactly for both the own-profile and
      // viewed-profile branches (previously two near-identical methods).
    }
  }

  /// Loads the trip list for the profile's target user (or the caller's own
  /// trips, when [_isOwnProfile] is `true` - either [ProfileState
  /// .targetUserId] is `null`, or it happens to equal the viewer's own id).
  ///
  /// Deliberately branches on [_isOwnProfile], NOT merely on whether
  /// [ProfileState.targetUserId] is non-null: `getUserTrips` is visibility-
  /// filtered (hides private trips) while `getMyTrips` returns the full
  /// list. If `targetUserId` is passed but happens to be the viewer's own
  /// id (self-search-result tap, deep link to one's own profile), the
  /// viewer's own private trips must still show via `getMyTrips` - matching
  /// pre-migration `_loadUserTrips`'s `_isViewingOwnProfile` branch exactly.
  ///
  /// Deliberately does NOT eagerly sort the fetched trips: the pre-migration
  /// `_loadUserTrips` did, using a comparator verbatim-identical to
  /// `_filteredAndSortedTrips`'s, but [ProfileState.filteredAndSortedTrips]
  /// always re-sorts on every read regardless of the underlying list's
  /// order, and nothing else reads [ProfileState.userTrips] in an
  /// order-sensitive way. So the eager sort was dead work with no
  /// observable effect - dropped here rather than ported, leaving exactly
  /// one comparator/call site instead of two.
  Future<void> loadUserTrips() async {
    state = state.copyWith(isLoadingTrips: true);

    try {
      final tripsPage = _isOwnProfile
          ? await _repository.getMyTrips(page: 0, size: 100)
          : await _repository.getUserTrips(state.targetUserId!, page: 0, size: 100);

      state = state.copyWith(userTrips: tripsPage.content, isLoadingTrips: false);
    } on AuthenticationRedirectException {
      state = state.copyWith(isLoadingTrips: false);
    } catch (e) {
      state = state.copyWith(isLoadingTrips: false);
      rethrow;
    }
  }

  void setSortOption(TripSortOption option) {
    state = state.copyWith(tripSortOption: option);
  }

  void toggleStatusFilter(TripStatus status) {
    final updated = Set<TripStatus>.from(state.selectedStatusFilters);
    if (updated.contains(status)) {
      updated.remove(status);
    } else {
      updated.add(status);
    }
    state = state.copyWith(selectedStatusFilters: updated);
  }

  void clearStatusFilters() {
    state = state.copyWith(selectedStatusFilters: {});
  }

  void toggleFilterPanel() {
    state = state.copyWith(showFilterPanel: !state.showFilterPanel);
  }
}

final profileNotifierProvider =
    NotifierProvider.autoDispose.family<ProfileNotifier, ProfileState, String?>(
  ProfileNotifier.new,
);
