import '../../../core/constants/enums.dart';
import 'comment.dart';
import 'trip_day.dart';
import 'trip_location.dart';

/// Simple location for planned waypoints
class PlannedWaypoint {
  final double latitude;
  final double longitude;

  PlannedWaypoint({required this.latitude, required this.longitude});

  factory PlannedWaypoint.fromJson(Map<String, dynamic> json) {
    return PlannedWaypoint(
      latitude: (json['latitude'] as num?)?.toDouble() ??
          (json['lat'] as num?)?.toDouble() ??
          0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ??
          (json['lon'] as num?)?.toDouble() ??
          0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
      };
}

/// Trip model
class Trip {
  final String id;
  final String userId;
  final String name;
  final String username;
  final String? avatarUrl;
  final String? description;
  final Visibility visibility;
  final TripStatus status;
  final int?
      updateRefresh; // interval in seconds for automatic location updates
  final bool automaticUpdates; // whether automatic updates are enabled
  final TripModality? tripModality; // modality of the trip (SIMPLE, MULTI_DAY)
  final DateTime? startDate;
  final DateTime? endDate;
  final List<TripLocation>? locations;
  final List<Comment>? comments;
  final int commentsCount;
  final int reactionsCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  // Planned route from trip plan
  final PlannedWaypoint? plannedStartLocation;
  final PlannedWaypoint? plannedEndLocation;
  final List<PlannedWaypoint>? plannedWaypoints;
  // Encoded polyline from the trip plan (road-snapped route between waypoints)
  final String? plannedEncodedPolyline;
  // Backend-computed encoded polyline (Google Encoded Polyline Algorithm)
  final String? encodedPolyline;
  final DateTime? polylineUpdatedAt;
  // Multi-day trip data
  final List<TripDay>? tripDays;
  final int? currentDay;
  // Trip plan reference
  final String? tripPlanId;

  /// Generate thumbnail URL based on trip ID or trip plan ID
  String get thumbnailUrl {
    final hasNoUpdates = locations == null || locations!.isEmpty;
    if (hasNoUpdates && tripPlanId != null && tripPlanId!.isNotEmpty) {
      return '/thumbnails/plans/$tripPlanId.png';
    }
    return '/thumbnails/trips/$id.png';
  }

  /// Default update refresh interval in seconds (30 minutes)
  static const int defaultUpdateRefresh = 1800;

  /// Minimum update refresh interval in seconds (1 minute)
  /// No longer bound by WorkManager's 15-min periodic limit since
  /// we use chained one-off tasks instead.
  static const int minUpdateRefresh = 60;

  /// Gets the effective update refresh interval, clamped to minimum
  int get effectiveUpdateRefresh {
    final refresh = updateRefresh ?? defaultUpdateRefresh;
    return refresh < minUpdateRefresh ? minUpdateRefresh : refresh;
  }

  Trip({
    required this.id,
    required this.userId,
    required this.name,
    required this.username,
    this.avatarUrl,
    this.description,
    required this.visibility,
    required this.status,
    this.updateRefresh,
    this.automaticUpdates = false,
    this.tripModality,
    this.startDate,
    this.endDate,
    this.locations,
    this.comments,
    this.commentsCount = 0,
    this.reactionsCount = 0,
    required this.createdAt,
    required this.updatedAt,
    this.plannedStartLocation,
    this.plannedEndLocation,
    this.plannedWaypoints,
    this.plannedEncodedPolyline,
    this.encodedPolyline,
    this.polylineUpdatedAt,
    this.tripDays,
    this.currentDay,
    this.tripPlanId,
  });

