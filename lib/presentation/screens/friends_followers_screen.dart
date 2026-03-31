import 'dart:async';
import 'package:flutter/material.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/data/models/user_models.dart';
import 'package:wanderer_frontend/data/models/responses/page_response.dart';
import 'package:wanderer_frontend/data/models/websocket/websocket_event.dart';
import 'package:wanderer_frontend/data/services/auth_service.dart';
import 'package:wanderer_frontend/data/services/user_service.dart';
import 'package:wanderer_frontend/data/services/websocket_service.dart';
import 'package:wanderer_frontend/presentation/helpers/dialog_helper.dart';
import 'package:wanderer_frontend/presentation/helpers/ui_helpers.dart';
import 'package:wanderer_frontend/presentation/helpers/auth_navigation_helper.dart';
import 'package:wanderer_frontend/presentation/helpers/page_transitions.dart';
import 'package:wanderer_frontend/presentation/widgets/common/wanderer_app_bar.dart';
import 'package:wanderer_frontend/presentation/widgets/common/app_sidebar.dart';
import 'package:wanderer_frontend/presentation/widgets/common/user_avatar.dart';
import 'package:wanderer_frontend/presentation/widgets/home/relationship_badge.dart';
import 'auth_screen.dart';
import 'home_screen.dart';
import 'settings_screen.dart';

/// Screen for managing friends and followers
class FriendsFollowersScreen extends StatefulWidget {
  const FriendsFollowersScreen({super.key});

  @override
  State<FriendsFollowersScreen> createState() => _FriendsFollowersScreenState();
}

