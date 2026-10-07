import '../../../core/constants/api_endpoints.dart';
import '../../models/trip_models.dart';
import '../api_client.dart';

/// Trip command client for write operations (Port 8081)
class TripCommandClient {
  final ApiClient _apiClient;

  TripCommandClient({ApiClient? apiClient})
      : _apiClient =
            apiClient ?? ApiClient(baseUrl: ApiEndpoints.commandBaseUrl);

  /// Create new trip
  /// Requires authentication (USER, ADMIN)
  /// Returns the trip ID immediately. Full trip data will be delivered via WebSocket.
  Future<String> createTrip(CreateTripRequest request) async {
    final response = await _apiClient.post(
      ApiEndpoints.tripsCreate,
      body: request.toJson(),
      requireAuth: true,
    );
    return _apiClient.handleAcceptedResponse(response);
  }

  /// Update trip
  /// Requires authentication (USER, ADMIN - owner only)
  /// Returns the trip ID immediately. Full trip data will be delivered via WebSocket.
  Future<String> updateTrip(String tripId, UpdateTripRequest request) async {
    final response = await _apiClient.put(
      ApiEndpoints.tripUpdate(tripId),
      body: request.toJson(),
      requireAuth: true,
    );
    return _apiClient.handleAcceptedResponse(response);
  }

  /// Change trip visibility (PUBLIC/PRIVATE/PROTECTED)
  /// Requires authentication (USER, ADMIN - owner only)
  /// Returns the trip ID immediately. Full trip data will be delivered via WebSocket.
  Future<String> changeVisibility(
    String tripId,
    ChangeVisibilityRequest request,
  ) async {
    final response = await _apiClient.patch(
      ApiEndpoints.tripVisibility(tripId),
      body: request.toJson(),
      requireAuth: true,
    );
    return _apiClient.handleAcceptedResponse(response);
  }

  /// Change trip status (CREATED/IN_PROGRESS/PAUSED/FINISHED)
  /// Requires authentication (USER, ADMIN - owner only)
  /// Returns the trip ID immediately. Full trip data will be delivered via WebSocket.
  Future<String> changeStatus(
      String tripId, ChangeStatusRequest request) async {
    final response = await _apiClient.patch(
      ApiEndpoints.tripStatus(tripId),
      body: request.toJson(),
      requireAuth: true,
    );
    return _apiClient.handleAcceptedResponse(response);
  }

  /// Change trip settings (automatic updates, time interval)
  /// Requires authentication (USER, ADMIN - owner only)
  /// Returns the trip ID immediately. Full trip data will be delivered via WebSocket.
  Future<String> changeSettings(
      String tripId, ChangeTripSettingsRequest request) async {
    final response = await _apiClient.patch(
      ApiEndpoints.tripSettings(tripId),
      body: request.toJson(),
      requireAuth: true,
    );
    return _apiClient.handleAcceptedResponse(response);
  }

  /// Toggle day state for MULTI_DAY trips.
  /// When IN_PROGRESS → ends day (status becomes RESTING).
  /// When RESTING → starts next day (status becomes IN_PROGRESS).
  /// Returns the trip ID immediately. Full trip data will be delivered via WebSocket.
  Future<String> toggleDay(String tripId) async {
    final response = await _apiClient.patch(
      ApiEndpoints.tripToggleDay(tripId),
      body: {},
      requireAuth: true,
    );
    return _apiClient.handleAcceptedResponse(response);
  }

  /// Delete trip
  /// Requires authentication (USER, ADMIN - owner only)
  /// Returns the trip ID immediately. Deletion will be confirmed via WebSocket.
  Future<String> deleteTrip(String tripId) async {
    final response = await _apiClient.delete(
      ApiEndpoints.tripDelete(tripId),
      requireAuth: true,
    );
    return _apiClient.handleAcceptedResponse(response);
  }

  /// Create trip from trip plan
  /// Requires authentication (USER, ADMIN - owner only)
  /// Returns the trip ID immediately. Full trip data will be delivered via WebSocket.
  Future<String> createTripFromPlan(
      String tripPlanId, TripFromPlanRequest request) async {
    final response = await _apiClient.post(
      ApiEndpoints.tripFromPlan(tripPlanId),
      body: request.toJson(),
      requireAuth: true,
    );
    return _apiClient.handleAcceptedResponse(response);
  }

  /// Create a trip and start it in one call (`POST /trips/start`).
  /// [idempotencyKey] must stay the same for every retry of one Start press:
  /// a repeat returns the original trip ([StartTripResult.replayed]).
  Future<StartTripResult> startTrip(StartTripRequest request,
      {required String idempotencyKey}) async {
    final response = await _apiClient.post(
      ApiEndpoints.tripsStart,
      body: request.toJson(),
      headers: {'Idempotency-Key': idempotencyKey},
      requireAuth: true,
    );
    return _apiClient.handleResponse(response, StartTripResult.fromJson);
  }

  /// Trip start funnel counter (`POST /analytics/events`). [event] is one
  /// of READY_SCREEN_VIEWED, CLOSED_WITHOUT_STARTING, SAVED_AS_PLAN;
  /// [source] SCRATCH or PLAN. TRIP_STARTED is counted by the server.
  Future<void> trackStartFunnel(String event, {String? source}) async {
    final response = await _apiClient.post(
      ApiEndpoints.analyticsEvents,
      body: {'event': event, if (source != null) 'source': source},
      requireAuth: true,
    );
    _apiClient.handleNoContentResponse(response);
  }
}
