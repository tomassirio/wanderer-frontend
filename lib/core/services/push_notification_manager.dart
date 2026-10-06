import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart'
    show kIsWeb, debugPrint, visibleForTesting;
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    show AndroidNotificationAction;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
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
    final n = activityNotification(
        AppLocalizations.fromController(), event.notificationType,
        message: event.message,
        referenceId: event.referenceId,
        actorId: event.actorId);
    if (n == null) return;
    _notificationService.showActivity(
      kind: n.kind,
      title: n.title,
      body: n.body,
      payload: n.payload,
      actions: n.actions,
      groupKey: n.groupKey,
    );
  }
}

/// How a backend notification shows in the shade: its channel, plain text
/// (no emoji; trip names unquoted), the screen it opens and its buttons.
/// Null for types that aren't pushed (a friend's every check-in stays in the
/// in-app list) or have no message.
@visibleForTesting
({
  NotificationChannelKind kind,
  String title,
  String? body,
  String payload,
  List<AndroidNotificationAction> actions,
  String? groupKey,
})? activityNotification(AppLocalizations l10n, String type,
    {required String message, String? referenceId, String? actorId}) {
  if (message.isEmpty) return null;
  final title = message.replaceAllMapped(notificationQuotes, (m) => m[1]!);
  final ref = referenceId ?? '';
  final view = NotificationService.button(
      NotificationService.actionOpen, l10n.notifView);
  switch (type.toUpperCase()) {
    case 'FRIEND_REQUEST_RECEIVED':
      return (
        kind: NotificationChannelKind.friends,
        title: title,
        body: l10n.notifFriendRequestBody,
        payload: 'request:$ref',
        actions: [
          if (ref.isNotEmpty) ...[
            NotificationService.button(
                NotificationService.actionAccept, l10n.acceptRequest),
            NotificationService.button(
                NotificationService.actionDecline, l10n.notifDecline),
          ],
        ],
        groupKey: null,
      );
    case 'FRIEND_REQUEST_ACCEPTED':
      return (
        kind: NotificationChannelKind.friends,
        title: title,
        body: null,
        payload: actorId == null ? 'friends' : 'user:$actorId',
        actions: const [],
        groupKey: null,
      );
    case 'FRIEND_REQUEST_DECLINED':
      return (
        kind: NotificationChannelKind.friends,
        title: title,
        body: null,
        payload: 'friends',
        actions: const [],
        groupKey: null,
      );
    case 'NEW_FOLLOWER':
      return (
        kind: NotificationChannelKind.friends,
        title: title,
        body: null,
        payload: ref.isEmpty ? 'friends' : 'user:$ref',
        actions: const [],
        groupKey: null,
      );
    case 'COMMENT_ON_TRIP':
      return (
        kind: NotificationChannelKind.comments,
        title: title,
        body: null,
        payload: 'trip:$ref',
        actions: [
          NotificationService.button(
              NotificationService.actionReply, l10n.reply),
          view,
        ],
        groupKey: ref.isEmpty ? null : 'comments:$ref',
      );
    // Their reference is a comment, not a trip: open the list.
    case 'REPLY_TO_COMMENT':
    case 'COMMENT_REACTION':
      return (
        kind: NotificationChannelKind.comments,
        title: title,
        body: null,
        payload: 'notifications',
        actions: const [],
        groupKey: null,
      );
    // A friend started or finished a trip.
    case 'TRIP_STATUS_CHANGED':
      return (
        kind: NotificationChannelKind.friends,
        title: title,
        body: null,
        payload: ref.isEmpty ? 'notifications' : 'trip:$ref',
        actions: const [],
        groupKey: null,
      );
    case 'ACHIEVEMENT_UNLOCKED':
      return (
        kind: NotificationChannelKind.achievements,
        title: title,
        body: null,
        payload: ref.isEmpty ? 'achievements' : 'achievement:$ref',
        actions: const [],
        groupKey: null,
      );
    default:
      return null;
  }
}

/// Quoted trip / achievement names inside a backend message.
final notificationQuotes = RegExp(r'"([^"]+)"');
