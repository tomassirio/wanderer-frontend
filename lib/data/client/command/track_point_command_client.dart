import 'dart:convert';

import '../../../core/constants/api_endpoints.dart';
import '../../models/trip_models.dart';
import '../api_client.dart';

/// Track point command client for write operations (Port 8081)
class TrackPointCommandClient {
  final ApiClient _apiClient;

  TrackPointCommandClient({ApiClient? apiClient})
      : _apiClient =
            apiClient ?? ApiClient(baseUrl: ApiEndpoints.commandBaseUrl);

  /// Uploads 1..500 recorded points (owner only). Idempotent per point id.
  /// Returns how many were new to the backend.
  Future<int> uploadTrackPoints(String tripId, List<TrackPoint> points) async {
    final response = await _apiClient.post(
      ApiEndpoints.tripTrackPoints(tripId),
      body: {'points': points.map((p) => p.toJson()).toList()},
      requireAuth: true,
    );
    _apiClient.handleNoContentResponse(response);
    final body = response.body.trim();
    if (body.isEmpty) return 0;
    final decoded = jsonDecode(body);
    return decoded is Map ? (decoded['accepted'] as num?)?.toInt() ?? 0 : 0;
  }
}
