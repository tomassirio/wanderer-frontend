import '../../../core/constants/api_endpoints.dart';
import '../../models/responses/page_response.dart';
import '../../models/trip_models.dart';
import '../api_client.dart';

/// Trip query client for read operations (Port 8082)
class TripQueryClient {
  final ApiClient _apiClient;

  TripQueryClient({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient(baseUrl: ApiEndpoints.queryBaseUrl);

  /// Get trip by ID
  /// Requires authentication (visibility-dependent)
  Future<Trip> getTripById(String tripId) async {
    final response = await _apiClient.get(
      ApiEndpoints.tripById(tripId),
      requireAuth: true,
    );
    return _apiClient.handleResponse(response, Trip.fromJson);
  }

  /// Get a public trip by ID (no authentication required)
  /// Used to fetch promoted pre-announced trips for guest users
  Future<Trip> getPublicTripById(String tripId) async {
    final response = await _apiClient.get(
      ApiEndpoints.tripById(tripId),
      requireAuth: false,
    );
    return _apiClient.handleResponse(response, Trip.fromJson);
  }

  /// Get all trips (paginated)
  /// Requires authentication (ADMIN only)
  Future<PageResponse<Trip>> getAllTrips({
    int page = 0,
    int size = 100,
    String sort = 'creationTimestamp,desc',
  }) async {
    final endpoint = '${ApiEndpoints.trips}?page=$page&size=$size&sort=$sort';
    final response = await _apiClient.get(
      endpoint,
      requireAuth: true,
    );
    return _apiClient.handlePageResponse(response, Trip.fromJson);
  }

  /// Get current user's trips
  /// Requires authentication (USER, ADMIN)
  Future<List<Trip>> getCurrentUserTrips() async {
    final response = await _apiClient.get(
      ApiEndpoints.tripsMe,
      requireAuth: true,
    );
    return _apiClient.handleListResponse(response, Trip.fromJson);
  }

  /// Get public trips (paginated)
  /// No authentication required
  Future<PageResponse<Trip>> getPublicTrips({
    int page = 0,
    int size = 100,
    String sort = 'creationTimestamp,desc',
  }) async {
    final endpoint =
        '${ApiEndpoints.tripsPublic}?page=$page&size=$size&sort=$sort';
    final response = await _apiClient.get(
      endpoint,
      requireAuth: false,
    );
    return _apiClient.handlePageResponse(response, Trip.fromJson);
  }

  /// Get available trips (paginated)
  /// Requires authentication (USER, ADMIN)
  Future<PageResponse<Trip>> getAvailableTrips({
    int page = 0,
    int size = 100,
    String sort = 'creationTimestamp,desc',
  }) async {
    final endpoint =
        '${ApiEndpoints.tripsAvailable}?page=$page&size=$size&sort=$sort';
    final response = await _apiClient.get(
      endpoint,
      requireAuth: true,
    );
    return _apiClient.handlePageResponse(response, Trip.fromJson);
  }

  /// Get trips by user ID
  /// Requires authentication (respects visibility rules)
  Future<List<Trip>> getTripsByUser(String userId) async {
    final response = await _apiClient.get(
      ApiEndpoints.tripsByUser(userId),
      requireAuth: true,
    );
    return _apiClient.handleListResponse(response, Trip.fromJson);
  }

  /// Get trip updates for a specific trip (paginated)
  /// Requires authentication (visibility-dependent)
  Future<PageResponse<TripLocation>> getTripUpdates(
    String tripId, {
    int page = 0,
    int size = 100,
    String sort = 'timestamp,desc',
  }) async {
    final endpoint =
        '${ApiEndpoints.tripUpdates(tripId)}?page=$page&size=$size&sort=$sort';
    final response = await _apiClient.get(
      endpoint,
      requireAuth: true,
    );
    return _apiClient.handlePageResponse(response, TripLocation.fromJson);
  }

  /// Get lightweight trip update locations for map + timeline (not paginated)
  /// Returns all location points for a trip without heavy fields (message, reactions)
  /// Requires authentication (visibility-dependent)
  Future<List<TripLocation>> getTripUpdateLocations(String tripId) async {
    final response = await _apiClient.get(
      ApiEndpoints.tripUpdateLocations(tripId),
      requireAuth: true,
    );
    return _apiClient.handleListResponse(response, TripLocation.fromJson);
  }
}
