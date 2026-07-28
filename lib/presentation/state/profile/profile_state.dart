import 'package:wanderer_frontend/core/constants/enums.dart';
import 'package:wanderer_frontend/data/models/domain/trip.dart';
import 'package:wanderer_frontend/data/models/user_models.dart';

/// Sort options for a profile's trip list. Presentation concerns (localized
/// labels, icons) live as an extension in `profile_screen.dart` - this enum
/// itself stays presentation-agnostic, matching
/// `trip_plan_detail_state.dart`'s `EditPlacementMode` convention of a plain
/// enum living alongside its state class.
enum TripSortOption {
  statusPriority,
  nameAsc,
  nameDesc,
  newestFirst,
  oldestFirst,
}

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
  final int followersCount;
  final int followingCount;
  final int friendsCount;
  final List<Trip> userTrips;
  final bool isLoadingTrips;
  final TripSortOption tripSortOption;
  final Set<TripStatus> selectedStatusFilters;
  final bool showFilterPanel;
  final bool isFollowingUser;
  final bool isAlreadyFriends;
  final bool hasSentFriendRequest;
  final String? sentFriendRequestId;

  const ProfileState({
    this.targetUserId,
    this.profile,
    this.isLoadingProfile = false,
    this.error,
    this.followersCount = 0,
    this.followingCount = 0,
    this.friendsCount = 0,
    this.userTrips = const [],
    this.isLoadingTrips = false,
    this.tripSortOption = TripSortOption.statusPriority,
    this.selectedStatusFilters = const {},
    this.showFilterPanel = false,
    this.isFollowingUser = false,
    this.isAlreadyFriends = false,
    this.hasSentFriendRequest = false,
    this.sentFriendRequestId,
  });

  ProfileState copyWith({
    String? targetUserId,
    UserProfile? profile,
    bool? isLoadingProfile,
    String? error,
    bool clearError = false,
    int? followersCount,
    int? followingCount,
    int? friendsCount,
    List<Trip>? userTrips,
    bool? isLoadingTrips,
    TripSortOption? tripSortOption,
    Set<TripStatus>? selectedStatusFilters,
    bool? showFilterPanel,
    bool? isFollowingUser,
    bool? isAlreadyFriends,
    bool? hasSentFriendRequest,
    String? sentFriendRequestId,
    bool clearSentFriendRequestId = false,
  }) {
    return ProfileState(
      targetUserId: targetUserId ?? this.targetUserId,
      profile: profile ?? this.profile,
      isLoadingProfile: isLoadingProfile ?? this.isLoadingProfile,
      error: clearError ? null : (error ?? this.error),
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      friendsCount: friendsCount ?? this.friendsCount,
      userTrips: userTrips ?? this.userTrips,
      isLoadingTrips: isLoadingTrips ?? this.isLoadingTrips,
      tripSortOption: tripSortOption ?? this.tripSortOption,
      selectedStatusFilters: selectedStatusFilters ?? this.selectedStatusFilters,
      showFilterPanel: showFilterPanel ?? this.showFilterPanel,
      isFollowingUser: isFollowingUser ?? this.isFollowingUser,
      isAlreadyFriends: isAlreadyFriends ?? this.isAlreadyFriends,
      hasSentFriendRequest: hasSentFriendRequest ?? this.hasSentFriendRequest,
      sentFriendRequestId: clearSentFriendRequestId
          ? null
          : (sentFriendRequestId ?? this.sentFriendRequestId),
    );
  }

  /// The single comparator for [TripSortOption.statusPriority], matching the
  /// pre-migration `_filteredAndSortedTrips` getter's comparator exactly.
  ///
  /// The pre-migration `_loadUserTrips` ran a verbatim-identical copy of this
  /// same comparator eagerly at load time. That eager sort was redundant:
  /// `_filteredAndSortedTrips` (now [filteredAndSortedTrips]) always
  /// re-sorts on every read regardless of what order the underlying list is
  /// in, and no other reader of the raw trip list (stat cards, trip counts,
  /// the per-status counts used for filter pills) is order-sensitive. So
  /// this migration drops the eager sort in `ProfileNotifier.loadUserTrips`
  /// entirely instead of porting it - one comparator, one call site, same
  /// observable output. Kept private (single-file use only), avoiding the
  /// cross-file Dart-library-privacy wrinkle a second call site would have
  /// required.
  static int _compareByStatusPriority(Trip a, Trip b) {
    const statusPriority = {
      TripStatus.inProgress: 0,
      TripStatus.paused: 1,
      TripStatus.resting: 2,
      TripStatus.created: 3,
      TripStatus.finished: 4,
    };
    final priorityA = statusPriority[a.status] ?? 5;
    final priorityB = statusPriority[b.status] ?? 5;
    if (priorityA != priorityB) {
      return priorityA.compareTo(priorityB);
    }
    return b.updatedAt.compareTo(a.updatedAt);
  }

  /// The filtered and sorted list of user trips based on the current sort
  /// option and status filters.
  List<Trip> get filteredAndSortedTrips {
    var trips = List<Trip>.from(userTrips);

    if (selectedStatusFilters.isNotEmpty) {
      trips = trips.where((t) => selectedStatusFilters.contains(t.status)).toList();
    }

    switch (tripSortOption) {
      case TripSortOption.statusPriority:
        trips.sort(_compareByStatusPriority);
        break;
      case TripSortOption.nameAsc:
        trips.sort((a, b) => a.name.compareTo(b.name));
        break;
      case TripSortOption.nameDesc:
        trips.sort((a, b) => b.name.compareTo(a.name));
        break;
      case TripSortOption.newestFirst:
        trips.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case TripSortOption.oldestFirst:
        trips.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
    }

    return trips;
  }
}
