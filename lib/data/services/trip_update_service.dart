import 'dart:async';
import 'dart:io';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:wanderer_frontend/core/constants/enums.dart';
import 'package:wanderer_frontend/data/client/command/trip_update_command_client.dart';
import 'package:wanderer_frontend/data/models/domain/location_update_result.dart';
import 'package:wanderer_frontend/data/models/requests/trip_update_request.dart';

/// Service for sending trip updates (location, battery, message)
/// Handles both automatic and manual updates
class TripUpdateService {
  final TripUpdateCommandClient _tripUpdateCommandClient;
  final Battery _battery;

  TripUpdateService({
    TripUpdateCommandClient? tripUpdateCommandClient,
    Battery? battery,
  })  : _tripUpdateCommandClient =
            tripUpdateCommandClient ?? TripUpdateCommandClient(),
        _battery = battery ?? Battery();

  /// Message used for automatic updates
  static const String automaticUpdateMessage = 'Automatic Update';

  /// Sends a trip update with current location and battery
  ///
  /// [tripId] - The ID of the trip to update
  /// [message] - Optional message (uses [automaticUpdateMessage] if null and isAutomatic is true)
  /// [isAutomatic] - Whether this is an automatic update
  /// [updateType] - Optional update type for lifecycle markers (TRIP_STARTED, TRIP_ENDED, etc.)
  ///
  /// Returns a [LocationUpdateResult] indicating success or a specific failure reason.
  Future<LocationUpdateResult> sendUpdate({
    required String tripId,
    String? message,
    bool isAutomatic = false,
    TripUpdateType? updateType,
  }) async {
    final sw = Stopwatch()..start();
    debugPrint(
        'TripUpdateService: 🚀 sendUpdate START (tripId=${tripId.substring(0, 8)}..., auto=$isAutomatic)');

    // Get current location (returns failure reason if it fails)
    final locationResult = await _getCurrentLocation();
    debugPrint(
        'TripUpdateService: 📍 Location fetch completed in ${sw.elapsedMilliseconds}ms '
        '— success=${locationResult.failureReason == null}');

    if (locationResult.failureReason != null) {
      debugPrint(
          'TripUpdateService: ❌ Location failed: ${locationResult.failureReason}');
      return LocationUpdateResult.failure(locationResult.failureReason!);
    }

    final position = locationResult.position!;
    debugPrint(
        'TripUpdateService: 📍 Position: ${position.latitude.toStringAsFixed(4)}, '
        '${position.longitude.toStringAsFixed(4)}');

    try {
      // Get battery level
      final batteryLevel = await _getBatteryLevel();
      debugPrint(
          'TripUpdateService: 🔋 Battery: $batteryLevel% (${sw.elapsedMilliseconds}ms)');

      // Determine message
      final updateMessage =
          isAutomatic ? automaticUpdateMessage : (message ?? '');

      // Create and send request
      final request = TripUpdateRequest(
        latitude: position.latitude,
        longitude: position.longitude,
        message: updateMessage.isNotEmpty ? updateMessage : null,
        battery: batteryLevel,
        updateType: updateType,
      );

      debugPrint(
          'TripUpdateService: 📡 Sending API request... (${sw.elapsedMilliseconds}ms)');
      await _tripUpdateCommandClient.createTripUpdate(tripId, request);
      debugPrint(
          'TripUpdateService: ✅ API call SUCCESS (${sw.elapsedMilliseconds}ms total)');

      return LocationUpdateResult.success(
        latitude: position.latitude,
        longitude: position.longitude,
        batteryLevel: batteryLevel,
      );
    } on SocketException catch (e) {
      debugPrint('TripUpdateService: Network error: $e');
      return const LocationUpdateResult.failure(
        LocationFailureReason.networkError,
      );
    } on TimeoutException catch (e) {
      debugPrint('TripUpdateService: Request timed out: $e');
      return const LocationUpdateResult.failure(
        LocationFailureReason.networkError,
      );
    } catch (e) {
      // Server / API errors — surface the actual message so the user
      // (and the developer via the snackbar) can see what went wrong.
      final errorMsg = e.toString();
      debugPrint('TripUpdateService: Failed to send update: $errorMsg');
      return LocationUpdateResult.failureWithDetail(
        LocationFailureReason.serverError,
        errorMsg,
      );
    }
  }

