import 'package:flutter_test/flutter_test.dart';
import 'package:wanderer_frontend/core/constants/enums.dart';
import 'package:wanderer_frontend/data/models/responses/page_response.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/data/repositories/home_repository.dart';
import 'package:wanderer_frontend/data/services/auth_service.dart';
import 'package:wanderer_frontend/data/services/trip_service.dart';

void main() {
  group('HomeRepository', () {
    late MockTripService mockTripService;
    late MockAuthService mockAuthService;
    late HomeRepository homeRepository;

    setUp(() {
      mockTripService = MockTripService();
      mockAuthService = MockAuthService();
      homeRepository = HomeRepository(
        tripService: mockTripService,
        authService: mockAuthService,
      );
    });

    group('getCurrentUsername', () {
      test('returns username from auth service', () async {
        mockAuthService.mockUsername = 'testuser';

        final result = await homeRepository.getCurrentUsername();

        expect(result, 'testuser');
        expect(mockAuthService.getUsernameCalled, true);
      });

      test('returns null when no username', () async {
        mockAuthService.mockUsername = null;

        final result = await homeRepository.getCurrentUsername();

        expect(result, isNull);
      });
    });

    group('getCurrentUserId', () {
      test('returns user ID from auth service', () async {
        mockAuthService.mockUserId = 'user-123';

        final result = await homeRepository.getCurrentUserId();

        expect(result, 'user-123');
        expect(mockAuthService.getUserIdCalled, true);
      });

      test('returns null when no user ID', () async {
        mockAuthService.mockUserId = null;

        final result = await homeRepository.getCurrentUserId();

        expect(result, isNull);
      });
    });

    group('isLoggedIn', () {
      test('returns true when user is logged in', () async {
        mockAuthService.mockIsLoggedIn = true;

        final result = await homeRepository.isLoggedIn();

        expect(result, true);
        expect(mockAuthService.isLoggedInCalled, true);
      });

      test('returns false when user is not logged in', () async {
        mockAuthService.mockIsLoggedIn = false;

        final result = await homeRepository.isLoggedIn();

        expect(result, false);
      });
    });

    group('loadTrips', () {
      test('loads available trips when user is logged in', () async {
        mockAuthService.mockIsLoggedIn = true;
        mockAuthService.mockUserId = 'user-123';
        mockTripService.mockTrips = [
          createMockTrip('trip-1', 'My Trip'),
          createMockTrip('trip-2', 'Another Trip'),
        ];

        final result = await homeRepository.loadTrips();

        expect(result.content.length, 2);
        expect(result.content[0].id, 'trip-1');
        expect(result.content[1].id, 'trip-2');
        expect(mockTripService.getAvailableTripsCalled, true);
        expect(mockTripService.getPublicTripsCalled, false);
      });

      test('loads public trips when user is not logged in', () async {
        mockAuthService.mockIsLoggedIn = false;
        mockAuthService.mockUserId = null;
        mockTripService.mockTrips = [
          createMockTrip('trip-public', 'Public Trip'),
        ];

        final result = await homeRepository.loadTrips();

        expect(result.content.length, 1);
        expect(result.content[0].id, 'trip-public');
        expect(mockTripService.getPublicTripsCalled, true);
        expect(mockTripService.getAvailableTripsCalled, false);
      });

      test(
        'loads public trips when userId is null even if logged in flag is true',
        () async {
          mockAuthService.mockIsLoggedIn = true;
          mockAuthService.mockUserId = null; // No user ID
          mockTripService.mockTrips = [
            createMockTrip('trip-public', 'Public Trip'),
          ];

          await homeRepository.loadTrips();

          expect(mockTripService.getPublicTripsCalled, true);
          expect(mockTripService.getAvailableTripsCalled, false);
        },
      );

      test('returns empty page when no trips available', () async {
        mockAuthService.mockIsLoggedIn = true;
        mockAuthService.mockUserId = 'user-123';
        mockTripService.mockTrips = [];

        final result = await homeRepository.loadTrips();

        expect(result.content, isEmpty);
      });

      test('passes through service errors', () async {
        mockAuthService.mockIsLoggedIn = true;
        mockAuthService.mockUserId = 'user-123';
        mockTripService.shouldThrowError = true;

        expect(() => homeRepository.loadTrips(), throwsException);
      });
    });

    group('logout', () {
      test('calls auth service logout', () async {
        await homeRepository.logout();

        expect(mockAuthService.logoutCalled, true);
      });

      test('logout passes through service errors', () async {
        mockAuthService.shouldThrowError = true;

        expect(() => homeRepository.logout(), throwsException);
      });
    });

    group('HomeRepository initialization', () {
      test('creates with provided services', () {
        final tripService = MockTripService();
        final authService = MockAuthService();
        final repo = HomeRepository(
          tripService: tripService,
          authService: authService,
        );

        expect(repo, isNotNull);
      });

      test('creates with default services when not provided', () {
        final repo = HomeRepository();

        expect(repo, isNotNull);
      });
    });
  });
}

// Helper function to create mock trips
Trip createMockTrip(String id, String name) {
  return Trip(
    id: id,
    userId: 'user-123',
    name: name,
    username: 'testuser',
    visibility: Visibility.public,
    status: TripStatus.created,
    commentsCount: 0,
    reactionsCount: 0,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
}

// Mock TripService
class MockTripService extends TripService {
  List<Trip> mockTrips = [];
  bool getAvailableTripsCalled = false;
  bool getPublicTripsCalled = false;
  bool shouldThrowError = false;

  PageResponse<Trip> _wrapInPage(List<Trip> trips) {
    return PageResponse(
      content: trips,
      totalElements: trips.length,
      totalPages: trips.isEmpty ? 0 : 1,
      number: 0,
      size: 20,
      first: true,
      last: true,
    );
  }

  @override
  Future<PageResponse<Trip>> getAvailableTrips({
    int page = 0,
    int size = 20,
  }) async {
    getAvailableTripsCalled = true;

    if (shouldThrowError) {
      throw Exception('Failed to load available trips');
    }

    return _wrapInPage(mockTrips);
  }

  @override
  Future<PageResponse<Trip>> getPublicTrips({
    int page = 0,
    int size = 20,
  }) async {
    getPublicTripsCalled = true;

    if (shouldThrowError) {
      throw Exception('Failed to load public trips');
    }

    return _wrapInPage(mockTrips);
  }
}

// Mock AuthService
class MockAuthService extends AuthService {
  String? mockUsername;
  String? mockUserId;
  bool mockIsLoggedIn = false;
  bool getUsernameCalled = false;
  bool getUserIdCalled = false;
  bool isLoggedInCalled = false;
  bool logoutCalled = false;
  bool shouldThrowError = false;

  @override
  Future<String?> getCurrentUsername() async {
    getUsernameCalled = true;
    return mockUsername;
  }

  @override
  Future<String?> getCurrentUserId() async {
    getUserIdCalled = true;
    return mockUserId;
  }

  @override
  Future<bool> isLoggedIn() async {
    isLoggedInCalled = true;
    return mockIsLoggedIn;
  }

  @override
  Future<void> logout() async {
    logoutCalled = true;

    if (shouldThrowError) {
      throw Exception('Logout failed');
    }
  }
}
