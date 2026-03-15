import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Service for showing local push notifications on Android.
///
/// Used primarily by [BackgroundUpdateManager] to inform the user
/// whether a background trip update succeeded or failed, including
/// battery level and location coordinates.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  /// Whether notifications are supported on the current platform.
  bool get _isSupported => !kIsWeb && Platform.isAndroid;

  /// Notification channel for trip update results.
  static const String _channelId = 'trip_updates';
  static const String _channelName = 'Trip Updates';
  static const String _channelDescription =
      'Notifications for automatic trip update results';

  /// Notification channel for in-app notifications (social, achievements, etc.)
  static const String _inAppChannelId = 'in_app_notifications';
  static const String _inAppChannelName = 'Notifications';
  static const String _inAppChannelDescription =
      'Friend requests, comments, achievements, and other activity';

  /// Notification IDs — using fixed IDs so each update replaces the previous
  static const int _updateResultId = 1001;

  /// Base ID for in-app notifications (incremented for each new notification)
  static const int _inAppBaseId = 2000;
  int _inAppIdCounter = 0;

  /// Initialize the notification plugin.
  /// Call once at app startup and again inside the WorkManager isolate.
  Future<void> initialize() async {
    if (!_isSupported || _isInitialized) return;

    try {
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );

      const initSettings = InitializationSettings(android: androidSettings);

      await _plugin.initialize(settings: initSettings);
      _isInitialized = true;
      debugPrint('NotificationService: Initialized successfully');
    } catch (e) {
      debugPrint('NotificationService: Failed to initialize: $e');
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

  /// Show a single clean notification for a successful trip update.
  Future<void> showUpdateSuccess({
    required String tripName,
    required double latitude,
    required double longitude,
    required int? batteryLevel,
  }) async {
    if (!_isSupported) return;
    if (!_isInitialized) await initialize();

    final locationText =
        '📍 ${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';

    await _showNotification(
      id: _updateResultId,
      title: '📍 $tripName — Location Updated',
      body: 'Auto-update: $locationText',
    );
  }

  /// Show a single clean notification for a failed trip update.
  Future<void> showUpdateFailure({
    required String tripName,
    required String reason,
  }) async {
    if (!_isSupported) return;
    if (!_isInitialized) await initialize();

    await _showNotification(
      id: _updateResultId,
      title: '❌ $tripName — Update Failed',
      body: reason,
    );
  }

  /// Show a push notification for an in-app notification (social activity).
  ///
  /// Each call uses a unique ID so notifications stack in the system tray.
  Future<void> showInAppNotification({
    required String title,
    required String body,
  }) async {
    if (!_isSupported) return;
    if (!_isInitialized) await initialize();

    final id = _inAppBaseId + (_inAppIdCounter++ % 500);

    await _showNotification(
      id: id,
      title: title,
      body: body,
      channelId: _inAppChannelId,
      channelName: _inAppChannelName,
      channelDescription: _inAppChannelDescription,
    );
  }

  /// Internal helper to display a local notification.
  Future<void> _showNotification({
    required int id,
    required String title,
    required String body,
    String? channelId,
    String? channelName,
    String? channelDescription,
  }) async {
    try {
      final androidDetails = AndroidNotificationDetails(
        channelId ?? _channelId,
        channelName ?? _channelName,
        channelDescription: channelDescription ?? _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
      );

      final details = NotificationDetails(android: androidDetails);

      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: details,
      );
      debugPrint('NotificationService: Showed notification "$title"');
    } catch (e) {
      debugPrint('NotificationService: Failed to show notification: $e');
    }
  }
}
