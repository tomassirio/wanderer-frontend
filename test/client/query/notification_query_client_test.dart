import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:wanderer_frontend/core/constants/api_endpoints.dart';
import 'package:wanderer_frontend/data/client/api_client.dart';
import 'package:wanderer_frontend/data/client/query/notification_query_client.dart';
import 'package:wanderer_frontend/data/storage/token_storage.dart';

void main() {
  group('NotificationQueryClient', () {
    late MockHttpClient mockHttpClient;
    late MockTokenStorage mockTokenStorage;
    late ApiClient apiClient;
    late NotificationQueryClient notificationQueryClient;

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
      notificationQueryClient = NotificationQueryClient(apiClient: apiClient);
    });

    group('getMyNotifications', () {
      test('returns paginated notifications', () async {
        final responseBody = {
          'content': [
            {
              'id': 'notif-1',
              'recipientId': 'user-1',
              'actorId': 'user-2',
              'type': 'FRIEND_REQUEST_RECEIVED',
              'referenceId': 'req-1',
              'message': 'alice sent you a friend request',
              'read': false,
              'createdAt': '2026-03-14T10:30:00Z',
            },
            {
              'id': 'notif-2',
              'recipientId': 'user-1',
              'actorId': null,
              'type': 'ACHIEVEMENT_UNLOCKED',
              'referenceId': 'ach-1',
              'message': 'You unlocked "First Century"!',
              'read': true,
              'createdAt': '2026-03-13T15:00:00Z',
            },
          ],
          'totalElements': 42,
          'totalPages': 3,
          'number': 0,
          'size': 20,
          'first': true,
          'last': false,
        };
        mockHttpClient.response = http.Response(
          jsonEncode(responseBody),
          200,
        );

        final result = await notificationQueryClient.getMyNotifications();

        expect(result.content.length, 2);
        expect(result.content[0].id, 'notif-1');
        expect(result.content[0].message, 'alice sent you a friend request');
        expect(result.content[0].read, false);
        expect(result.content[1].actorId, isNull);
        expect(result.totalElements, 42);
        expect(result.totalPages, 3);
        expect(result.first, true);
        expect(result.last, false);
        expect(mockHttpClient.lastMethod, 'GET');
        expect(
          mockHttpClient.lastUri.toString(),
          contains('/notifications/me'),
        );
        expect(
          mockHttpClient.lastHeaders?['Authorization'],
          'Bearer test-token',
        );
      });

      test('passes pagination parameters', () async {
        mockHttpClient.response = http.Response(
          jsonEncode({
            'content': [],
            'totalElements': 0,
            'totalPages': 0,
            'number': 1,
            'size': 10,
            'first': false,
            'last': true,
          }),
          200,
        );

        await notificationQueryClient.getMyNotifications(
          page: 1,
          size: 10,
        );

        expect(mockHttpClient.lastUri.toString(), contains('page=1'));
        expect(mockHttpClient.lastUri.toString(), contains('size=10'));
      });

      test('returns empty page when no notifications', () async {
        mockHttpClient.response = http.Response(
          jsonEncode({
            'content': [],
            'totalElements': 0,
            'totalPages': 0,
            'number': 0,
            'size': 20,
            'first': true,
            'last': true,
          }),
          200,
        );

        final result = await notificationQueryClient.getMyNotifications();

        expect(result.content, isEmpty);
        expect(result.totalElements, 0);
      });

      test('throws exception on error response', () async {
        mockHttpClient.response = http.Response(
          '{"message":"Unauthorized"}',
          401,
        );

        expect(
          () => notificationQueryClient.getMyNotifications(),
          throwsException,
        );
      });
    });

    group('getUnreadCount', () {
      test('returns unread count', () async {
        mockHttpClient.response = http.Response('7', 200);

        final result = await notificationQueryClient.getUnreadCount();

        expect(result, 7);
        expect(mockHttpClient.lastMethod, 'GET');
        expect(
          mockHttpClient.lastUri.toString(),
          contains('/notifications/me/unread-count'),
        );
        expect(
          mockHttpClient.lastHeaders?['Authorization'],
          'Bearer test-token',
        );
      });

      test('returns zero for no unread notifications', () async {
        mockHttpClient.response = http.Response('0', 200);

        final result = await notificationQueryClient.getUnreadCount();

        expect(result, 0);
      });

      test('returns zero for non-numeric response', () async {
        mockHttpClient.response = http.Response('', 200);

        final result = await notificationQueryClient.getUnreadCount();

        expect(result, 0);
      });

      test('throws exception on error response', () async {
        mockHttpClient.response = http.Response(
          '{"message":"Unauthorized"}',
          401,
        );

        expect(
          () => notificationQueryClient.getUnreadCount(),
          throwsException,
        );
      });
    });

    group('NotificationQueryClient initialization', () {
      test('uses provided ApiClient', () {
        final customApiClient = ApiClient(
          baseUrl: 'http://custom-url',
          httpClient: mockHttpClient,
          tokenStorage: mockTokenStorage,
        );
        final client = NotificationQueryClient(apiClient: customApiClient);

        expect(client, isNotNull);
      });

      test(
        'creates default ApiClient with query base URL when not provided',
        () {
          final client = NotificationQueryClient();

          expect(client, isNotNull);
        },
      );
    });
  });
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
