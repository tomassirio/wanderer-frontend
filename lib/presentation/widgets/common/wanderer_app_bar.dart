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
import 'package:wanderer_frontend/core/constants/api_endpoints.dart';

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

  /// Called when the user's avatar is updated via WebSocket event.
  /// Parent screens should use this to update their own avatar state
  /// (e.g. for the sidebar).
  final ValueChanged<String?>? onAvatarUpdated;

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
    this.onAvatarUpdated,
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

  /// Locally-tracked avatar URL, updated via WebSocket events.
  /// When non-null, overrides [widget.avatarUrl] so the avatar updates
  /// immediately without waiting for the parent to rebuild.
  String? _localAvatarUrl;
  bool _hasLocalAvatarOverride = false;

  /// The effective avatar URL: local override if available, otherwise widget prop.
  String? get _effectiveAvatarUrl =>
      _hasLocalAvatarOverride ? _localAvatarUrl : widget.avatarUrl;

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
      _startPolling();
    }

    // Always listen to the global WebSocket events stream immediately.
    // This ensures notification events are caught even before the userId
    // is available — the global stream receives events from ALL subscribed
    // topics (including ones subscribed by other screens).
    _wsSubscription = _webSocketService.events.listen(_handleGlobalEvent);

    // If userId is already available, ensure the user topic is subscribed.
    if (widget.isLoggedIn && widget.userId != null) {
      _ensureUserTopicSubscribed(widget.userId!);
    }
  }

  @override
  void didUpdateWidget(covariant WandererAppBar oldWidget) {
    super.didUpdateWidget(oldWidget);

    // When the parent provides a new avatarUrl, clear the local override
    // so we use the parent's value (which is now up-to-date).
    if (widget.avatarUrl != oldWidget.avatarUrl) {
      _hasLocalAvatarOverride = false;
      _localAvatarUrl = null;
    }

    if (widget.isLoggedIn && !oldWidget.isLoggedIn) {
      // Just became logged in — fetch the real count from the API
      // to pick up any notifications missed during the async window.
      _fetchUnreadCount();
      _startPolling();
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
    _stopPolling();
    _searchAnimController.dispose();
    super.dispose();
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _debounceTimer?.cancel();
    _debounceTimer = null;
  }

  /// Start periodic polling as a reliable fallback.
  /// This ensures the badge updates even when the WebSocket connection
  /// is unavailable (e.g. dev server, firewall, or backend doesn't send
  /// NOTIFICATION_CREATED events).
  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted && widget.isLoggedIn) {
        _fetchUnreadCount();
      }
    });
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
    } else if (event.type == WebSocketEventType.userAvatarUploaded) {
      _handleAvatarUploaded();
    } else if (event.type == WebSocketEventType.userAvatarDeleted) {
      _handleAvatarDeleted();
    } else if (_notificationTriggerEvents.contains(event.type)) {
      // Other events that typically create a notification on the backend.
      // Debounce an API refresh so we don't fire for every single event.
      _debounceFetchUnreadCount();
    }
  }

  /// Handle avatar uploaded: the image URL path stays the same but the
  /// content changed, so we bust all caches and force a reload.
  void _handleAvatarUploaded() {
    if (!mounted) return;
    debugPrint('WandererAppBar: _handleAvatarUploaded called');
    _bustAvatarCache();
  }

  /// Handle avatar deleted: bust cache to force a reload. The server will
  /// return a 404 so [NetworkImage] fails and the fallback initial is shown.
  void _handleAvatarDeleted() {
    if (!mounted) return;
    debugPrint('WandererAppBar: _handleAvatarDeleted called');
    _bustAvatarCache();
  }

  /// Evict the old avatar from Flutter's image cache, then generate a new
  /// cache-busted URL with a timestamp so [NetworkImage] fetches fresh.
  void _bustAvatarCache() {
    final baseUrl = widget.avatarUrl ?? _localAvatarUrl;
    if (baseUrl == null || baseUrl.isEmpty) {
      debugPrint('WandererAppBar: _bustAvatarCache — no base URL, skipping');
      return;
    }

    // Evict the old resolved URL from Flutter's in-memory image cache
    // so the cached pixels are discarded.
    final oldResolvedUrl = ApiEndpoints.resolveThumbnailUrl(baseUrl);
    if (oldResolvedUrl.isNotEmpty) {
      final evicted = PaintingBinding.instance.imageCache
          .evict(NetworkImage(oldResolvedUrl));
      debugPrint(
          'WandererAppBar: Evicted old avatar from imageCache: $evicted ($oldResolvedUrl)');
    }

    // Build a new URL with a timestamp cache-buster.
    final cleanUrl = baseUrl.split('?').first;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final cacheBustedUrl = '$cleanUrl?v=$timestamp';

    debugPrint(
        'WandererAppBar: Cache-busted avatar URL: $cacheBustedUrl (was: $baseUrl)');

    setState(() {
      _localAvatarUrl = cacheBustedUrl;
      _hasLocalAvatarOverride = true;
    });

    // Notify parent so it can update its own state (e.g. for sidebar).
    widget.onAvatarUpdated?.call(cacheBustedUrl);
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

  /// Build a [NetworkImage] for the avatar. When the URL has been cache-busted
  /// (contains `?v=`), add no-cache headers so the HTTP client bypasses its
  /// disk cache and fetches fresh from the server.
  ImageProvider? _avatarImageProvider() {
    final url = _effectiveAvatarUrl;
    if (url == null || url.isEmpty) return null;
    final resolved = ApiEndpoints.resolveThumbnailUrl(url);
    if (resolved.isEmpty) return null;
    final isBusted = url.contains('?v=');
    return NetworkImage(
      resolved,
      headers: isBusted
          ? const {'Cache-Control': 'no-cache', 'Pragma': 'no-cache'}
          : null,
    );
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
    final l10n = context.l10n;
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
        // Dark mode toggle — only for logged in users; hidden while search is expanded
        if (!_isSearchExpanded && widget.isLoggedIn)
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
        // Search icon — only for logged in users (hidden while search is expanded)
        if (!_isSearchExpanded && widget.isLoggedIn)
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: l10n.search,
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
                backgroundImage: _avatarImageProvider(),
                child:
                    _effectiveAvatarUrl == null || _effectiveAvatarUrl!.isEmpty
                        ? Text(
                            _avatarInitial,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
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
                              backgroundImage: _avatarImageProvider(),
                              child: _effectiveAvatarUrl == null ||
                                      _effectiveAvatarUrl!.isEmpty
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
