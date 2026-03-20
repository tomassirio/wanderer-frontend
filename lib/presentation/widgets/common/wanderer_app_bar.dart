import 'dart:async';

import 'package:flutter/material.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/data/models/websocket/websocket_event.dart';
import 'package:wanderer_frontend/data/services/notification_api_service.dart';
import 'package:wanderer_frontend/data/services/websocket_service.dart';
import 'package:wanderer_frontend/presentation/widgets/common/notifications_dropdown.dart';
import 'package:wanderer_frontend/core/theme/theme_controller.dart';
import 'package:wanderer_frontend/presentation/widgets/common/wanderer_logo.dart';
import 'package:wanderer_frontend/presentation/widgets/common/search_bar_widget.dart';

/// Reusable AppBar for the Wanderer application
class WandererAppBar extends StatefulWidget implements PreferredSizeWidget {
  final bool isLoggedIn;
  final VoidCallback? onLoginPressed;
  final String? username;
  final String? userId;
  final String? displayName;
  final String? avatarUrl;
  final VoidCallback? onProfile;
  final VoidCallback? onSettings;
  final VoidCallback? onLogout;

  const WandererAppBar({
    super.key,
    required this.isLoggedIn,
    this.onLoginPressed,
    this.username,
    this.userId,
    this.displayName,
    this.avatarUrl,
    this.onProfile,
    this.onSettings,
    this.onLogout,
  });

