import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/data/client/api_client.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/data/models/user_models.dart';
import 'package:wanderer_frontend/data/repositories/profile_repository.dart';
import 'package:wanderer_frontend/data/services/user_service.dart';
import 'package:wanderer_frontend/presentation/helpers/dialog_helper.dart';
import 'package:wanderer_frontend/presentation/helpers/ui_helpers.dart';
import 'package:wanderer_frontend/presentation/helpers/page_transitions.dart';
import 'package:wanderer_frontend/presentation/widgets/common/wanderer_app_bar.dart';
import 'package:wanderer_frontend/presentation/widgets/common/app_sidebar.dart';
import 'package:wanderer_frontend/core/constants/api_endpoints.dart';
import '../../core/constants/enums.dart';
import '../../data/client/google_maps_api_client.dart';
import '../helpers/trip_route_helper.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'auth_screen.dart';
import 'home_screen.dart';
import 'settings_screen.dart';
import 'trip_detail_screen.dart';
import 'friends_followers_screen.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';

/// Returns a localized label for a [TripStatus] using the current locale.
String _localizedTripStatus(TripStatus status, AppLocalizations l10n) {
  switch (status) {
    case TripStatus.created:
      return l10n.draft;
    case TripStatus.inProgress:
      return l10n.live;
    case TripStatus.paused:
      return l10n.paused;
    case TripStatus.finished:
      return l10n.completed;
    case TripStatus.resting:
      return l10n.resting;
  }
}

/// Sort options for trips in the profile
enum TripSortOption {
  statusPriority,
  nameAsc,
  nameDesc,
  newestFirst,
  oldestFirst;

  String labelFor(AppLocalizations l10n) {
    switch (this) {
      case TripSortOption.statusPriority:
        return l10n.sortOptionStatus;
      case TripSortOption.nameAsc:
        return l10n.sortOptionNameAZ;
      case TripSortOption.nameDesc:
        return l10n.sortOptionNameZA;
      case TripSortOption.newestFirst:
        return l10n.sortOptionNewest;
      case TripSortOption.oldestFirst:
        return l10n.sortOptionOldest;
    }
  }

  IconData get icon {
    switch (this) {
      case TripSortOption.statusPriority:
        return Icons.priority_high;
      case TripSortOption.nameAsc:
        return Icons.sort_by_alpha;
      case TripSortOption.nameDesc:
        return Icons.sort_by_alpha;
      case TripSortOption.newestFirst:
        return Icons.arrow_downward;
      case TripSortOption.oldestFirst:
        return Icons.arrow_upward;
    }
  }
}

/// User profile screen showing user information, statistics, and trips
class ProfileScreen extends StatefulWidget {
  final String? userId;

