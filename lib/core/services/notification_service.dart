import 'dart:io' show Platform;
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/data/models/domain/location_update_result.dart';

/// Android notification categories. Each one is its own channel, so people
/// can mute achievements without missing a failed check-in.
enum NotificationChannelKind {
  liveTrip,
  tripProblems,
  comments,
  friends,
  achievements
}

/// Service for showing local notifications on Android.
///
/// Payloads say which screen a notification opens: `trip:<id>`,
/// `request:<id>`, `user:<id>`, `achievement:<id>`, `friends` or
/// `notifications`. Taps and buttons go to [onResponse].
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  /// Whether notifications are supported on the current platform.
  bool get _isSupported => !kIsWeb && Platform.isAndroid;

  /// White-on-transparent hiker (res/drawable); Android paints it.
  static const String _smallIcon = 'ic_stat_wanderer';

  /// Trail orange: the icon's circle in the shade.
  static const Color _color = Color(0xFFC2410C);

  /// Same ID as the native TripTrackingService channel and notification, so
  /// while that service runs this notification replaces its content.
  static const String _liveChannelId = 'trip_tracking_channel';
  static const int liveTripId = 9001;

  /// One "check-in wasn't posted" at a time; a newer one replaces it.
  static const int _problemId = 1001;

  /// Channels of earlier versions (one catch-all each), removed on start.
  static const List<String> _legacyChannels = [
    'trip_updates',
    'in_app_notifications',
  ];

  /// Button IDs.
  static const String actionCheckIn = 'trip_check_in';
  static const String actionPause = 'trip_pause';
  static const String actionRest = 'trip_rest';
  static const String actionRetry = 'trip_retry';
  static const String actionOpen = 'open';
  static const String actionReply = 'reply';
  static const String actionAccept = 'accept';
  static const String actionDecline = 'decline';

  /// Runs a tap (null action) or a button for a payload. A notification that
  /// launched the app waits here until the handler is set.
  static void Function(String? actionId, String payload)? _onResponse;
  static NotificationResponse? _pending;
  static set onResponse(void Function(String? actionId, String payload)? h) {
    _onResponse = h;
    final pending = _pending;
    _pending = null;
    if (h != null && pending != null) _dispatch(pending);
  }

  /// Base ID for social notifications (incremented for each new one).
  static const int _inAppBaseId = 2000;
  int _inAppIdCounter = 0;

  static String channelId(NotificationChannelKind kind) => switch (kind) {
        NotificationChannelKind.liveTrip => _liveChannelId,
        NotificationChannelKind.tripProblems => 'trip_problems',
        NotificationChannelKind.comments => 'comments',
        NotificationChannelKind.friends => 'friends',
        NotificationChannelKind.achievements => 'achievements',
      };

  static AndroidNotificationChannel _channel(
      AppLocalizations l10n, NotificationChannelKind kind) {
    final id = channelId(kind);
    return switch (kind) {
      NotificationChannelKind.liveTrip => AndroidNotificationChannel(
          id, l10n.notifChannelLiveTrip,
          description: l10n.notifChannelLiveTripDesc,
          importance: Importance.low,
          playSound: false,
          enableVibration: false,
          showBadge: false),
      NotificationChannelKind.tripProblems => AndroidNotificationChannel(
          id, l10n.notifChannelTripProblems,
          description: l10n.notifChannelTripProblemsDesc,
          importance: Importance.high),
      NotificationChannelKind.comments => AndroidNotificationChannel(
          id, l10n.notifChannelComments,
          description: l10n.notifChannelCommentsDesc),
      NotificationChannelKind.friends => AndroidNotificationChannel(
          id, l10n.notifChannelFriends,
          description: l10n.notifChannelFriendsDesc),
      NotificationChannelKind.achievements => AndroidNotificationChannel(
          id, l10n.notifChannelAchievements,
          description: l10n.notifChannelAchievementsDesc,
          importance: Importance.low),
    };
  }

  /// Initialize the notification plugin and register the channels.
  /// Call once at app startup and again inside the WorkManager isolate.
  Future<void> initialize() async {
    if (!_isSupported || _isInitialized) return;

    try {
      const initSettings = InitializationSettings(
        android: AndroidInitializationSettings(_smallIcon),
      );
      await _plugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: _dispatch,
      );
      _isInitialized = true;

      // Re-registering also refreshes names after a language change.
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final l10n = AppLocalizations.fromController();
      for (final kind in NotificationChannelKind.values) {
        await android?.createNotificationChannel(_channel(l10n, kind));
      }
      for (final id in _legacyChannels) {
        await android?.deleteNotificationChannel(channelId: id);
      }

      // A notification tapped while the app was closed launches it.
      final launch = await _plugin.getNotificationAppLaunchDetails();
      final response = launch?.notificationResponse;
      if (launch?.didNotificationLaunchApp == true && response != null) {
        _dispatch(response);
      }
      debugPrint('NotificationService: Initialized successfully');
    } catch (e) {
      debugPrint('NotificationService: Failed to initialize: $e');
    }
  }

  static void _dispatch(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    final handler = _onResponse;
    if (handler == null) {
      _pending = response;
      return;
    }
    handler(response.actionId, payload);
  }

  /// Whether the user allows notifications (false where unsupported).
  Future<bool> areEnabled() async {
    if (!_isSupported) return false;
    try {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>()
              ?.areNotificationsEnabled() ??
          true;
    } catch (_) {
      return false;
    }
  }

  /// Request notification permission (Android 13+).
  /// Returns `true` if granted (or if the platform doesn't require asking).
  Future<bool> requestPermission() async {
    if (!_isSupported) return false;

    try {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        final granted = await androidPlugin.requestNotificationsPermission();
        debugPrint(
          'NotificationService: Permission ${granted == true ? 'granted' : 'denied'}',
        );
        return granted ?? false;
      }
      return true; // Pre-Android 13, permission is granted by default
    } catch (e) {
      debugPrint('NotificationService: Error requesting permission: $e');
      return false;
    }
  }

  /// "22:45".
  static String hm(DateTime t) {
    final l = t.toLocal();
    return '${l.hour.toString().padLeft(2, '0')}:'
        '${l.minute.toString().padLeft(2, '0')}';
  }

  /// Live-trip text: "Day 12 · last check-in 22:45 in Nieuwegein", then
  /// "Next auto check-in at 23:03" when auto check-ins run.
  static String liveTripBody(
    AppLocalizations l10n, {
    int? day,
    DateTime? lastCheckIn,
    String? place,
    DateTime? nextCheckIn,
  }) {
    final line = [
      if (day != null) l10n.dayNumber(day),
      if (lastCheckIn != null)
        place == null || place.isEmpty
            ? l10n.notifLastCheckIn(hm(lastCheckIn))
            : l10n.notifLastCheckInAt(hm(lastCheckIn), place),
    ].join(' · ');
    if (nextCheckIn == null) return line;
    final next = l10n.notifNextCheckIn(hm(nextCheckIn));
    return line.isEmpty ? next : '$line\n$next';
  }

  /// What a failed check-in says: what happened and what to do next. Error
  /// codes and IDs stay in the logs.
  static String checkInFailureBody(
      AppLocalizations l10n, String tripName, LocationUpdateResult? result) {
    if (result == null) return l10n.notifSignedOut;
    return switch (result.failureReason) {
      LocationFailureReason.serverError
          when result.statusCode == 403 || result.statusCode == 404 =>
        l10n.notifCheckInGone(tripName),
      LocationFailureReason.serverError when result.statusCode == 401 =>
        l10n.notifSignedOut,
      LocationFailureReason.networkError => l10n.notifCheckInOffline,
      LocationFailureReason.servicesDisabled => l10n.notifCheckInLocationOff,
      LocationFailureReason.permissionDenied ||
      LocationFailureReason.permissionDeniedForever =>
        l10n.notifCheckInNoPermission,
      LocationFailureReason.timeout => l10n.notifCheckInNoFix,
      _ => l10n.notifCheckInGeneric,
    };
  }

  /// Show (or refresh, silently) the ongoing live-trip notification, with
  /// a "Live" timer from [liveSince] and Check in / Pause / Rest buttons.
  /// Buttons open the app, where [onResponse] runs them signed in.
  Future<void> showLiveTrip({
    required String tripId,
    required String tripName,
    required String body,
    DateTime? liveSince,
    bool canRest = false,
  }) async {
    if (!_isSupported) return;
    if (!_isInitialized) await initialize();
    final l10n = AppLocalizations.fromController();
    final channel = _channel(l10n, NotificationChannelKind.liveTrip);
    try {
      await _plugin.show(
        id: liveTripId,
        title: tripName,
        body: body,
        payload: 'trip:$tripId',
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            channelDescription: channel.description,
            icon: _smallIcon,
            color: _color,
            importance: Importance.low,
            priority: Priority.low,
            ongoing: true,
            autoCancel: false,
            onlyAlertOnce: true,
            silent: true,
            subText: l10n.live,
            showWhen: liveSince != null,
            when: liveSince?.millisecondsSinceEpoch,
            usesChronometer: liveSince != null,
            styleInformation: BigTextStyleInformation(body),
            category: AndroidNotificationCategory.service,
            actions: [
              button(actionCheckIn, l10n.tripCheckIn, keep: true),
              button(actionPause, l10n.pause, keep: true),
              if (canRest) button(actionRest, l10n.tripRestAction, keep: true),
            ],
          ),
        ),
      );
    } catch (e) {
      debugPrint('NotificationService: Failed to show live trip: $e');
    }
  }

  /// Remove the live-trip notification (trip paused, resting or finished).
  Future<void> cancelLiveTrip() async {
    if (!_isSupported) return;
    try {
      await _plugin.cancel(id: liveTripId);
    } catch (e) {
      debugPrint('NotificationService: Failed to cancel live trip: $e');
    }
  }

  /// "Your check-in wasn't posted" on the Trip problems channel, with
  /// Open trip and Try again. A null [result] means the session expired.
  Future<void> showCheckInFailed({
    required String tripId,
    required String tripName,
    LocationUpdateResult? result,
  }) async {
    if (!_isSupported) return;
    if (!_isInitialized) await initialize();
    final l10n = AppLocalizations.fromController();
    await _show(
      id: _problemId,
      kind: NotificationChannelKind.tripProblems,
      title: l10n.notifCheckInFailedTitle,
      body: checkInFailureBody(l10n, tripName, result),
      payload: 'trip:$tripId',
      actions: [
        button(actionOpen, l10n.notifOpenTrip),
        if (result != null) button(actionRetry, l10n.notifTryAgain),
      ],
    );
  }

  /// A social / achievement notification. Comments on the same trip
  /// ([groupKey]) are bundled together.
  Future<void> showActivity({
    required NotificationChannelKind kind,
    required String title,
    String? body,
    required String payload,
    List<AndroidNotificationAction> actions = const [],
    String? groupKey,
  }) async {
    if (!_isSupported) return;
    if (!_isInitialized) await initialize();

    await _show(
      id: _inAppBaseId + (_inAppIdCounter++ % 500),
      kind: kind,
      title: title,
      body: body,
      payload: payload,
      actions: actions,
      groupKey: groupKey,
    );
    if (groupKey != null) {
      // Android only bundles a group that has a summary notification.
      await _show(
        id: 3000 + groupKey.hashCode.abs() % 1000,
        kind: kind,
        title: title,
        payload: payload,
        groupKey: groupKey,
        summary: true,
      );
    }
  }

  /// A button that opens the app; [keep] leaves the notification up.
  static AndroidNotificationAction button(String id, String label,
          {bool keep = false}) =>
      AndroidNotificationAction(id, label,
          showsUserInterface: true, cancelNotification: !keep);

  Future<void> _show({
    required int id,
    required NotificationChannelKind kind,
    required String title,
    String? body,
    required String payload,
    List<AndroidNotificationAction> actions = const [],
    String? groupKey,
    bool summary = false,
  }) async {
    final channel = _channel(AppLocalizations.fromController(), kind);
    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        payload: payload,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            channelDescription: channel.description,
            icon: _smallIcon,
            color: _color,
            importance: channel.importance,
            priority: switch (channel.importance) {
              Importance.high => Priority.high,
              Importance.low => Priority.low,
              _ => Priority.defaultPriority,
            },
            // A failure that repeats while the last one is up stays quiet.
            onlyAlertOnce: true,
            styleInformation:
                body == null ? null : BigTextStyleInformation(body),
            actions: actions,
            groupKey: groupKey,
            setAsGroupSummary: summary,
          ),
        ),
      );
      debugPrint('NotificationService: Showed notification "$title"');
    } catch (e) {
      debugPrint('NotificationService: Failed to show notification: $e');
    }
  }
}
