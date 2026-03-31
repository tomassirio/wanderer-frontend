import 'package:flutter_test/flutter_test.dart';
import 'package:wanderer_frontend/core/constants/enums.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/data/models/responses/page_response.dart';
import 'package:wanderer_frontend/data/models/user_models.dart';
import 'package:wanderer_frontend/data/repositories/profile_repository.dart';
import 'package:wanderer_frontend/data/services/user_service.dart';
import 'package:wanderer_frontend/data/services/trip_service.dart';
import 'package:wanderer_frontend/data/services/auth_service.dart';

void main() {
  group('ProfileRepository', () {
    late MockUserService mockUserService;
    late MockTripService mockTripService;
    late MockAuthService mockAuthService;
    late ProfileRepository profileRepository;

    setUp(() {
      mockUserService = MockUserService();
      mockTripService = MockTripService();
      mockAuthService = MockAuthService();
      profileRepository = ProfileRepository(
        userService: mockUserService,
        tripService: mockTripService,
        authService: mockAuthService,
      );
    });

    group('getMyProfile', () {
      test('returns user profile from user service', () async {
        mockUserService.mockProfile = createMockProfile('user-1', 'testuser');

        final result = await profileRepository.getMyProfile();

        expect(result.id, 'user-1');
        expect(result.username, 'testuser');
        expect(mockUserService.getMyProfileCalled, true);
      });

      test('passes through service errors', () async {
        mockUserService.shouldThrowError = true;

        expect(() => profileRepository.getMyProfile(), throwsException);
      });
    });

    group('updateProfile', () {
      test('updates profile successfully', () async {
        final request = UpdateProfileRequest(
          displayName: 'New Name',
          bio: 'New bio',
        );
        mockUserService.mockProfile = createMockProfile('user-1', 'testuser');

        final result = await profileRepository.updateProfile(request);

        expect(result, 'user-1');
        expect(mockUserService.updateProfileCalled, true);
      });

      test('passes through service errors', () async {
        final request = UpdateProfileRequest(displayName: 'New Name');
        mockUserService.shouldThrowError = true;

        expect(() => profileRepository.updateProfile(request), throwsException);
      });
    });

    group('getMyTrips', () {
      test('returns all trips for the current user', () async {
        mockTripService.mockTrips = [
          createMockTrip('trip-1', 'Trip 1'),
          createMockTrip('trip-2', 'Trip 2'),
        ];

        final result = await profileRepository.getMyTrips();

        expect(result.content.length, 2);
        expect(result.content[0].id, 'trip-1');
        expect(result.content[1].id, 'trip-2');
        expect(mockTripService.getMyTripsCalled, true);
        expect(mockTripService.getUserTripsCalled, false);
      });

      test('returns empty list when no trips', () async {
        mockTripService.mockTrips = [];

        final result = await profileRepository.getMyTrips();

        expect(result.content, isEmpty);
      });

      test('passes through service errors', () async {
        mockTripService.shouldThrowError = true;

        expect(
          () => profileRepository.getMyTrips(),
          throwsException,
        );
      });
    });

    group('getUserTrips', () {
      test('returns trips for the specified user', () async {
        mockTripService.mockTrips = [
          createMockTrip('trip-1', 'Trip 1'),
          createMockTrip('trip-2', 'Trip 2'),
        ];

        final result = await profileRepository.getUserTrips('user-123');

        expect(result.content.length, 2);
        expect(result.content[0].id, 'trip-1');
        expect(result.content[1].id, 'trip-2');
        // Verify it called getUserTrips(userId), not getMyTrips
        expect(mockTripService.getUserTripsCalled, true);
        expect(mockTripService.getMyTripsCalled, false);
      });

      test('returns empty list when no trips', () async {
        mockTripService.mockTrips = [];

        final result = await profileRepository.getUserTrips('user-123');

        expect(result.content, isEmpty);
      });

      test('passes through service errors', () async {
        mockTripService.shouldThrowError = true;

        expect(
          () => profileRepository.getUserTrips('user-123'),
          throwsException,
        );
      });
    });

    group('isLoggedIn', () {
      test('returns true when user is logged in', () async {
        mockAuthService.mockIsLoggedIn = true;

        final result = await profileRepository.isLoggedIn();

        expect(result, true);
        expect(mockAuthService.isLoggedInCalled, true);
      });

      test('returns false when user is not logged in', () async {
        mockAuthService.mockIsLoggedIn = false;

        final result = await profileRepository.isLoggedIn();

        expect(result, false);
      });
    });

    group('getCurrentUsername', () {
      test('returns username from auth service', () async {
        mockAuthService.mockUsername = 'testuser';

        final result = await profileRepository.getCurrentUsername();

        expect(result, 'testuser');
        expect(mockAuthService.getUsernameCalled, true);
      });

      test('returns null when no username', () async {
        mockAuthService.mockUsername = null;

        final result = await profileRepository.getCurrentUsername();

        expect(result, isNull);
      });
    });

    group('getCurrentUserId', () {
      test('returns user ID from auth service', () async {
        mockAuthService.mockUserId = 'user-123';

        final result = await profileRepository.getCurrentUserId();

        expect(result, 'user-123');
        expect(mockAuthService.getUserIdCalled, true);
      });

      test('returns null when no user ID', () async {
        mockAuthService.mockUserId = null;

        final result = await profileRepository.getCurrentUserId();

        expect(result, isNull);
      });
    });

    group('logout', () {
      test('calls auth service logout', () async {
        await profileRepository.logout();

        expect(mockAuthService.logoutCalled, true);
      });

      test('logout passes through service errors', () async {
        mockAuthService.shouldThrowError = true;

        expect(() => profileRepository.logout(), throwsException);
      });
    });

    group('ProfileRepository initialization', () {
      test('creates with provided services', () {
        final userService = MockUserService();
        final tripService = MockTripService();
        final authService = MockAuthService();
        final repo = ProfileRepository(
          userService: userService,
          tripService: tripService,
          authService: authService,
        );

        expect(repo, isNotNull);
      });

      test('creates with default services when not provided', () {
        final repo = ProfileRepository();

        expect(repo, isNotNull);
      });
    });
  });
}

