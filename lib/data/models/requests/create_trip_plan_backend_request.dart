/// GeoLocation model matching backend structure
class GeoLocation {
  final double lat;
  final double lon;

  GeoLocation({required this.lat, required this.lon});

  Map<String, dynamic> toJson() => {'lat': lat, 'lon': lon};
}

/// Request model for creating a trip plan matching backend API
class CreateTripPlanBackendRequest {
  final String name;
  final String planType;
  final DateTime startDate;
  final DateTime endDate;

  /// Optional: a plan can be saved before its route is known.
  final GeoLocation? startLocation;
  final GeoLocation? endLocation;
  final List<GeoLocation> waypoints;
  final Map<String, dynamic>? metadata;
  final String? plannedPolyline;

  CreateTripPlanBackendRequest({
    required this.name,
    required this.planType,
    required this.startDate,
    required this.endDate,
    this.startLocation,
    this.endLocation,
    this.waypoints = const [],
    this.metadata,
    this.plannedPolyline,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'planType': planType,
        'startDate':
            startDate.toIso8601String().split('T')[0], // LocalDate format
        'endDate': endDate.toIso8601String().split('T')[0], // LocalDate format
        if (startLocation != null) 'startLocation': startLocation!.toJson(),
        if (endLocation != null) 'endLocation': endLocation!.toJson(),
        'waypoints': waypoints.map((w) => w.toJson()).toList(),
        if (metadata != null) 'metadata': metadata,
        if (plannedPolyline != null) 'plannedPolyline': plannedPolyline,
      };
}
