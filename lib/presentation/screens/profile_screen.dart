import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/core/providers/app_providers.dart';
import 'package:wanderer_frontend/data/client/api_client.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/data/models/user_models.dart';
import 'package:wanderer_frontend/data/models/websocket/websocket_event.dart';
import 'package:wanderer_frontend/data/repositories/profile_repository.dart';
import 'package:wanderer_frontend/data/services/websocket_service.dart';
import 'package:wanderer_frontend/presentation/helpers/dialog_helper.dart';
import 'package:wanderer_frontend/presentation/helpers/ui_helpers.dart';
import 'package:wanderer_frontend/presentation/helpers/page_transitions.dart';
import 'package:wanderer_frontend/presentation/helpers/avatar_helper.dart';
import 'package:wanderer_frontend/presentation/state/profile/profile_notifier.dart';
import 'package:wanderer_frontend/presentation/state/profile/profile_state.dart';
import 'package:wanderer_frontend/presentation/state/user_chrome/user_chrome_notifier.dart';
import 'package:wanderer_frontend/presentation/state/user_chrome/user_chrome_state.dart';
import 'package:wanderer_frontend/presentation/widgets/common/wanderer_app_bar.dart';
import 'package:wanderer_frontend/presentation/widgets/common/app_sidebar.dart';
import 'package:wanderer_frontend/presentation/widgets/profile/profile_avatar_image.dart';
import 'package:wanderer_frontend/presentation/widgets/profile/profile_action_buttons.dart';
import 'package:wanderer_frontend/presentation/widgets/profile/profile_stats_row.dart';
import 'package:wanderer_frontend/presentation/widgets/profile/profile_sort_dropdown.dart';
import 'package:wanderer_frontend/presentation/widgets/profile/profile_filter_toggle_button.dart';
import 'package:wanderer_frontend/presentation/widgets/profile/profile_status_filter_pills.dart';
import 'package:wanderer_frontend/presentation/widgets/profile/profile_trip_card.dart';
import 'package:wanderer_frontend/core/constants/api_endpoints.dart';
import '../../core/constants/enums.dart';
import 'auth_screen.dart';
import 'home_screen.dart';
import 'settings_screen.dart';
import 'trip_detail_screen.dart';
import 'friends_followers_screen.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';

/// Presentation for [TripSortOption] (localized labels, icons) - the enum
/// itself lives in `profile_state.dart` alongside `ProfileState`, which owns
/// it as business state; this screen-only extension keeps `AppLocalizations`
/// and `IconData` out of the state layer.
extension TripSortOptionUi on TripSortOption {
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

/// Whether `ProfileScreen._buildBody()` should show the "please log in" /
/// fetch-error prompt instead of profile content.
///
/// `!isLoggedIn` alone isn't enough: the "viewing own profile while logged
/// out" path deliberately never calls `ProfileNotifier.loadProfile()`
/// (avoiding a doomed API call), so no `ProfileState.error` gets set for
/// it - this is what still shows the "please log in" prompt in that case.
/// The `isOwnProfile` restriction matters because viewing SOMEONE ELSE's
/// profile while logged out must NOT trip this: that's handled by the
/// redirect-to-`AuthScreen` in `_loadProfile()`, during whose fade-transition
/// window this screen should keep rendering its plain "no profile data"
/// fallback, not a login prompt. `isLoggedIn` (from `UserChromeState`) can
/// also be transiently false on a deep link straight into this screen for
/// another user's profile, before `UserChromeNotifier.loadUserInfo()`
/// resolves, even when the viewer actually is logged in - `isOwnProfile`
/// guards against misfiring on that race too.
bool profileScreenShowsLoginOrErrorPrompt({
  required bool hasError,
  required bool isLoggedIn,
  required bool isOwnProfile,
}) {
  return hasError || (!isLoggedIn && isOwnProfile);
}

/// User profile screen showing user information, statistics, and trips
class ProfileScreen extends ConsumerStatefulWidget {
  final String? userId;

  const ProfileScreen({super.key, this.userId});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late final ProfileRepository _repository;
  late final WebSocketService _webSocketService;
  StreamSubscription? _userEventSubscription;
  final int _selectedSidebarIndex = 4; // Profile is index 4

