import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter/widgets.dart' show WidgetsFlutterBinding;
import 'package:geolocator_android/geolocator_android.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'package:wanderer_frontend/core/services/notification_service.dart';
import 'package:wanderer_frontend/data/services/trip_update_service.dart';
import 'package:wanderer_frontend/data/storage/token_refresh_manager.dart';
import 'package:wanderer_frontend/data/storage/token_storage.dart';

/// Unique task name for trip updates
const String tripUpdateTaskName = 'tripAutoUpdate';

/// Key for storing active trip ID in shared preferences
const String _activeTripIdKey = 'active_trip_id_for_updates';

/// Key for storing the active trip name for notifications
/// NOTE: The native TripTrackingService reads this key directly from
/// SharedPreferences (with the "flutter." prefix added by the plugin).
/// If this key is renamed, update TripTrackingService.PREFS_TRIP_NAME_KEY too.
const String _activeTripNameKey = 'active_trip_name_for_updates';

/// Key for storing the desired update interval (seconds)
const String _updateIntervalKey = 'update_interval_seconds';

/// Key to signal the background isolate that chained updates are active
const String _chainedUpdatesActiveKey = 'chained_updates_active';

/// Tag used for all chained update tasks — allows cancellation by tag
const String _chainedTaskTag = 'trip_auto_update_chain';

/// Schedules the next chained one-off task with the user's desired delay.
/// Called from the background isolate after each successful execution.
Future<void> _scheduleNextChainedTask(SharedPreferences prefs) async {
  final isActive = prefs.getBool(_chainedUpdatesActiveKey) ?? false;
  final tripId = prefs.getString(_activeTripIdKey);
  final intervalSeconds = prefs.getInt(_updateIntervalKey) ?? 900;

  if (!isActive || tripId == null || tripId.isEmpty) {
    debugPrint(
        'BG_CHAIN: Not scheduling next task — active=$isActive, tripId=$tripId');
    return;
  }

  final taskId = 'trip_update_chain_${DateTime.now().millisecondsSinceEpoch}';
  debugPrint('BG_CHAIN: Scheduling next task in ${intervalSeconds}s '
      '(${(intervalSeconds / 60).toStringAsFixed(1)} min), taskId=$taskId');

  await Workmanager().registerOneOffTask(
    taskId,
    tripUpdateTaskName,
    tag: _chainedTaskTag,
    initialDelay: Duration(seconds: intervalSeconds),
    constraints: Constraints(
      networkType: NetworkType.connected,
      requiresBatteryNotLow: false,
      requiresCharging: false,
      requiresDeviceIdle: false,
      requiresStorageNotLow: false,
    ),
    existingWorkPolicy: ExistingWorkPolicy.keep,
    backoffPolicy: BackoffPolicy.linear,
    backoffPolicyDelay: const Duration(minutes: 1),
  );
}

