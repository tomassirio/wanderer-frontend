import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:wanderer_frontend/core/constants/api_endpoints.dart';
import 'package:wanderer_frontend/data/client/api_client.dart';
import 'package:wanderer_frontend/data/client/command/notification_command_client.dart';
import 'package:wanderer_frontend/data/storage/token_storage.dart';

void main() {
  group('NotificationCommandClient', () {
    late MockHttpClient mockHttpClient;
    late MockTokenStorage mockTokenStorage;
    late ApiClient apiClient;
    late NotificationCommandClient notificationCommandClient;

    setUp(() {
      mockHttpClient = MockHttpClient();
      mockTokenStorage = MockTokenStorage();
      mockTokenStorage.accessToken = 'test-token';
      mockTokenStorage.tokenType = 'Bearer';
      apiClient = ApiClient(
        baseUrl: ApiEndpoints.commandBaseUrl,
        httpClient: mockHttpClient,
        tokenStorage: mockTokenStorage,
      );
      notificationCommandClient =
          NotificationCommandClient(apiClient: apiClient);
    });

    group('markAsRead', () {
      test('marks a notification as read successfully', () async {
        mockHttpClient.response = http.Response('', 202);

        await notificationCommandClient.markAsRead('notif-123');

        expect(mockHttpClient.lastMethod, 'PATCH');
        expect(
          mockHttpClient.lastUri?.path,
          endsWith('/notifications/notif-123/read'),
        );
        expect(
          mockHttpClient.lastHeaders?['Authorization'],
          'Bearer test-token',
        );
      });

      test('markAsRead requires authentication', () async {
        mockHttpClient.response = http.Response('', 202);

        await notificationCommandClient.markAsRead('notif-123');

        expect(mockHttpClient.lastHeaders?['Authorization'], isNotNull);
      });

      test('markAsRead throws exception on not found', () async {
        mockHttpClient.response = http.Response(
          '{"message":"Notification not found"}',
          404,
        );

        expect(
          () => notificationCommandClient.markAsRead('notif-invalid'),
          throwsException,
        );
      });

      test('markAsRead throws exception on forbidden', () async {
        mockHttpClient.response = http.Response(
          '{"message":"Access denied"}',
          403,
        );

        expect(
          () => notificationCommandClient.markAsRead('notif-123'),
          throwsException,
        );
      });
    });

    group('markAllAsRead', () {
      test('marks all notifications as read and returns count', () async {
        mockHttpClient.response = http.Response('12', 202);

        final result = await notificationCommandClient.markAllAsRead();

        expect(result, 12);
        expect(mockHttpClient.lastMethod, 'PATCH');
        expect(
          mockHttpClient.lastUri?.path,
          endsWith('/notifications/me/read-all'),
        );
        expect(
          mockHttpClient.lastHeaders?['Authorization'],
          'Bearer test-token',
        );
      });

      test('markAllAsRead returns zero when no unread', () async {
        mockHttpClient.response = http.Response('0', 202);

        final result = await notificationCommandClient.markAllAsRead();

        expect(result, 0);
      });

      test('markAllAsRead requires authentication', () async {
        mockHttpClient.response = http.Response('0', 202);

        await notificationCommandClient.markAllAsRead();

        expect(mockHttpClient.lastHeaders?['Authorization'], isNotNull);
      });

      test('markAllAsRead throws exception on error', () async {
        mockHttpClient.response = http.Response(
          '{"message":"Unauthorized"}',
          401,
        );

        expect(
          () => notificationCommandClient.markAllAsRead(),
          throwsException,
        );
      });
    });

    group('NotificationCommandClient initialization', () {
      test('uses provided ApiClient', () {
        final customApiClient = ApiClient(
          baseUrl: 'http://custom-url',
          httpClient: mockHttpClient,
          tokenStorage: mockTokenStorage,
        );
        final client = NotificationCommandClient(apiClient: customApiClient);

        expect(client, isNotNull);
      });

      test(
        'creates default ApiClient with command base URL when not provided',
        () {
          final client = NotificationCommandClient();

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
