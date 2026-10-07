import '../../../core/constants/enums.dart';

/// Body of `POST /trips/start`: creates the trip, makes it live and records
/// the first check-in (TRIP_STARTED) at [lat]/[lon] in one call.
class StartTripRequest {
  /// Ignored by the backend when [tripPlanId] is set (the plan name wins).
  final String name;
  final Visibility visibility;

  /// Ignored when [tripPlanId] is set (the plan type wins).
  final TripModality tripModality;
  final bool automaticUpdates;
  final int? updateRefresh; // in seconds
  final double lat;
  final double lon;
  final int? battery;
  final String? tripPlanId;

  const StartTripRequest({
    required this.name,
    required this.visibility,
    required this.tripModality,
    required this.automaticUpdates,
    this.updateRefresh,
    required this.lat,
    required this.lon,
    this.battery,
    this.tripPlanId,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'visibility': visibility.toJson(),
        'tripModality': tripModality.toJson(),
        'automaticUpdates': automaticUpdates,
        if (updateRefresh != null) 'updateRefresh': updateRefresh,
        'location': {'lat': lat, 'lon': lon},
        if (battery != null) 'battery': battery,
        if (tripPlanId != null) 'tripPlanId': tripPlanId,
      };
}

/// `POST /trips/start` response; [replayed] when the Idempotency-Key was
/// already used (the original trip is returned, nothing new is created).
class StartTripResult {
  final String tripId;
  final String? tripUpdateId;
  final TripStatus status;
  final bool replayed;

  const StartTripResult({
    required this.tripId,
    this.tripUpdateId,
    required this.status,
    this.replayed = false,
  });

  factory StartTripResult.fromJson(Map<String, dynamic> json) =>
      StartTripResult(
        tripId: json['tripId'] as String,
        tripUpdateId: json['tripUpdateId'] as String?,
        status: TripStatus.fromJson(json['status'] as String? ?? 'IN_PROGRESS'),
        replayed: json['replayed'] as bool? ?? false,
      );
}