  factory Trip.fromJson(Map<String, dynamic> json) {
    final tripSettings = json['tripSettings'] as Map<String, dynamic>?;
    final tripDetails = json['tripDetails'] as Map<String, dynamic>?;
    final userDetails = json['userDetails'] as Map<String, dynamic>?;

    // Parse planned waypoints from tripDetails
    PlannedWaypoint? plannedStart;
    PlannedWaypoint? plannedEnd;
    List<PlannedWaypoint>? plannedWaypoints;
    String? plannedEncodedPolyline;

    if (tripDetails != null) {
      if (tripDetails['startLocation'] != null) {
        plannedStart = PlannedWaypoint.fromJson(
          tripDetails['startLocation'] as Map<String, dynamic>,
        );
      }
      if (tripDetails['endLocation'] != null) {
        plannedEnd = PlannedWaypoint.fromJson(
          tripDetails['endLocation'] as Map<String, dynamic>,
        );
      }
      if (tripDetails['waypoints'] != null &&
          tripDetails['waypoints'] is List) {
        plannedWaypoints = (tripDetails['waypoints'] as List)
            .where((wp) => wp != null)
            .map((wp) => PlannedWaypoint.fromJson(wp as Map<String, dynamic>))
            .toList();
      }
      plannedEncodedPolyline = tripDetails['plannedPolyline'] as String? ??
          tripDetails['encodedPolyline'] as String?;
    }

    // Also check top-level plannedPolyline (backend returns it at root level)
    plannedEncodedPolyline ??= json['plannedPolyline'] as String?;


    return Trip(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      name: json['name'] as String? ??
          json['title'] as String? ??
          'Untitled Trip',
      username: json['username'] as String? ?? '',
      avatarUrl:
          userDetails?['avatarUrl'] as String? ?? json['avatarUrl'] as String?,
      description: json['description'] as String?,
      visibility: Visibility.fromJson(
        ((tripSettings?['visibility'] ?? json['visibility']) as String?) ??
            'PRIVATE',
      ),
      status: TripStatus.fromJson(
        ((tripSettings?['tripStatus'] ?? json['status']) as String?) ??
            'CREATED',
      ),
      updateRefresh:
          (tripSettings?['updateRefresh'] ?? json['updateRefresh']) as int?,
      automaticUpdates: ((tripSettings?['automaticUpdates'] ??
              json['automaticUpdates']) as bool?) ??
          false,
      tripModality: (tripSettings?['tripModality'] ?? json['tripModality']) !=
              null
          ? TripModality.fromJson(
              (tripSettings?['tripModality'] ?? json['tripModality']) as String,
            )
          : null,
      startDate: json['startDate'] != null
          ? DateTime.tryParse(json['startDate'] as String)
          : null,
      endDate: json['endDate'] != null
          ? DateTime.tryParse(json['endDate'] as String)
          : null,
      locations: json['tripUpdates'] != null && json['tripUpdates'] is List
          ? (json['tripUpdates'] as List)
              .where((loc) => loc != null)
              .map(
                (loc) => TripLocation.fromJson(loc as Map<String, dynamic>),
              )
              .toList()
          : null,
      comments: json['comments'] != null && json['comments'] is List
          ? (json['comments'] as List)
              .where((comment) => comment != null)
              .map(
                (comment) => Comment.fromJson(comment as Map<String, dynamic>),
              )
              .toList()
          : null,
      commentsCount: (json['comments'] as List?)?.length ??
          (json['commentsCount'] as int?) ??
          0,
      reactionsCount: (json['reactionsCount'] as int?) ?? 0,
      createdAt: DateTime.tryParse(
            (json['creationTimestamp'] ?? json['createdAt']) as String? ?? '',
          ) ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(
            (json['updatedAt'] ?? json['creationTimestamp']) as String? ?? '',
          ) ??
          DateTime.now(),
      plannedStartLocation: plannedStart,
      plannedEndLocation: plannedEnd,
      plannedWaypoints: plannedWaypoints,
      plannedEncodedPolyline: plannedEncodedPolyline,
      encodedPolyline: json['encodedPolyline'] as String?,
      polylineUpdatedAt: json['polylineUpdatedAt'] != null
          ? DateTime.tryParse(json['polylineUpdatedAt'] as String)
          : null,
      tripDays: json['tripDays'] != null && json['tripDays'] is List
          ? (json['tripDays'] as List)
              .where((day) => day != null)
              .map((day) => TripDay.fromJson(day as Map<String, dynamic>))
              .toList()
          : null,
      currentDay: (tripDetails?['currentDay'] ?? json['currentDay']) as int?,
      tripPlanId: json['tripPlanId'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'name': name,
        'username': username,
        if (avatarUrl != null) 'avatarUrl': avatarUrl,
        if (description != null) 'description': description,
        'visibility': visibility.toJson(),
        'status': status.toJson(),
        if (updateRefresh != null) 'updateRefresh': updateRefresh,
        'automaticUpdates': automaticUpdates,
        if (tripModality != null) 'tripModality': tripModality!.toJson(),
        if (startDate != null) 'startDate': startDate!.toIso8601String(),
        if (endDate != null) 'endDate': endDate!.toIso8601String(),
        if (locations != null)
          'locations': locations!.map((loc) => loc.toJson()).toList(),
        if (comments != null)
          'comments': comments!.map((comment) => comment.toJson()).toList(),
        'commentsCount': commentsCount,
        'reactionsCount': reactionsCount,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        if (plannedStartLocation != null)
          'plannedStartLocation': plannedStartLocation!.toJson(),
        if (plannedEndLocation != null)
          'plannedEndLocation': plannedEndLocation!.toJson(),
        if (plannedWaypoints != null)
          'plannedWaypoints':
              plannedWaypoints!.map((wp) => wp.toJson()).toList(),
        if (plannedEncodedPolyline != null)
          'plannedEncodedPolyline': plannedEncodedPolyline,
        if (encodedPolyline != null) 'encodedPolyline': encodedPolyline,
        if (polylineUpdatedAt != null)
          'polylineUpdatedAt': polylineUpdatedAt!.toIso8601String(),
        if (tripDays != null)
          'tripDays': tripDays!.map((day) => day.toJson()).toList(),
        if (currentDay != null) 'currentDay': currentDay,
        if (tripPlanId != null) 'tripPlanId': tripPlanId,
      };

  /// Check if trip has planned route from a trip plan
  bool get hasPlannedRoute =>
      plannedStartLocation != null ||
      plannedEndLocation != null ||
      (plannedWaypoints != null && plannedWaypoints!.isNotEmpty) ||
      (plannedEncodedPolyline != null && plannedEncodedPolyline!.isNotEmpty);

  /// Creates a copy of this Trip with the given fields replaced with new values.
  /// Useful for merging updated trip data while preserving existing fields.
  Trip copyWith({
    String? id,
    String? userId,
    String? name,
    String? username,
    String? avatarUrl,
    String? description,
    Visibility? visibility,
    TripStatus? status,
    int? updateRefresh,
    bool? automaticUpdates,
    TripModality? tripModality,
    DateTime? startDate,
    DateTime? endDate,
    List<TripLocation>? locations,
    List<Comment>? comments,
    int? commentsCount,
    int? reactionsCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    PlannedWaypoint? plannedStartLocation,
    PlannedWaypoint? plannedEndLocation,
    List<PlannedWaypoint>? plannedWaypoints,
    String? plannedEncodedPolyline,
    String? encodedPolyline,
    DateTime? polylineUpdatedAt,
    List<TripDay>? tripDays,
    int? currentDay,
    String? tripPlanId,
  }) {
    return Trip(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      description: description ?? this.description,
      visibility: visibility ?? this.visibility,
      status: status ?? this.status,
      updateRefresh: updateRefresh ?? this.updateRefresh,
      automaticUpdates: automaticUpdates ?? this.automaticUpdates,
      tripModality: tripModality ?? this.tripModality,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      locations: locations ?? this.locations,
      comments: comments ?? this.comments,
      commentsCount: commentsCount ?? this.commentsCount,
      reactionsCount: reactionsCount ?? this.reactionsCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      plannedStartLocation: plannedStartLocation ?? this.plannedStartLocation,
      plannedEndLocation: plannedEndLocation ?? this.plannedEndLocation,
      plannedWaypoints: plannedWaypoints ?? this.plannedWaypoints,
      plannedEncodedPolyline:
          plannedEncodedPolyline ?? this.plannedEncodedPolyline,
      encodedPolyline: encodedPolyline ?? this.encodedPolyline,
      polylineUpdatedAt: polylineUpdatedAt ?? this.polylineUpdatedAt,
      tripDays: tripDays ?? this.tripDays,
      currentDay: currentDay ?? this.currentDay,
      tripPlanId: tripPlanId ?? this.tripPlanId,
    );
  }
}
