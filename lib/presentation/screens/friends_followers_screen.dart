import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wanderer_frontend/core/constants/api_endpoints.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/core/providers/app_providers.dart';
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
import 'package:wanderer_frontend/presentation/screens/profile_screen.dart'
    show ProfileOrigin;
import 'package:wanderer_frontend/presentation/widgets/common/wanderer_app_bar.dart';
import 'package:wanderer_frontend/presentation/widgets/common/app_sidebar.dart';
import 'package:wanderer_frontend/presentation/widgets/common/user_avatar.dart';
import 'package:wanderer_frontend/presentation/widgets/common/pill.dart';
import 'package:wanderer_frontend/presentation/widgets/common/web_page_header.dart';
import 'package:wanderer_frontend/presentation/widgets/friends/friends_web_widgets.dart';
import 'package:wanderer_frontend/presentation/widgets/android/android_ui.dart';
import 'package:wanderer_frontend/presentation/widgets/common/wanderer_sheet.dart';
import 'search_screen.dart';
import 'package:wanderer_frontend/presentation/widgets/search/search_overlay.dart';
import 'auth_screen.dart';
import 'settings_screen.dart';
import 'package:wanderer_frontend/presentation/widgets/common/wanderer_scaffold.dart';
import 'package:wanderer_frontend/presentation/screens/initial_screen.dart';

/// Screen for managing friends and followers
class FriendsFollowersScreen extends ConsumerStatefulWidget {
  const FriendsFollowersScreen({super.key});

  @override
  ConsumerState<FriendsFollowersScreen> createState() =>
      _FriendsFollowersScreenState();
}

