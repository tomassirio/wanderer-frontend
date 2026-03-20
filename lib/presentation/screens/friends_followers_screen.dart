import 'dart:async';
import 'package:flutter/material.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/data/models/user_models.dart';
import 'package:wanderer_frontend/data/models/websocket/websocket_event.dart';
import 'package:wanderer_frontend/data/services/auth_service.dart';
import 'package:wanderer_frontend/data/services/user_service.dart';
import 'package:wanderer_frontend/data/services/websocket_service.dart';
import 'package:wanderer_frontend/presentation/helpers/dialog_helper.dart';
import 'package:wanderer_frontend/presentation/helpers/ui_helpers.dart';
import 'package:wanderer_frontend/presentation/helpers/auth_navigation_helper.dart';
import 'package:wanderer_frontend/presentation/widgets/common/wanderer_app_bar.dart';
import 'package:wanderer_frontend/presentation/widgets/common/app_sidebar.dart';
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

  // Data
  List<UserFollow> _followers = [];
  List<UserFollow> _following = [];
  List<Friendship> _friends = [];
  List<FriendRequest> _receivedRequests = [];
  List<FriendRequest> _sentRequests = [];

  // User profiles cache (userId -> UserProfile)
  final Map<String, UserProfile> _userProfiles = {};

  // State
  bool _isLoading = false;
  String? _error;
  UserProfile? _currentUser;
  bool _isLoggedIn = false;
  bool _isAdmin = false;
  final int _selectedSidebarIndex = 2; // Friends is index 2

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
    _initWebSocket();
  }

  Future<void> _initWebSocket() async {
    await _webSocketService.connect();
    _wsSubscription = _webSocketService.events.listen(_handleWebSocketEvent);
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
    // Reload data to get updated lists
    _loadData();
    if (mounted) {
      UiHelpers.showSuccessMessage(context, 'You have a new follower!');
    }
  }

  void _handleUserUnfollowed(UserUnfollowedEvent event) {
    // Reload data to get updated lists
    _loadData();
  }

  void _handleFriendRequestSent(FriendRequestSentEvent event) {
    // Reload data to get updated lists
    _loadData();
    if (mounted) {
      UiHelpers.showSuccessMessage(context, 'You received a friend request!');
    }
  }

  void _handleFriendRequestAccepted(FriendRequestAcceptedEvent event) {
    // Reload data to get updated lists
    _loadData();
    if (mounted) {
      UiHelpers.showSuccessMessage(context, 'Friend request accepted!');
    }
  }

  void _handleFriendRequestDeclined(FriendRequestDeclinedEvent event) {
    // Reload data to get updated lists
    _loadData();
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
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

      // Load all data in parallel
      final results = await Future.wait([
        _userService.getFollowers(),
        _userService.getFollowing(),
        _userService.getFriends(),
        _userService.getReceivedFriendRequests(),
        _userService.getSentFriendRequests(),
      ]);

      setState(() {
        _followers = results[0] as List<UserFollow>;
        _following = results[1] as List<UserFollow>;
        _friends = results[2] as List<Friendship>;
        _receivedRequests = results[3] as List<FriendRequest>;
        _sentRequests = results[4] as List<FriendRequest>;
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
    // Collect all unique user IDs
    final userIds = <String>{};

    for (final follower in _followers) {
      userIds.add(follower.followerId);
    }
    for (final following in _following) {
      userIds.add(following.followedId);
    }
    for (final friend in _friends) {
      userIds.add(friend.friendId);
    }
    for (final request in _receivedRequests) {
      userIds.add(request.senderId);
    }
    for (final request in _sentRequests) {
      userIds.add(request.receiverId);
    }

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

  Future<void> _navigateToAuth() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AuthScreen()),
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
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
  }

  Future<void> _handleLogout() async {
    final confirm = await DialogHelper.showLogoutConfirmation(context);

    if (confirm) {
      await AuthService().logout();
      if (mounted) {
        // Navigate to home screen and clear navigation stack
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      }
    }
  }

  Future<void> _handleFollowUser(String userId) async {
    try {
      await _userService.followUser(userId);
      if (mounted) {
        UiHelpers.showSuccessMessage(context, 'Follow request sent!');
        await _loadData();
      }
    } catch (e) {
      if (mounted) {
        UiHelpers.showErrorMessage(context, 'Failed to follow user: $e');
      }
    }
  }

  Future<void> _handleUnfollowUser(String userId) async {
    try {
      await _userService.unfollowUser(userId);
      if (mounted) {
        UiHelpers.showSuccessMessage(context, 'Unfollowed user');
        await _loadData();
      }
    } catch (e) {
      if (mounted) {
        UiHelpers.showErrorMessage(context, 'Failed to unfollow user: $e');
      }
    }
  }

  Future<void> _handleAcceptFriendRequest(String requestId) async {
    try {
      await _userService.acceptFriendRequest(requestId);
      if (mounted) {
        UiHelpers.showSuccessMessage(context, 'Friend request accepted!');
        await _loadData();
      }
    } catch (e) {
      if (mounted) {
        UiHelpers.showErrorMessage(
            context, 'Failed to accept friend request: $e');
      }
    }
  }

  Future<void> _handleDeclineFriendRequest(String requestId) async {
    try {
      await _userService.deleteFriendRequest(requestId);
      if (mounted) {
        UiHelpers.showSuccessMessage(context, 'Friend request declined');
        await _loadData();
      }
    } catch (e) {
      if (mounted) {
        UiHelpers.showErrorMessage(
            context, 'Failed to decline friend request: $e');
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
                child: const Text('Login'),
              ),
            ],
          ],
        ),
      );
    }

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
                  _buildTab(Icons.people, 'Friends', _friends.length, isNarrow),
                  _buildTab(Icons.person_add, 'Followers', _followers.length,
                      isNarrow),
                  _buildTab(Icons.person_outline, 'Following',
                      _following.length, isNarrow),
                  _buildTab(Icons.notifications, 'Requests',
                      _receivedRequests.length, isNarrow),
                ],
              );
            },
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildFriendsTab(),
              _buildFollowersTab(),
              _buildFollowingTab(),
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

  Widget _buildFriendsTab() {
    final l10n = context.l10n;
    if (_friends.isEmpty) {
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
        itemCount: _friends.length,
        itemBuilder: (context, index) {
          final friendship = _friends[index];
          final profile = _userProfiles[friendship.friendId];

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              onTap: () => _navigateToUserProfile(friendship.friendId),
              leading: CircleAvatar(
                backgroundImage: profile?.avatarUrl != null
                    ? NetworkImage(profile!.avatarUrl!)
                    : null,
                child: profile?.avatarUrl == null
                    ? const Icon(Icons.person)
                    : null,
              ),
              title: Text(profile?.username ?? 'Unknown User'),
              subtitle: profile?.displayName != null
                  ? Text(profile!.displayName!)
                  : null,
              trailing: IconButton(
                icon: const Icon(Icons.message),
                onPressed: () {
                  UiHelpers.showSuccessMessage(
                    context,
                    'Messaging coming soon!',
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFollowersTab() {
    final l10n = context.l10n;
    if (_followers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person_add_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              l10n.noFollowersYet,
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
        itemCount: _followers.length,
        itemBuilder: (context, index) {
          final follower = _followers[index];
          final profile = _userProfiles[follower.followerId];

          // Check if we're already following this user
          final isFollowingBack = _following.any(
            (f) => f.followedId == follower.followerId,
          );

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              onTap: () => _navigateToUserProfile(follower.followerId),
              leading: CircleAvatar(
                backgroundImage: profile?.avatarUrl != null
                    ? NetworkImage(profile!.avatarUrl!)
                    : null,
                child: profile?.avatarUrl == null
                    ? const Icon(Icons.person)
                    : null,
              ),
              title: Text(profile?.username ?? 'Unknown User'),
              subtitle: profile?.displayName != null
                  ? Text(profile!.displayName!)
                  : null,
              trailing: isFollowingBack
                  ? OutlinedButton(
                      onPressed: () => _handleUnfollowUser(follower.followerId),
                      child: Text(l10n.unfollow),
                    )
                  : ElevatedButton(
                      onPressed: () => _handleFollowUser(follower.followerId),
                      child: Text(l10n.followBack),
                    ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFollowingTab() {
    final l10n = context.l10n;
    if (_following.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              l10n.notFollowingAnyone,
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
        itemCount: _following.length,
        itemBuilder: (context, index) {
          final following = _following[index];
          final profile = _userProfiles[following.followedId];

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              onTap: () => _navigateToUserProfile(following.followedId),
              leading: CircleAvatar(
                backgroundImage: profile?.avatarUrl != null
                    ? NetworkImage(profile!.avatarUrl!)
                    : null,
                child: profile?.avatarUrl == null
                    ? const Icon(Icons.person)
                    : null,
              ),
              title: Text(profile?.username ?? 'Unknown User'),
              subtitle: profile?.displayName != null
                  ? Text(profile!.displayName!)
                  : null,
              trailing: ElevatedButton(
                onPressed: () => _handleUnfollowUser(following.followedId),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey,
                ),
                child: Text(l10n.unfollow),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRequestsTab() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            labelColor: Colors.black,
            tabs: [
              Tab(text: 'Received'),
              Tab(text: 'Sent'),
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
              leading: CircleAvatar(
                backgroundImage: profile?.avatarUrl != null
                    ? NetworkImage(profile!.avatarUrl!)
                    : null,
                child: profile?.avatarUrl == null
                    ? const Icon(Icons.person)
                    : null,
              ),
              title: Text(profile?.username ?? 'Unknown User'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (profile?.displayName != null) Text(profile!.displayName!),
                  Text(
                    'Sent ${_formatDate(request.createdAt)}',
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
              leading: CircleAvatar(
                backgroundImage: profile?.avatarUrl != null
                    ? NetworkImage(profile!.avatarUrl!)
                    : null,
                child: profile?.avatarUrl == null
                    ? const Icon(Icons.person)
                    : null,
              ),
              title: Text(profile?.username ?? 'Unknown User'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (profile?.displayName != null) Text(profile!.displayName!),
                  Text(
                    'Sent ${_formatDate(request.createdAt)}',
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 7) {
      return '${date.day}/${date.month}/${date.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'just now';
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
