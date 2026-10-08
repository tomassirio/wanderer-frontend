import '../../../core/constants/api_endpoints.dart';
import '../../models/trip_models.dart';
import '../api_client.dart';

/// Trip update command client for write operations (Port 8081)
class TripUpdateCommandClient {
  final ApiClient _apiClient;

  TripUpdateCommandClient({ApiClient? apiClient})
      : _apiClient =
            apiClient ?? ApiClient(baseUrl: ApiEndpoints.commandBaseUrl);

  /// Create trip update (location, battery, message)
  /// Requires authentication (USER, ADMIN - trip owner only)
  /// Returns the trip update ID immediately. Full data will be delivered via WebSocket.
  Future<String> createTripUpdate(
    String tripId,
    TripUpdateRequest request,
  ) =>
      postTripUpdateJson(tripId, request.toJson());

  /// Posts an already serialised [TripUpdateRequest] (from the offline
  /// outbox). Returns the trip update ID.
  Future<String> postTripUpdateJson(
    String tripId,
    Map<String, dynamic> body,
  ) async {
    final response = await _apiClient.post(
      ApiEndpoints.tripUpdates(tripId),
      body: body,
      requireAuth: true,
    );
    return _apiClient.handleAcceptedResponse(response);
  }
}
