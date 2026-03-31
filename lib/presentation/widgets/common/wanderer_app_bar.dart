import 'dart:async';

import 'package:flutter/material.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/data/client/websocket_client.dart';
import 'package:wanderer_frontend/data/models/websocket/websocket_event.dart';
import 'package:wanderer_frontend/data/services/notification_api_service.dart';
import 'package:wanderer_frontend/data/services/websocket_service.dart';
import 'package:wanderer_frontend/presentation/widgets/common/notifications_dropdown.dart';
import 'package:wanderer_frontend/core/theme/theme_controller.dart';
import 'package:wanderer_frontend/presentation/widgets/common/wanderer_logo.dart';
import 'package:wanderer_frontend/presentation/helpers/avatar_helper.dart';
import 'package:wanderer_frontend/core/constants/api_endpoints.dart';
import 'package:wanderer_frontend/presentation/screens/search_screen.dart';

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
  final Widget? leading;

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
    this.leading,
  });

  @override
  State<WandererAppBar> createState() => _WandererAppBarState();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _WandererAppBarState extends State<WandererAppBar>
    with SingleTickerProviderStateMixin {
  int _unreadCount = 0;
  final NotificationApiService _notificationService = NotificationApiService();
  final WebSocketService _webSocketService = WebSocketService();
  final GlobalKey _notificationButtonKey = GlobalKey();
  StreamSubscription<WebSocketEvent>? _wsSubscription;
  StreamSubscription<WebSocketConnectionState>? _wsConnectionSubscription;
  String? _subscribedUserId;
  Timer? _pollTimer;
  Timer? _debounceTimer;
  bool _isWebSocketConnected = false;

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
    if (widget.isLoggedIn) {
      _fetchUnreadCount();
    }

    // Always listen to the global WebSocket events stream immediately.
    // This ensures notification events are caught even before the userId
    // is available — the global stream receives events from ALL subscribed
    // topics (including ones subscribed by other screens).
    _wsSubscription = _webSocketService.events.listen(_handleGlobalEvent);

    // Listen to WebSocket connection state to manage polling strategy
    _wsConnectionSubscription =
        _webSocketService.connectionState.listen(_handleConnectionStateChange);

    // If userId is already available, ensure the user topic is subscribed.
    if (widget.isLoggedIn && widget.userId != null) {
      _ensureUserTopicSubscribed(widget.userId!);
    }
  }

  @override
  void didUpdateWidget(covariant WandererAppBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoggedIn && !oldWidget.isLoggedIn) {
      // Just became logged in — fetch the real count from the API
      // to pick up any notifications missed during the async window.
      _fetchUnreadCount();
      if (widget.userId != null) {
        _ensureUserTopicSubscribed(widget.userId!);
      }
    } else if (!widget.isLoggedIn && oldWidget.isLoggedIn) {
      _stopPolling();
      setState(() {
        _unreadCount = 0;
      });
    } else if (widget.isLoggedIn &&
        widget.userId != oldWidget.userId &&
        widget.userId != null) {
      // User ID changed while still logged in — resubscribe to user topic
      // and refresh count in case it was stale.
      _fetchUnreadCount();
      _ensureUserTopicSubscribed(widget.userId!);
    }
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _wsSubscription = null;
    _wsConnectionSubscription?.cancel();
    _wsConnectionSubscription = null;
    _stopPolling();
    super.dispose();
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _debounceTimer?.cancel();
    _debounceTimer = null;
  }

  /// Start smart polling as a fallback only when WebSocket is disconnected.
  /// Uses a longer interval (5 minutes) since WebSocket provides real-time updates.
  /// Automatically stops when WebSocket reconnects.
  void _startPolling() {
    if (_isWebSocketConnected) {
      // WebSocket is connected, no need to poll
      debugPrint('WandererAppBar: WebSocket connected, skipping polling');
      return;
    }

    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (mounted && widget.isLoggedIn && !_isWebSocketConnected) {
        debugPrint('WandererAppBar: Polling fallback - fetching unread count');
        _fetchUnreadCount();
      }
    });
    debugPrint('WandererAppBar: Started polling fallback (5 min interval)');
  }

  /// Handle WebSocket connection state changes
  void _handleConnectionStateChange(WebSocketConnectionState state) {
    if (!mounted) return;

    final wasConnected = _isWebSocketConnected;
    _isWebSocketConnected = state == WebSocketConnectionState.connected;

    if (_isWebSocketConnected && !wasConnected) {
      // WebSocket just connected - stop polling and fetch current count
      debugPrint('WandererAppBar: WebSocket connected, stopping polling');
      _stopPolling();
      if (widget.isLoggedIn) {
        _fetchUnreadCount();
      }
    } else if (!_isWebSocketConnected && wasConnected) {
      // WebSocket just disconnected - start polling fallback
      debugPrint(
          'WandererAppBar: WebSocket disconnected, starting polling fallback');
      if (widget.isLoggedIn) {
        _startPolling();
      }
    }
  }

  /// Ensure the user's WebSocket topic is subscribed so NOTIFICATION_CREATED
  /// events arrive. The global events listener is set up separately in
  /// initState and doesn't depend on this.
  void _ensureUserTopicSubscribed(String userId) {
    if (_subscribedUserId == userId) return;
    _subscribedUserId = userId;

    // Fire-and-forget: connect then subscribe to the user topic.
    // The global events listener (set up in initState) will already
    // catch events once the subscription is active.
    _webSocketService.connect().then((_) {
      if (!mounted || _subscribedUserId != userId) return;
      _webSocketService.subscribeToUser(userId);
    });
  }

  /// Handle a WebSocket event from the global events stream.
  void _handleGlobalEvent(WebSocketEvent event) {
    if (!mounted || !widget.isLoggedIn) return;

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

  /// Get the initials for the avatar (max 3 letters)
  String get _avatarInitial {
    return AvatarHelper.getInitials(widget.displayName, widget.username ?? '?');
  }

  void _navigateToSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SearchScreen()),
    );
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
    final l10n = context.l10n;
    return AppBar(
      backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      centerTitle: isDesktop,
      leading: widget.leading,
      title: Row(
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
          const Text(
            'Wanderer',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      actions: [
        // Dark mode toggle — only for logged in users
        if (widget.isLoggedIn)
          ValueListenableBuilder<ThemeMode>(
            valueListenable: ThemeController().themeMode,
            builder: (context, mode, _) {
              final isDark = mode == ThemeMode.dark;
              return IconButton(
                icon: Icon(
                  isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                ),
                tooltip:
                    isDark ? l10n.switchToLightMode : l10n.switchToDarkMode,
                onPressed: () => ThemeController().setDarkMode(!isDark),
              );
            },
          ),
        // Search icon — only for logged in users
        if (widget.isLoggedIn)
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: l10n.search,
            onPressed: _navigateToSearch,
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
            tooltip: l10n.notifications,
            onPressed: _showNotificationsDropdown,
          ),
        if (!widget.isLoggedIn && widget.onLoginPressed != null)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: widget.onLoginPressed,
              icon: const Icon(Icons.login, size: 18, color: Colors.white),
              label: Text(l10n.login,
                  style: const TextStyle(fontSize: 13, color: Colors.white)),
            ),
          ),
        if (widget.isLoggedIn && widget.username != null)
          Padding(
            padding: EdgeInsets.only(right: isDesktop ? 16 : 4),
            child: PopupMenuButton<String>(
              icon: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundImage:
                    widget.avatarUrl != null && widget.avatarUrl!.isNotEmpty
                        ? NetworkImage(
                            ApiEndpoints.resolveThumbnailUrl(widget.avatarUrl))
                        : null,
                onForegroundImageError:
                    widget.avatarUrl != null && widget.avatarUrl!.isNotEmpty
                        ? (_, __) {}
                        : null,
                child: Text(
                  _avatarInitial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              tooltip: l10n.profile,
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
                              foregroundImage: widget.avatarUrl != null &&
                                      widget.avatarUrl!.isNotEmpty
                                  ? NetworkImage(
                                      ApiEndpoints.resolveThumbnailUrl(
                                          widget.avatarUrl))
                                  : null,
                              onForegroundImageError:
                                  widget.avatarUrl != null &&
                                          widget.avatarUrl!.isNotEmpty
                                      ? (_, __) {}
                                      : null,
                              child: Text(
                                _avatarInitial,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
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
                PopupMenuItem<String>(
                  value: 'profile',
                  child: Row(
                    children: [
                      const Icon(Icons.person),
                      const SizedBox(width: 12),
                      Text(l10n.userProfile),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'settings',
                  child: Row(
                    children: [
                      const Icon(Icons.settings),
                      const SizedBox(width: 12),
                      Text(l10n.settings),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'logout',
                  child: Row(
                    children: [
                      const Icon(Icons.logout, color: Colors.red),
                      const SizedBox(width: 12),
                      Text(l10n.logout,
                          style: const TextStyle(color: Colors.red)),
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