  UserChromeState get _chrome => ref.watch(userChromeNotifierProvider);
  bool get _isLoggedIn => _chrome.isLoggedIn;
  bool get _isAdmin => _chrome.isAdmin;
  String? get _currentUserId => _chrome.userId;
  String? get _currentUsername => _chrome.username;
  String? get _currentDisplayName => _chrome.displayName;
  String? get _currentAvatarUrl => _chrome.avatarUrl;

  ProfileState get _profileState =>
      ref.watch(profileNotifierProvider(widget.userId));
  Uint8List? get _optimisticAvatarBytes => _profileState.optimisticAvatarBytes;
  UserProfile? get _profile => _profileState.profile;
  bool get _isLoadingProfile => _profileState.isLoadingProfile;
  String? get _error => _profileState.error;
  List<Trip> get _userTrips => _profileState.userTrips;
  bool get _isLoadingTrips => _profileState.isLoadingTrips;
  int get _followersCount => _profileState.followersCount;
  int get _followingCount => _profileState.followingCount;
  int get _friendsCount => _profileState.friendsCount;
  TripSortOption get _tripSortOption => _profileState.tripSortOption;
  Set<TripStatus> get _selectedStatusFilters => _profileState.selectedStatusFilters;
  bool get _showFilterPanel => _profileState.showFilterPanel;
  List<Trip> get _filteredAndSortedTrips => _profileState.filteredAndSortedTrips;
  bool get _hasSentFriendRequest => _profileState.hasSentFriendRequest;
  bool get _isAlreadyFriends => _profileState.isAlreadyFriends;
  bool get _isFollowingUser => _profileState.isFollowingUser;
  String? get _sentFriendRequestId => _profileState.sentFriendRequestId;

  /// The avatar URL to render: for your own profile, prefer the live
  /// `UserChromeState` value (kept fresh by avatar upload/delete) over the
  /// possibly-stale `_profile!.avatarUrl`; for someone else's profile,
  /// always use their fetched profile's avatar URL.
  String? get _resolvedAvatarUrl => _isViewingOwnProfile
      ? (_currentAvatarUrl ?? _profile!.avatarUrl)
      : _profile!.avatarUrl;

  String get _avatarInitials =>
      AvatarHelper.getInitials(_profile!.displayName, _profile!.username);

  @override
  void initState() {
    super.initState();
    ref
        .read(profileNotifierProvider(widget.userId).notifier)
        .seedTargetUserId(widget.userId);
    _repository = ref.read(profileRepositoryProvider);
    _webSocketService = ref.read(websocketServiceProvider);
    _loadProfile();
    _setupUserWebSocket();
  }

  @override
  void dispose() {
    _userEventSubscription?.cancel();
    super.dispose();
  }

  void _setupUserWebSocket() async {
    await _webSocketService.connect();

    // Get both user IDs
    final currentUserId = await _repository.getCurrentUserId();
    final viewedUserId = widget.userId ?? currentUserId;

    if (viewedUserId == null) return;

    debugPrint(
        'ProfileScreen: Setting up WebSocket - current: $currentUserId, viewing: $viewedUserId');

    // Subscribe to both users if viewing another profile
    if (widget.userId != null &&
        currentUserId != null &&
        currentUserId != viewedUserId) {
      debugPrint(
          'ProfileScreen: Subscribing to both current user and viewed user');
      _webSocketService.subscribeToUser(currentUserId);
      _webSocketService.subscribeToUser(viewedUserId);

      // Listen to global events stream to catch updates from both users
      _userEventSubscription = _webSocketService.events.listen((event) {
        debugPrint(
            'ProfileScreen: Received global WebSocket event: ${event.type}');
        if ((event.type == WebSocketEventType.userProfileUpdated ||
                event.type == WebSocketEventType.userAvatarUploaded ||
                event.type == WebSocketEventType.userAvatarDeleted) &&
            mounted) {
          debugPrint('ProfileScreen: Handling user update event');
          _handleUserProfileUpdated();
        }
      });
    } else {
      // Viewing own profile - just subscribe to own updates
      final userStream = _webSocketService.subscribeToUser(viewedUserId);
      _userEventSubscription = userStream.listen((event) {
        debugPrint('ProfileScreen: Received WebSocket event: ${event.type}');
        if ((event.type == WebSocketEventType.userProfileUpdated ||
                event.type == WebSocketEventType.userAvatarUploaded ||
                event.type == WebSocketEventType.userAvatarDeleted) &&
            mounted) {
          debugPrint('ProfileScreen: Handling user update event');
          _handleUserProfileUpdated();
        }
      });
    }
  }

