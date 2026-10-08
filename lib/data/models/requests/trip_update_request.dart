import '../../../core/constants/enums.dart';

/// Request model for trip update/location
class TripUpdateRequest {
  /// Null only for lifecycle markers sent without a GPS fix.
  final double? latitude;
  final double? longitude;
  final String? message;
  final String? imageUrl;
  final int? battery;
  final TripUpdateType? updateType;

  /// Client-generated id; the backend ignores a repeat (safe retries).
  final String? id;

  /// When the phone captured the check-in (it may be sent much later).
  final DateTime? recordedAt;

  TripUpdateRequest({
    required this.latitude,
    required this.longitude,
    this.message,
    this.imageUrl,
    this.battery,
    this.updateType,
    this.id,
    this.recordedAt,
  });

  Map<String, dynamic> toJson() => {
        if (latitude != null && longitude != null)
          'location': {
            'lat': latitude,
            'lon': longitude,
          },
        if (message != null) 'message': message,
        if (imageUrl != null) 'imageUrl': imageUrl,
        if (battery != null) 'battery': battery,
        if (updateType != null) 'updateType': updateType!.toJson(),
        if (id != null) 'id': id,
        if (recordedAt != null)
          'recordedAt': recordedAt!.toUtc().toIso8601String(),
      };
}