class _FriendsFollowersScreenState
    extends ConsumerState<FriendsFollowersScreen> {
  late final UserService _userService;
  late final AuthService _authService;
  late final WebSocketService _webSocketService;

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
  int _webTab = 0; // web: 0 friends, 1 requests, 2 suggestions

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
    _userService = ref.read(userServiceProvider);
    _authService = ref.read(authServiceProvider);
    _webSocketService = ref.read(websocketServiceProvider);

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
      await _authService.logout();
      if (mounted) {
        // Navigate to home screen and clear navigation stack
        Navigator.of(context).pushAndRemoveUntil(
          PageTransitions.fade(const InitialScreen()),
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
    AuthNavigationHelper.navigateToUserProfile(context, userId,
        origin: ProfileOrigin.friends);
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return _buildAndroid();
    return WandererScaffold(
      hideAppBarWithSidebar: true,
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
      body: _buildWebBody(),
    );
  }

  // ---------------------------------------------------------------------
  // Android layout (canvas "AndroidFriends"): Friends / Requests /
  // Suggested tabs over a plain list; row actions live in a bottom sheet.
  // ---------------------------------------------------------------------

  Widget _buildAndroid() {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    final Widget body;
    if (_isLoading && _currentUser == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null && !_isLoggedIn) {
      body = Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textMuted)),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: _navigateToAuth, child: Text(l10n.login)),
        ]),
      );
    } else {
      final rows = switch (_webTab) {
        0 => [
            for (final u in _associatedUsers)
              _androidRow(
                userId: u.id,
                username: u.username,
                displayName: u.displayName,
                isFriend: u.isFriend,
                isFollowing: u.isFollowing,
                isFollowedBy: u.isFollowedBy,
              ),
          ],
        1 => [
            for (final r in [..._receivedRequests, ..._sentRequests])
              _androidRequestRow(r),
          ],
        _ => [
            for (final u in _discoverableUsers)
              () {
                final a =
                    _associatedUsers.where((x) => x.id == u.id).firstOrNull;
                return _androidRow(
                  userId: u.id,
                  username: u.username,
                  displayName: u.displayName,
                  isFriend: a?.isFriend ?? false,
                  isFollowing: a?.isFollowing ?? false,
                  isFollowedBy: a?.isFollowedBy ?? false,
                );
              }(),
          ],
      };
      final (hasMore, loadingMore, loadMore) = switch (_webTab) {
        0 => (
            _hasMoreAssociated,
            _isLoadingMoreAssociated,
            _loadMoreAssociated
          ),
        2 => (_hasMoreDiscover, _isLoadingMoreDiscover, _loadMoreDiscover),
        _ => (false, false, () async {}),
      };
      final empty = switch (_webTab) {
        0 => FriendsEmptyState(
            title: l10n.friendsEmptyTitle, body: l10n.friendsEmptyBody),
        1 => FriendsEmptyState(
            icon: Icons.inbox_outlined,
            title: l10n.noFriendRequests,
            body: l10n.sendFriendRequests),
        _ => FriendsEmptyState(
            icon: Icons.explore_outlined,
            title: l10n.noUsersToDiscover,
            body: l10n.addFriendsToDiscoverMore),
      };
      body = Column(children: [
        _androidTabs(c),
        Expanded(
          child: ColoredBox(
            color: c.surface,
            child: RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  if (rows.isEmpty)
                    Padding(padding: const EdgeInsets.all(16), child: empty)
                  else
                    ...rows,
                  if (hasMore)
                    _buildLoadMoreButton(
                        isLoading: loadingMore, onPressed: loadMore),
                ],
              ),
            ),
          ),
        ),
      ]);
    }
    return Scaffold(
      backgroundColor: c.ground,
      appBar: AndroidTopBar(
        title: l10n.friends,
        actions: [
          IconButton(
            tooltip: l10n.friendsSearchByUsername,
            icon: const Icon(Icons.person_search_outlined),
            onPressed: _openSearch,
          ),
        ],
      ),
      body: body,
    );
  }

  Widget _androidTabs(WandererColors c) {
    final l10n = context.l10n;
    final tabs = [
      (l10n.friends, _associatedUsers.length, c.trailSoftBg, c.accentText),
      (
        l10n.requestsTab,
        _receivedRequests.length + _sentRequests.length,
        _receivedRequests.isNotEmpty ? WandererTheme.trail : c.neutralBg,
        _receivedRequests.isNotEmpty ? Colors.white : c.neutralFg,
      ),
      (
        l10n.friendsSuggestionsTab,
        _discoverableUsers.length,
        c.neutralBg,
        c.neutralFg
      ),
    ];
    return Container(
      decoration:
          BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
      child: Row(children: [
        for (var i = 0; i < tabs.length; i++)
          Expanded(
            child: Semantics(
              selected: _webTab == i,
              button: true,
              child: InkWell(
                onTap: () => setState(() => _webTab = i),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        width: 3,
                        color: _webTab == i
                            ? WandererTheme.trail
                            : Colors.transparent,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(tabs[i].$1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: _webTab == i
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              color: _webTab == i ? c.accentText : c.textMuted,
                            )),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 1),
                        decoration: BoxDecoration(
                            color: tabs[i].$3,
                            borderRadius: BorderRadius.circular(999)),
                        child: Text('${tabs[i].$2}',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: tabs[i].$4)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _androidTile({
    required String userId,
    required String username,
    String? displayName,
    required String subtitle,
    required Widget trailing,
  }) {
    final c = WandererTheme.of(context);
    return InkWell(
      onTap: () => _navigateToUserProfile(userId),
      child: Container(
        constraints: const BoxConstraints(minHeight: 68),
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: c.lineSoft))),
        child: Row(children: [
          UserAvatar(
            userId: userId,
            username: username,
            displayName: displayName,
            radius: 22,
            backgroundColor: c.trailSoftBg,
            textColor: c.accentText,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(displayName ?? username,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: c.text)),
                if (subtitle.isNotEmpty)
                  Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: c.textMuted)),
              ],
            ),
          ),
          trailing,
        ]),
      ),
    );
  }

  Widget _androidRow({
    required String userId,
    required String username,
    String? displayName,
    required bool isFriend,
    required bool isFollowing,
    required bool isFollowedBy,
  }) {
    final l10n = context.l10n;
    final received = _receivedFrom(userId);
    final sent = _sentTo(userId);
    final subtitle = [
      if (isFriend) l10n.friend,
      if (!isFriend && received != null) l10n.friendsPillWantsToBeFriends,
      if (!isFriend && sent != null) l10n.friendsPillRequestPending,
      if (isFollowing) l10n.friendsPillYouFollow,
      if (isFollowedBy) l10n.friendsPillFollowsYou,
    ].join(' · ');
    return _androidTile(
      userId: userId,
      username: username,
      displayName: displayName,
      subtitle: subtitle,
      trailing: IconButton(
        tooltip: l10n.youMoreOptions,
        icon: Icon(Icons.more_vert, color: WandererTheme.of(context).textMuted),
        onPressed: () => _androidActions(
          userId: userId,
          username: username,
          isFriend: isFriend,
          isFollowing: isFollowing,
          received: received,
          sent: sent,
        ),
      ),
    );
  }

  Widget _androidRequestRow(FriendRequest request) {
    final l10n = context.l10n;
    final c = WandererTheme.of(context);
    final received = _receivedRequests.contains(request);
    final userId = received ? request.senderId : request.receiverId;
    final profile = _userProfiles[userId];
    final when = _formatDate(context, request.createdAt);
    return _androidTile(
      userId: userId,
      username: profile?.username ?? l10n.unknownUser,
      displayName: profile?.displayName,
      subtitle: received
          ? '${l10n.friendsPillWantsToBeFriends} · $when'
          : '${l10n.friendsPillRequestPending} · $when',
      trailing: received
          ? Row(mainAxisSize: MainAxisSize.min, children: [
              FilledButton(
                onPressed: () => _handleAcceptFriendRequest(request.id),
                style: FilledButton.styleFrom(
                  backgroundColor: WandererTheme.trail,
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(l10n.acceptRequest),
              ),
              IconButton(
                tooltip: l10n.declineRequest,
                icon: Icon(Icons.close, color: c.textMuted),
                onPressed: () => _handleDeclineFriendRequest(request.id),
              ),
            ])
          : TextButton(
              onPressed: () => _handleCancelFriendRequest(request.id),
              style: TextButton.styleFrom(foregroundColor: c.accentText),
              child: Text(l10n.friendsCancelRequest),
            ),
    );
  }

  Future<void> _androidActions({
    required String userId,
    required String username,
    required bool isFriend,
    required bool isFollowing,
    FriendRequest? received,
    FriendRequest? sent,
  }) {
    final l10n = context.l10n;
    Widget item(IconData icon, String label, Future<void> Function() onTap) =>
        ListTile(
          leading: Icon(icon),
          title: Text(label),
          onTap: () {
            Navigator.pop(context);
            onTap();
          },
        );
    return showWandererSheet(
      context,
      title: username,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          item(Icons.person_outline, l10n.viewProfile,
              () async => _navigateToUserProfile(userId)),
          if (!isFriend && received != null) ...[
            item(Icons.check, l10n.acceptRequest,
                () => _handleAcceptFriendRequest(received.id)),
            item(Icons.close, l10n.declineRequest,
                () => _handleDeclineFriendRequest(received.id)),
          ] else if (!isFriend && sent != null)
            item(Icons.person_remove_outlined, l10n.friendsCancelRequest,
                () => _handleCancelFriendRequest(sent.id))
          else if (!isFriend)
            item(Icons.person_add_alt, l10n.friendsAddFriend,
                () => _handleSendFriendRequest(userId, username))
          else
            item(Icons.person_remove_outlined, l10n.unfriend,
                () => _handleRemoveFriend(userId, username)),
          isFollowing
              ? item(Icons.remove_circle_outline, l10n.unfollow,
                  () => _handleUnfollowUser(userId))
              : item(Icons.add_circle_outline, l10n.follow,
                  () => _handleFollowUser(userId)),
        ],
      ),
    );
  }

  Future<void> _handleRemoveFriend(String userId, String username) async {
    try {
      await _userService.removeFriend(userId);
      if (mounted) {
        UiHelpers.showSuccessMessage(
            context, context.l10n.noLongerFriendsWith(username));
        await _loadData();
      }
    } catch (e) {
      if (mounted) UiHelpers.showErrorMessage(context, e.toString());
    }
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

  // ---------------------------------------------------------------------
  // Web layout (design board "Friends"). Android: [_buildAndroid].
  // ---------------------------------------------------------------------

  FriendRequest? _receivedFrom(String userId) =>
      _receivedRequests.where((r) => r.senderId == userId).firstOrNull;

  FriendRequest? _sentTo(String userId) =>
      _sentRequests.where((r) => r.receiverId == userId).firstOrNull;

  Future<void> _handleCancelFriendRequest(String requestId) async {
    try {
      await _userService.deleteFriendRequest(requestId);
      if (mounted) {
        UiHelpers.showSuccessMessage(
            context, context.l10n.friendRequestCancelled);
        await _loadData();
      }
    } catch (e) {
      if (mounted) {
        UiHelpers.showErrorMessage(
            context, context.l10n.failedToDeclineFriendRequest(e.toString()));
      }
    }
  }

  void _openSearch() {
    if (kIsWeb) {
      showSearchOverlay(context);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SearchScreen()),
    );
  }

  /// Copies the `/user/<username>` deep link (see UserRouteStrategy).
  void _copyInviteLink() {
    final username = _currentUser?.username;
    if (username == null) return;
    Clipboard.setData(ClipboardData(
        text:
            '${ApiEndpoints.appBaseUrl}/user/${Uri.encodeComponent(username)}'));
    UiHelpers.showSuccessMessage(context, context.l10n.friendsInviteLinkCopied);
  }

  Widget _buildWebBody() {
    final l10n = context.l10n;
    // Polling reloads every 15s; only block the page on the first load.
    if (_isLoading && _currentUser == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && !_isLoggedIn) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: _navigateToAuth, child: Text(l10n.login)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1000;
        final gutter = constraints.maxWidth >= 720 ? 40.0 : 16.0;
        final side = [
          AddFriendsCard(
            onSearch: _openSearch,
            onCopyInviteLink: _currentUser == null ? null : _copyInviteLink,
          ),
          const SizedBox(height: 24),
          WaitingForYouCard(
            requests: [
              for (final r in _receivedRequests)
                (
                  id: r.id,
                  username:
                      _userProfiles[r.senderId]?.username ?? l10n.unknownUser,
                  displayName: _userProfiles[r.senderId]?.displayName,
                  avatarUrl: _userProfiles[r.senderId]?.avatarUrl,
                  onOpen: () => _navigateToUserProfile(r.senderId),
                ),
            ],
            onAccept: _handleAcceptFriendRequest,
            onDecline: _handleDeclineFriendRequest,
          ),
        ];

        return ListView(
          padding: EdgeInsets.fromLTRB(gutter, 28, gutter, 40),
          children: [
            WebPageHeader(
              title: l10n.friends,
              subtitle: l10n.friendsPageSubtitle,
              userId: _currentUser?.id,
              isLoggedIn: _isLoggedIn,
            ),
            const SizedBox(height: 24),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildWebListCard()),
                  const SizedBox(width: 24),
                  SizedBox(width: 360, child: Column(children: side)),
                ],
              )
            else ...[
              ...side,
              const SizedBox(height: 24),
              _buildWebListCard(),
            ],
          ],
        );
      }),
    );
  }

  Widget _buildWebListCard() {
    final l10n = context.l10n;
    final requestCount = _receivedRequests.length + _sentRequests.length;
    final rows = switch (_webTab) {
      0 => _associatedUsers.map(_buildWebAssociatedRow).toList(),
      1 => [
          ..._receivedRequests.map((r) => _buildWebRequestRow(r, true)),
          ..._sentRequests.map((r) => _buildWebRequestRow(r, false)),
        ],
      _ => _discoverableUsers.map(_buildWebSuggestionRow).toList(),
    };
    final (hasMore, loadingMore, loadMore) = switch (_webTab) {
      0 => (_hasMoreAssociated, _isLoadingMoreAssociated, _loadMoreAssociated),
      2 => (_hasMoreDiscover, _isLoadingMoreDiscover, _loadMoreDiscover),
      _ => (false, false, () async {}),
    };
    final empty = switch (_webTab) {
      0 => FriendsEmptyState(
          title: l10n.friendsEmptyTitle, body: l10n.friendsEmptyBody),
      1 => FriendsEmptyState(
          icon: Icons.inbox_outlined,
          title: l10n.noFriendRequests,
          body: l10n.sendFriendRequests),
      _ => FriendsEmptyState(
          icon: Icons.explore_outlined,
          title: l10n.noUsersToDiscover,
          body: l10n.addFriendsToDiscoverMore),
    };

    return Container(
      decoration: WandererTheme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FriendsUnderlineTabs(
            tabs: [
              (l10n.friends, _associatedUsers.length, false),
              (l10n.requestsTab, requestCount, _receivedRequests.isNotEmpty),
              (l10n.friendsSuggestionsTab, _discoverableUsers.length, false),
            ],
            selected: _webTab,
            onSelected: (i) => setState(() => _webTab = i),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (rows.isEmpty) empty else ...rows,
                if (hasMore)
                  _buildLoadMoreButton(
                      isLoading: loadingMore, onPressed: loadMore),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _viewProfileButton(String userId) => OutlinedButton(
        onPressed: () => _navigateToUserProfile(userId),
        style: friendsRowButtonStyle(context),
        child: Text(context.l10n.viewProfile),
      );

  Widget _followButton(String userId, bool isFollowing) => TextButton(
        onPressed: () => isFollowing
            ? _handleUnfollowUser(userId)
            : _handleFollowUser(userId),
        child: Text(isFollowing ? context.l10n.unfollow : context.l10n.follow),
      );

  /// Relationship pills plus the friend-request action for a person.
  (List<Widget>, List<Widget>) _relationshipParts({
    required String userId,
    required String username,
    required bool isFriend,
    required bool isFollowing,
    required bool isFollowedBy,
  }) {
    final l10n = context.l10n;
    final received = _receivedFrom(userId);
    final sent = _sentTo(userId);
    final pills = <Widget>[
      if (isFriend) Pill(l10n.friend, tone: PillTone.completed),
      if (!isFriend && sent != null)
        Pill(l10n.friendsPillRequestPending, tone: PillTone.gold),
      if (!isFriend && received != null)
        Pill(l10n.friendsPillWantsToBeFriends, tone: PillTone.promoted),
      if (isFollowing) Pill(l10n.friendsPillYouFollow, tone: PillTone.progress),
      if (isFollowedBy) Pill(l10n.friendsPillFollowsYou),
    ];
    final actions = <Widget>[
      _viewProfileButton(userId),
      if (!isFriend && received != null) ...[
        FriendsAcceptButton(
            onPressed: () => _handleAcceptFriendRequest(received.id)),
        FriendsDeclineButton(
            onPressed: () => _handleDeclineFriendRequest(received.id)),
      ] else if (!isFriend && sent != null)
        OutlinedButton(
          onPressed: () => _handleCancelFriendRequest(sent.id),
          style: friendsRowButtonStyle(context,
              foreground: Theme.of(context).colorScheme.error),
          child: Text(l10n.friendsCancelRequest),
        )
      else if (!isFriend)
        OutlinedButton(
          onPressed: () => _handleSendFriendRequest(userId, username),
          style: friendsRowButtonStyle(context),
          child: Text(l10n.friendsAddFriend),
        ),
      _followButton(userId, isFollowing),
    ];
    return (pills, actions);
  }

  Widget _buildWebAssociatedRow(UserRelationship user) {
    final (pills, actions) = _relationshipParts(
      userId: user.id,
      username: user.username,
      isFriend: user.isFriend,
      isFollowing: user.isFollowing,
      isFollowedBy: user.isFollowedBy,
    );
    return FriendRow(
      username: user.username,
      displayName: user.displayName,
      avatarUrl: user.avatarUrl,
      pills: pills,
      actions: actions,
      onTap: () => _navigateToUserProfile(user.id),
    );
  }

  Widget _buildWebSuggestionRow(UserProfile user) {
    final associated =
        _associatedUsers.where((a) => a.id == user.id).firstOrNull;
    final (pills, actions) = _relationshipParts(
      userId: user.id,
      username: user.username,
      isFriend: associated?.isFriend ?? false,
      isFollowing: associated?.isFollowing ?? false,
      isFollowedBy: associated?.isFollowedBy ?? false,
    );
    return FriendRow(
      username: user.username,
      displayName: user.displayName,
      avatarUrl: user.avatarUrl,
      pills: pills,
      actions: actions,
      onTap: () => _navigateToUserProfile(user.id),
    );
  }

  Widget _buildWebRequestRow(FriendRequest request, bool received) {
    final l10n = context.l10n;
    final userId = received ? request.senderId : request.receiverId;
    final profile = _userProfiles[userId];
    final username = profile?.username ?? l10n.unknownUser;
    return FriendRow(
      username: username,
      displayName: profile?.displayName,
      avatarUrl: profile?.avatarUrl,
      pills: [
        received
            ? Pill(l10n.friendsPillWantsToBeFriends, tone: PillTone.promoted)
            : Pill(l10n.friendsPillRequestPending, tone: PillTone.gold),
        Pill(l10n.sentDateLabel(_formatDate(context, request.createdAt))),
      ],
      actions: [
        _viewProfileButton(userId),
        if (received) ...[
          FriendsAcceptButton(
              onPressed: () => _handleAcceptFriendRequest(request.id)),
          FriendsDeclineButton(
              onPressed: () => _handleDeclineFriendRequest(request.id)),
        ] else
          OutlinedButton(
            onPressed: () => _handleCancelFriendRequest(request.id),
            style: friendsRowButtonStyle(context,
                foreground: Theme.of(context).colorScheme.error),
            child: Text(l10n.friendsCancelRequest),
          ),
      ],
      onTap: () => _navigateToUserProfile(userId),
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
}