  @override
  State<WandererAppBar> createState() => _WandererAppBarState();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _WandererAppBarState extends State<WandererAppBar>
    with SingleTickerProviderStateMixin {
  bool _isSearchExpanded = false;
  int _unreadCount = 0;
  final NotificationApiService _notificationService = NotificationApiService();
  final WebSocketService _webSocketService = WebSocketService();
  final GlobalKey _notificationButtonKey = GlobalKey();
  StreamSubscription<WebSocketEvent>? _wsSubscription;
  String? _subscribedUserId;
  Timer? _pollTimer;
  Timer? _debounceTimer;

  late final AnimationController _searchAnimController;
  late final Animation<double> _searchAnimation;

  /// Event types that typically generate a notification on the backend.
  /// When any of these arrive we debounce-refresh the unread count from the API.
  static const _notificationTriggerEvents = {
    WebSocketEventType.commentAdded,
    WebSocketEventType.userFollowed,
    WebSocketEventType.friendRequestSent,
    WebSocketEventType.friendRequestAccepted,
    WebSocketEventType.friendRequestDeclined,
    WebSocketEventType.friendshipCreated,
    WebSocketEventType.tripStatusChanged,
    WebSocketEventType.tripUpdateCreated,
    WebSocketEventType.commentReactionAdded,
    WebSocketEventType.commentReactionReplaced,
    WebSocketEventType.commentReaction,
  };

  @override
  void initState() {
    super.initState();
    _searchAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _searchAnimation = CurvedAnimation(
      parent: _searchAnimController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _searchAnimController.addStatusListener((status) {
      if (status == AnimationStatus.dismissed) {
        setState(() => _isSearchExpanded = false);
      }
    });
    if (widget.isLoggedIn) {
      _fetchUnreadCount();
      _subscribeToNotificationEvents();
    }
  }

  @override
  void didUpdateWidget(covariant WandererAppBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoggedIn && !oldWidget.isLoggedIn) {
      _fetchUnreadCount();
      _subscribeToNotificationEvents();
    } else if (!widget.isLoggedIn && oldWidget.isLoggedIn) {
      _cancelSubscriptions();
      setState(() {
        _unreadCount = 0;
      });
    } else if (widget.isLoggedIn &&
        widget.userId != oldWidget.userId &&
        widget.userId != null) {
      // User ID changed while still logged in — resubscribe
      _fetchUnreadCount();
      _subscribeToNotificationEvents();
    }
  }

  @override
  void dispose() {
    _cancelSubscriptions();
    _searchAnimController.dispose();
    super.dispose();
  }

  void _cancelSubscriptions() {
    _wsSubscription?.cancel();
    _wsSubscription = null;
    _pollTimer?.cancel();
    _pollTimer = null;
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _subscribedUserId = null;
  }

  void _subscribeToNotificationEvents() {
    final userId = widget.userId;
    if (userId == null) return;

    // Already subscribed to this user — skip
    if (_subscribedUserId == userId && _wsSubscription != null) return;

    _wsSubscription?.cancel();
    _wsSubscription = null;
    _pollTimer?.cancel();
    _debounceTimer?.cancel();
    _subscribedUserId = userId;

    // Start periodic polling as a reliable fallback.
    // This ensures the badge updates even when the WebSocket connection
    // is unavailable (e.g. dev server, firewall, or backend doesn't send
    // NOTIFICATION_CREATED events).
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && widget.isLoggedIn) {
        _fetchUnreadCount();
      }
    });

    // Kick off WebSocket connect + subscribe asynchronously
    _connectAndSubscribe(userId);
  }

  Future<void> _connectAndSubscribe(String userId) async {
    // Ensure the WebSocket is connected before subscribing.
    // Awaiting avoids the race where subscribeToUser runs before the
    // connection is established and _handleConnectionStateChange has
    // already fired for pending subscriptions.
    await _webSocketService.connect();

    if (!mounted || _subscribedUserId != userId) return;

    // Subscribe to the user's WebSocket topic so NOTIFICATION_CREATED events
    // arrive on all platforms (PushNotificationManager only subscribes on Android)
    _webSocketService.subscribeToUser(userId);

    // Listen on the global events stream — it receives ALL events from every
    // subscribed topic.
    _wsSubscription = _webSocketService.events.listen((event) {
      if (!mounted) return;

      if (event.type == WebSocketEventType.notificationCreated) {
        // Explicit notification event → increment immediately
        setState(() {
          _unreadCount++;
        });
      } else if (_notificationTriggerEvents.contains(event.type)) {
        // Other events that typically create a notification on the backend.
        // Debounce an API refresh so we don't fire for every single event.
        _debounceFetchUnreadCount();
      }
    });
  }

  /// Debounce the unread count fetch so rapid-fire events only trigger one call.
  void _debounceFetchUnreadCount() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 2), () {
      if (mounted && widget.isLoggedIn) {
        _fetchUnreadCount();
      }
    });
  }

  Future<void> _fetchUnreadCount() async {
    try {
      final count = await _notificationService.getUnreadCount();
      if (mounted) {
        setState(() {
          _unreadCount = count;
        });
      }
    } catch (e) {
      debugPrint('WandererAppBar: Failed to fetch unread count: $e');
    }
  }

  /// Get the initial letter for the avatar, preferring displayName over username
  String get _avatarInitial {
    final name = widget.displayName ?? widget.username ?? '';
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  void _toggleSearch() {
    if (_isSearchExpanded) {
      _searchAnimController.reverse();
    } else {
      setState(() => _isSearchExpanded = true);
      _searchAnimController.forward();
    }
  }

  void _showNotificationsDropdown() {
    final renderBox =
        _notificationButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final buttonPosition = renderBox.localToGlobal(Offset.zero);
    final buttonSize = renderBox.size;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;

    final position = RelativeRect.fromRect(
      Rect.fromLTWH(
        buttonPosition.dx,
        buttonPosition.dy + buttonSize.height,
        buttonSize.width,
        0,
      ),
      Offset.zero & overlay.size,
    );

    showNotificationsDropdown(context: context, position: position).then((_) {
      // Always refresh the unread count when the dropdown closes,
      // regardless of how it was dismissed (notification tap, "Read all",
      // or barrier tap). This ensures the badge stays in sync.
      if (mounted && widget.isLoggedIn) {
        _fetchUnreadCount();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 600;
    return AppBar(
      backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      centerTitle: isDesktop,
      titleSpacing: _isSearchExpanded ? 8.0 : (isDesktop ? null : 0),
      title: _isSearchExpanded
          ? Align(
              alignment: Alignment.center,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(1.0, 0.0),
                    end: Offset.zero,
                  ).animate(_searchAnimation),
                  child: FadeTransition(
                    opacity: _searchAnimation,
                    child: SearchBarWidget(onClose: _toggleSearch),
                  ),
                ),
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  borderRadius: BorderRadius.circular(15),
                  child: const Padding(
                    padding: EdgeInsets.all(2.0),
                    child: WandererLogo(size: 30),
                  ),
                ),
                const SizedBox(width: 8),
                const Flexible(
                  child: Text(
                    'Wanderer',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
      actions: [
        // Dark mode toggle — hidden while search is expanded
        if (!_isSearchExpanded)
          ValueListenableBuilder<ThemeMode>(
            valueListenable: ThemeController().themeMode,
            builder: (context, mode, _) {
              final isDark = mode == ThemeMode.dark;
              return IconButton(
                icon: Icon(
                  isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                ),
                tooltip:
                    isDark ? 'Switch to light mode' : 'Switch to dark mode',
                onPressed: () => ThemeController().setDarkMode(!isDark),
              );
            },
          ),
        // Search icon (hidden while search is expanded — close is inside the bar)
        if (!_isSearchExpanded)
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search',
            onPressed: _toggleSearch,
          ),
        // Notifications icon with badge (only for logged in users)
        if (widget.isLoggedIn)
          IconButton(
            key: _notificationButtonKey,
            icon: Badge(
              isLabelVisible: _unreadCount > 0,
              label: Text(
                _unreadCount > 99 ? '99+' : '$_unreadCount',
                style: const TextStyle(fontSize: 10),
              ),
              child: const Icon(Icons.notifications_outlined),
            ),
            tooltip: 'Notifications',
            onPressed: _showNotificationsDropdown,
          ),
        if (!widget.isLoggedIn && widget.onLoginPressed != null)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: widget.onLoginPressed,
              icon: const Icon(Icons.login, size: 18, color: Colors.white),
              label: const Text('Login',
                  style: TextStyle(fontSize: 13, color: Colors.white)),
            ),
          ),
        if (widget.isLoggedIn && widget.username != null)
          Padding(
            padding: EdgeInsets.only(right: isDesktop ? 16 : 4),
            child: PopupMenuButton<String>(
              icon: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primary,
                backgroundImage:
                    widget.avatarUrl != null && widget.avatarUrl!.isNotEmpty
                        ? NetworkImage(widget.avatarUrl!)
                        : null,
                child: widget.avatarUrl == null || widget.avatarUrl!.isEmpty
                    ? Text(
                        _avatarInitial,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              tooltip: 'Profile',
              onSelected: (value) {
                switch (value) {
                  case 'profile':
                    widget.onProfile?.call();
                    break;
                  case 'settings':
                    widget.onSettings?.call();
                    break;
                  case 'logout':
                    widget.onLogout?.call();
                    break;
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem<String>(
                  enabled: false,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor:
                                  Theme.of(context).colorScheme.primary,
                              backgroundImage: widget.avatarUrl != null &&
                                      widget.avatarUrl!.isNotEmpty
                                  ? NetworkImage(widget.avatarUrl!)
                                  : null,
                              child: widget.avatarUrl == null ||
                                      widget.avatarUrl!.isEmpty
                                  ? Text(
                                      _avatarInitial,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.displayName ?? widget.username!,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    '@${widget.username!}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Divider(),
                      ],
                    ),
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'profile',
                  child: Row(
                    children: [
                      Icon(Icons.person),
                      SizedBox(width: 12),
                      Text('User Profile'),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'settings',
                  child: Row(
                    children: [
                      Icon(Icons.settings),
                      SizedBox(width: 12),
                      Text('Settings'),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout, color: Colors.red),
                      SizedBox(width: 12),
                      Text('Logout', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
