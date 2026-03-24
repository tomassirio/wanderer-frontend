import '../../../core/constants/enums.dart';

/// Request model for trip update/location
class TripUpdateRequest {
  final double latitude;
  final double longitude;
  final String? message;
  final String? imageUrl;
  final int? battery;
  final TripUpdateType? updateType;

  TripUpdateRequest({
    required this.latitude,
    required this.longitude,
    this.message,
    this.imageUrl,
    this.battery,
    this.updateType,
  });

  Map<String, dynamic> toJson() => {
        'location': {
          'lat': latitude,
          'lon': longitude,
        },
        if (message != null) 'message': message,
        if (imageUrl != null) 'imageUrl': imageUrl,
        if (battery != null) 'battery': battery,
        if (updateType != null) 'updateType': updateType!.toJson(),
      };
}