  void _handleUserProfileUpdated() async {
    debugPrint('ProfileScreen: _handleUserProfileUpdated called');

    // If we have an optimistic avatar, wait a bit before fetching to ensure backend is ready
    if (_optimisticAvatarBytes != null) {
      debugPrint(
          'ProfileScreen: Optimistic avatar present, waiting 2 seconds before fetching');
      await Future.delayed(const Duration(seconds: 2));
    }

    try {
      // Always refresh current user details for AppBar/Sidebar
      final currentUser = await _repository.getMyProfile();
      await _repository.refreshUserDetails();

      if (mounted) {
        ref.read(userChromeNotifierProvider.notifier).updateAvatarUrl(
              currentUser.avatarUrl.isNotEmpty
                  ? '${currentUser.avatarUrl}?t=${DateTime.now().millisecondsSinceEpoch}'
                  : null,
            );
        ref
            .read(userChromeNotifierProvider.notifier)
            .updateDisplayName(currentUser.displayName);
        // If viewing own profile, also update the profile data
        if (_isViewingOwnProfile) {
          ref
              .read(profileNotifierProvider(widget.userId).notifier)
              .setProfile(currentUser);
        }
        if (_isViewingOwnProfile) {
          ref
              .read(profileNotifierProvider(widget.userId).notifier)
              .setOptimisticAvatarBytes(null);
        }

        // Force image cache eviction to show new avatar immediately
        if (currentUser.avatarUrl.isNotEmpty) {
          final baseUrl =
              ApiEndpoints.resolveThumbnailUrl(currentUser.avatarUrl);
          debugPrint('ProfileScreen: Evicting image cache for $baseUrl');
          NetworkImage(baseUrl).evict();
          NetworkImage('$baseUrl?t=${DateTime.now().millisecondsSinceEpoch}')
              .evict();
        }
      }

      // If viewing another user's profile, also refresh their data
      if (!_isViewingOwnProfile && widget.userId != null) {
        final viewedProfile = await _repository.getUserProfile(widget.userId!);
        if (mounted) {
          ref
              .read(profileNotifierProvider(widget.userId).notifier)
              .setProfile(viewedProfile);
        }
      }
    } catch (e) {
      debugPrint('Failed to refresh profile after update: $e');
    }
  }

  /// Check if viewing own profile (either no userId passed, or userId matches current user)
  bool get _isViewingOwnProfile =>
      widget.userId == null ||
      (widget.userId != null && widget.userId == _currentUserId);

