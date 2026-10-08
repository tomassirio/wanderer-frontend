import 'dart:async' show unawaited;
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart'
    show kIsWeb, debugPrint, visibleForTesting;
import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter/widgets.dart'
    show AppLifecycleListener, WidgetsFlutterBinding;
import 'package:geolocator_android/geolocator_android.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'package:wanderer_frontend/core/constants/enums.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/l10n/locale_controller.dart';
import 'package:wanderer_frontend/core/l10n/translation_loader.dart';
import 'package:wanderer_frontend/core/services/notification_service.dart';
import 'package:wanderer_frontend/data/models/domain/location_update_result.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/data/services/track_sync_service.dart';
import 'package:wanderer_frontend/data/services/trip_service.dart';
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

/// Wire name of the live trip's [RecordingProfile].
/// NOTE: TripTrackingService reads it as "flutter.active_recording_profile".
const String _activeProfileKey = 'active_recording_profile';

/// Whether the live trip has automatic updates on; without them the chain
/// only uploads the track, even in Battery saver.
const String _autoCheckInKey = 'auto_check_in_enabled';

/// Whether the chain posts an "Automatic Update" on each tick.
bool _chainChecksIn(SharedPreferences prefs) =>
    (RecordingProfile.fromWireName(prefs.getString(_activeProfileKey)) ??
            RecordingProfile.saver)
        .autoCheckIn &&
    (prefs.getBool(_autoCheckInKey) ?? true);

/// Per-trip profile the user picked; absent means the modality default.
String _profileKey(String tripId) => 'recording_profile_$tripId';

/// Key to signal the background isolate that chained updates are active
const String _chainedUpdatesActiveKey = 'chained_updates_active';

/// When the next chained check-in is due (ms since epoch), for the live
/// notification's "Next auto check-in at …".
const String _nextCheckInKey = 'next_auto_check_in_at';

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

  await _registerChainTask(prefs, intervalSeconds, ExistingWorkPolicy.keep);
}

/// Registers the next chain tick after the active profile's upload interval
/// (the trip's [intervalSeconds] in Battery saver) and records when the next
/// automatic check-in is due, if the profile makes one.
Future<void> _registerChainTask(SharedPreferences prefs, int intervalSeconds,
    ExistingWorkPolicy policy) async {
  final profile =
      RecordingProfile.fromWireName(prefs.getString(_activeProfileKey)) ??
          RecordingProfile.saver;
  final delaySeconds = profile.uploadSeconds(intervalSeconds);
  if (_chainChecksIn(prefs)) {
    await prefs.setInt(
        _nextCheckInKey,
        DateTime.now()
            .add(Duration(seconds: delaySeconds))
            .millisecondsSinceEpoch);
  } else {
    await prefs.remove(_nextCheckInKey);
  }

  final taskId = 'trip_update_chain_${DateTime.now().millisecondsSinceEpoch}';
  debugPrint('BG_CHAIN: Scheduling next task in ${delaySeconds}s '
      '(${profile.wireName}), taskId=$taskId');

  await Workmanager().registerOneOffTask(
    taskId,
    tripUpdateTaskName,
    tag: _chainedTaskTag,
    initialDelay: Duration(seconds: delaySeconds),
    constraints: Constraints(
      networkType: NetworkType.connected,
      requiresBatteryNotLow: false,
      requiresCharging: false,
      requiresDeviceIdle: false,
      requiresStorageNotLow: false,
    ),
    existingWorkPolicy: policy,
    backoffPolicy: BackoffPolicy.linear,
    backoffPolicyDelay: const Duration(minutes: 1),
  );
}

/// Clears the chain's preferences so no further tick schedules a successor.
Future<void> _clearChain(SharedPreferences prefs) async {
  await prefs.setBool(_chainedUpdatesActiveKey, false);
  await prefs.remove(_activeTripIdKey);
  await prefs.remove(_activeTripNameKey);
  await prefs.remove(_updateIntervalKey);
  await prefs.remove(_nextCheckInKey);
  await prefs.remove(_activeProfileKey);
  await prefs.remove(_autoCheckInKey);
}