// Helper function to create mock user profiles
UserProfile createMockProfile(String id, String username) {
  return UserProfile(
    id: id,
    username: username,
    email: '$username@example.com',
    displayName: username,
    bio: 'Test bio',
    followersCount: 10,
    followingCount: 5,
    tripsCount: 3,
    isFollowing: false,
    createdAt: DateTime.now(),
  );
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

// Mock UserService
class MockUserService extends UserService {
  UserProfile? mockProfile;
  bool getMyProfileCalled = false;
  bool updateProfileCalled = false;
  bool shouldThrowError = false;

  @override
  Future<UserProfile> getMyProfile() async {
    getMyProfileCalled = true;

    if (shouldThrowError) {
      throw Exception('Failed to get profile');
    }

    return mockProfile!;
  }

  @override
  Future<String> updateProfile(UpdateProfileRequest request) async {
    updateProfileCalled = true;

    if (shouldThrowError) {
      throw Exception('Failed to update profile');
    }

    return mockProfile!.id;
  }
}

// Mock TripService
class MockTripService extends TripService {
  List<Trip> mockTrips = [];
  bool getUserTripsCalled = false;
  bool getMyTripsCalled = false;
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
  Future<PageResponse<Trip>> getUserTrips(
    String userId, {
    int page = 0,
    int size = 20,
  }) async {
    getUserTripsCalled = true;

    if (shouldThrowError) {
      throw Exception('Failed to load trips');
    }

    return _wrapInPage(mockTrips);
  }

  @override
  Future<PageResponse<Trip>> getMyTrips({
    int page = 0,
    int size = 20,
  }) async {
    getMyTripsCalled = true;

    if (shouldThrowError) {
      throw Exception('Failed to load trips');
    }
    return _wrapInPage(mockTrips);
  }

  @override
  Future<Trip> getTripById(String tripId) async {
    if (shouldThrowError) {
      throw Exception('Failed to get trip');
    }
    return mockTrips.first;
  }

  @override
  Future<String> createTrip(CreateTripRequest request) async {
    if (shouldThrowError) {
      throw Exception('Failed to create trip');
    }
    return 'trip-123';
  }

  @override
  Future<String> updateTrip(String tripId, UpdateTripRequest request) async {
    if (shouldThrowError) {
      throw Exception('Failed to update trip');
    }
    return tripId;
  }

  @override
  Future<String> deleteTrip(String tripId) async {
    if (shouldThrowError) {
      throw Exception('Failed to delete trip');
    }
    return tripId;
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