/// Top-level callback dispatcher for WorkManager
/// Must be a top-level function (not a class method)
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    final startTime = DateTime.now();
    final tag =
        'BG_UPDATE[${startTime.hour}:${startTime.minute.toString().padLeft(2, '0')}:${startTime.second.toString().padLeft(2, '0')}]';

    WidgetsFlutterBinding.ensureInitialized();

    // Background isolates don't auto-register platform plugins.
    // Explicitly register GeolocatorAndroid so the geolocator package
    // routes through the Android LocationManager (via forceLocationManager)
    // instead of the Fused Location Provider which hangs in background.
    if (!kIsWeb && Platform.isAndroid) {
      GeolocatorAndroid.registerWith();
    }

    debugPrint('$tag: ⚡ WorkManager task fired. taskName=$taskName');

    if (taskName == tripUpdateTaskName) {
      final notificationService = NotificationService();
      await notificationService.initialize();

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.reload();
        final tripId = prefs.getString(_activeTripIdKey);
        final tripName = prefs.getString(_activeTripNameKey) ?? 'Trip Update';
        final intervalSeconds = prefs.getInt(_updateIntervalKey) ?? 900;

        debugPrint(
            '$tag: tripId=${tripId ?? 'NULL'}, name=$tripName, interval=${intervalSeconds}s');

        if (tripId == null || tripId.isEmpty) {
          debugPrint('$tag: No active trip ID — skipping');
          return true;
        }

        final tokenStorage = TokenStorage();

        // Refresh the access token if it has expired.  This is necessary
        // because the background task may run hours after the user last opened
        // the app, by which point the short-lived access token will have
        // expired.  ensureValidToken checks expiry and uses the refresh token
        // to obtain a new access token silently.
        final tokenValid = await TokenRefreshManager.instance.ensureValidToken(
          tokenStorage: tokenStorage,
        );

        debugPrint('$tag: tokenValid=$tokenValid');

        if (!tokenValid) {
          debugPrint(
              '$tag: Could not obtain a valid token — user may need to log in again');
          await notificationService.showUpdateFailure(
            tripName: tripName,
            reason: 'Please open the app and log in again',
          );
          await _scheduleNextChainedTask(prefs);
          return true;
        }

        debugPrint('$tag: Sending update for trip $tripId');
        final updateService = TripUpdateService();
        final result = await updateService.sendUpdate(
          tripId: tripId,
          isAutomatic: true,
        );

        final elapsed = DateTime.now().difference(startTime).inMilliseconds;

        if (result.isSuccess) {
          await notificationService.showUpdateSuccess(
            tripName: tripName,
            latitude: result.latitude!,
            longitude: result.longitude!,
            batteryLevel: result.batteryLevel,
          );
          debugPrint('$tag: ✅ SUCCESS in ${elapsed}ms');
        } else {
          await notificationService.showUpdateFailure(
            tripName: tripName,
            reason: result.userMessage,
          );
          debugPrint('$tag: ❌ FAILED in ${elapsed}ms — '
              'reason=${result.failureReason}, detail=${result.errorDetail}');
        }

        await _scheduleNextChainedTask(prefs);
        return true;
      } catch (e, stackTrace) {
        final elapsed = DateTime.now().difference(startTime).inMilliseconds;
        debugPrint('$tag: 💥 EXCEPTION in ${elapsed}ms: $e\n$stackTrace');

        try {
          final tripName = (await SharedPreferences.getInstance())
                  .getString(_activeTripNameKey) ??
              'Trip Update';
          await notificationService.showUpdateFailure(
            tripName: tripName,
            reason: 'Something went wrong. Will retry next cycle.',
          );
        } catch (_) {}

        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.reload();
          await _scheduleNextChainedTask(prefs);
        } catch (_) {}

        return true;
      }
    }

    debugPrint('$tag: Unknown task name: $taskName — skipping');
    return true;
  });
}

/// Manages background updates for trips using WorkManager
/// Only works on Android - no-ops on other platforms
///
/// Uses chained one-off tasks instead of periodic tasks to bypass
/// Android's 15-minute minimum interval for periodic WorkManager tasks.
/// After each execution, the callback schedules the next one-off task
/// with the user's desired delay.
///
/// A foreground service ([TripTrackingService]) is started alongside the
/// WorkManager chain.  An active foreground service exempts the app from
/// Android's Doze mode, which would otherwise defer WorkManager tasks until
/// the next maintenance window (potentially hours later).  With the service
/// running the WorkManager tasks fire at the configured interval even while
/// the phone is locked and the screen is off.
class BackgroundUpdateManager {
  static final BackgroundUpdateManager _instance =
      BackgroundUpdateManager._internal();

  factory BackgroundUpdateManager() => _instance;

  BackgroundUpdateManager._internal();

  bool _isInitialized = false;

  /// MethodChannel used to start/stop the native [TripTrackingService].
  static const MethodChannel _trackingChannel = MethodChannel(
    'com.tomassirio.wanderer.wanderer_frontend/trip_tracking',
  );

  /// Check if we're on a supported platform (Android only)
  bool get _isSupported => !kIsWeb && Platform.isAndroid;

