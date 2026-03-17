import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:wanderer_frontend/core/constants/api_endpoints.dart';
import 'package:wanderer_frontend/data/client/api_client.dart';
import 'package:wanderer_frontend/data/client/query/trip_query_client.dart';
import 'package:wanderer_frontend/data/storage/token_storage.dart';

void main() {
  group('TripQueryClient', () {
    late MockHttpClient mockHttpClient;
    late MockTokenStorage mockTokenStorage;
    late ApiClient apiClient;
    late TripQueryClient tripQueryClient;

    setUp(() {
      mockHttpClient = MockHttpClient();
      mockTokenStorage = MockTokenStorage();
      mockTokenStorage.accessToken = 'test-token';
      mockTokenStorage.tokenType = 'Bearer';
      apiClient = ApiClient(
        baseUrl: ApiEndpoints.queryBaseUrl,
        httpClient: mockHttpClient,
        tokenStorage: mockTokenStorage,
      );
      tripQueryClient = TripQueryClient(apiClient: apiClient);
    });

    group('getTripById', () {
      test('successful retrieval returns Trip', () async {
        final responseBody = {
          'id': 'trip-123',
          'userId': 'user-123',
          'username': 'testuser',
          'name': 'My Trip',
          'description': 'A great adventure',
          'visibility': 'PUBLIC',
          'status': 'IN_PROGRESS',
          'commentsCount': 5,
          'reactionsCount': 10,
          'createdAt': DateTime.now().toIso8601String(),
          'updatedAt': DateTime.now().toIso8601String(),
        };
        mockHttpClient.response = http.Response(jsonEncode(responseBody), 200);

        final result = await tripQueryClient.getTripById('trip-123');

        expect(result.id, 'trip-123');
        expect(result.name, 'My Trip');
        expect(mockHttpClient.lastMethod, 'GET');
        expect(
          mockHttpClient.lastUri?.path,
          endsWith(ApiEndpoints.tripById('trip-123')),
        );
        expect(
          mockHttpClient.lastHeaders?['Authorization'],
          'Bearer test-token',
        );
      });

      test('getTripById requires authentication', () async {
        final responseBody = {
          'id': 'trip-123',
          'userId': 'user-123',
          'username': 'testuser',
          'name': 'My Trip',
          'visibility': 'PRIVATE',
          'status': 'CREATED',
          'commentsCount': 0,
          'reactionsCount': 0,
          'createdAt': DateTime.now().toIso8601String(),
          'updatedAt': DateTime.now().toIso8601String(),
        };
        mockHttpClient.response = http.Response(jsonEncode(responseBody), 200);

        await tripQueryClient.getTripById('trip-123');

        expect(mockHttpClient.lastHeaders?['Authorization'], isNotNull);
      });

      test('getTripById throws exception on not found', () async {
        mockHttpClient.response = http.Response(
          '{"message":"Trip not found"}',
          404,
        );

        expect(
          () => tripQueryClient.getTripById('trip-invalid'),
          throwsException,
        );
      });

      test('getTripById throws exception on unauthorized', () async {
        mockHttpClient.response = http.Response(
          '{"message":"Not authorized to view this trip"}',
          403,
        );

        expect(() => tripQueryClient.getTripById('trip-123'), throwsException);
      });
    });

    group('getAllTrips', () {
      test('successful retrieval returns paginated trips', () async {
        final trips = [
          {
            'id': 'trip-1',
            'userId': 'user-1',
            'username': 'user1',
            'name': 'Trip 1',
            'visibility': 'PUBLIC',
            'status': 'CREATED',
            'commentsCount': 0,
            'reactionsCount': 0,
            'createdAt': DateTime.now().toIso8601String(),
            'updatedAt': DateTime.now().toIso8601String(),
          },
          {
            'id': 'trip-2',
            'userId': 'user-2',
            'username': 'user2',
            'name': 'Trip 2',
            'visibility': 'PRIVATE',
            'status': 'IN_PROGRESS',
            'commentsCount': 3,
            'reactionsCount': 5,
            'createdAt': DateTime.now().toIso8601String(),
            'updatedAt': DateTime.now().toIso8601String(),
          },
        ];
        final responseBody = _wrapInPage(trips);
        mockHttpClient.response = http.Response(jsonEncode(responseBody), 200);

        final result = await tripQueryClient.getAllTrips();

        expect(result.content.length, 2);
        expect(result.content[0].id, 'trip-1');
        expect(result.content[1].id, 'trip-2');
        expect(result.totalElements, 2);
        expect(result.first, true);
        expect(result.last, true);
        expect(mockHttpClient.lastMethod, 'GET');
        expect(mockHttpClient.lastUri?.path, endsWith(ApiEndpoints.trips));
        expect(
          mockHttpClient.lastHeaders?['Authorization'],
          'Bearer test-token',
        );
      });

      test('getAllTrips sends pagination query params', () async {
        mockHttpClient.response =
            http.Response(jsonEncode(_wrapInPage([])), 200);

        await tripQueryClient.getAllTrips(page: 2, size: 10);

        final uri = mockHttpClient.lastUri!;
        expect(uri.queryParameters['page'], '2');
        expect(uri.queryParameters['size'], '10');
      });

      test('getAllTrips requires authentication (ADMIN)', () async {
        mockHttpClient.response =
            http.Response(jsonEncode(_wrapInPage([])), 200);

        await tripQueryClient.getAllTrips();

        expect(mockHttpClient.lastHeaders?['Authorization'], isNotNull);
      });

      test('getAllTrips throws exception on unauthorized', () async {
        mockHttpClient.response = http.Response(
          '{"message":"Admin access required"}',
          403,
        );

        expect(() => tripQueryClient.getAllTrips(), throwsException);
      });
    });

    group('getCurrentUserTrips', () {
      test('successful retrieval returns user trips', () async {
        final responseBody = [
          {
            'id': 'trip-1',
            'userId': 'user-123',
            'username': 'testuser',
            'name': 'My Trip 1',
            'visibility': 'PRIVATE',
            'status': 'CREATED',
            'commentsCount': 0,
            'reactionsCount': 0,
            'createdAt': DateTime.now().toIso8601String(),
            'updatedAt': DateTime.now().toIso8601String(),
          },
          {
            'id': 'trip-2',
            'userId': 'user-123',
            'username': 'testuser',
            'name': 'My Trip 2',
            'visibility': 'PUBLIC',
            'status': 'FINISHED',
            'commentsCount': 10,
            'reactionsCount': 20,
            'createdAt': DateTime.now().toIso8601String(),
            'updatedAt': DateTime.now().toIso8601String(),
          },
        ];
        mockHttpClient.response = http.Response(jsonEncode(responseBody), 200);

        final result = await tripQueryClient.getCurrentUserTrips();

        expect(result.length, 2);
        expect(result[0].userId, 'user-123');
        expect(result[1].userId, 'user-123');
        expect(mockHttpClient.lastMethod, 'GET');
        expect(mockHttpClient.lastUri?.path, endsWith(ApiEndpoints.tripsMe));
        expect(
          mockHttpClient.lastHeaders?['Authorization'],
          'Bearer test-token',
        );
      });

      test('getCurrentUserTrips requires authentication', () async {
        mockHttpClient.response = http.Response(jsonEncode([]), 200);

        await tripQueryClient.getCurrentUserTrips();

        expect(mockHttpClient.lastHeaders?['Authorization'], isNotNull);
      });

      test(
        'getCurrentUserTrips returns empty list when user has no trips',
        () async {
          mockHttpClient.response = http.Response(jsonEncode([]), 200);

          final result = await tripQueryClient.getCurrentUserTrips();

          expect(result, isEmpty);
        },
      );
    });

    group('getPublicTrips', () {
      test('successful retrieval returns paginated public trips', () async {
        final trips = [
          {
            'id': 'trip-1',
            'userId': 'user-1',
            'username': 'user1',
            'name': 'Public Trip 1',
            'visibility': 'PUBLIC',
            'status': 'IN_PROGRESS',
            'commentsCount': 5,
            'reactionsCount': 15,
            'createdAt': DateTime.now().toIso8601String(),
            'updatedAt': DateTime.now().toIso8601String(),
          },
        ];
        mockHttpClient.response =
            http.Response(jsonEncode(_wrapInPage(trips)), 200);

        final result = await tripQueryClient.getPublicTrips();

        expect(result.content.length, 1);
        expect(result.content[0].name, 'Public Trip 1');
        expect(mockHttpClient.lastMethod, 'GET');
        expect(
          mockHttpClient.lastUri?.path,
          endsWith(ApiEndpoints.tripsPublic),
        );
      });

      test('getPublicTrips does not require authentication', () async {
        mockTokenStorage.accessToken = null;
        mockTokenStorage.tokenType = null;
        mockHttpClient.response =
            http.Response(jsonEncode(_wrapInPage([])), 200);

        await tripQueryClient.getPublicTrips();

        expect(mockHttpClient.lastHeaders?['Authorization'], isNull);
      });

      test('getPublicTrips returns empty page when no public trips', () async {
        mockHttpClient.response =
            http.Response(jsonEncode(_wrapInPage([])), 200);

        final result = await tripQueryClient.getPublicTrips();

        expect(result.content, isEmpty);
        expect(result.totalElements, 0);
      });
    });

    group('getAvailableTrips', () {
      test('successful retrieval returns paginated available trips', () async {
        final trips = [
          {
            'id': 'trip-1',
            'userId': 'user-1',
            'username': 'user1',
            'name': 'Available Trip',
            'visibility': 'PROTECTED',
            'status': 'CREATED',
            'commentsCount': 0,
            'reactionsCount': 0,
            'createdAt': DateTime.now().toIso8601String(),
            'updatedAt': DateTime.now().toIso8601String(),
          },
        ];
        mockHttpClient.response =
            http.Response(jsonEncode(_wrapInPage(trips)), 200);

        final result = await tripQueryClient.getAvailableTrips();

        expect(result.content.length, 1);
        expect(result.content[0].name, 'Available Trip');
        expect(mockHttpClient.lastMethod, 'GET');
        expect(
          mockHttpClient.lastUri?.path,
          endsWith(ApiEndpoints.tripsAvailable),
        );
        expect(
          mockHttpClient.lastHeaders?['Authorization'],
          'Bearer test-token',
        );
      });

      test('getAvailableTrips requires authentication', () async {
        mockHttpClient.response =
            http.Response(jsonEncode(_wrapInPage([])), 200);

        await tripQueryClient.getAvailableTrips();

        expect(mockHttpClient.lastHeaders?['Authorization'], isNotNull);
      });
    });

    group('getTripsByUser', () {
      test('successful retrieval returns user trips', () async {
        final responseBody = [
          {
            'id': 'trip-1',
            'userId': 'user-456',
            'username': 'otheruser',
            'name': 'Other User Trip',
            'visibility': 'PUBLIC',
            'status': 'FINISHED',
            'commentsCount': 8,
            'reactionsCount': 12,
            'createdAt': DateTime.now().toIso8601String(),
            'updatedAt': DateTime.now().toIso8601String(),
          },
        ];
        mockHttpClient.response = http.Response(jsonEncode(responseBody), 200);

        final result = await tripQueryClient.getTripsByUser('user-456');

        expect(result.length, 1);
        expect(result[0].userId, 'user-456');
        expect(result[0].username, 'otheruser');
        expect(mockHttpClient.lastMethod, 'GET');
        expect(
          mockHttpClient.lastUri?.path,
          endsWith(ApiEndpoints.tripsByUser('user-456')),
        );
        expect(
          mockHttpClient.lastHeaders?['Authorization'],
          'Bearer test-token',
        );
      });

      test('getTripsByUser requires authentication', () async {
        mockHttpClient.response = http.Response(jsonEncode([]), 200);

        await tripQueryClient.getTripsByUser('user-456');

        expect(mockHttpClient.lastHeaders?['Authorization'], isNotNull);
      });

      test('getTripsByUser throws exception on user not found', () async {
        mockHttpClient.response = http.Response(
          '{"message":"User not found"}',
          404,
        );

        expect(
          () => tripQueryClient.getTripsByUser('user-invalid'),
          throwsException,
        );
      });

      test(
        'getTripsByUser returns empty list when user has no trips',
        () async {
          mockHttpClient.response = http.Response(jsonEncode([]), 200);

          final result = await tripQueryClient.getTripsByUser('user-456');

          expect(result, isEmpty);
        },
      );
    });

    group('TripQueryClient initialization', () {
      test('uses provided ApiClient', () {
        final customApiClient = ApiClient(
          baseUrl: 'http://custom-url',
          httpClient: mockHttpClient,
          tokenStorage: mockTokenStorage,
        );
        final client = TripQueryClient(apiClient: customApiClient);

        expect(client, isNotNull);
      });

      test(
        'creates default ApiClient with query base URL when not provided',
        () {
          final client = TripQueryClient();

          expect(client, isNotNull);
        },
      );
    });

    group('getTripUpdateLocations', () {
      test('successful retrieval returns list of locations', () async {
        final responseBody = [
          {
            'id': 'update-1',
            'lat': 42.8805,
            'lon': -8.5449,
            'timestamp': '2026-03-15T10:46:00Z',
            'updateType': 'REGULAR',
            'battery': 71,
            'city': 'Utrecht',
            'country': 'Netherlands',
            'temperatureCelsius': 8.7,
            'weatherCondition': 'CLEAR',
          },
          {
            'id': 'update-2',
            'lat': 43.0,
            'lon': -8.6,
            'timestamp': '2026-03-15T12:00:00Z',
            'updateType': 'MANUAL',
            'battery': 55,
            'city': 'Amsterdam',
            'country': 'Netherlands',
          },
        ];
        mockHttpClient.response = http.Response(jsonEncode(responseBody), 200);

        final result = await tripQueryClient.getTripUpdateLocations('trip-123');

        expect(result.length, 2);
        expect(result[0].id, 'update-1');
        expect(result[0].latitude, 42.8805);
        expect(result[0].longitude, -8.5449);
        expect(result[0].city, 'Utrecht');
        expect(result[0].battery, 71);
        expect(result[1].id, 'update-2');
        expect(mockHttpClient.lastMethod, 'GET');
        expect(
          mockHttpClient.lastUri?.path,
          endsWith(ApiEndpoints.tripUpdateLocations('trip-123')),
        );
      });

      test('getTripUpdateLocations requires authentication', () async {
        mockHttpClient.response = http.Response(jsonEncode([]), 200);

        await tripQueryClient.getTripUpdateLocations('trip-123');

        expect(mockHttpClient.lastHeaders?['Authorization'], isNotNull);
      });

      test('getTripUpdateLocations returns empty list when no updates',
          () async {
        mockHttpClient.response = http.Response(jsonEncode([]), 200);

        final result = await tripQueryClient.getTripUpdateLocations('trip-123');

        expect(result, isEmpty);
      });
    });
  });
}