class _FriendsFollowersScreenState extends State<FriendsFollowersScreen>
    with SingleTickerProviderStateMixin {
  final UserService _userService = UserService();
  final AuthService _authService = AuthService();
  final WebSocketService _webSocketService = WebSocketService();

  late TabController _tabController;
  StreamSubscription<WebSocketEvent>? _wsSubscription;
  Timer? _pollTimer;
  Timer? _debounceTimer;
  String? _subscribedUserId;

  // Data
  List<UserRelationship> _associatedUsers = [];
  List<FriendRequest> _receivedRequests = [];
  List<FriendRequest> _sentRequests = [];
  List<UserProfile> _discoverableUsers = [];

  // User profiles cache (userId -> UserProfile)
  final Map<String, UserProfile> _userProfiles = {};

  // State
  bool _isLoading = false;
  bool _isLoggedIn = false;
  String? _error;
  UserProfile? _currentUser;
  bool _isAdmin = false;
  final int _selectedSidebarIndex = 2; // Friends is index 2

  // Pagination — People tab
  static const int _pageSize = 20;
  int _associatedPage = 0;
  bool _hasMoreAssociated = false;
  bool _isLoadingMoreAssociated = false;

  // Pagination — Discover tab
  int _discoverPage = 0;
  bool _hasMoreDiscover = false;
  bool _isLoadingMoreDiscover = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();

    // Listen to the global WebSocket events stream immediately so events
    // are caught even before the async connect / userId resolution finishes.
    _wsSubscription = _webSocketService.events.listen(_handleWebSocketEvent);

    // Fire-and-forget: connect to WebSocket server. Once connected the
    // pending user subscriptions will be activated automatically.
    _webSocketService.connect();

    // Start periodic polling as a reliable fallback — ensures the
    // relationship lists stay fresh even when WebSocket events are missed.
    _startPolling();
  }

  /// Start periodic polling as a reliable fallback.
  /// This ensures the relationship data stays fresh even when the WebSocket
  /// connection is unavailable or events are missed.
  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted && _isLoggedIn) {
        _loadData();
      }
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _debounceTimer?.cancel();
    _debounceTimer = null;
  }

  /// Ensure the user's WebSocket topic is subscribed so user-scoped events
  /// (e.g. follow/friend activity) are received on the global stream.
  void _ensureUserTopicSubscribed(String userId) {
    if (_subscribedUserId == userId) return;
    _subscribedUserId = userId;

    // Fire-and-forget: connect then subscribe to the user topic.
    _webSocketService.connect().then((_) {
      if (!mounted || _subscribedUserId != userId) return;
      _webSocketService.subscribeToUser(userId);
      debugPrint(
          'FriendsFollowersScreen: Subscribed to user topic for user $userId');
    });
  }

  /// Debounce the data refresh so rapid-fire WS events only trigger one
  /// API call.
  void _debouncedLoadData() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        _loadData();
      }
    });
  }

  void _handleWebSocketEvent(WebSocketEvent event) {
    if (!mounted) return;

    switch (event.type) {
      case WebSocketEventType.userFollowed:
        _handleUserFollowed(event as UserFollowedEvent);
        break;
      case WebSocketEventType.userUnfollowed:
        _handleUserUnfollowed(event as UserUnfollowedEvent);
        break;
      case WebSocketEventType.friendRequestSent:
        _handleFriendRequestSent(event as FriendRequestSentEvent);
        break;
      case WebSocketEventType.friendRequestAccepted:
        _handleFriendRequestAccepted(event as FriendRequestAcceptedEvent);
        break;
      case WebSocketEventType.friendRequestDeclined:
        _handleFriendRequestDeclined(event as FriendRequestDeclinedEvent);
        break;
      default:
        break;
    }
  }

  void _handleUserFollowed(UserFollowedEvent event) {
    // Immediate refresh + toast for user-visible events
    _loadData();
    if (mounted) {
      final l10n = context.l10n;
      UiHelpers.showSuccessMessage(context, l10n.newFollowerMsg);
    }
  }

  void _handleUserUnfollowed(UserUnfollowedEvent event) {
    // Debounce — unfollows can come in bursts and don't need a toast
    _debouncedLoadData();
  }

  void _handleFriendRequestSent(FriendRequestSentEvent event) {
    // Immediate refresh + toast for user-visible events
    _loadData();
    if (mounted) {
      final l10n = context.l10n;
      UiHelpers.showSuccessMessage(context, l10n.friendRequestReceivedMsg);
    }
  }

  void _handleFriendRequestAccepted(FriendRequestAcceptedEvent event) {
    // Immediate refresh + toast for user-visible events
    _loadData();
    if (mounted) {
      final l10n = context.l10n;
      UiHelpers.showSuccessMessage(context, l10n.friendRequestAcceptedMsg);
    }
  }

  void _handleFriendRequestDeclined(FriendRequestDeclinedEvent event) {
    // Debounce — declines can come in bursts and don't need a toast
    _debouncedLoadData();
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _wsSubscription = null;
    _stopPolling();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Check if logged in
      final profile = await _userService.getMyProfile();
      final isAdmin = await _authService.isAdmin();
      setState(() {
        _currentUser = profile;
        _isLoggedIn = true;
        _isAdmin = isAdmin;
      });

      // Subscribe to the user's WebSocket topic so user-scoped events
      // (follow/friend activity) arrive on the global stream.
      _ensureUserTopicSubscribed(profile.id);

      // Load all data in parallel
      final results = await Future.wait([
        _userService.getAssociatedUsers(profile.id, page: 0, size: _pageSize),
        _userService.getReceivedFriendRequests(),
        _userService.getSentFriendRequests(),
        _userService.getDiscoverableUsers(page: 0, size: _pageSize),
      ]);

      final associatedPage = results[0] as PageResponse<UserRelationship>;
      final discoverPage = results[3] as PageResponse<UserProfile>;

      setState(() {
        _associatedUsers = associatedPage.content;
        _associatedPage = 0;
        _hasMoreAssociated = !associatedPage.last;
        _receivedRequests = results[1] as List<FriendRequest>;
        _sentRequests = results[2] as List<FriendRequest>;
        _discoverableUsers = discoverPage.content;
        _discoverPage = 0;
        _hasMoreDiscover = !discoverPage.last;
        _isLoading = false;
      });

      // Load user profiles for display
      await _loadUserProfiles();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
        _isLoggedIn = false;
      });
    }
  }

  Future<void> _loadUserProfiles() async {
    // Only need to load profiles for friend request senders/receivers
    // (associated users already have profile data from the endpoint)
    final userIds = <String>{};

    for (final request in _receivedRequests) {
      userIds.add(request.senderId);
    }
    for (final request in _sentRequests) {
      userIds.add(request.receiverId);
    }

    if (userIds.isEmpty) return;

    // Load profiles in parallel
    try {
      final profiles = await Future.wait(
        userIds.map((id) => _userService.getUserById(id)),
      );

      setState(() {
        for (final profile in profiles) {
          _userProfiles[profile.id] = profile;
        }
      });
    } catch (e) {
      // Silently fail, profiles will show as unknown
    }
  }

  Future<void> _loadMoreAssociated() async {
    if (_isLoadingMoreAssociated ||
        !_hasMoreAssociated ||
        _currentUser == null) {
      return;
    }

    setState(() => _isLoadingMoreAssociated = true);

    try {
      final nextPage = _associatedPage + 1;
      final page = await _userService.getAssociatedUsers(
        _currentUser!.id,
        page: nextPage,
        size: _pageSize,
      );

      setState(() {
        _associatedUsers = [..._associatedUsers, ...page.content];
        _associatedPage = nextPage;
        _hasMoreAssociated = !page.last;
        _isLoadingMoreAssociated = false;
      });
    } catch (e) {
      setState(() => _isLoadingMoreAssociated = false);
    }
  }

  Future<void> _loadMoreDiscover() async {
    if (_isLoadingMoreDiscover || !_hasMoreDiscover) return;

    setState(() => _isLoadingMoreDiscover = true);

    try {
      final nextPage = _discoverPage + 1;
      final page = await _userService.getDiscoverableUsers(
        page: nextPage,
        size: _pageSize,
      );

      setState(() {
        _discoverableUsers = [..._discoverableUsers, ...page.content];
        _discoverPage = nextPage;
        _hasMoreDiscover = !page.last;
        _isLoadingMoreDiscover = false;
      });
    } catch (e) {
      setState(() => _isLoadingMoreDiscover = false);
    }
  }

  Future<void> _navigateToAuth() async {
    final result = await Navigator.push(
      context,
      PageTransitions.fade(const AuthScreen()),
    );

    if (result == true && mounted) {
      await _loadData();
    }
  }

  void _navigateToProfile() {
    AuthNavigationHelper.navigateToOwnProfile(context);
  }

  void _handleSettings() {
    Navigator.push(
      context,
      PageTransitions.slideFromBottom(const SettingsScreen()),
    );
  }

  Future<void> _handleLogout() async {
    final confirm = await DialogHelper.showLogoutConfirmation(context);

    if (confirm) {
      await AuthService().logout();
      if (mounted) {
        // Navigate to home screen and clear navigation stack
        Navigator.of(context).pushAndRemoveUntil(
          PageTransitions.fade(const HomeScreen()),
          (route) => false,
        );
      }
    }
  }

  Future<void> _handleFollowUser(String userId) async {
    try {
      await _userService.followUser(userId);
      if (mounted) {
        final l10n = context.l10n;
        UiHelpers.showSuccessMessage(context, l10n.followRequestSentMsg);
        await _loadData();
      }
    } catch (e) {
      if (mounted) {
        final l10n = context.l10n;
        UiHelpers.showErrorMessage(
            context, l10n.failedToFollowUser(e.toString()));
      }
    }
  }

  Future<void> _handleUnfollowUser(String userId) async {
    try {
      await _userService.unfollowUser(userId);
      if (mounted) {
        final l10n = context.l10n;
        UiHelpers.showSuccessMessage(context, l10n.unfollowedUserMsg);
        await _loadData();
      }
    } catch (e) {
      if (mounted) {
        final l10n = context.l10n;
        UiHelpers.showErrorMessage(
            context, l10n.failedToUnfollowUser(e.toString()));
      }
    }
  }

  Future<void> _handleSendFriendRequest(String userId, String username) async {
    try {
      await _userService.sendFriendRequest(userId);
      if (mounted) {
        final l10n = context.l10n;
        UiHelpers.showSuccessMessage(
            context, l10n.friendRequestSentTo(username));
        await _loadData();
      }
    } catch (e) {
      if (mounted) {
        UiHelpers.showErrorMessage(context, e.toString());
      }
    }
  }

  Future<void> _handleAcceptFriendRequest(String requestId) async {
    try {
      await _userService.acceptFriendRequest(requestId);
      if (mounted) {
        final l10n = context.l10n;
        UiHelpers.showSuccessMessage(context, l10n.friendRequestAcceptedMsg);
        await _loadData();
      }
    } catch (e) {
      if (mounted) {
        final l10n = context.l10n;
        UiHelpers.showErrorMessage(
            context, l10n.failedToAcceptFriendRequest(e.toString()));
      }
    }
  }

  Future<void> _handleDeclineFriendRequest(String requestId) async {
    try {
      await _userService.deleteFriendRequest(requestId);
      if (mounted) {
        final l10n = context.l10n;
        UiHelpers.showSuccessMessage(context, l10n.friendRequestDeclinedMsg);
        await _loadData();
      }
    } catch (e) {
      if (mounted) {
        final l10n = context.l10n;
        UiHelpers.showErrorMessage(
            context, l10n.failedToDeclineFriendRequest(e.toString()));
      }
    }
  }

  void _navigateToUserProfile(String userId) {
    AuthNavigationHelper.navigateToUserProfile(context, userId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: WandererAppBar(
        isLoggedIn: _isLoggedIn,
        onLoginPressed: _navigateToAuth,
        username: _currentUser?.username,
        userId: _currentUser?.id,
        displayName: _currentUser?.displayName,
        avatarUrl: _currentUser?.avatarUrl,
        onProfile: _navigateToProfile,
        onSettings: _handleSettings,
        onLogout: _handleLogout,
      ),
      drawer: AppSidebar(
        username: _currentUser?.username,
        userId: _currentUser?.id,
        displayName: _currentUser?.displayName,
        avatarUrl: _currentUser?.avatarUrl,
        selectedIndex: _selectedSidebarIndex,
        onLogout: _handleLogout,
        onSettings: _handleSettings,
        isAdmin: _isAdmin,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final l10n = context.l10n;
    if (_isLoading) {
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
              _error!,
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

    final totalRequests = _receivedRequests.length + _sentRequests.length;

    return Column(
      children: [
        Container(
          color: Theme.of(context).primaryColor,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 500;
              return TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                isScrollable: false,
                labelPadding: const EdgeInsets.symmetric(horizontal: 2),
                tabs: [
                  _buildTab(Icons.people, l10n.friends, _associatedUsers.length,
                      isNarrow),
                  _buildTab(Icons.explore, l10n.discover,
                      _discoverableUsers.length, isNarrow),
                  _buildTab(Icons.notifications, l10n.requestsTab,
                      totalRequests, isNarrow),
                ],
              );
            },
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildPeopleTab(),
              _buildDiscoverTab(),
              _buildRequestsTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTab(IconData icon, String label, int count, bool isNarrow) {
    if (isNarrow) {
      // Mobile: icon + count badge, no text label to save space
      return Tab(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style:
                    const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    }
    // Wide screen: icon + full label with count
    return Tab(
      text: '$label ($count)',
      icon: Icon(icon),
    );
  }

  /// Builds the merged People tab showing all associated users in a single
  /// scrollable list. Each user appears once with relationship badges and
  /// appropriate action buttons.
  Widget _buildPeopleTab() {
    final l10n = context.l10n;

    if (_associatedUsers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.people_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              l10n.noFriendsYet,
              style: const TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.sendFriendRequests,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _associatedUsers.length + (_hasMoreAssociated ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _associatedUsers.length) {
            return _buildLoadMoreButton(
              isLoading: _isLoadingMoreAssociated,
              onPressed: _loadMoreAssociated,
            );
          }
          final user = _associatedUsers[index];
          final hasPendingRequest =
              _sentRequests.any((r) => r.receiverId == user.id);
          final hasReceivedRequest = _receivedRequests.firstWhere(
            (r) => r.senderId == user.id,
            orElse: () => FriendRequest(
                id: '',
                senderId: '',
                receiverId: '',
                status: FriendRequestStatus.pending,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now()),
          );
          final receivedRequestId =
              hasReceivedRequest.id.isNotEmpty ? hasReceivedRequest.id : null;

          return _buildAssociatedUserTile(
            user,
            hasPendingRequest: hasPendingRequest,
            receivedRequestId: receivedRequestId,
          );
        },
      ),
    );
  }

  /// Builds a tile for an associated user showing all relationship badges and
  /// contextual action buttons.
  Widget _buildAssociatedUserTile(
    UserRelationship user, {
    required bool hasPendingRequest,
    String? receivedRequestId,
  }) {
    // Build list of relationship badges
    final badges = <Widget>[];
    if (user.isFriend) {
      badges.add(const RelationshipBadge(
        type: RelationshipType.friend,
        compact: true,
      ));
    }
    if (user.isFollowedBy) {
      badges.add(const RelationshipBadge(
        type: RelationshipType.follower,
        compact: true,
      ));
    }
    if (user.isFollowing) {
      badges.add(const RelationshipBadge(
        type: RelationshipType.following,
        compact: true,
      ));
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: ListTile(
          onTap: () => _navigateToUserProfile(user.id),
          leading: UserAvatar(
            avatarUrl: user.avatarUrl,
            username: user.username,
            displayName: user.displayName,
            radius: 20,
          ),
          title: Text(user.username),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (user.displayName != null) Text(user.displayName!),
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: badges,
              ),
            ],
          ),
          trailing: _buildAssociatedUserActions(
            user,
            hasPendingRequest: hasPendingRequest,
            receivedRequestId: receivedRequestId,
          ),
        ),
      ),
    );
  }

  /// Builds contextual action buttons for an associated user.
  Widget _buildAssociatedUserActions(
    UserRelationship user, {
    required bool hasPendingRequest,
    String? receivedRequestId,
  }) {
    final actions = <Widget>[];

    // Follow / Unfollow button
    actions.add(
      Container(
        height: 32,
        decoration: BoxDecoration(
          color: user.isFollowing
              ? Colors.blue.withOpacity(0.7)
              : Colors.grey.withOpacity(0.3),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              if (user.isFollowing) {
                _handleUnfollowUser(user.id);
              } else {
                _handleFollowUser(user.id);
              }
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Icon(
                user.isFollowing ? Icons.person_remove : Icons.person_add,
                size: 16,
                color: user.isFollowing ? Colors.white : Colors.black54,
              ),
            ),
          ),
        ),
      ),
    );

    // Friend request / accept / pending button
    if (!user.isFriend) {
      if (receivedRequestId != null) {
        // Received a request from this user — show accept/decline
        actions.add(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.check, color: Colors.green),
                onPressed: () => _handleAcceptFriendRequest(receivedRequestId),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                iconSize: 20,
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.red),
                onPressed: () => _handleDeclineFriendRequest(receivedRequestId),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                iconSize: 20,
              ),
            ],
          ),
        );
      } else {
        // Send / pending friend request button
        actions.add(
          Container(
            height: 32,
            decoration: BoxDecoration(
              color: hasPendingRequest
                  ? Colors.orange.withOpacity(0.7)
                  : Colors.green.withOpacity(0.7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: hasPendingRequest
                    ? null
                    : () => _handleSendFriendRequest(user.id, user.username),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: Icon(
                    hasPendingRequest ? Icons.hourglass_top : Icons.people,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < actions.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          actions[i],
        ],
      ],
    );
  }

  /// Builds the Discover tab showing users you may know (friends of friends,
  /// people followed by friends).
  Widget _buildDiscoverTab() {
    final l10n = context.l10n;

    if (_discoverableUsers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.explore_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              l10n.noUsersToDiscover,
              style: const TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.addFriendsToDiscoverMore,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _discoverableUsers.length + (_hasMoreDiscover ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _discoverableUsers.length) {
            return _buildLoadMoreButton(
              isLoading: _isLoadingMoreDiscover,
              onPressed: _loadMoreDiscover,
            );
          }
          final user = _discoverableUsers[index];

          // Determine existing relationship from associated users
          final associated = _associatedUsers
              .cast<UserRelationship?>()
              .firstWhere((a) => a!.id == user.id, orElse: () => null);
          final isFriend = associated?.isFriend ?? false;
          final isFollowing = associated?.isFollowing ?? false;
          final hasPendingRequest =
              _sentRequests.any((r) => r.receiverId == user.id);

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              onTap: () => _navigateToUserProfile(user.id),
              leading: UserAvatar(
                avatarUrl: user.avatarUrl,
                username: user.username,
                displayName: user.displayName,
                radius: 20,
              ),
              title: Text(user.username),
              subtitle:
                  user.displayName != null ? Text(user.displayName!) : null,
              trailing: _buildDiscoverActions(
                user,
                isFriend: isFriend,
                isFollowing: isFollowing,
                hasPendingRequest: hasPendingRequest,
              ),
            ),
          );
        },
      ),
    );
  }

  /// Builds action buttons for a discoverable user based on existing
  /// relationship status.
  Widget _buildDiscoverActions(
    UserProfile user, {
    required bool isFriend,
    required bool isFollowing,
    required bool hasPendingRequest,
  }) {
    final l10n = context.l10n;

    if (isFriend) {
      // Already friends — show badge only
      return const RelationshipBadge(
        type: RelationshipType.friend,
        compact: true,
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Follow / unfollow button
        Container(
          height: 32,
          decoration: BoxDecoration(
            color: isFollowing
                ? Colors.blue.withOpacity(0.7)
                : Colors.grey.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                if (isFollowing) {
                  _handleUnfollowUser(user.id);
                } else {
                  _handleFollowUser(user.id);
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isFollowing ? Icons.person_remove : Icons.person_add,
                      size: 16,
                      color: isFollowing ? Colors.white : Colors.black54,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isFollowing ? l10n.unfollow : l10n.follow,
                      style: TextStyle(
                        fontSize: 12,
                        color: isFollowing ? Colors.white : Colors.black54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        // Friend request button
        Container(
          height: 32,
          decoration: BoxDecoration(
            color: hasPendingRequest
                ? Colors.orange.withOpacity(0.7)
                : Colors.green.withOpacity(0.7),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: hasPendingRequest
                  ? null
                  : () => _handleSendFriendRequest(user.id, user.username),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      hasPendingRequest ? Icons.hourglass_top : Icons.people,
                      size: 16,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      hasPendingRequest
                          ? l10n.requestsTab
                          : l10n.sendFriendRequest,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Reusable load-more button for paginated lists.
  Widget _buildLoadMoreButton({
    required bool isLoading,
    required VoidCallback onPressed,
  }) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : TextButton.icon(
                onPressed: onPressed,
                icon: const Icon(Icons.expand_more),
                label: Text(l10n.loadMore),
              ),
      ),
    );
  }

  Widget _buildRequestsTab() {
    final l10n = context.l10n;
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            labelColor: Colors.black,
            tabs: [
              Tab(text: l10n.receivedTab),
              Tab(text: l10n.sentTab),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildReceivedRequestsView(),
                _buildSentRequestsView(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceivedRequestsView() {
    final l10n = context.l10n;
    if (_receivedRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              l10n.noFriendRequests,
              style: const TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _receivedRequests.length,
        itemBuilder: (context, index) {
          final request = _receivedRequests[index];
          final profile = _userProfiles[request.senderId];

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              onTap: () => _navigateToUserProfile(request.senderId),
              leading: UserAvatar(
                avatarUrl: profile?.avatarUrl,
                username: profile?.username ?? l10n.unknownUser,
                displayName: profile?.displayName,
                radius: 20,
              ),
              title: Text(profile?.username ?? l10n.unknownUser),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (profile?.displayName != null) Text(profile!.displayName!),
                  Text(
                    l10n.sentDateLabel(_formatDate(context, request.createdAt)),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.check, color: Colors.green),
                    onPressed: () => _handleAcceptFriendRequest(request.id),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: () => _handleDeclineFriendRequest(request.id),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSentRequestsView() {
    final l10n = context.l10n;
    if (_sentRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.send_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              l10n.noSentRequests,
              style: const TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _sentRequests.length,
        itemBuilder: (context, index) {
          final request = _sentRequests[index];
          final profile = _userProfiles[request.receiverId];

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              onTap: () => _navigateToUserProfile(request.receiverId),
              leading: UserAvatar(
                avatarUrl: profile?.avatarUrl,
                username: profile?.username ?? l10n.unknownUser,
                displayName: profile?.displayName,
                radius: 20,
              ),
              title: Text(profile?.username ?? l10n.unknownUser),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (profile?.displayName != null) Text(profile!.displayName!),
                  Text(
                    l10n.sentDateLabel(_formatDate(context, request.createdAt)),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              trailing: Chip(
                label: Text(request.status.toJson()),
                backgroundColor: _getStatusColor(request.status),
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatDate(BuildContext context, DateTime date) {
    final l10n = context.l10n;
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 7) {
      return '${date.day}/${date.month}/${date.year}';
    } else if (difference.inDays > 0) {
      return l10n.daysAgoShort(difference.inDays);
    } else if (difference.inHours > 0) {
      return l10n.hoursAgoShort(difference.inHours);
    } else if (difference.inMinutes > 0) {
      return l10n.minutesAgoShort(difference.inMinutes);
    } else {
      return l10n.justNow;
    }
  }

  Color _getStatusColor(FriendRequestStatus status) {
    switch (status) {
      case FriendRequestStatus.pending:
        return Colors.orange.withOpacity(0.3);
      case FriendRequestStatus.accepted:
        return Colors.green.withOpacity(0.3);
      case FriendRequestStatus.declined:
        return Colors.red.withOpacity(0.3);
    }
  }
}
