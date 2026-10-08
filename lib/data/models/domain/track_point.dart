/// A raw GPS fix recorded on the phone (see `TripTrackingService.kt`).
/// Dense and silent: drives the route line and the distance, never shown in
/// the timeline.
class TrackPoint {
  /// Client-generated UUID; makes uploads idempotent.
  final String id;
  final String tripId;
  final double lat;
  final double lon;
  final double? accuracyM;
  final double? altitudeM;
  final DateTime recordedAt;

  /// Whether the backend has accepted it.
  final bool synced;

  const TrackPoint({
    required this.id,
    required this.tripId,
    required this.lat,
    required this.lon,
    this.accuracyM,
    this.altitudeM,
    required this.recordedAt,
    this.synced = false,
  });

  /// From a `track_points` row.
  factory TrackPoint.fromRow(Map<String, Object?> row) => TrackPoint(
        id: row['id'] as String,
        tripId: row['trip_id'] as String,
        lat: (row['lat'] as num).toDouble(),
        lon: (row['lon'] as num).toDouble(),
        accuracyM: (row['accuracy_m'] as num?)?.toDouble(),
        altitudeM: (row['altitude_m'] as num?)?.toDouble(),
        recordedAt: DateTime.fromMillisecondsSinceEpoch(
            row['recorded_at'] as int,
            isUtc: true),
        synced: row['synced'] == 1,
      );

  /// From the backend's `{lat, lon, recordedAt}` (`GET …/track-points`,
  /// `TRACK_UPDATED`). It has no id, so the capture time stands in.
  factory TrackPoint.fromJson(Map<String, dynamic> json, String tripId) {
    final recordedAt = DateTime.parse(json['recordedAt'] as String);
    return TrackPoint(
      id: recordedAt.toIso8601String(),
      tripId: tripId,
      lat: (json['lat'] as num).toDouble(),
      lon: (json['lon'] as num).toDouble(),
      recordedAt: recordedAt,
      synced: true,
    );
  }

  /// Upload shape for `POST /trips/{tripId}/track-points`.
  Map<String, dynamic> toJson() => {
        'id': id,
        'lat': lat,
        'lon': lon,
        if (accuracyM != null) 'accuracyM': accuracyM,
        if (altitudeM != null) 'altitudeM': altitudeM,
        'recordedAt': recordedAt.toUtc().toIso8601String(),
      };
}