/// Whether the chain should keep checking in: only while the backend says the
/// trip is live. The check-in endpoint accepts any status, so without this a
/// chain whose trip never went (or no longer is) IN_PROGRESS — a start the
/// backend rejected after its 202, a pause/finish from another device, a
/// deleted trip — posts "Automatic Update"s forever. A failed lookup keeps
/// going (being offline must not end tracking).
@visibleForTesting
Future<bool> shouldKeepAutoUpdating(Future<Trip> Function() fetchTrip) async {
  try {
    return (await fetchTrip()).status == TripStatus.inProgress;
  } catch (e) {
    debugPrint('BG_UPDATE: trip status lookup failed ($e) — continuing');
    return true;
  }
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
      // Notification text and channel names in the user's language.
      await LocaleController().initialize();
      await TranslationLoader.instance.load();
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
          await notificationService.showCheckInFailed(
              tripId: tripId, tripName: tripName);
          await _scheduleNextChainedTask(prefs);
          return true;
        }

        Trip? trip;
        if (!await shouldKeepAutoUpdating(
            () async => trip = await TripService().getTripById(tripId))) {
          debugPrint('$tag: Trip $tripId is not IN_PROGRESS — ending chain');
          // The foreground service can only be stopped from the UI isolate;
          // initialize() does that on the next app start.
          await _clearChain(prefs);
          return true;
        }

        // Live (or automatic updates off): just upload what was recorded.
        // Battery saver: also post the automatic check-in (which flushes the
        // track first).
        if (!_chainChecksIn(prefs)) {
          final flushed = await TrackSyncService().flush(tripId);
          debugPrint('$tag: synced track (rejected=${flushed.rejectedStatus}, '
              'pending=${flushed.hasPending})');
          if (flushed.rejectedStatus != null) {
            await _clearChain(prefs);
          } else {
            await _scheduleNextChainedTask(prefs);
          }
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
          debugPrint('$tag: ✅ SUCCESS in ${elapsed}ms');
        } else {
          await notificationService.showCheckInFailed(
              tripId: tripId, tripName: tripName, result: result);
          debugPrint('$tag: ❌ FAILED in ${elapsed}ms — '
              'reason=${result.failureReason}, detail=${result.errorDetail}');
          // Trip deleted, no longer ours or no longer live: retrying
          // can't help.
          if (result.statusCode == 403 ||
              result.statusCode == 404 ||
              result.statusCode == 409) {
            await _clearChain(prefs);
            return true;
          }
        }

        await _scheduleNextChainedTask(prefs);
        // Auto check-ins edit the live notification in place, silently.
        if (result.isSuccess && trip != null) {
          await showLiveTripNotification(trip!, lastCheckIn: DateTime.now());
        }
        return true;
      } catch (e, stackTrace) {
        final elapsed = DateTime.now().difference(startTime).inMilliseconds;
        debugPrint('$tag: 💥 EXCEPTION in ${elapsed}ms: $e\n$stackTrace');

        try {
          final prefs = await SharedPreferences.getInstance();
          final tripId = prefs.getString(_activeTripIdKey);
          if (tripId != null) {
            await notificationService.showCheckInFailed(
              tripId: tripId,
              tripName: prefs.getString(_activeTripNameKey) ?? '',
              result: const LocationUpdateResult.failure(
                  LocationFailureReason.unknownError),
            );
          }
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

/// Shows (or silently refreshes) the ongoing live-trip notification for
/// [trip]: day, last check-in and place, next auto check-in, a "Live" timer
/// from the start of the current stretch, and the trip's buttons.
Future<void> showLiveTripNotification(Trip trip,
    {DateTime? lastCheckIn, String? place}) async {
  final prefs = await SharedPreferences.getInstance();
  final next = (prefs.getBool(_chainedUpdatesActiveKey) ?? false) &&
          prefs.getString(_activeTripIdKey) == trip.id
      ? prefs.getInt(_nextCheckInKey)
      : null;
  final multiDay = trip.tripModality == TripModality.multiDay;
  final openDay = trip.tripDays?.where((d) => d.endTimestamp == null);
  await NotificationService().showLiveTrip(
    tripId: trip.id,
    tripName: trip.name,
    body: NotificationService.liveTripBody(
      AppLocalizations.fromController(),
      day: multiDay ? trip.currentDay : null,
      lastCheckIn: lastCheckIn,
      place: place,
      nextCheckIn:
          next == null ? null : DateTime.fromMillisecondsSinceEpoch(next),
    ),
    liveSince: (openDay == null || openDay.isEmpty)
        ? trip.startDate
        : openDay.last.startTimestamp,
    canRest: multiDay,
  );
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
  AppLifecycleListener? _resumeListener;

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
      // Upload whatever was recorded or queued while we were away.
      _resumeListener ??=
          AppLifecycleListener(onResume: () => TrackSyncService().flushAll());
      unawaited(TrackSyncService().flushAll());
      // A chain the background task ended (trip no longer live) leaves the
      // tracking service running; stop it.
      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool(_chainedUpdatesActiveKey) ?? false)) {
        await _stopForegroundService();
      }
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
  /// [modality] - Picks the default [RecordingProfile] when the user hasn't
  /// chosen one for this trip.
  /// [autoCheckIn] - Whether the trip has automatic updates on; off, the
  /// chain only uploads the track.
  ///
  /// Also starts the native track recorder with that profile; the chain
  /// then syncs at the profile's upload interval.
  Future<void> startAutoUpdates(
      String tripId, String tripName, int intervalSeconds,
      {TripModality? modality, bool autoCheckIn = true}) async {
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
      final profile = await recordingProfileFor(tripId, modality);
      await prefs.setString(_activeTripIdKey, tripId);
      await prefs.setString(_activeTripNameKey, tripName);
      await prefs.setInt(_updateIntervalKey, intervalSeconds);
      await prefs.setString(_activeProfileKey, profile.wireName);
      await prefs.setBool(_autoCheckInKey, autoCheckIn);
      await prefs.setBool(_chainedUpdatesActiveKey, true);

      // Verify the writes
      debugPrint('BackgroundUpdateManager: 📝 Stored: tripId=$tripId, '
          'interval=${intervalSeconds}s (${(intervalSeconds / 60).toStringAsFixed(1)} min), '
          'chainActive=true');

      // Schedule the first one-off task with the desired delay.
      // The foreground service is started AFTER scheduling succeeds so that it
      // is never left running if the WorkManager registration throws.
      await _registerChainTask(
          prefs, intervalSeconds, ExistingWorkPolicy.replace);

      // Start the foreground service AFTER WorkManager scheduling succeeds.
      // An active foreground service keeps the app process out of Doze mode,
      // ensuring the WorkManager tasks above fire at the configured interval
      // even when the phone is locked. It also records the track.
      await _startForegroundService(tripName, tripId, profile);

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
      await _clearChain(prefs);

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

  /// Stops the chain only if it belongs to [tripId]; another trip's chain is
  /// left alone.
  Future<void> stopAutoUpdatesFor(String tripId) async {
    if (!_isSupported) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_activeTripIdKey) == tripId) {
      await stopAutoUpdates(tripId);
    }
  }

  /// Whether [trip] records its track while in progress: single-day trips
  /// always, multi-day trips only with automatic updates on. Automatic
  /// updates themselves only decide the automatic check-ins.
  static bool recordsTrack(Trip trip) =>
      trip.automaticUpdates || trip.tripModality == TripModality.simple;

  /// Starts (or restarts) recording [trip] when it is in progress and
  /// [recordsTrack], otherwise stops its chain.
  Future<void> syncRecording(Trip trip) async {
    if (!_isSupported) return;
    if (trip.status == TripStatus.inProgress && recordsTrack(trip)) {
      await startAutoUpdates(trip.id, trip.name, trip.effectiveUpdateRefresh,
          modality: trip.tripModality, autoCheckIn: trip.automaticUpdates);
    } else {
      await stopAutoUpdatesFor(trip.id);
    }
  }

  /// Final flush before a rest / pause / finish: stops recording [tripId]
  /// (so no point lands after the status change) and uploads the rest.
  /// Call it before changing the status; offline, the data stays queued.
  Future<void> stopAndFlush(String tripId) async {
    if (!_isSupported) return;
    await stopAutoUpdatesFor(tripId);
    // Don't hold the status change hostage to a slow network.
    await TrackSyncService().flush(tripId).timeout(const Duration(seconds: 15),
        onTimeout: () => (rejectedStatus: null, hasPending: true));
  }

  // ---------------------------------------------------------------------------
  // Recording profile
  // ---------------------------------------------------------------------------

  /// The profile [tripId] records with: the user's choice for that trip, or
  /// the default for its [modality].
  static Future<RecordingProfile> recordingProfileFor(
      String tripId, TripModality? modality) async {
    final prefs = await SharedPreferences.getInstance();
    return RecordingProfile.fromWireName(
            prefs.getString(_profileKey(tripId))) ??
        RecordingProfile.defaultFor(modality);
  }

  /// [recordingProfileFor] for [trip].
  Future<RecordingProfile> recordingProfile(Trip trip) =>
      recordingProfileFor(trip.id, trip.tripModality);

  /// Stores the user's [profile] for [trip] and, if it is the live trip,
  /// applies it right away (recorder and sync interval).
  Future<void> setRecordingProfile(Trip trip, RecordingProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileKey(trip.id), profile.wireName);
    if (!_isSupported ||
        !(prefs.getBool(_chainedUpdatesActiveKey) ?? false) ||
        prefs.getString(_activeTripIdKey) != trip.id) {
      return;
    }
    await prefs.setString(_activeProfileKey, profile.wireName);
    try {
      await _registerChainTask(prefs, prefs.getInt(_updateIntervalKey) ?? 900,
          ExistingWorkPolicy.replace);
      await _trackingChannel
          .invokeMethod<void>('setProfile', {'profile': profile.wireName});
    } catch (e) {
      debugPrint('BackgroundUpdateManager: ⚠️ Could not apply profile: $e');
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
      await _clearChain(prefs);

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
  // Live trip notification
  // ---------------------------------------------------------------------------

  /// Last live notification content, reused after a notification action.
  ({Trip trip, DateTime? lastCheckIn, String? place})? _live;

  /// Shows the ongoing live-trip notification while [trip] is in progress,
  /// removes it otherwise. [lastCheckIn] and [place] are its latest update.
  Future<void> syncLiveNotification(Trip trip,
      {DateTime? lastCheckIn, String? place}) async {
    if (!_isSupported) return;
    if (trip.status != TripStatus.inProgress) {
      _live = null;
      await NotificationService().cancelLiveTrip();
      return;
    }
    _live = (trip: trip, lastCheckIn: lastCheckIn, place: place);
    await _showLive();
    // ponytail: the native tracking service may post its own notification
    // (same ID) just after starting; post ours again once it has. Move the
    // actions into TripTrackingService if this ever flickers.
    Future.delayed(const Duration(seconds: 2), _showLive);
  }

  Future<void> _showLive() async {
    final live = _live;
    if (live == null) return;
    await showLiveTripNotification(live.trip,
        lastCheckIn: live.lastCheckIn, place: live.place);
  }

  /// Runs a trip button (Check in / Try again / Pause / Rest) for [tripId].
  Future<void> handleLiveTripAction(String actionId, String tripId) async {
    try {
      switch (actionId) {
        case NotificationService.actionCheckIn:
        case NotificationService.actionRetry:
          final result = await TripUpdateService().sendUpdate(tripId: tripId);
          final live = _live?.trip.id == tripId ? _live : null;
          if (!result.isSuccess) {
            await NotificationService().showCheckInFailed(
              tripId: tripId,
              tripName: live?.trip.name ?? '',
              result: result,
            );
          } else if (live != null) {
            _live = (trip: live.trip, lastCheckIn: DateTime.now(), place: null);
            await _showLive();
          }
        case NotificationService.actionPause:
          await stopAndFlush(tripId);
          await TripService().changeStatus(
              tripId, ChangeStatusRequest(status: TripStatus.paused));
          await _endLive(tripId);
        case NotificationService.actionRest:
          await stopAndFlush(tripId);
          await TripService().toggleDay(tripId);
          final day = _live?.trip.currentDay;
          await TripUpdateService().sendUpdate(
            tripId: tripId,
            updateType: TripUpdateType.dayEnd,
            message: day == null ? null : 'Day $day finished',
          );
          await _endLive(tripId);
      }
    } catch (e) {
      debugPrint('BackgroundUpdateManager: Live action $actionId failed: $e');
    }
  }

  Future<void> _endLive(String tripId) async {
    await stopAutoUpdates(tripId);
    _live = null;
    await NotificationService().cancelLiveTrip();
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
  Future<void> _startForegroundService(
      String tripName, String tripId, RecordingProfile profile) async {
    try {
      await _trackingChannel.invokeMethod<void>('startTracking', {
        'tripName': tripName,
        'tripId': tripId,
        'profile': profile.wireName,
      });
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
