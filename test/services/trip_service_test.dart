import 'package:flutter_test/flutter_test.dart';
import 'package:wanderer_frontend/core/constants/enums.dart';
import 'package:wanderer_frontend/data/models/responses/page_response.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/data/services/trip_service.dart';
import 'package:wanderer_frontend/data/client/clients.dart';

void main() {
  group('TripService', () {
    late MockTripQueryClient mockTripQueryClient;
    late MockTripCommandClient mockTripCommandClient;
    late MockTripPlanCommandClient mockTripPlanCommandClient;
    late MockTripUpdateCommandClient mockTripUpdateCommandClient;
    late TripService tripService;

    setUp(() {
      mockTripQueryClient = MockTripQueryClient();
      mockTripCommandClient = MockTripCommandClient();
      mockTripPlanCommandClient = MockTripPlanCommandClient();
      mockTripUpdateCommandClient = MockTripUpdateCommandClient();
      tripService = TripService(
        tripQueryClient: mockTripQueryClient,
        tripCommandClient: mockTripCommandClient,
        tripPlanCommandClient: mockTripPlanCommandClient,
        tripUpdateCommandClient: mockTripUpdateCommandClient,
      );
    });

    group('Trip Query Operations', () {
      test('getMyTrips returns user trips', () async {
        final mockTrips = [
          createMockTrip('trip-1', 'My Trip 1'),
          createMockTrip('trip-2', 'My Trip 2'),
        ];
        mockTripQueryClient.mockTrips = mockTrips;

        final result = await tripService.getMyTrips();

        expect(result.length, 2);
        expect(mockTripQueryClient.getCurrentUserTripsCalled, true);
      });

      test('getTripById returns specific trip', () async {
        final mockTrip = createMockTrip('trip-123', 'Specific Trip');
        mockTripQueryClient.mockTrip = mockTrip;

        final result = await tripService.getTripById('trip-123');

        expect(result.id, 'trip-123');
        expect(mockTripQueryClient.getTripByIdCalled, true);
        expect(mockTripQueryClient.lastTripId, 'trip-123');
      });

      test('getAllTrips returns all trips (paginated)', () async {
        final mockTrips = [
          createMockTrip('trip-1', 'Trip 1'),
          createMockTrip('trip-2', 'Trip 2'),
          createMockTrip('trip-3', 'Trip 3'),
        ];
        mockTripQueryClient.mockTrips = mockTrips;

        final result = await tripService.getAllTrips();

        expect(result.content.length, 3);
        expect(mockTripQueryClient.getAllTripsCalled, true);
      });

      test('getPublicTrips returns public trips (paginated)', () async {
        final mockTrips = [createMockTrip('trip-1', 'Public Trip 1')];
        mockTripQueryClient.mockTrips = mockTrips;

        final result = await tripService.getPublicTrips();

        expect(result.content.length, 1);
        expect(mockTripQueryClient.getPublicTripsCalled, true);
      });

      test('getAvailableTrips returns available trips (paginated)', () async {
        final mockTrips = [createMockTrip('trip-1', 'Available Trip')];
        mockTripQueryClient.mockTrips = mockTrips;

        final result = await tripService.getAvailableTrips();

        expect(result.content.isNotEmpty, true);
        expect(mockTripQueryClient.getAvailableTripsCalled, true);
      });

      test('getUserTrips returns trips for specific user', () async {
        final mockTrips = [createMockTrip('trip-1', 'User Trip')];
        mockTripQueryClient.mockTrips = mockTrips;

        final result = await tripService.getUserTrips('user-123');

        expect(result.isNotEmpty, true);
        expect(mockTripQueryClient.getTripsByUserCalled, true);
        expect(mockTripQueryClient.lastUserId, 'user-123');
      });
    });

    group('Trip Command Operations', () {
      test('createTrip creates new trip', () async {
        final request = CreateTripRequest(
          name: 'New Trip',
          visibility: Visibility.public,
        );
        mockTripCommandClient.mockTripId = 'trip-new';

        final result = await tripService.createTrip(request);

        expect(result, 'trip-new');
        expect(mockTripCommandClient.createTripCalled, true);
      });

      test('updateTrip updates existing trip', () async {
        final request = UpdateTripRequest(name: 'Updated Trip');
        mockTripCommandClient.mockTripId = 'trip-1';

        final result = await tripService.updateTrip('trip-1', request);

        expect(result, 'trip-1');
        expect(mockTripCommandClient.updateTripCalled, true);
        expect(mockTripCommandClient.lastTripId, 'trip-1');
      });

      test('changeVisibility changes trip visibility', () async {
        final request = ChangeVisibilityRequest(visibility: Visibility.private);
        mockTripCommandClient.mockTripId = 'trip-1';

        final result = await tripService.changeVisibility('trip-1', request);

        expect(result, 'trip-1');
        expect(mockTripCommandClient.changeVisibilityCalled, true);
      });

      test('changeStatus changes trip status', () async {
        final request = ChangeStatusRequest(status: TripStatus.created);
        mockTripCommandClient.mockTripId = 'trip-1';

        final result = await tripService.changeStatus('trip-1', request);

        expect(result, 'trip-1');
        expect(mockTripCommandClient.changeStatusCalled, true);
      });

      test('toggleDay toggles day state for multi-day trips', () async {
        mockTripCommandClient.mockTripId = 'trip-1';

        final result = await tripService.toggleDay('trip-1');

        expect(result, 'trip-1');
        expect(mockTripCommandClient.toggleDayCalled, true);
        expect(mockTripCommandClient.lastTripId, 'trip-1');
      });

      test('deleteTrip deletes trip', () async {
        mockTripCommandClient.mockTripId = 'trip-1';

        final result = await tripService.deleteTrip('trip-1');

        expect(result, 'trip-1');
        expect(mockTripCommandClient.deleteTripCalled, true);
        expect(mockTripCommandClient.lastDeleteTripId, 'trip-1');
      });

      test('createTripFromPlan creates trip from plan', () async {
        mockTripCommandClient.mockTripId = 'trip-from-plan';

        final request = TripFromPlanRequest(
          visibility: Visibility.public,
          tripModality: TripModality.simple,
        );
        final result = await tripService.createTripFromPlan(
          'plan-123',
          request,
        );

        expect(result, 'trip-from-plan');
        expect(mockTripCommandClient.createTripFromPlanCalled, true);
        expect(mockTripCommandClient.lastPlanId, 'plan-123');
      });

      test('sendTripUpdate sends update', () async {
        final request = TripUpdateRequest(
          latitude: 37.7749,
          longitude: -122.4194,
          message: 'Update message',
        );
        mockTripUpdateCommandClient.mockTripUpdateId = 'update-123';

        final result = await tripService.sendTripUpdate('trip-1', request);

        expect(result, 'update-123');
        expect(mockTripUpdateCommandClient.createTripUpdateCalled, true);
        expect(mockTripUpdateCommandClient.lastTripId, 'trip-1');
      });
    });

    group('Trip Plan Operations', () {
      test('createTripPlan creates new plan', () async {
        final request = CreateTripPlanRequest(name: 'Plan 1');
        mockTripPlanCommandClient.mockTripPlanId = 'plan-1';

        final result = await tripService.createTripPlan(request);

        expect(result, 'plan-1');
        expect(mockTripPlanCommandClient.createTripPlanCalled, true);
      });

      test('updateTripPlan updates existing plan', () async {
        final request = UpdateTripPlanRequest(name: 'Updated Plan');
        mockTripPlanCommandClient.mockTripPlanId = 'plan-1';

        final result = await tripService.updateTripPlan('plan-1', request);

        expect(result, 'plan-1');
        expect(mockTripPlanCommandClient.updateTripPlanCalled, true);
      });

      test('deleteTripPlan deletes plan', () async {
        mockTripPlanCommandClient.mockTripPlanId = 'plan-1';

        final result = await tripService.deleteTripPlan('plan-1');

        expect(result, 'plan-1');
        expect(mockTripPlanCommandClient.deleteTripPlanCalled, true);
        expect(mockTripPlanCommandClient.lastPlanId, 'plan-1');
      });
    });

    group('Error Handling', () {
      test('passes through query errors', () async {
        mockTripQueryClient.shouldThrowError = true;

        expect(() => tripService.getMyTrips(), throwsException);
      });

      test('passes through command errors', () async {
        mockTripCommandClient.shouldThrowError = true;
        final request = CreateTripRequest(
          name: 'Test',
          visibility: Visibility.public,
        );

        expect(() => tripService.createTrip(request), throwsException);
      });
    });
  });
}

