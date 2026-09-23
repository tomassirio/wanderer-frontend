import 'dart:async';

import 'package:flutter/material.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/services/navigation_service.dart';
import 'package:wanderer_frontend/data/client/websocket_client.dart';
import 'package:wanderer_frontend/data/models/websocket/websocket_event.dart';
import 'package:wanderer_frontend/data/services/achievement_service.dart';
import 'package:wanderer_frontend/data/services/user_service.dart';
import 'package:wanderer_frontend/data/services/websocket_service.dart';
import 'package:wanderer_frontend/data/storage/token_storage.dart';
import 'package:wanderer_frontend/presentation/helpers/auth_navigation_helper.dart';
import 'package:wanderer_frontend/presentation/widgets/achievements/achievement_dialog.dart';
import 'package:wanderer_frontend/presentation/widgets/common/toasts.dart';

/// Web only: turns real-time WebSocket events into toasts.
///
/// Single source of truth is NOTIFICATION_CREATED (the backend already
/// decided who gets notified and never notifies the actor), so nothing
/// double-fires. COMMENT_ADDED is only used to borrow the comment text.
/// Started from [NotificationBell] once the user topic is subscribed.
class LiveToastBridge {
  static final LiveToastBridge _instance = LiveToastBridge._();
  factory LiveToastBridge() => _instance;
  LiveToastBridge._();

  final _ws = WebSocketService();
  StreamSubscription<WebSocketEvent>? _events;
  StreamSubscription<WebSocketConnectionState>? _connection;
  String? _userId;
  bool _wasConnected = false;
  bool _pausedShown = false;

  /// Latest comment text per "tripId|userId", from COMMENT_ADDED events of
  /// trips the app happens to be subscribed to.
  // ponytail: only filled when that trip's topic is subscribed and the
  // event arrives before the notification; otherwise the body is the trip.
  final _recentComments = <String, String>{};

  /// Idempotent; call after [WebSocketService.connect].
  void start(String userId) {
    if (_userId == userId && _events != null) return;
    stop();
    _userId = userId;
    _wasConnected = _ws.isConnected;
    _events = _ws.events.listen(_onEvent);
    _connection = _ws.connectionState.listen(_onConnection);
  }

  void stop() {
    _events?.cancel();
    _connection?.cancel();
    _events = null;
    _connection = null;
    _userId = null;
    _pausedShown = false;
    _recentComments.clear();
  }

  /// Logging out doesn't dispose the bell or the socket, so check.
  Future<bool> _stillLoggedIn() async {
    final me = _userId;
    if (me != null && await TokenStorage().getUserId() == me) return true;
    stop();
    return false;
  }

  void _onConnection(WebSocketConnectionState state) async {
    if (!await _stillLoggedIn()) return;
    final l10n = AppLocalizations.fromController();
    final connected = state == WebSocketConnectionState.connected;
    if (connected && _pausedShown) {
      Toasts.dismiss('ws-connection');
      Toasts.show(
          ToastData(kind: ToastKind.success, title: l10n.liveToastBack));
      _pausedShown = false;
    } else if (!connected && _wasConnected && !_pausedShown) {
      Toasts.show(ToastData(
        kind: ToastKind.error,
        title: l10n.liveToastPausedTitle,
        body: l10n.liveToastPausedBody,
        groupKey: 'ws-connection',
      ));
      _pausedShown = true;
    }
    _wasConnected = connected;
  }

  void _onEvent(WebSocketEvent event) async {
    final me = _userId;
    if (me == null) return;
    if (event is CommentAddedEvent) {
      if (_recentComments.length > 50) _recentComments.clear();
      _recentComments['${event.tripId}|${event.userId}'] = event.message;
      return;
    }
    if (event is! NotificationCreatedEvent) return;
    if (!await _stillLoggedIn()) return;
    final toast = liveToastFor(
      event,
      myUserId: me,
      l10n: AppLocalizations.fromController(),
      commentText: _recentComments['${event.referenceId}|${event.actorId}'],
    );
    if (toast != null) Toasts.show(toast);
  }
}

/// What the toast links and buttons do (navigator + services).
class _Actions {
  const _Actions();

  BuildContext? get _ctx => NavigationService().navigatorKey.currentContext;

  void openTrip(String tripId) {
    final ctx = _ctx;
    if (ctx != null) Navigator.of(ctx).pushNamed('/trip/$tripId');
  }

  void openProfile(String userId) {
    final ctx = _ctx;
    if (ctx != null) AuthNavigationHelper.navigateToUserProfile(ctx, userId);
  }

  void openAchievement(String achievementId) async {
    try {
      final mine = await AchievementService().getMyAchievements();
      final ua = mine.where((a) => a.achievement.id == achievementId);
      final ctx = _ctx;
      if (ctx == null || !ctx.mounted) return;
      if (ua.isNotEmpty) {
        await showAchievementDialog(ctx, ua.first.achievement,
            unlocked: ua.first);
        return;
      }
    } catch (_) {}
    final ctx = _ctx;
    if (ctx != null && ctx.mounted) {
      AuthNavigationHelper.navigateToAchievements(ctx);
    }
  }

