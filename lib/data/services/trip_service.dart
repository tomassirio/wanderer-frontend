import '../models/responses/page_response.dart';
import '../models/trip_models.dart';
import '../client/clients.dart';

/// Service for trip operations
class TripService {
  final TripQueryClient _tripQueryClient;
  final TripCommandClient _tripCommandClient;
  final TripPlanCommandClient _tripPlanCommandClient;
  final TripUpdateCommandClient _tripUpdateCommandClient;

  TripService({
    TripQueryClient? tripQueryClient,
    TripCommandClient? tripCommandClient,
    TripPlanCommandClient? tripPlanCommandClient,
    TripUpdateCommandClient? tripUpdateCommandClient,
  })  : _tripQueryClient = tripQueryClient ?? TripQueryClient(),
        _tripCommandClient = tripCommandClient ?? TripCommandClient(),
        _tripPlanCommandClient =
            tripPlanCommandClient ?? TripPlanCommandClient(),
        _tripUpdateCommandClient =
            tripUpdateCommandClient ?? TripUpdateCommandClient();

  // ===== Trip Query Operations =====

  /// Get all my trips
  Future<List<Trip>> getMyTrips() async {
    return await _tripQueryClient.getCurrentUserTrips();
  }

  /// Get trip details
  Future<Trip> getTripById(String tripId) async {
    return await _tripQueryClient.getTripById(tripId);
  }

  /// Get a public trip by ID (no authentication required)
  /// Used to fetch promoted pre-announced trips for guest users
  Future<Trip> getPublicTripById(String tripId) async {
    return await _tripQueryClient.getPublicTripById(tripId);
  }

  /// Get all trips (admin only, paginated)
  Future<PageResponse<Trip>> getAllTrips({
    int page = 0,
    int size = 20,
  }) async {
    return await _tripQueryClient.getAllTrips(page: page, size: size);
  }

  /// Get public trips (paginated)
  Future<PageResponse<Trip>> getPublicTrips({
    int page = 0,
    int size = 20,
  }) async {
    return await _tripQueryClient.getPublicTrips(page: page, size: size);
  }

  /// Get available trips (paginated)
  Future<PageResponse<Trip>> getAvailableTrips({
    int page = 0,
    int size = 20,
  }) async {
    return await _tripQueryClient.getAvailableTrips(page: page, size: size);
  }

  /// Get trips by user ID (respects visibility)
  Future<List<Trip>> getUserTrips(String userId) async {
    return await _tripQueryClient.getTripsByUser(userId);
  }

  // ===== Trip Command Operations =====

  /// Create a new trip
  /// Returns the trip ID immediately. Full trip data will be delivered via WebSocket.
  Future<String> createTrip(CreateTripRequest request) async {
    return await _tripCommandClient.createTrip(request);
  }

  /// Update a trip
  /// Returns the trip ID immediately. Full trip data will be delivered via WebSocket.
  Future<String> updateTrip(String tripId, UpdateTripRequest request) async {
    return await _tripCommandClient.updateTrip(tripId, request);
  }

  /// Change trip visibility
  /// Returns the trip ID immediately. Full trip data will be delivered via WebSocket.
  Future<String> changeVisibility(
    String tripId,
    ChangeVisibilityRequest request,
  ) async {
    return await _tripCommandClient.changeVisibility(tripId, request);
  }

  /// Change trip status (start/pause/finish)
  /// Returns the trip ID immediately. Full trip data will be delivered via WebSocket.
  Future<String> changeStatus(
      String tripId, ChangeStatusRequest request) async {
    return await _tripCommandClient.changeStatus(tripId, request);
  }

  /// Change trip settings (automatic updates, time interval)
  /// Returns the trip ID immediately. Full trip data will be delivered via WebSocket.
  Future<String> changeSettings(
      String tripId, ChangeTripSettingsRequest request) async {
    return await _tripCommandClient.changeSettings(tripId, request);
  }

  /// Toggle day state for MULTI_DAY trips (end day / start next day)
  /// Returns the trip ID immediately. Full trip data will be delivered via WebSocket.
  Future<String> toggleDay(String tripId) async {
    return await _tripCommandClient.toggleDay(tripId);
  }

  /// Delete a trip
  /// Returns the trip ID immediately. Deletion will be confirmed via WebSocket.
  Future<String> deleteTrip(String tripId) async {
    return await _tripCommandClient.deleteTrip(tripId);
  }

  /// Create trip from trip plan
  /// Returns the trip ID immediately. Full trip data will be delivered via WebSocket.
  Future<String> createTripFromPlan(
      String tripPlanId, TripFromPlanRequest request) async {
    return await _tripCommandClient.createTripFromPlan(tripPlanId, request);
  }

  /// Send trip update (location, message)
  /// Returns the trip update ID immediately. Full data will be delivered via WebSocket.
  Future<String> sendTripUpdate(
      String tripId, TripUpdateRequest request) async {
    return await _tripUpdateCommandClient.createTripUpdate(tripId, request);
  }

  // ===== Trip Plan Operations =====

  /// Create a trip plan
  /// Returns the trip plan ID immediately. Full data will be delivered via WebSocket.
  Future<String> createTripPlan(CreateTripPlanRequest request) async {
    return await _tripPlanCommandClient.createTripPlan(request);
  }

  /// Update a trip plan
  /// Returns the trip plan ID immediately. Full data will be delivered via WebSocket.
  Future<String> updateTripPlan(
    String planId,
    UpdateTripPlanRequest request,
  ) async {
    return await _tripPlanCommandClient.updateTripPlan(planId, request);
  }

  /// Delete a trip plan
  /// Returns the trip plan ID immediately. Deletion will be confirmed via WebSocket.
  Future<String> deleteTripPlan(String planId) async {
    return await _tripPlanCommandClient.deleteTripPlan(planId);
  }

  // ===== Trip Updates Operations =====

  /// Get trip updates for a specific trip (paginated)
  Future<PageResponse<TripLocation>> getTripUpdates(
    String tripId, {
    int page = 0,
    int size = 50,
  }) async {
    return await _tripQueryClient.getTripUpdates(tripId,
        page: page, size: size);
  }
}