  /// Initialize the WorkManager
  /// Call this once at app startup (e.g., in main.dart)
  Future<void> initialize() async {
    if (!_isSupported) {
      debugPrint(
          'BackgroundUpdateManager: Skipped init — platform not supported');
      return;
    }
    if (_isInitialized) {
      debugPrint('BackgroundUpdateManager: Already initialized');
      return;
    }

    try {
      await Workmanager().initialize(
        callbackDispatcher,
        isInDebugMode: false,
      );
      _isInitialized = true;
      debugPrint(
          'BackgroundUpdateManager: ✅ Initialized successfully (debug mode ON)');
    } catch (e) {
      debugPrint('BackgroundUpdateManager: ❌ Failed to initialize: $e');
    }
  }

  /// Start automatic updates for a trip using chained one-off tasks.
  ///
  /// [tripId] - The ID of the trip to send updates for
  /// [tripName] - The name of the trip (shown in notifications)
  /// [intervalSeconds] - The interval between updates (any value, no 15 min minimum)
  Future<void> startAutoUpdates(
      String tripId, String tripName, int intervalSeconds) async {
    if (!_isSupported) {
      debugPrint('BackgroundUpdateManager: Not supported on this platform');
      return;
    }

    if (!_isInitialized) {
      debugPrint(
          'BackgroundUpdateManager: Not initialized yet, initializing now...');
      await initialize();
    }

    try {
      // Cancel any existing tasks first
      await stopAutoUpdates(tripId);

      // Store trip ID and interval in shared preferences for the background task
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_activeTripIdKey, tripId);
      await prefs.setString(_activeTripNameKey, tripName);
      await prefs.setInt(_updateIntervalKey, intervalSeconds);
      await prefs.setBool(_chainedUpdatesActiveKey, true);

      // Verify the writes
      debugPrint('BackgroundUpdateManager: 📝 Stored: tripId=$tripId, '
          'interval=${intervalSeconds}s (${(intervalSeconds / 60).toStringAsFixed(1)} min), '
          'chainActive=true');

      // Schedule the first one-off task with the desired delay.
      // The foreground service is started AFTER scheduling succeeds so that it
      // is never left running if the WorkManager registration throws.
      final taskId =
          'trip_update_chain_${DateTime.now().millisecondsSinceEpoch}';

      await Workmanager().registerOneOffTask(
        taskId,
        tripUpdateTaskName,
        tag: _chainedTaskTag,
        initialDelay: Duration(seconds: intervalSeconds),
        constraints: Constraints(
          networkType: NetworkType.connected,
          requiresBatteryNotLow: false,
          requiresCharging: false,
          requiresDeviceIdle: false,
          requiresStorageNotLow: false,
        ),
        existingWorkPolicy: ExistingWorkPolicy.replace,
        backoffPolicy: BackoffPolicy.linear,
        backoffPolicyDelay: const Duration(minutes: 1),
      );

      // Start the foreground service AFTER WorkManager scheduling succeeds.
      // An active foreground service keeps the app process out of Doze mode,
      // ensuring the WorkManager tasks above fire at the configured interval
      // even when the phone is locked.
      await _startForegroundService(tripName);

      debugPrint(
          'BackgroundUpdateManager: ✅ Started auto updates for trip $tripId '
          'every ${intervalSeconds}s (${(intervalSeconds / 60).toStringAsFixed(1)} min)');

      debugPrint(
          'BackgroundUpdateManager: 🔑 SharedPrefs keys: ${prefs.getKeys().join(', ')}');
    } catch (e) {
      debugPrint('BackgroundUpdateManager: ❌ Failed to start auto updates: $e');
    }
  }

  /// Stop automatic updates for a trip
  Future<void> stopAutoUpdates(String tripId) async {
    if (!_isSupported) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      // Mark chained updates as inactive FIRST so any in-flight task
      // that completes won't schedule a successor.
      await prefs.setBool(_chainedUpdatesActiveKey, false);
      await prefs.remove(_activeTripIdKey);
      await prefs.remove(_activeTripNameKey);
      await prefs.remove(_updateIntervalKey);

      // Stop the foreground service so the app can enter Doze when idle
      await _stopForegroundService();

      // Cancel by tag first (more targeted), then cancel all as fallback
      await Workmanager().cancelByTag(_chainedTaskTag);
      await Workmanager().cancelAll();
      debugPrint(
          'BackgroundUpdateManager: Stopped auto updates for trip $tripId');
    } catch (e) {
      debugPrint('BackgroundUpdateManager: Failed to stop auto updates: $e');
    }
  }

  /// Trigger a single background update NOW for testing.
  /// Uses registerOneOffTask which fires almost immediately,
  /// bypassing the 15-minute minimum of periodic tasks.
  /// This exercises the exact same code path as the periodic task
  /// (separate isolate, callbackDispatcher, SharedPreferences, etc.)
  Future<void> triggerTestUpdate(String tripId, {String? tripName}) async {
    if (!_isSupported) {
      debugPrint('BackgroundUpdateManager: Not supported on this platform');
      return;
    }

    if (!_isInitialized) {
      await initialize();
    }

    try {
      // Store trip ID so the background isolate can read it
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_activeTripIdKey, tripId);
      if (tripName != null) {
        await prefs.setString(_activeTripNameKey, tripName);
      }

      final taskId =
          'trip_update_test_${DateTime.now().millisecondsSinceEpoch}';
      debugPrint(
          'BackgroundUpdateManager: 🧪 Triggering test update for trip $tripId (taskId=$taskId)');

      await Workmanager().registerOneOffTask(
        taskId,
        tripUpdateTaskName,
        constraints: Constraints(
          networkType: NetworkType.connected,
        ),
        existingWorkPolicy: ExistingWorkPolicy.replace,
      );

      debugPrint(
          'BackgroundUpdateManager: 🧪 One-off test task registered — should fire within seconds');
    } catch (e) {
      debugPrint(
          'BackgroundUpdateManager: ❌ Failed to trigger test update: $e');
    }
  }

  /// Stop all automatic updates
  Future<void> stopAllAutoUpdates() async {
    if (!_isSupported) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_chainedUpdatesActiveKey, false);
      await prefs.remove(_activeTripIdKey);
      await prefs.remove(_activeTripNameKey);
      await prefs.remove(_updateIntervalKey);

      await _stopForegroundService();

      await Workmanager().cancelByTag(_chainedTaskTag);
      await Workmanager().cancelAll();
      debugPrint('BackgroundUpdateManager: Stopped all auto updates');
    } catch (e) {
      debugPrint(
          'BackgroundUpdateManager: Failed to stop all auto updates: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Foreground service helpers
  // ---------------------------------------------------------------------------

  /// Start the native [TripTrackingService] foreground service.
  ///
  /// The service shows a persistent "Tracking: [tripName]" notification and
  /// keeps the app process active (i.e. not subject to Doze mode), which lets
  /// WorkManager tasks fire at their configured intervals even when the phone
  /// is locked and the screen is off.
  Future<void> _startForegroundService(String tripName) async {
    try {
      await _trackingChannel
          .invokeMethod<void>('startTracking', {'tripName': tripName});
      debugPrint(
          'BackgroundUpdateManager: 📱 Foreground service started (trip=$tripName)');
    } catch (e) {
      // Non-fatal — WorkManager tasks will still run; they may just be deferred
      // by Doze on some devices.
      debugPrint(
          'BackgroundUpdateManager: ⚠️ Could not start foreground service: $e');
    }
  }

  /// Stop the native [TripTrackingService] foreground service.
  Future<void> _stopForegroundService() async {
    try {
      await _trackingChannel.invokeMethod<void>('stopTracking');
      debugPrint('BackgroundUpdateManager: 📱 Foreground service stopped');
    } catch (e) {
      debugPrint(
          'BackgroundUpdateManager: ⚠️ Could not stop foreground service: $e');
    }
  }
}