/// Helper to wrap a list of items in a Spring Boot `Page<T>` JSON structure
Map<String, dynamic> _wrapInPage(List<dynamic> content) {
  return {
    'content': content,
    'totalElements': content.length,
    'totalPages': content.isEmpty ? 0 : 1,
    'number': 0,
    'size': 20,
    'first': true,
    'last': true,
    'empty': content.isEmpty,
  };
}

// Mock HTTP Client
class MockHttpClient extends http.BaseClient {
  http.Response? response;
  String? lastMethod;
  Uri? lastUri;
  Map<String, String>? lastHeaders;
  String? lastBody;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    lastMethod = request.method;
    lastUri = request.url;
    lastHeaders = request.headers;

    if (request is http.Request) {
      lastBody = request.body;
    }

    final resp = response ?? http.Response('', 200);
    return http.StreamedResponse(
      Stream.value(resp.bodyBytes),
      resp.statusCode,
      headers: resp.headers,
      request: request,
    );
  }
}

// Mock Token Storage
class MockTokenStorage extends TokenStorage {
  String? accessToken;
  String? refreshToken;
  String? tokenType;
  bool _isLoggedIn = false;
  bool _isExpired = false;

  @override
  Future<String?> getAccessToken() async => accessToken;

  @override
  Future<String?> getRefreshToken() async => refreshToken;

  @override
  Future<String?> getTokenType() async => tokenType;

  @override
  Future<bool> isLoggedIn() async => _isLoggedIn;

  @override
  Future<bool> isAccessTokenExpired() async => _isExpired;

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    required String tokenType,
    required int expiresIn,
    String? userId,
    String? username,
    String? displayName,
  }) async {
    this.accessToken = accessToken;
    this.refreshToken = refreshToken;
    this.tokenType = tokenType;
    _isLoggedIn = true;
    _isExpired = false;
  }

  @override
  Future<void> clearTokens() async {
    accessToken = null;
    refreshToken = null;
    tokenType = null;
    _isLoggedIn = false;
    _isExpired = true;
  }
}