  Future<void> _loadProfile() async {
    final profileNotifier =
        ref.read(profileNotifierProvider(widget.userId).notifier);

    try {
      final isLoggedIn = await _repository.isLoggedIn();

      // If viewing another user's profile and not logged in, redirect to auth
      if (widget.userId != null && !isLoggedIn) {
        // Navigate to auth screen - use push so user can go back
        if (mounted) {
          Navigator.push(
            context,
            PageTransitions.fade(const AuthScreen()),
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
          await ref.read(userChromeNotifierProvider.notifier).loadUserInfo();
        } catch (e) {
          // Ignore error loading current user
        }
      }

      // If viewing another user's profile
      if (widget.userId != null) {
        await profileNotifier.loadProfile();
        final profile = _profile;
        if (profile == null) return;

        // Seed follower/following counts synchronously from the profile
        // response already in hand, before the slower dedicated
        // loadSocialCounts() round trip resolves - matches the
        // pre-migration synchronous seed so stat cards don't flash 0.
        profileNotifier.seedSocialCountsFromProfile(profile);

        // Load user's trips
        _loadUserTripsFireAndForget();

        // Load the viewed user's actual social counts
        if (isLoggedIn) {
          await ref
              .read(profileNotifierProvider(widget.userId).notifier)
              .loadSocialCounts();
        }

        // Only load friendship status if viewing someone else's profile
        if (isLoggedIn && widget.userId != _currentUserId) {
          await ref
              .read(profileNotifierProvider(widget.userId).notifier)
              .loadFriendshipStatus();
        }
        return;
      }

      // Viewing own profile: if not logged in, don't even try the fetch -
      // ProfileNotifier isn't invoked here (avoids a doomed API call).
      // `_buildBody()`'s `!_isLoggedIn` check independently shows the
      // "please log in" prompt, so no ProfileState.error is needed for it.
      if (!isLoggedIn) {
        return;
      }

      await profileNotifier.loadProfile();
      final profile = _profile;
      if (profile == null) return;

      // Load user's trips and social counts
      _loadUserTripsFireAndForget();
      await ref
          .read(profileNotifierProvider(widget.userId).notifier)
          .loadSocialCounts();
    } on AuthenticationRedirectException {
      // User is being redirected to login - don't show error.
    } catch (_) {
      // ProfileNotifier.loadProfile() already records fetch errors in
      // ProfileState; errors from the surrounding calls above (trips,
      // social counts, friendship status) are handled by those methods
      // themselves. Nothing further to do here.
    }
  }

  /// Fires `ProfileNotifier.loadUserTrips()` without awaiting it (matching
  /// the pre-migration fire-and-forget `_loadUserTrips(...)` call sites),
  /// but still catches a rejected Future so a trip-load failure surfaces as
  /// the same error snackbar the pre-migration code showed, instead of
  /// leaking as an unhandled async exception - see
  /// `TripDetailNotifier`'s `sendLifecycleUpdate` fire-and-forget fix
  /// (commit 96314e7) for why this guard matters.
  void _loadUserTripsFireAndForget() {
    ref
        .read(profileNotifierProvider(widget.userId).notifier)
        .loadUserTrips()
        .catchError((e) {
      if (mounted) {
        UiHelpers.showErrorMessage(context, 'Failed to load trips: $e');
      }
    });
  }

  Future<void> _logout() async {
    final confirm = await DialogHelper.showLogoutConfirmation(context);

    if (confirm) {
      await ref.read(userChromeNotifierProvider.notifier).logout();
      if (mounted) {
        // Navigate to home screen and clear navigation stack
        Navigator.of(context).pushAndRemoveUntil(
          PageTransitions.fade(const HomeScreen()),
          (route) => false,
        );
      }
    }
  }

  void _handleSettings() {
    Navigator.push(
      context,
      PageTransitions.slideFromBottom(const SettingsScreen()),
    );
  }

  Future<void> _navigateToAuth() async {
    final result = await Navigator.push(
      context,
      PageTransitions.fade(const AuthScreen()),
    );

    if (result == true || mounted) {
      await _loadProfile();
    }
  }

  void _navigateToTripDetail(Trip trip) {
    Navigator.push(
      context,
      PageTransitions.slideFromRight(TripDetailScreen(trip: trip)),
    );
  }

  void _navigateToFriendsFollowers() {
    Navigator.push(
      context,
      PageTransitions.slideFromBottom(const FriendsFollowersScreen()),
    );
  }

  void _navigateToOwnProfile() {
    // If already viewing own profile, do nothing
    if (_isViewingOwnProfile) return;

    // Navigate to own profile (without userId = current user's profile)
    Navigator.pushReplacement(
      context,
      PageTransitions.slideFromRight(const ProfileScreen()),
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
    final wasFollowing = _isFollowingUser;

    try {
      await ref.read(profileNotifierProvider(widget.userId).notifier).toggleFollow();
      if (mounted) {
        UiHelpers.showSuccessMessage(
          context,
          wasFollowing
              ? l10n.unfollowedUser(_profile!.username)
              : l10n.nowFollowingUser(_profile!.username),
        );
      }
    } catch (e) {
      if (mounted) {
        UiHelpers.showErrorMessage(
          context,
          wasFollowing
              ? 'Failed to unfollow user: $e'
              : 'Failed to follow user: $e',
        );
      }
    }
  }

  Future<void> _handleSendFriendRequest() async {
    if (_profile == null) return;
    final l10n = context.l10n;

    final wasAlreadyFriends = _isAlreadyFriends;
    final wasCancelling = _hasSentFriendRequest && _sentFriendRequestId != null;

    try {
      await ref
          .read(profileNotifierProvider(widget.userId).notifier)
          .toggleFriendRequest();
      if (!mounted) return;
      if (wasAlreadyFriends) {
        UiHelpers.showSuccessMessage(
            context, l10n.noLongerFriendsWith(_profile!.username));
      } else if (wasCancelling) {
        UiHelpers.showSuccessMessage(context, l10n.friendRequestCancelled);
      } else {
        UiHelpers.showSuccessMessage(
            context, l10n.friendRequestSentTo(_profile!.username));
      }
    } catch (e) {
      if (!mounted) return;
      if (wasAlreadyFriends) {
        UiHelpers.showErrorMessage(context, 'Failed to remove friend: $e');
      } else if (wasCancelling) {
        UiHelpers.showErrorMessage(
            context, 'Failed to cancel friend request: $e');
      } else {
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
      await ref
          .read(profileNotifierProvider(widget.userId).notifier)
          .updateProfile(displayName, bio);
      if (mounted) {
        UiHelpers.showSuccessMessage(
            context, context.l10n.profileUpdatedSuccessfully);
      }
    } catch (e) {
      if (mounted) {
        UiHelpers.showErrorMessage(context, context.l10n.failedToUpdateProfile);
      }
    }
  }

  // ignore: use_build_context_synchronously
  Future<void> _handleAvatarUpload() async {
    // Capture context at the start to avoid async gap issues
    final capturedContext = context;

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
      );

      if (image == null) return;

      // Validate file format
      final filename = image.name.toLowerCase();
      final validFormats = ['.jpg', '.jpeg', '.png', '.webp'];
      final hasValidExtension =
          validFormats.any((ext) => filename.endsWith(ext));

      if (!hasValidExtension) {
        if (mounted) {
          UiHelpers.showErrorMessage(
            capturedContext,
            'Invalid image format. Only JPEG, PNG, and WebP are supported.',
          );
        }
        return;
      }

      // Check file size (5MB max)
      final fileSize = await image.length();
      if (fileSize > 5 * 1024 * 1024) {
        if (mounted) {
          UiHelpers.showErrorMessage(
            capturedContext,
            'Image too large. Maximum size is 5MB.',
          );
        }
        return;
      }

      // Crop image to square/circle
      final CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: image.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        compressQuality: 85,
        maxWidth: 1024,
        maxHeight: 1024,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Avatar',
            toolbarColor: WandererTheme.primaryOrange,
            toolbarWidgetColor: Colors.white,
            statusBarColor: WandererTheme.primaryOrange,
            activeControlsWidgetColor: WandererTheme.primaryOrange,
            backgroundColor: Colors.black,
            lockAspectRatio: true,
            hideBottomControls: false,
            initAspectRatio: CropAspectRatioPreset.square,
            showCropGrid: true,
          ),
          IOSUiSettings(
            title: 'Crop Avatar',
            aspectRatioLockEnabled: true,
            minimumAspectRatio: 1.0,
          ),
          WebUiSettings(
            context: capturedContext,
            presentStyle: WebPresentStyle.dialog,
            size: const CropperSize(
              width: 520,
              height: 520,
            ),
          ),
        ],
      );