  /// Gets the current location **without** requesting permissions.
  ///
  /// Permission requesting is a UI concern and must be handled by the caller
  /// (e.g. the screen / repository) *before* invoking [sendUpdate].
  /// This method only checks the current permission state and fails fast
  /// if it isn't sufficient.
  ///
  /// Returns a [_LocationFetchResult] that either holds a [Position]
  /// or a [LocationFailureReason] explaining why it failed.
  Future<_LocationFetchResult> _getCurrentLocation() async {
    try {
      debugPrint('TripUpdateService: 🔍 Checking location service enabled...');
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      debugPrint(
          'TripUpdateService: 🔍 Location service enabled: $serviceEnabled');
      if (!serviceEnabled) {
        debugPrint('TripUpdateService: Location services are disabled');
        return _LocationFetchResult.fail(
          LocationFailureReason.servicesDisabled,
        );
      }

      debugPrint('TripUpdateService: 🔍 Checking location permission...');
      final permission = await Geolocator.checkPermission();
      debugPrint('TripUpdateService: 🔍 Location permission: $permission');

      if (permission == LocationPermission.denied) {
        debugPrint('TripUpdateService: Location permission denied');
        return _LocationFetchResult.fail(
          LocationFailureReason.permissionDenied,
        );
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint(
          'TripUpdateService: Location permission permanently denied',
        );
        return _LocationFetchResult.fail(
          LocationFailureReason.permissionDeniedForever,
        );
      }

      // On Android, use AndroidSettings with forceLocationManager: true.
      // The Fused Location Provider (Google Play Services) does NOT deliver
      // results inside WorkManager background isolates — the request hangs
      // until the app returns to the foreground. Using the raw Android
      // LocationManager API fixes this.
      try {
        Position position;
        if (!kIsWeb && Platform.isAndroid) {
          position = await GeolocatorPlatform.instance.getCurrentPosition(
            locationSettings: AndroidSettings(
              accuracy: LocationAccuracy.medium,
              forceLocationManager: true,
              timeLimit: const Duration(seconds: 20),
            ),
          );
        } else {
          position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.medium,
            timeLimit: const Duration(seconds: 15),
          );
        }
        return _LocationFetchResult.ok(position);
      } on TimeoutException {
        debugPrint(
          'TripUpdateService: getCurrentPosition timed out, '
          'trying getLastKnownPosition as fallback',
        );
      }

      // Fallback: use the last known position (cached by the OS).
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        debugPrint(
          'TripUpdateService: Using last known position as fallback',
        );
        return _LocationFetchResult.ok(lastKnown);
      }

      debugPrint('TripUpdateService: No position available (timeout + '
          'no cached position)');
      return _LocationFetchResult.fail(LocationFailureReason.timeout);
    } on TimeoutException catch (e) {
      debugPrint('TripUpdateService: Location request timed out: $e');
      return _LocationFetchResult.fail(LocationFailureReason.timeout);
    } catch (e) {
      debugPrint('TripUpdateService: Error getting location: $e');
      return _LocationFetchResult.fail(LocationFailureReason.unknownError);
    }
  }

  /// Gets the current battery level (0-100) or null if unavailable
  Future<int?> _getBatteryLevel() async {
    try {
      final level = await _battery.batteryLevel;
      return level >= 0 ? level : null;
    } catch (e) {
      debugPrint('TripUpdateService: Error getting battery level: $e');
      return null;
    }
  }
}

/// Internal helper to carry either a [Position] or a failure reason
/// out of [TripUpdateService._getCurrentLocation].
class _LocationFetchResult {
  final Position? position;
  final LocationFailureReason? failureReason;

  const _LocationFetchResult._({this.position, this.failureReason});

  factory _LocationFetchResult.ok(Position position) =>
      _LocationFetchResult._(position: position);

  factory _LocationFetchResult.fail(LocationFailureReason reason) =>
      _LocationFetchResult._(failureReason: reason);
}