  Future<void> acceptFriendRequest(String requestId) async {
    final l10n = AppLocalizations.fromController();
    try {
      await UserService().acceptFriendRequest(requestId);
      Toasts.show(ToastData(
          kind: ToastKind.success, title: l10n.friendRequestAcceptedMsg));
    } catch (e) {
      Toasts.show(ToastData(
          kind: ToastKind.error,
          title: l10n.failedToAcceptFriendRequest(e.toString())));
    }
  }

  Future<void> declineFriendRequest(String requestId) async {
    final l10n = AppLocalizations.fromController();
    try {
      await UserService().deleteFriendRequest(requestId);
      Toasts.show(ToastData(
          kind: ToastKind.info, title: l10n.friendRequestDeclinedMsg));
    } catch (e) {
      Toasts.show(ToastData(
          kind: ToastKind.error,
          title: l10n.failedToDeclineFriendRequest(e.toString())));
    }
  }
}

/// Pure mapping of a NOTIFICATION_CREATED event to a toast, or null when
/// it shouldn't show (not for me, my own action, unknown type).
///
/// Names come from the backend's English message ("julresch commented on
/// your trip \"Santiago 2026\""): the actor is the first word, the quoted
/// part is the trip / achievement name.
ToastData? liveToastFor(
  NotificationCreatedEvent e, {
  required String myUserId,
  required AppLocalizations l10n,
  String? commentText,
}) {
  if (e.recipientId.isNotEmpty && e.recipientId != myUserId) return null;
  if (e.actorId != null && e.actorId == myUserId) return null;

  final msg = e.message.trim();
  final user = msg.split(' ').first;
  final q1 = msg.indexOf('"'), q2 = msg.lastIndexOf('"');
  final quoted = q2 > q1 && q1 >= 0 ? msg.substring(q1 + 1, q2) : '';
  final ref = e.referenceId;
  final actor = e.actorId;
  const actions = _Actions();

  ToastData social(String title,
          {String? body,
          String? groupKey,
          String Function(int)? groupedTitle,
          String? link,
          VoidCallback? onLink}) =>
      ToastData(
        kind: ToastKind.social,
        title: title,
        body: body,
        initial: user,
        linkLabel: onLink == null ? null : link,
        onLink: onLink,
        groupKey: groupKey,
        groupedTitle: groupedTitle,
      );

  switch (e.notificationType.toUpperCase()) {
    case 'COMMENT_ON_TRIP':
      return social(
        l10n.liveToastCommented(user),
        body: commentText != null && commentText.isNotEmpty
            ? '“$commentText”'
            : l10n.liveToastOnYourTrip(quoted),
        groupKey: 'comments:$ref',
        groupedTitle: (n) => l10n.liveToastCommentsGrouped(n, quoted),
        link: l10n.reply,
        onLink: ref == null ? null : () => actions.openTrip(ref),
      );
    case 'REPLY_TO_COMMENT':
      // referenceId is the parent comment; no trip to open.
      return social(l10n.liveToastReplied(user));
    case 'COMMENT_REACTION':
      return social(l10n.liveToastReacted(user));
    case 'NEW_FOLLOWER':
      return social(
        l10n.liveToastFollowed(user),
        link: l10n.viewProfile,
        onLink: actor == null ? null : () => actions.openProfile(actor),
      );
    case 'FRIEND_REQUEST_RECEIVED':
      return ToastData(
        kind: ToastKind.request,
        title: l10n.liveToastFriendRequest(user),
        onAccept: ref == null ? null : () => actions.acceptFriendRequest(ref),
        onDecline: ref == null ? null : () => actions.declineFriendRequest(ref),
      );
    case 'FRIEND_REQUEST_ACCEPTED':
      return social(
        l10n.liveToastFriendAccepted(user),
        link: l10n.viewProfile,
        onLink: actor == null ? null : () => actions.openProfile(actor),
      );
    case 'FRIEND_REQUEST_DECLINED':
      return ToastData(
          kind: ToastKind.info,
          title: l10n.liveToastFriendDeclined,
          icon: Icons.person_off_outlined);
    case 'ACHIEVEMENT_UNLOCKED':
      return ToastData(
        kind: ToastKind.achievement,
        title: l10n.liveToastAchievement,
        body: quoted.isEmpty ? null : quoted,
        linkLabel: l10n.liveToastSeeAchievement,
        onLink: ref == null ? null : () => actions.openAchievement(ref),
      );
    case 'TRIP_STATUS_CHANGED':
    case 'TRIP_UPDATE_POSTED':
      final String title;
      if (e.notificationType.toUpperCase() == 'TRIP_UPDATE_POSTED') {
        title = l10n.liveToastTripUpdate(user);
      } else if (msg.contains(' finished ')) {
        title = l10n.liveToastTripFinished(user, quoted);
      } else {
        title = l10n.liveToastTripStarted(user, quoted);
      }
      return ToastData(
        kind: ToastKind.info,
        icon: Icons.place_outlined,
        title: title,
        body: e.notificationType.toUpperCase() == 'TRIP_UPDATE_POSTED'
            ? quoted
            : null,
        linkLabel: l10n.profileOpenLiveMap,
        onLink: ref == null ? null : () => actions.openTrip(ref),
      );
    default:
      return null;
  }
}
