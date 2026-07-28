import 'package:wanderer_frontend/data/models/user_models.dart';

/// `null` sortOption/statusFilters/etc. placeholders for concerns migrated
/// by later tasks in this plan (Tasks 4-6) live in this same class, added
/// incrementally task-by-task, following `TripDetailState`'s established
/// multi-concern-in-one-state convention for a single screen's notifier.
class ProfileState {
  /// The user id this notifier is scoped to (the family key, mirrored into
  /// state for convenient reading) - `null` means "my own profile".
  final String? targetUserId;
  final UserProfile? profile;
  final bool isLoadingProfile;
  final String? error;

  const ProfileState({
    this.targetUserId,
    this.profile,
    this.isLoadingProfile = false,
    this.error,
  });

  ProfileState copyWith({
    String? targetUserId,
    UserProfile? profile,
    bool? isLoadingProfile,
    String? error,
    bool clearError = false,
  }) {
    return ProfileState(
      targetUserId: targetUserId ?? this.targetUserId,
      profile: profile ?? this.profile,
      isLoadingProfile: isLoadingProfile ?? this.isLoadingProfile,
      error: clearError ? null : (error ?? this.error),
    );
  }
}
