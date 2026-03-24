import '../../../core/constants/enums.dart';
import 'reaction.dart';

/// Trip location/update model
class TripLocation {
  final String id;
  final double latitude;
  final double longitude;
  final String? message;
  final String? imageUrl;
  final DateTime timestamp;
  final int? battery;
  final List<Reaction>? reactions;
  final String? city;
  final String? country;
  final double? temperatureCelsius;
  final WeatherCondition? weatherCondition;
  final TripUpdateType updateType;
  final double? distanceSoFarKm;

  TripLocation({
    required this.id,
    required this.latitude,
    required this.longitude,
    this.message,
    this.imageUrl,
    required this.timestamp,
    this.battery,
    this.reactions,
    this.city,
    this.country,
    this.temperatureCelsius,
    this.weatherCondition,
    this.updateType = TripUpdateType.regular,
    this.distanceSoFarKm,
  });

  factory TripLocation.fromJson(Map<String, dynamic> json) {
    final location = json['location'] as Map<String, dynamic>?;
    final reactionsJson = json['reactions'];
    List<Reaction>? reactionsList;

    if (reactionsJson != null) {
      if (reactionsJson is Map) {
        // Handle reactions as a map with reaction types as keys
        reactionsList = [];
        reactionsJson.forEach((key, value) {
          if (value is List) {
            for (var reactionJson in value) {
              reactionsList!.add(Reaction.fromJson(reactionJson));
            }
          }
        });
      } else if (reactionsJson is List) {
        // Handle reactions as a list
        reactionsList = reactionsJson
            .map((r) => Reaction.fromJson(r as Map<String, dynamic>))
            .toList();
      }
    }

    return TripLocation(
      id: json['id'] as String? ?? '',
      latitude:
          (location?['lat'] ?? json['lat'] ?? json['latitude'] ?? 0).toDouble(),
      longitude: (location?['lon'] ?? json['lon'] ?? json['longitude'] ?? 0)
          .toDouble(),
      message: json['message'] as String?,
      imageUrl: json['imageUrl'] as String?,
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.now(),
      battery: json['battery'] as int?,
      reactions: reactionsList,
      city: json['city'] as String?,
      country: json['country'] as String?,
      temperatureCelsius: (json['temperatureCelsius'] as num?)?.toDouble(),
      weatherCondition: json['weatherCondition'] != null
          ? WeatherCondition.fromJson(json['weatherCondition'] as String)
          : null,
      updateType: json['updateType'] != null
          ? TripUpdateType.fromJson(json['updateType'] as String)
          : TripUpdateType.regular,
      distanceSoFarKm: (json['distanceSoFarKm'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'latitude': latitude,
        'longitude': longitude,
        if (message != null) 'message': message,
        if (imageUrl != null) 'imageUrl': imageUrl,
        'timestamp': timestamp.toIso8601String(),
        if (battery != null) 'battery': battery,
        if (reactions != null)
          'reactions': reactions!.map((r) => r.toJson()).toList(),
        if (city != null) 'city': city,
        if (country != null) 'country': country,
        if (temperatureCelsius != null)
          'temperatureCelsius': temperatureCelsius,
        if (weatherCondition != null)
          'weatherCondition': weatherCondition!.toJson(),
        if (updateType != TripUpdateType.regular)
          'updateType': updateType.toJson(),
        if (distanceSoFarKm != null) 'distanceSoFarKm': distanceSoFarKm,
      };

  /// Create a copy with updated place information
  TripLocation copyWith({
    String? id,
    double? latitude,
    double? longitude,
    String? message,
    String? imageUrl,
    DateTime? timestamp,
    int? battery,
    List<Reaction>? reactions,
    String? city,
    String? country,
    double? temperatureCelsius,
    WeatherCondition? weatherCondition,
    TripUpdateType? updateType,
    double? distanceSoFarKm,
  }) {
    return TripLocation(
      id: id ?? this.id,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      message: message ?? this.message,
      imageUrl: imageUrl ?? this.imageUrl,
      timestamp: timestamp ?? this.timestamp,
      battery: battery ?? this.battery,
      reactions: reactions ?? this.reactions,
      city: city ?? this.city,
      country: country ?? this.country,
      temperatureCelsius: temperatureCelsius ?? this.temperatureCelsius,
      weatherCondition: weatherCondition ?? this.weatherCondition,
      updateType: updateType ?? this.updateType,
      distanceSoFarKm: distanceSoFarKm ?? this.distanceSoFarKm,
    );
  }

  /// Get the display location (city, country or coordinates)
  String get displayLocation {
    if (city != null && country != null) {
      return '$city, $country';
    }
    return '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';
  }

  /// Get reaction count
  int get reactionCount => reactions?.length ?? 0;

  /// Whether this update is a lifecycle marker (DAY_START, DAY_END, TRIP_STARTED, TRIP_ENDED)
  /// Lifecycle markers have location: null from the backend
  bool get isLifecycleMarker =>
      updateType == TripUpdateType.dayStart ||
      updateType == TripUpdateType.dayEnd ||
      updateType == TripUpdateType.tripStarted ||
      updateType == TripUpdateType.tripEnded;

  /// Whether this update has a real location (not a 0,0 fallback from null)
  bool get hasLocation => latitude != 0.0 || longitude != 0.0;
}
