import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/providers/app_providers.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/data/client/websocket_client.dart';
import 'package:wanderer_frontend/data/models/websocket/websocket_event.dart';
import 'package:wanderer_frontend/data/services/notification_api_service.dart';
import 'package:wanderer_frontend/data/services/websocket_service.dart';
import 'package:wanderer_frontend/presentation/widgets/common/notifications_dropdown.dart';

/// Notifications button with a live unread badge (WebSocket, with polling
/// fallback) that opens the notifications dropdown.
///
/// Used by [WandererAppBar] and by the web page headers. [outlined] renders
/// the 44px bordered square from the web design.
class NotificationBell extends ConsumerStatefulWidget {
  final bool isLoggedIn;
  final String? userId;
  final GlobalKey? notificationButtonKey;
  final bool outlined;

  const NotificationBell({
    super.key,
    required this.isLoggedIn,
    this.userId,
    this.notificationButtonKey,
    this.outlined = false,
  });

  @override
  ConsumerState<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends ConsumerState<NotificationBell> {
  int _unreadCount = 0;
  late final NotificationApiService _notificationService;
  late final WebSocketService _webSocketService;
  final GlobalKey _notificationButtonKey = GlobalKey();
  GlobalKey get _effectiveNotificationButtonKey =>
      widget.notificationButtonKey ?? _notificationButtonKey;
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
    _notificationService = ref.read(notificationApiServiceProvider);
    _webSocketService = ref.read(websocketServiceProvider);

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
  void didUpdateWidget(covariant NotificationBell oldWidget) {
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
      debugPrint('NotificationBell: WebSocket connected, skipping polling');
      return;
    }

    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (mounted && widget.isLoggedIn && !_isWebSocketConnected) {
        debugPrint(
            'NotificationBell: Polling fallback - fetching unread count');
        _fetchUnreadCount();
      }
    });
    debugPrint('NotificationBell: Started polling fallback (5 min interval)');
  }

  /// Handle WebSocket connection state changes
  void _handleConnectionStateChange(WebSocketConnectionState state) {
    if (!mounted) return;

    final wasConnected = _isWebSocketConnected;
    _isWebSocketConnected = state == WebSocketConnectionState.connected;

    if (_isWebSocketConnected && !wasConnected) {
      // WebSocket just connected - stop polling and fetch current count
      debugPrint('NotificationBell: WebSocket connected, stopping polling');
      _stopPolling();
      if (widget.isLoggedIn) {
        _fetchUnreadCount();
      }
    } else if (!_isWebSocketConnected && wasConnected) {
      // WebSocket just disconnected - start polling fallback
      debugPrint(
          'NotificationBell: WebSocket disconnected, starting polling fallback');
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
      debugPrint('NotificationBell: Failed to fetch unread count: $e');
    }
  }

  /// Get the initials for the avatar (max 3 letters)
  void _showNotificationsDropdown() {
    final renderBox = _effectiveNotificationButtonKey.currentContext
        ?.findRenderObject() as RenderBox?;
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
    final l10n = context.l10n;
    final badge = Badge(
      isLabelVisible: _unreadCount > 0,
      label: Text(
        _unreadCount > 99 ? '99+' : '$_unreadCount',
        style: const TextStyle(fontSize: 10),
      ),
      child:
          Icon(Icons.notifications_outlined, size: widget.outlined ? 18 : null),
    );
    if (!widget.outlined) {
      return IconButton(
        key: _effectiveNotificationButtonKey,
        icon: badge,
        tooltip: l10n.notifications,
        onPressed: _showNotificationsDropdown,
      );
    }
    return HeaderIconButton(
      key: _effectiveNotificationButtonKey,
      tooltip: l10n.notifications,
      onPressed: _showNotificationsDropdown,
      child: badge,
    );
  }
}

/// 44px square, surface fill, 1px line border: the web header icon button.
class HeaderIconButton extends StatelessWidget {
  final String tooltip;
  final VoidCallback onPressed;
  final Widget child;

  const HeaderIconButton({
    super.key,
    required this.tooltip,
    required this.onPressed,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        fixedSize: const Size(44, 44),
        backgroundColor: c.surface,
        foregroundColor: c.neutralFg,
        side: BorderSide(color: c.line),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(WandererTheme.radiusControl)),
      ),
      icon: IconTheme.merge(
        data: const IconThemeData(size: 18),
        child: child,
      ),
    );
  }
}
