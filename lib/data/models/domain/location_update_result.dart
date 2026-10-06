/// Reason why a location-based trip update failed.
enum LocationFailureReason {
  /// GPS / location services are turned off on the device.
  servicesDisabled,

  /// The user denied the location permission (but can still grant it).
  permissionDenied,

  /// The user permanently denied location permission (must open Settings).
  permissionDeniedForever,

  /// The GPS fix took too long (poor signal, indoors, etc.).
  timeout,

  /// An unexpected error occurred while fetching location.
  unknownError,

  /// The API call to send the update failed (location was fine).
  networkError,

  /// The server returned an error (e.g. 4xx/5xx).
  serverError,
}

/// The result of a [TripUpdateService.sendUpdate] call.
///
/// Use [isSuccess] to check the outcome.  When `!isSuccess`,
/// [failureReason] tells the caller *why* it failed so the UI
/// can show a specific, actionable message.
class LocationUpdateResult {
  final bool isSuccess;
  final LocationFailureReason? failureReason;

  /// Detail from the server / exception, for logs only — never shown.
  final String? errorDetail;

  /// HTTP status of a [LocationFailureReason.serverError], when known.
  final int? statusCode;

  /// Location and battery data captured during the update attempt.
  /// Available on both success and some failures (e.g. network errors
  /// where the location was obtained but the API call failed).
  final double? latitude;
  final double? longitude;
  final int? batteryLevel;

  /// Successful update.
  const LocationUpdateResult.success({
    this.latitude,
    this.longitude,
    this.batteryLevel,
  })  : isSuccess = true,
        failureReason = null,
        errorDetail = null,
        statusCode = null;

  /// Failed update with a specific reason.
  const LocationUpdateResult.failure(LocationFailureReason reason)
      : isSuccess = false,
        failureReason = reason,
        errorDetail = null,
        statusCode = null,
        latitude = null,
        longitude = null,
        batteryLevel = null;

  /// Failed update with a reason and extra detail text.
  const LocationUpdateResult.failureWithDetail(
    LocationFailureReason reason,
    this.errorDetail, {
    this.statusCode,
  })  : isSuccess = false,
        failureReason = reason,
        latitude = null,
        longitude = null,
        batteryLevel = null;

  /// Returns a user-friendly message for the failure reason.
  String get userMessage {
    switch (failureReason) {
      case LocationFailureReason.servicesDisabled:
        return 'Location services are disabled. '
            'Please enable GPS in your device settings.';
      case LocationFailureReason.permissionDenied:
        return 'Location permission was denied. '
            'Please allow location access to send updates.';
      case LocationFailureReason.permissionDeniedForever:
        return 'Location permission is permanently denied. '
            'Please enable it in your device settings.';
      case LocationFailureReason.timeout:
        return 'Could not get a GPS fix in time. '
            'Try moving to an area with better signal.';
      case LocationFailureReason.unknownError:
        return 'An unexpected error occurred while getting your location.';
      case LocationFailureReason.networkError:
        return 'Failed to send the update. '
            'Please check your internet connection.';
      case LocationFailureReason.serverError:
        return 'The server returned an error. Please try again later.';
      case null:
        return '';
    }
  }
}
