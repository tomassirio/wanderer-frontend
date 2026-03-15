import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wanderer_frontend/core/services/notification_service.dart';
import 'package:wanderer_frontend/data/models/websocket/websocket_event.dart';
import 'package:wanderer_frontend/data/services/websocket_service.dart';

/// Manages push notifications triggered by real-time WebSocket events.
///
/// When a [NotificationCreatedEvent] arrives on the user topic, this manager
/// shows a local push notification via [NotificationService] — provided the
/// user has enabled push notifications in settings.
///
/// Mobile-only (Android); no-ops silently on web.
class PushNotificationManager {
  static final PushNotificationManager _instance =
      PushNotificationManager._internal();
  factory PushNotificationManager() => _instance;
  PushNotificationManager._internal();

  static const String _prefKey = 'push_notifications_enabled';

  final WebSocketService _webSocketService = WebSocketService();
  final NotificationService _notificationService = NotificationService();

  StreamSubscription<WebSocketEvent>? _userSubscription;
  String? _subscribedUserId;
  bool _enabled = true;

  bool get _isSupported => !kIsWeb && Platform.isAndroid;

  /// Whether push notifications are currently enabled.
  bool get isEnabled => _enabled;

  /// Start listening for notification events for the given [userId].
  ///
  /// Call this once the user is logged in and the WebSocket is connected.
  /// Calling again with the same [userId] is a no-op.
  Future<void> start(String userId) async {
    if (!_isSupported) return;
    if (_subscribedUserId == userId && _userSubscription != null) return;

    // Load preference from disk
    await _loadPreference();

    // Clean up any previous subscription
    stop();

    _subscribedUserId = userId;
    final userStream = _webSocketService.subscribeToUser(userId);
    _userSubscription = userStream.listen(_handleEvent);
    debugPrint(
      'PushNotificationManager: Started for user $userId (enabled=$_enabled)',
    );
  }

  /// Stop listening and unsubscribe from user events.
  void stop() {
    _userSubscription?.cancel();
    _userSubscription = null;

    if (_subscribedUserId != null) {
      _webSocketService.unsubscribeFromUser(_subscribedUserId!);
      debugPrint(
        'PushNotificationManager: Stopped for user $_subscribedUserId',
      );
      _subscribedUserId = null;
    }
  }

  /// Enable or disable push notifications and persist the preference.
  Future<void> setEnabled(bool enabled) async {
    _enabled = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKey, enabled);
      debugPrint(
        'PushNotificationManager: Push notifications '
        '${enabled ? 'enabled' : 'disabled'}',
      );
    } catch (e) {
      debugPrint('PushNotificationManager: Failed to save preference: $e');
    }
  }

  /// Load the push-notification preference from SharedPreferences.
  Future<void> _loadPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(_prefKey) ?? true;
    } catch (e) {
      _enabled = true;
      debugPrint('PushNotificationManager: Failed to load preference: $e');
    }
  }

  /// Load the preference and return the current value.
  Future<bool> loadEnabled() async {
    await _loadPreference();
    return _enabled;
  }

  void _handleEvent(WebSocketEvent event) {
    if (!_enabled) return;

    if (event is NotificationCreatedEvent) {
      _showPushNotification(event);
    }
  }

  void _showPushNotification(NotificationCreatedEvent event) {
    final title = _titleForType(event.notificationType);
    final body = event.message;

    if (body.isEmpty) return;

    _notificationService.showInAppNotification(title: title, body: body);
  }

  String _titleForType(String notificationType) {
    switch (notificationType.toUpperCase()) {
      case 'FRIEND_REQUEST_RECEIVED':
        return '👋 Friend Request';
      case 'FRIEND_REQUEST_ACCEPTED':
        return '🤝 Friend Request Accepted';
      case 'FRIEND_REQUEST_DECLINED':
        return '😔 Friend Request Declined';
      case 'COMMENT_ON_TRIP':
        return '💬 New Comment';
      case 'REPLY_TO_COMMENT':
        return '↩️ Reply';
      case 'COMMENT_REACTION':
        return '❤️ Reaction';
      case 'NEW_FOLLOWER':
        return '👤 New Follower';
      case 'ACHIEVEMENT_UNLOCKED':
        return '🏆 Achievement Unlocked';
      case 'TRIP_STATUS_CHANGED':
        return '🗺️ Trip Update';
      case 'TRIP_UPDATE_POSTED':
        return '📍 Trip Update';
      default:
        return '🔔 Wanderer';
    }
  }
}