// Helper functions
Trip createMockTrip(
  String id,
  String name, {
  Visibility visibility = Visibility.public,
  TripStatus status = TripStatus.created,
}) {
  return Trip(
    id: id,
    userId: 'user-1',
    name: name,
    username: 'testuser',
    visibility: visibility,
    status: status,
    commentsCount: 0,
    reactionsCount: 0,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
}

TripPlan createMockTripPlan(String id, String name) {
  return TripPlan(
    id: id,
    userId: 'user-1',
    name: name,
    planType: 'SIMPLE',
    createdTimestamp: DateTime.now(),
  );
}

// Mock TripQueryClient
class MockTripQueryClient extends TripQueryClient {
  List<Trip>? mockTrips;
  Trip? mockTrip;
  bool getCurrentUserTripsCalled = false;
  bool getTripByIdCalled = false;
  bool getAllTripsCalled = false;
  bool getPublicTripsCalled = false;
  bool getAvailableTripsCalled = false;
  bool getTripsByUserCalled = false;
  bool getTripUpdateLocationsCalled = false;
  String? lastTripId;
  String? lastUserId;
  bool shouldThrowError = false;

  PageResponse<Trip> _wrapInPage(List<Trip> trips) {
    return PageResponse(
      content: trips,
      totalElements: trips.length,
      totalPages: 1,
      number: 0,
      size: 20,
      first: true,
      last: true,
    );
  }

  @override
  Future<List<Trip>> getCurrentUserTrips() async {
    getCurrentUserTripsCalled = true;
    if (shouldThrowError) throw Exception('Failed to get user trips');
    return mockTrips ?? [];
  }

  @override
  Future<Trip> getTripById(String tripId) async {
    getTripByIdCalled = true;
    lastTripId = tripId;
    if (shouldThrowError) throw Exception('Failed to get trip');
    return mockTrip!;
  }

  @override
  Future<PageResponse<Trip>> getAllTrips({
    int page = 0,
    int size = 20,
    String sort = 'creationTimestamp,desc',
  }) async {
    getAllTripsCalled = true;
    if (shouldThrowError) throw Exception('Failed to get all trips');
    return _wrapInPage(mockTrips ?? []);
  }

  @override
  Future<PageResponse<Trip>> getPublicTrips({
    int page = 0,
    int size = 20,
    String sort = 'creationTimestamp,desc',
  }) async {
    getPublicTripsCalled = true;
    if (shouldThrowError) throw Exception('Failed to get public trips');
    return _wrapInPage(mockTrips ?? []);
  }

  @override
  Future<PageResponse<Trip>> getAvailableTrips({
    int page = 0,
    int size = 20,
    String sort = 'creationTimestamp,desc',
  }) async {
    getAvailableTripsCalled = true;
    if (shouldThrowError) throw Exception('Failed to get available trips');
    return _wrapInPage(mockTrips ?? []);
  }

  @override
  Future<List<Trip>> getTripsByUser(String userId) async {
    getTripsByUserCalled = true;
    lastUserId = userId;
    if (shouldThrowError) throw Exception('Failed to get user trips');
    return mockTrips ?? [];
  }

  @override
  Future<List<TripLocation>> getTripUpdateLocations(String tripId) async {
    getTripUpdateLocationsCalled = true;
    lastTripId = tripId;
    if (shouldThrowError) throw Exception('Failed to get locations');
    return [];
  }
}

// Mock TripCommandClient
class MockTripCommandClient extends TripCommandClient {
  String? mockTripId;
  bool createTripCalled = false;
  bool updateTripCalled = false;
  bool changeVisibilityCalled = false;
  bool changeStatusCalled = false;
  bool toggleDayCalled = false;
  bool deleteTripCalled = false;
  bool createTripFromPlanCalled = false;
  String? lastTripId;
  String? lastDeleteTripId;
  String? lastPlanId;
  bool shouldThrowError = false;

  @override
  Future<String> createTrip(CreateTripRequest request) async {
    createTripCalled = true;
    if (shouldThrowError) throw Exception('Failed to create trip');
    return mockTripId!;
  }

  @override
  Future<String> updateTrip(String tripId, UpdateTripRequest request) async {
    updateTripCalled = true;
    lastTripId = tripId;
    if (shouldThrowError) throw Exception('Failed to update trip');
    return mockTripId!;
  }

  @override
  Future<String> changeVisibility(
    String tripId,
    ChangeVisibilityRequest request,
  ) async {
    changeVisibilityCalled = true;
    lastTripId = tripId;
    if (shouldThrowError) throw Exception('Failed to change visibility');
    return mockTripId!;
  }

  @override
  Future<String> changeStatus(
      String tripId, ChangeStatusRequest request) async {
    changeStatusCalled = true;
    lastTripId = tripId;
    if (shouldThrowError) throw Exception('Failed to change status');
    return mockTripId!;
  }

  @override
  Future<String> toggleDay(String tripId) async {
    toggleDayCalled = true;
    lastTripId = tripId;
    if (shouldThrowError) throw Exception('Failed to toggle day');
    return mockTripId!;
  }

  @override
  Future<String> deleteTrip(String tripId) async {
    deleteTripCalled = true;
    lastDeleteTripId = tripId;
    if (shouldThrowError) throw Exception('Failed to delete trip');
    return mockTripId!;
  }

  @override
  Future<String> createTripFromPlan(
      String tripPlanId, TripFromPlanRequest request) async {
    createTripFromPlanCalled = true;
    lastPlanId = tripPlanId;
    if (shouldThrowError) throw Exception('Failed to create trip from plan');
    return mockTripId!;
  }
}

// Mock TripPlanCommandClient
class MockTripPlanCommandClient extends TripPlanCommandClient {
  String? mockTripPlanId;
  bool createTripPlanCalled = false;
  bool updateTripPlanCalled = false;
  bool deleteTripPlanCalled = false;
  String? lastPlanId;
  bool shouldThrowError = false;

  @override
  Future<String> createTripPlan(CreateTripPlanRequest request) async {
    createTripPlanCalled = true;
    if (shouldThrowError) throw Exception('Failed to create plan');
    return mockTripPlanId!;
  }

  @override
  Future<String> updateTripPlan(
    String planId,
    UpdateTripPlanRequest request,
  ) async {
    updateTripPlanCalled = true;
    lastPlanId = planId;
    if (shouldThrowError) throw Exception('Failed to update plan');
    return mockTripPlanId!;
  }

  @override
  Future<String> deleteTripPlan(String planId) async {
    deleteTripPlanCalled = true;
    lastPlanId = planId;
    if (shouldThrowError) throw Exception('Failed to delete plan');
    return mockTripPlanId!;
  }
}

// Mock TripUpdateCommandClient
class MockTripUpdateCommandClient extends TripUpdateCommandClient {
  String? mockTripUpdateId;
  bool createTripUpdateCalled = false;
  String? lastTripId;
  bool shouldThrowError = false;

  @override
  Future<String> createTripUpdate(
    String tripId,
    TripUpdateRequest request,
  ) async {
    createTripUpdateCalled = true;
    lastTripId = tripId;
    if (shouldThrowError) throw Exception('Failed to create update');
    return mockTripUpdateId!;
  }
}