      if (croppedFile == null) {
        // User cancelled cropping
        return;
      }

      final bytes = await croppedFile.readAsBytes();

      // Optimistic UI update - show the image immediately
      if (mounted) {
        ref
            .read(profileNotifierProvider(widget.userId).notifier)
            .setOptimisticAvatarBytes(bytes);
      }

      // On web, image_cropper returns a blob URL with a UUID filename
      // (no extension), so the backend can't determine the content type.
      // Preserve the original image's extension to ensure a valid MIME type.
      final originalExt =
          image.name.contains('.') ? '.${image.name.split('.').last}' : '.png';
      final croppedName = croppedFile.path.split('/').last;
      final uploadName =
          croppedName.contains('.') ? croppedName : '$croppedName$originalExt';

      await ref
          .read(profileNotifierProvider(widget.userId).notifier)
          .uploadAvatar(bytes, uploadName);

      if (mounted) {
        UiHelpers.showSuccessMessage(
          capturedContext,
          'Avatar uploading... You\'ll see it in a moment!',
        );
      }
    } catch (e) {
      // ProfileNotifier.uploadAvatar already clears the optimistic bytes
      // internally on failure - just show the error toast here.
      if (mounted) {
        UiHelpers.showErrorMessage(
            capturedContext, 'Failed to upload avatar: $e');
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
      await ref
          .read(profileNotifierProvider(widget.userId).notifier)
          .deleteAvatar();

      if (mounted) {
        UiHelpers.showSuccessMessage(
          context,
          'Avatar deleting... You\'ll see it removed in a moment!',
        );
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
        onProfile: () => _navigateToOwnProfile(),
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

    // See profileScreenShowsLoginOrErrorPrompt's doc for why this isn't
    // just `_error != null`.
    if (profileScreenShowsLoginOrErrorPrompt(
      hasError: _error != null,
      isLoggedIn: _isLoggedIn,
      isOwnProfile: widget.userId == null,
    )) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              !_isLoggedIn ? l10n.mustBeLoggedInToViewProfile : _error!,
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
          ProfileStatsRow(
            tripsCount: _userTrips.length,
            followersCount: _followersCount,
            followingCount: _followingCount,
            friendsCount: _friendsCount,
            isViewingOwnProfile: _isViewingOwnProfile,
            onFollowersFollowingFriendsTap: _navigateToFriendsFollowers,
          ),
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
            // Only one of the two slots below actually renders this at a
            // time (isWide XOR !isWide), so a single shared instance is
            // safe here.
            final actionButtons = ProfileActionButtons(
              isViewingOwnProfile: _isViewingOwnProfile,
              isFollowingUser: _isFollowingUser,
              isAlreadyFriends: _isAlreadyFriends,
              hasSentFriendRequest: _hasSentFriendRequest,
              onEdit: _showEditProfileDialog,
              onFollow: _handleFollowUser,
              onSendFriendRequest: _handleSendFriendRequest,
            );

            final userInfoSection = Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAvatarWidget(),
                const SizedBox(width: 16),
                Expanded(
                  child: Stack(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _profile!.displayName ?? _profile!.username,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (_isFollowingUser && !_isViewingOwnProfile)
                            const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Icon(
                                Icons.person_add_alt_1,
                                size: 16,
                                color: Colors.blue,
                              ),
                            ),
                          const SizedBox(height: 2),
                          Text(
                            '@${_profile!.username}',
                            style: TextStyle(
                                fontSize: 14, color: Colors.grey[600]),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          GestureDetector(
                            onTap: () {
                              Clipboard.setData(
                                  ClipboardData(text: _profile!.id));
                              UiHelpers.showInfoMessage(
                                  context, 'User ID copied to clipboard');
                            },
                            child: Text(
                              _profile!.id,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 9,
                                color: primaryColor.withValues(alpha: 0.8),
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (!isWide)
                        Positioned(
                          top: 0,
                          right: 0,
                          child: actionButtons,
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
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: actionButtons,
                  ),
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
      return ProfileAvatarImage(
        optimisticAvatarBytes: _optimisticAvatarBytes,
        avatarUrl: _resolvedAvatarUrl,
        initials: _avatarInitials,
        radius: 40,
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
              if (_profile!.avatarUrl.isNotEmpty) {
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
                ProfileAvatarImage(
                  optimisticAvatarBytes: _optimisticAvatarBytes,
                  avatarUrl: _resolvedAvatarUrl,
                  initials: _avatarInitials,
                  radius: 40,
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
                    onPressed: () => ref
                        .read(profileNotifierProvider(widget.userId).notifier)
                        .clearStatusFilters(),
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
                child: ProfileSortDropdown(
                  currentOption: _tripSortOption,
                  onSelect: (option) => ref
                      .read(profileNotifierProvider(widget.userId).notifier)
                      .setSortOption(option),
                ),
              ),
              const SizedBox(width: 8),
              // Filter toggle button with badge
              ProfileFilterToggleButton(
                hasActive: hasActiveFilters,
                count: activeFilterCount,
                isPanelOpen: _showFilterPanel,
                onTap: () => ref
                    .read(profileNotifierProvider(widget.userId).notifier)
                    .toggleFilterPanel(),
              ),
            ],
          ),
          // Animated filter panel
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: ProfileStatusFilterPills(
                userTrips: _userTrips,
                selectedStatusFilters: _selectedStatusFilters,
                onToggleStatus: (status) => ref
                    .read(profileNotifierProvider(widget.userId).notifier)
                    .toggleStatusFilter(status),
                onClearAll: () => ref
                    .read(profileNotifierProvider(widget.userId).notifier)
                    .clearStatusFilters(),
              ),
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

  Widget _buildTripCard(Trip trip) {
    return ProfileTripCard(
      trip: trip,
      onTap: () => _navigateToTripDetail(trip),
    );
  }
}