  const ProfileScreen({super.key, this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ProfileRepository _repository = ProfileRepository();
  final UserService _userService = UserService();
  UserProfile? _profile;
  List<Trip> _userTrips = [];
  bool _isLoadingProfile = false;
  bool _isLoadingTrips = false;
  String? _error;
  bool _isLoggedIn = false;
  bool _isAdmin = false;
  bool _hasSentFriendRequest =
      false; // Track if friend request was sent locally
  bool _isAlreadyFriends = false; // Track if already friends with user
  bool _isFollowingUser = false; // Track if following this user
  String? _sentFriendRequestId; // Store the request ID for cancellation
  String? _currentUserId; // Track the logged-in user's ID
  String? _currentUsername; // Track the logged-in user's username
  String? _currentDisplayName; // Track the logged-in user's display name
  String? _currentAvatarUrl; // Track the logged-in user's avatar URL
  final int _selectedSidebarIndex = 4; // Profile is index 4

  // Actual counts loaded from API (for own profile)
  int _followersCount = 0;
  int _followingCount = 0;
  int _friendsCount = 0;

  // Sorting and filtering
  TripSortOption _tripSortOption = TripSortOption.statusPriority;
  final Set<TripStatus> _selectedStatusFilters = {}; // empty = show all
  bool _showFilterPanel = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    super.dispose();
  }

  /// Check if viewing own profile (either no userId passed, or userId matches current user)
  bool get _isViewingOwnProfile =>
      widget.userId == null ||
      (widget.userId != null && widget.userId == _currentUserId);

  /// Get the filtered and sorted list of user trips based on the current
  /// sort option and upcoming trips filter.
  List<Trip> get _filteredAndSortedTrips {
    var trips = List<Trip>.from(_userTrips);

    // Filter by selected statuses (empty = show all)
    if (_selectedStatusFilters.isNotEmpty) {
      trips = trips
          .where((t) => _selectedStatusFilters.contains(t.status))
          .toList();
    }

    // Sort the trips based on the selected sort option
    switch (_tripSortOption) {
      case TripSortOption.statusPriority:
        trips.sort((a, b) {
          const statusPriority = {
            TripStatus.inProgress: 0,
            TripStatus.paused: 1,
            TripStatus.resting: 2,
            TripStatus.created: 3,
            TripStatus.finished: 4,
          };
          final priorityA = statusPriority[a.status] ?? 5;
          final priorityB = statusPriority[b.status] ?? 5;
          if (priorityA != priorityB) return priorityA.compareTo(priorityB);
          return b.updatedAt.compareTo(a.updatedAt);
        });
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

  Future<void> _loadProfile() async {
    setState(() {
      _isLoadingProfile = true;
      _error = null;
    });

    try {
      final isLoggedIn = await _repository.isLoggedIn();
      final isAdmin = await _repository.isAdmin();
      setState(() {
        _isLoggedIn = isLoggedIn;
        _isAdmin = isAdmin;
      });

      // If viewing another user's profile and not logged in, redirect to auth
      if (widget.userId != null && !isLoggedIn) {
        setState(() {
          _isLoadingProfile = false;
        });
        // Navigate to auth screen - use push so user can go back
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AuthScreen()),
          ).then((_) {
            // Reload profile after returning from auth
            if (mounted) {
              _loadProfile();
            }
          });
        }
        return;
      }

      // Load current user ID and username if logged in (needed to determine if viewing own profile and for AppBar/Sidebar)
      if (isLoggedIn) {
        try {
          final currentUser = await _repository.getMyProfile();
          setState(() {
            _currentUserId = currentUser.id;
            _currentUsername = currentUser.username;
            _currentDisplayName = currentUser.displayName;
            _currentAvatarUrl = currentUser.avatarUrl;
          });
        } catch (e) {
          // Ignore error loading current user
        }
      }

      // If viewing another user's profile
      if (widget.userId != null) {
        final profile = await _repository.getUserProfile(widget.userId!);
        setState(() {
          _profile = profile;
          _followersCount = profile.followersCount;
          _followingCount = profile.followingCount;
          _isLoadingProfile = false;
        });

        // Load user's trips
        _loadUserTrips(profile.id);

        // Load the viewed user's actual social counts
        if (isLoggedIn) {
          await _loadUserSocialCounts(profile.id);
        }

        // Only load friendship status if viewing someone else's profile
        if (isLoggedIn && widget.userId != _currentUserId) {
          await _loadFriendshipStatus(profile.id);
        }
        return;
      }

      // Viewing own profile
      if (!isLoggedIn) {
        setState(() {
          _isLoadingProfile = false;
          _error = 'You must be logged in to view your profile';
        });
        return;
      }

      final profile = await _repository.getMyProfile();
      setState(() {
        _profile = profile;
        _isLoadingProfile = false;
      });

      // Load user's trips and social counts
      _loadUserTrips(profile.id);
      await _loadSocialCounts();
    } on AuthenticationRedirectException {
      // User is being redirected to login - don't show error
      if (mounted) {
        setState(() {
          _isLoadingProfile = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoadingProfile = false;
      });
    }
  }

  /// Load follower, following, and friends counts from API (for own profile)
  Future<void> _loadSocialCounts() async {
    try {
      final results = await Future.wait([
        _userService.getFollowers(),
        _userService.getFollowing(),
        _userService.getFriends(),
      ]);

      if (mounted) {
        setState(() {
          _followersCount = (results[0] as List).length;
          _followingCount = (results[1] as List).length;
          _friendsCount = (results[2] as List).length;
        });
      }
    } catch (e) {
      // Silently fail - use profile counts as fallback
      debugPrint('Failed to load social counts: $e');
    }
  }

  /// Load follower, following, and friends counts for another user
  Future<void> _loadUserSocialCounts(String userId) async {
    try {
      final results = await Future.wait([
        _userService.getUserFollowers(userId),
        _userService.getUserFollowing(userId),
        _userService.getUserFriends(userId),
      ]);

      if (mounted) {
        setState(() {
          _followersCount = (results[0] as List).length;
          _followingCount = (results[1] as List).length;
          _friendsCount = (results[2] as List).length;
        });
      }
    } catch (e) {
      // Silently fail - keep counts from profile response as fallback
      debugPrint('Failed to load user social counts: $e');
    }
  }

  /// Load friendship and follow status when viewing another user's profile
  Future<void> _loadFriendshipStatus(String userId) async {
    try {
      // Check if already following this user
      final following = await _userService.getFollowing();
      final isFollowing = following.any((f) => f.followedId == userId);

      // Check if already friends
      final friends = await _userService.getFriends();
      final isAlreadyFriends = friends.any((f) => f.friendId == userId);

      // Check if already sent a friend request
      final sentRequests = await _userService.getSentFriendRequests();
      final pendingRequest = sentRequests.cast<FriendRequest?>().firstWhere(
            (r) =>
                r!.receiverId == userId &&
                r.status == FriendRequestStatus.pending,
            orElse: () => null,
          );
      final hasSentRequest = pendingRequest != null;
      final requestId = pendingRequest?.id;

      if (mounted) {
        setState(() {
          _isFollowingUser = isFollowing;
          _isAlreadyFriends = isAlreadyFriends;
          _hasSentFriendRequest = hasSentRequest;
          _sentFriendRequestId = requestId;
        });
      }
    } catch (e) {
      // Silently fail - social features are optional
      debugPrint('Failed to load friendship status: $e');
    }
  }

  Future<void> _loadUserTrips(String userId) async {
    setState(() {
      _isLoadingTrips = true;
    });

    try {
      final trips = _isViewingOwnProfile
          ? await _repository.getMyTrips()
          : await _repository.getUserTrips(userId);
      // Sort: ongoing trips first (inProgress > paused > resting > created > finished)
      trips.sort((a, b) {
        const statusPriority = {
          TripStatus.inProgress: 0,
          TripStatus.paused: 1,
          TripStatus.resting: 2,
          TripStatus.created: 3,
          TripStatus.finished: 4,
        };
        final priorityA = statusPriority[a.status] ?? 5;
        final priorityB = statusPriority[b.status] ?? 5;
        if (priorityA != priorityB) return priorityA.compareTo(priorityB);
        // Within same status, sort by most recently updated
        return b.updatedAt.compareTo(a.updatedAt);
      });
      setState(() {
        _userTrips = trips;
        _isLoadingTrips = false;
      });
    } on AuthenticationRedirectException {
      // User is being redirected to login - don't show error
      if (mounted) {
        setState(() {
          _isLoadingTrips = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingTrips = false;
      });
      if (mounted) {
        UiHelpers.showErrorMessage(context, 'Failed to load trips: $e');
      }
    }
  }

  Future<void> _logout() async {
    final confirm = await DialogHelper.showLogoutConfirmation(context);

    if (confirm) {
      await _repository.logout();
      if (mounted) {
        // Navigate to home screen and clear navigation stack
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      }
    }
  }

  void _handleSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
  }

  Future<void> _navigateToAuth() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AuthScreen()),
    );

    if (result == true || mounted) {
      await _loadProfile();
    }
  }

  void _navigateToTripDetail(Trip trip) {
    Navigator.push(
      context,
      PageTransitions.slideUp(TripDetailScreen(trip: trip)),
    );
  }

  void _navigateToFriendsFollowers() {
    Navigator.push(
      context,
      PageTransitions.slideUp(const FriendsFollowersScreen()),
    );
  }

  Future<void> _showEditProfileDialog() async {
    if (_profile == null) return;

    final l10n = context.l10n;

    final displayNameController = TextEditingController(
      text: _profile!.displayName,
    );
    final bioController = TextEditingController(text: _profile!.bio);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.editProfile),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: displayNameController,
                decoration: InputDecoration(
                  labelText: l10n.displayName,
                  hintText: l10n.yourDisplayName,
                ),
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: bioController,
                decoration: InputDecoration(
                  labelText: l10n.bio,
                  hintText: l10n.tellUsAboutYourself,
                ),
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => Navigator.pop(context, true),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.save),
          ),
        ],
      ),
    );

    if (result == true) {
      await _updateProfile(
        displayNameController.text,
        bioController.text,
      );
    }

    displayNameController.dispose();
    bioController.dispose();
  }

  Future<void> _handleFollowUser() async {
    if (_profile == null) return;
    final l10n = context.l10n;

    // Toggle between follow and unfollow
    if (_isFollowingUser) {
      try {
        await _userService.unfollowUser(_profile!.id);
        setState(() {
          _isFollowingUser = false;
        });
        if (mounted) {
          UiHelpers.showSuccessMessage(
              context, l10n.unfollowedUser(_profile!.username));
        }
      } catch (e) {
        if (mounted) {
          UiHelpers.showErrorMessage(context, 'Failed to unfollow user: $e');
        }
      }
    } else {
      try {
        await _userService.followUser(_profile!.id);
        setState(() {
          _isFollowingUser = true;
        });
        if (mounted) {
          UiHelpers.showSuccessMessage(
              context, l10n.nowFollowingUser(_profile!.username));
        }
      } catch (e) {
        if (mounted) {
          UiHelpers.showErrorMessage(context, 'Failed to follow user: $e');
        }
      }
    }
  }

  Future<void> _handleSendFriendRequest() async {
    if (_profile == null) return;
    final l10n = context.l10n;

    // If already friends, allow unfriending
    if (_isAlreadyFriends) {
      try {
        await _userService.removeFriend(_profile!.id);
        setState(() {
          _isAlreadyFriends = false;
        });
        if (mounted) {
          UiHelpers.showSuccessMessage(
              context, l10n.noLongerFriendsWith(_profile!.username));
        }
      } catch (e) {
        if (mounted) {
          UiHelpers.showErrorMessage(context, 'Failed to remove friend: $e');
        }
      }
      return;
    }

    // Cancel existing friend request
    if (_hasSentFriendRequest && _sentFriendRequestId != null) {
      try {
        await _userService.deleteFriendRequest(_sentFriendRequestId!);
        setState(() {
          _hasSentFriendRequest = false;
          _sentFriendRequestId = null;
        });
        if (mounted) {
          UiHelpers.showSuccessMessage(
              context, l10n.friendRequestCancelled);
        }
      } catch (e) {
        if (mounted) {
          UiHelpers.showErrorMessage(
              context, 'Failed to cancel friend request: $e');
        }
      }
      return;
    }

    // Send new friend request
    try {
      final requestId = await _userService.sendFriendRequest(_profile!.id);
      setState(() {
        _hasSentFriendRequest = true;
        _sentFriendRequestId = requestId;
      });
      if (mounted) {
        UiHelpers.showSuccessMessage(
            context, l10n.friendRequestSentTo(_profile!.username));
      }
    } catch (e) {
      if (mounted) {
        UiHelpers.showErrorMessage(
            context, 'Failed to send friend request: $e');
      }
    }
  }

  Future<void> _updateProfile(
    String displayName,
    String bio,
  ) async {
    try {
      final request = UpdateProfileRequest(
        displayName: displayName.isEmpty ? null : displayName,
        bio: bio.isEmpty ? null : bio,
      );

      // PATCH returns 202 Accepted with just a UUID
      await _repository.updateProfile(request);

      // Re-fetch profile to get the updated data
      try {
        final refreshedProfile = await _repository.getMyProfile();
        // Save updated details to local storage for sidebar/appbar
        await _repository.refreshUserDetails();
        setState(() {
          _profile = refreshedProfile;
          _currentDisplayName = refreshedProfile.displayName;
          _currentAvatarUrl = refreshedProfile.avatarUrl;
        });
      } catch (_) {
        // If re-fetch fails, optimistically update local state
        // with the values the user just submitted
        if (_profile != null) {
          setState(() {
            _profile = UserProfile(
              id: _profile!.id,
              username: _profile!.username,
              email: _profile!.email,
              displayName: displayName.isEmpty ? null : displayName,
              bio: bio.isEmpty ? null : bio,
              avatarUrl: _profile!.avatarUrl,
              followersCount: _profile!.followersCount,
              followingCount: _profile!.followingCount,
              friendsCount: _profile!.friendsCount,
              tripsCount: _profile!.tripsCount,
              isFollowing: _profile!.isFollowing,
              createdAt: _profile!.createdAt,
            );
            _currentDisplayName = displayName.isEmpty ? null : displayName;
          });
        }
      }

      if (mounted) {
        UiHelpers.showSuccessMessage(
            context, context.l10n.profileUpdatedSuccessfully);
      }
    } catch (e) {
      if (mounted) {
        UiHelpers.showErrorMessage(
            context, context.l10n.failedToUpdateProfile);
      }
    }
  }

  Future<void> _handleAvatarUpload() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image == null) return;

      // Check file size (5MB max)
      final fileSize = await image.length();
      if (fileSize > 5 * 1024 * 1024) {
        if (mounted) {
          UiHelpers.showErrorMessage(
            context,
            'Image too large. Maximum size is 5MB.',
          );
        }
        return;
      }

      final bytes = await image.readAsBytes();
      await _repository.uploadAvatar(bytes, image.name);

      // Refresh profile to get new avatar URL
      final refreshedProfile = await _repository.getMyProfile();
      await _repository.refreshUserDetails();

      setState(() {
        _profile = refreshedProfile;
        _currentAvatarUrl = refreshedProfile.avatarUrl;
      });

      if (mounted) {
        UiHelpers.showSuccessMessage(context, 'Avatar updated successfully!');
      }
    } catch (e) {
      if (mounted) {
        UiHelpers.showErrorMessage(context, 'Failed to upload avatar: $e');
      }
    }
  }

  Future<void> _handleAvatarDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Avatar'),
        content:
            const Text('Are you sure you want to delete your profile picture?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _repository.deleteAvatar();

      // Refresh profile
      final refreshedProfile = await _repository.getMyProfile();
      await _repository.refreshUserDetails();

      setState(() {
        _profile = refreshedProfile;
        _currentAvatarUrl = null;
      });

      if (mounted) {
        UiHelpers.showSuccessMessage(context, 'Avatar deleted successfully!');
      }
    } catch (e) {
      if (mounted) {
        UiHelpers.showErrorMessage(context, 'Failed to delete avatar: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: WandererAppBar(
        isLoggedIn: _isLoggedIn,
        onLoginPressed: _navigateToAuth,
        username: _currentUsername,
        userId: _currentUserId,
        displayName: _currentDisplayName,
        avatarUrl: _currentAvatarUrl,
        onProfile: () {},
        onSettings: _handleSettings,
        onLogout: _logout,
      ),
      drawer: AppSidebar(
        username: _currentUsername,
        userId: _currentUserId,
        displayName: _currentDisplayName,
        avatarUrl: _currentAvatarUrl,
        selectedIndex: _selectedSidebarIndex,
        onLogout: _logout,
        onSettings: _handleSettings,
        isAdmin: _isAdmin,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final l10n = context.l10n;
    if (_isLoadingProfile) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              !_isLoggedIn
                  ? l10n.mustBeLoggedInToViewProfile
                  : _error!,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            if (!_isLoggedIn) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _navigateToAuth,
                child: Text(l10n.login),
              ),
            ],
          ],
        ),
      );
    }

    if (_profile == null) {
      return Center(child: Text(l10n.noProfileData));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProfileHeader(),
          const SizedBox(height: 24),
          _buildStatsRow(),
          const SizedBox(height: 24),
          _buildTripsSection(),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    final l10n = context.l10n;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 500;

            final userInfoSection = Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAvatarWidget(),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              _profile!.displayName ?? _profile!.username,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (_isFollowingUser && !_isViewingOwnProfile) ...[
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.person_add_alt_1,
                              size: 20,
                              color: Colors.blue,
                            ),
                          ],
                          if (!isWide) ...[
                            const Spacer(),
                            _buildActionButtons(),
                          ],
                        ],
                      ),
                      Text(
                        '@${_profile!.username}',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 4),
                      SelectableText(
                        _profile!.id,
                        style: TextStyle(
                          fontSize: 11,
                          color: primaryColor.withValues(alpha: 0.8),
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );

            final bioSection = Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: primaryColor.withValues(alpha: 0.25),
                ),
              ),
              constraints: const BoxConstraints(minHeight: 60),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _profile!.bio != null && _profile!.bio!.isNotEmpty
                        ? Text(
                            _profile!.bio!,
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.grey[800],
                              height: 1.4,
                            ),
                          )
                        : Text(
                            _isViewingOwnProfile
                                ? l10n.tapPencilToAddBio
                                : l10n.noBioYet,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[400],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                  ),
                  if (isWide) _buildActionButtons(),
                ],
              ),
            );

            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: constraints.maxWidth * 0.35,
                    child: userInfoSection,
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: bioSection),
                ],
              );
            } else {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  userInfoSection,
                  const SizedBox(height: 12),
                  bioSection,
                ],
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildAvatarWidget() {
    if (!_isViewingOwnProfile) {
      // For other users, just show the avatar
      return CircleAvatar(
        radius: 40,
        backgroundImage: _profile!.avatarUrl != null
            ? NetworkImage(
                ApiEndpoints.resolveThumbnailUrl(_profile!.avatarUrl))
            : null,
        child: _profile!.avatarUrl == null
            ? Text(
                _profile!.username.substring(0, 1).toUpperCase(),
                style: const TextStyle(fontSize: 32),
              )
            : null,
      );
    }

    // For own profile, make it clickable with hover effect
    bool isHovering = false;
    return StatefulBuilder(
      builder: (context, setState) {
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => isHovering = true),
          onExit: (_) => setState(() => isHovering = false),
          child: GestureDetector(
            onTap: () {
              if (_profile!.avatarUrl != null) {
                // Show options: change or delete
                showModalBottomSheet(
                  context: context,
                  builder: (context) => SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.photo_camera),
                          title: const Text('Change Avatar'),
                          onTap: () {
                            Navigator.pop(context);
                            _handleAvatarUpload();
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.delete, color: Colors.red),
                          title: const Text('Delete Avatar',
                              style: TextStyle(color: Colors.red)),
                          onTap: () {
                            Navigator.pop(context);
                            _handleAvatarDelete();
                          },
                        ),
                      ],
                    ),
                  ),
                );
              } else {
                // No avatar, just upload
                _handleAvatarUpload();
              }
            },
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundImage: _profile!.avatarUrl != null
                      ? NetworkImage(
                          ApiEndpoints.resolveThumbnailUrl(_profile!.avatarUrl))
                      : null,
                  child: _profile!.avatarUrl == null
                      ? Text(
                          _profile!.username.substring(0, 1).toUpperCase(),
                          style: const TextStyle(fontSize: 32),
                        )
                      : null,
                ),
                // Hover overlay with camera icon
                if (isHovering)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withOpacity(0.5),
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButtons() {
    final l10n = context.l10n;
    if (_isViewingOwnProfile) {
      return IconButton(
        icon: const Icon(Icons.edit),
        onPressed: _showEditProfileDialog,
        tooltip: l10n.editProfile,
        iconSize: 20,
      );
    } else {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              _isFollowingUser ? Icons.person_remove : Icons.person_add,
            ),
            onPressed: _handleFollowUser,
            tooltip: _isFollowingUser ? l10n.unfollow : l10n.follow,
            color: _isFollowingUser ? Colors.blue : null,
            iconSize: 20,
          ),
          IconButton(
            icon: Icon(
              _isAlreadyFriends
                  ? Icons.people
                  : _hasSentFriendRequest
                      ? Icons.person_add_disabled
                      : Icons.person_add_alt,
            ),
            onPressed: _handleSendFriendRequest,
            tooltip: _isAlreadyFriends
                ? l10n.unfriend
                : _hasSentFriendRequest
                    ? l10n.cancelFriendRequest
                    : l10n.sendFriendRequest,
            color: _isAlreadyFriends
                ? Colors.green
                : _hasSentFriendRequest
                    ? Colors.orange
                    : null,
            iconSize: 20,
          ),
        ],
      );
    }
  }

  Widget _buildStatsRow() {
    final l10n = context.l10n;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStatCard(l10n.trips, _userTrips.length.toString(), null),
        _buildStatCard(l10n.followers, _followersCount.toString(),
            _isViewingOwnProfile ? _navigateToFriendsFollowers : null),
        _buildStatCard(l10n.following, _followingCount.toString(),
            _isViewingOwnProfile ? _navigateToFriendsFollowers : null),
        _buildStatCard(l10n.friends, _friendsCount.toString(),
            _isViewingOwnProfile ? _navigateToFriendsFollowers : null),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, VoidCallback? onTap) {
    final card = Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );

    return Expanded(
      child: onTap != null
          ? InkWell(
              onTap: onTap,
              child: card,
            )
          : card,
    );
  }

  Widget _buildTripsSection() {
    final l10n = context.l10n;
    final filtered = _filteredAndSortedTrips;
    final hasActiveFilters = _selectedStatusFilters.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.backpack_rounded,
                  size: 22,
                  color: WandererTheme.primaryOrange,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.myTripsLabel(_isViewingOwnProfile),
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            if (_userTrips.isNotEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: WandererTheme.primaryOrange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  hasActiveFilters
                      ? '${filtered.length} of ${_userTrips.length}'
                      : l10n.tripCountLabel(_userTrips.length),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: WandererTheme.primaryOrange,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        // Sort + filter controls
        if (_userTrips.isNotEmpty) ...[
          _buildSortAndFilterControls(),
          const SizedBox(height: 12),
        ],
        if (_isLoadingTrips)
          const Center(child: CircularProgressIndicator())
        else if (_userTrips.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(l10n.noTripsYet),
            ),
          )
        else if (filtered.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(Icons.filter_list_off,
                      size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  Text(
                    l10n.noTripsMatchFilters,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () =>
                        setState(() => _selectedStatusFilters.clear()),
                    child: Text(l10n.clearFilters),
                  ),
                ],
              ),
            ),
          )
        else
          ...filtered.map(
            (trip) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildTripCard(trip),
            ),
          ),
        // Extra bottom padding so the last card is fully visible
        const SizedBox(height: 16),
      ],
    );
  }

  /// Builds a stylish sort & filter control bar with glassmorphism design.
  Widget _buildSortAndFilterControls() {
    final hasActiveFilters = _selectedStatusFilters.isNotEmpty;
    final activeFilterCount = _selectedStatusFilters.length;

    return Container(
      decoration: WandererTheme.glassDecoration(
        radius: WandererTheme.glassRadiusSmall,
        shadow: WandererTheme.cardShadow,
        backgroundColor: WandererTheme.glassBackgroundFor(context),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // Compact toolbar row: Sort dropdown + Filter toggle
          Row(
            children: [
              // Sort dropdown button
              Expanded(
                child: _buildSortDropdown(),
              ),
              const SizedBox(width: 8),
              // Filter toggle button with badge
              _buildFilterToggleButton(hasActiveFilters, activeFilterCount),
            ],
          ),
          // Animated filter panel
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _buildStatusFilterPills(),
            ),
            crossFadeState: _showFilterPanel
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
            sizeCurve: Curves.easeInOut,
          ),
        ],
      ),
    );
  }

  /// A sleek dropdown-style sort button.
  Widget _buildSortDropdown() {
    final l10n = context.l10n;
    return InkWell(
      onTap: () => _showSortBottomSheet(),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: WandererTheme.primaryOrange.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: WandererTheme.primaryOrange.withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            Icon(
              _tripSortOption.icon,
              size: 16,
              color: WandererTheme.primaryOrange,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _tripSortOption.labelFor(l10n),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.unfold_more_rounded,
              size: 16,
              color: WandererTheme.primaryOrange.withOpacity(0.7),
            ),
          ],
        ),
      ),
    );
  }

  /// Shows a bottom sheet with sort options.
  void _showSortBottomSheet() {
    final l10n = context.l10n;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        final sheetBg =
            isDark ? const Color(0xFF1E1E1E) : WandererTheme.backgroundCard;
        final handleColor = isDark ? Colors.grey[600] : Colors.grey[300];
        final titleColor = theme.colorScheme.onSurface;
        final unselectedTextColor = theme.colorScheme.onSurface;
        final unselectedIconColor =
            isDark ? Colors.grey[400] : Colors.grey[500];

        return Container(
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: handleColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Icon(Icons.sort_rounded,
                        size: 20, color: WandererTheme.primaryOrange),
                    const SizedBox(width: 8),
                    Text(
                      l10n.sortTripsBy,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: titleColor,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ...TripSortOption.values.map((option) {
                final isSelected = _tripSortOption == option;
                return ListTile(
                  leading: Icon(
                    option.icon,
                    color: isSelected
                        ? WandererTheme.primaryOrange
                        : unselectedIconColor,
                    size: 20,
                  ),
                  title: Text(
                    option.labelFor(l10n),
                    style: TextStyle(
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected
                          ? WandererTheme.primaryOrange
                          : unselectedTextColor,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle_rounded,
                          color: WandererTheme.primaryOrange, size: 20)
                      : null,
                  onTap: () {
                    setState(() => _tripSortOption = option);
                    Navigator.pop(context);
                  },
                  dense: true,
                  visualDensity: VisualDensity.compact,
                );
              }),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  /// A filter toggle button with an animated badge.
  Widget _buildFilterToggleButton(bool hasActive, int count) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inactiveIconColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _showFilterPanel = !_showFilterPanel),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: hasActive
                ? WandererTheme.primaryOrange.withOpacity(0.12)
                : Colors.grey.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: hasActive
                  ? WandererTheme.primaryOrange.withOpacity(0.3)
                  : Colors.grey.withOpacity(0.2),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _showFilterPanel
                    ? Icons.filter_list_off_rounded
                    : Icons.filter_list_rounded,
                size: 16,
                color:
                    hasActive ? WandererTheme.primaryOrange : inactiveIconColor,
              ),
              if (hasActive) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: WandererTheme.primaryOrange,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Builds pill-shaped status filter buttons.
  Widget _buildStatusFilterPills() {
    final l10n = context.l10n;
    // Gather statuses that have trips
    final statusCounts = <TripStatus, int>{};
    for (final trip in _userTrips) {
      statusCounts[trip.status] = (statusCounts[trip.status] ?? 0) + 1;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Clear all button row
        if (_selectedStatusFilters.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GestureDetector(
              onTap: () => setState(() => _selectedStatusFilters.clear()),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.close_rounded,
                      size: 14, color: WandererTheme.primaryOrange),
                  const SizedBox(width: 4),
                  Text(
                    l10n.clearAllFilters,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: WandererTheme.primaryOrange,
                    ),
                  ),
                ],
              ),
            ),
          ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: TripStatus.values
              .where((s) => (statusCounts[s] ?? 0) > 0)
              .map((status) {
            final isSelected = _selectedStatusFilters.contains(status);
            final count = statusCounts[status]!;
            final statusColor = _getStatusChipColor(status);

            return GestureDetector(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _selectedStatusFilters.remove(status);
                  } else {
                    _selectedStatusFilters.add(status);
                  }
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color:
                      isSelected ? statusColor : statusColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color:
                        isSelected ? statusColor : statusColor.withOpacity(0.3),
                    width: 1.5,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: statusColor.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getStatusIcon(status),
                      size: 14,
                      color: isSelected ? Colors.white : statusColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _localizedTripStatus(status, l10n),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : statusColor.withOpacity(0.9),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white.withOpacity(0.25)
                            : statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  /// Returns an icon for each trip status.
  IconData _getStatusIcon(TripStatus status) {
    switch (status) {
      case TripStatus.created:
        return Icons.edit_note_rounded;
      case TripStatus.inProgress:
        return Icons.directions_walk_rounded;
      case TripStatus.paused:
        return Icons.pause_circle_outline_rounded;
      case TripStatus.finished:
        return Icons.check_circle_outline_rounded;
      case TripStatus.resting:
        return Icons.hotel_rounded;
    }
  }

  Color _getStatusChipColor(TripStatus status) {
    switch (status) {
      case TripStatus.created:
        return Colors.grey;
      case TripStatus.inProgress:
        return Colors.blue;
      case TripStatus.paused:
        return Colors.orange;
      case TripStatus.finished:
        return Colors.green;
      case TripStatus.resting:
        return WandererTheme.statusResting;
    }
  }

  Widget _buildTripCard(Trip trip) {
    return ProfileTripCard(
      trip: trip,
      onTap: () => _navigateToTripDetail(trip),
    );
  }
}

/// Trip card for profile screen with mini map
class ProfileTripCard extends StatefulWidget {
  final Trip trip;
  final VoidCallback onTap;

  const ProfileTripCard({super.key, required this.trip, required this.onTap});

  @override
  State<ProfileTripCard> createState() => _ProfileTripCardState();
}

class _ProfileTripCardState extends State<ProfileTripCard> {
  String? _encodedPolyline;
  late final GoogleMapsApiClient _mapsClient;

  @override
  void initState() {
    super.initState();
    final apiKey = ApiEndpoints.googleMapsApiKey;
    _mapsClient = GoogleMapsApiClient(apiKey);
    _loadRoute();
  }

  /// Load the encoded polyline for the miniature map using the shared
  /// [TripRouteHelper]. Uses the backend-provided polyline, in-memory cache,
  /// or encodes raw sorted points as straight-line fallback.
  void _loadRoute() {
    final encoded = TripRouteHelper.fetchEncodedPolyline(widget.trip);
    if (mounted && encoded != null) {
      setState(() {
        _encodedPolyline = encoded;
      });
    }
  }

  /// Generate static map image URL from Google Maps Static API
  String _generateStaticMapUrl() {
    final sorted = TripRouteHelper.getSortedLocations(widget.trip);
    if (sorted.isEmpty) {
      return '';
    }

    final firstLoc = sorted.first;
    final lastLoc = sorted.last;

    if (sorted.length == 1) {
      // Single location
      return _mapsClient.generateStaticMapUrl(
        center: LatLng(firstLoc.latitude, firstLoc.longitude),
        markers: [
          MapMarker(
            position: LatLng(firstLoc.latitude, firstLoc.longitude),
            color: 'green',
          ),
        ],
        size: GoogleMapsApiClient.defaultSquareSize,
      );
    } else {
      // Multiple locations - show route
      return _mapsClient.generateRouteMapUrl(
        startPoint: LatLng(firstLoc.latitude, firstLoc.longitude),
        endPoint: LatLng(lastLoc.latitude, lastLoc.longitude),
        encodedPolyline: _encodedPolyline,
        size: GoogleMapsApiClient.defaultSquareSize,
      );
    }
  }

  Color _getStatusColor(TripStatus status) {
    switch (status) {
      case TripStatus.created:
        return Colors.grey;
      case TripStatus.inProgress:
        return Colors.blue;
      case TripStatus.paused:
        return Colors.orange;
      case TripStatus.finished:
        return Colors.green;
      case TripStatus.resting:
        return WandererTheme.statusResting;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mini map preview (120x120)
            SizedBox(width: 120, height: 120, child: _buildMiniMap()),
            // Trip info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Trip title
                    Text(
                      widget.trip.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor(widget.trip.status),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _localizedTripStatus(widget.trip.status, l10n),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Metadata
                    Row(
                      children: [
                        Icon(Icons.comment, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          '${widget.trip.commentsCount}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          widget.trip.visibility.toJson() == 'PUBLIC'
                              ? Icons.public
                              : Icons.lock,
                          size: 14,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          widget.trip.visibility.toJson(),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniMap() {
    if (widget.trip.locations == null || widget.trip.locations!.isEmpty) {
      return Container(
        color: Colors.grey[300],
        child: Center(
          child: Icon(Icons.map_outlined, size: 32, color: Colors.grey[500]),
        ),
      );
    }

    return Image.network(
      _generateStaticMapUrl(),
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          color: Colors.grey[300],
          child: Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                  : null,
              strokeWidth: 2,
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: Colors.grey[300],
          child: Center(
            child: Icon(Icons.map, size: 32, color: Colors.grey[500]),
          ),
        );
      },
    );
  }
}
