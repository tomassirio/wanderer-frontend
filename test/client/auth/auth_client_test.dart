import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:wanderer_frontend/core/constants/api_endpoints.dart';
import 'package:wanderer_frontend/data/client/api_client.dart';
import 'package:wanderer_frontend/data/client/auth/auth_client.dart';
import 'package:wanderer_frontend/data/models/auth_models.dart';
import 'package:wanderer_frontend/data/storage/token_storage.dart';

void main() {
  group('AuthClient', () {
    late MockHttpClient mockHttpClient;
    late MockTokenStorage mockTokenStorage;
    late ApiClient apiClient;
    late AuthClient authClient;

    setUp(() {
      mockHttpClient = MockHttpClient();
      mockTokenStorage = MockTokenStorage();
      apiClient = ApiClient(
        baseUrl: ApiEndpoints.authBaseUrl,
        httpClient: mockHttpClient,
        tokenStorage: mockTokenStorage,
      );
      authClient = AuthClient(apiClient: apiClient);
    });

    group('login', () {
      test('successful login returns AuthResponse', () async {
        final request = LoginRequest(
          identifier: 'testuser',
          password: 'password123',
        );
        final responseBody = {
          'access_token': 'test-access-token',
          'refresh_token': 'test-refresh-token',
          'token_type': 'Bearer',
          'expires_in': 3600,
          'user_id': 'user-123',
          'username': 'testuser',
        };
        mockHttpClient.response = http.Response(jsonEncode(responseBody), 200);

        final result = await authClient.login(request);

        expect(result.accessToken, 'test-access-token');
        expect(result.refreshToken, 'test-refresh-token');
        expect(result.tokenType, 'Bearer');
        expect(result.expiresIn, 3600);
        expect(result.userId, 'user-123');
        expect(result.username, 'testuser');
        expect(mockHttpClient.lastMethod, 'POST');
        expect(mockHttpClient.lastUri?.path, endsWith(ApiEndpoints.authLogin));
        expect(mockHttpClient.lastBody, jsonEncode(request.toJson()));
      });

      test('login does not require authentication', () async {
        final request = LoginRequest(
          identifier: 'testuser',
          password: 'password123',
        );
        mockHttpClient.response = http.Response(
          '{"access_token":"token","refresh_token":"refresh","token_type":"Bearer","expires_in":3600}',
          200,
        );

        await authClient.login(request);

        expect(mockHttpClient.lastHeaders?['Authorization'], isNull);
      });

      test('login throws exception on error', () async {
        final request = LoginRequest(
          identifier: 'testuser',
          password: 'wrongpassword',
        );
        mockHttpClient.response = http.Response(
          '{"message":"Invalid credentials"}',
          401,
        );

        expect(() => authClient.login(request), throwsException);
      });
    });

    group('register', () {
      test('successful registration returns RegisterPendingResponse (202)',
          () async {
        final request = RegisterRequest(
          username: 'newuser',
          email: 'newuser@example.com',
          password: 'password123',
        );
        final responseBody = {
          'message':
              'Registration pending. Please check your email to verify your account.',
        };
        mockHttpClient.response = http.Response(jsonEncode(responseBody), 202);

        final result = await authClient.register(request);

        expect(result.message, contains('check your email'));
        expect(mockHttpClient.lastMethod, 'POST');
        expect(
          mockHttpClient.lastUri?.path,
          endsWith(ApiEndpoints.authRegister),
        );
        expect(mockHttpClient.lastBody, jsonEncode(request.toJson()));
      });

      test('register does not require authentication', () async {
        final request = RegisterRequest(
          username: 'newuser',
          email: 'newuser@example.com',
          password: 'password123',
        );
        mockHttpClient.response = http.Response(
          '{"message":"Registration pending. Please check your email to verify your account."}',
          202,
        );

        await authClient.register(request);

        expect(mockHttpClient.lastHeaders?['Authorization'], isNull);
      });

      test('register throws exception on validation error', () async {
        final request = RegisterRequest(
          username: 'u',
          email: 'invalid-email',
          password: '123',
        );
        mockHttpClient.response = http.Response(
          '{"message":"Validation failed","errors":["Username too short","Invalid email","Password too weak"]}',
          400,
        );

        expect(() => authClient.register(request), throwsException);
      });
    });

    group('verifyEmail', () {
      test('successful email verification returns AuthResponse (201)',
          () async {
        final request = VerifyEmailRequest(token: 'valid-token');
        final responseBody = {
          'accessToken': 'new-access-token',
          'refreshToken': 'new-refresh-token',
          'tokenType': 'Bearer',
          'expiresIn': 3600,
        };
        mockHttpClient.response = http.Response(jsonEncode(responseBody), 201);

        final result = await authClient.verifyEmail(request);

        expect(result.accessToken, 'new-access-token');
        expect(result.refreshToken, 'new-refresh-token');
        expect(result.tokenType, 'Bearer');
        expect(result.expiresIn, 3600);
        expect(mockHttpClient.lastMethod, 'POST');
        expect(
          mockHttpClient.lastUri?.path,
          endsWith(ApiEndpoints.authVerifyEmail),
        );
        expect(mockHttpClient.lastBody, jsonEncode(request.toJson()));
      });

      test('verifyEmail does not require authentication', () async {
        final request = VerifyEmailRequest(token: 'valid-token');
        mockHttpClient.response = http.Response(
          '{"accessToken":"token","refreshToken":"refresh","tokenType":"Bearer","expiresIn":3600}',
          201,
        );

        await authClient.verifyEmail(request);

        expect(mockHttpClient.lastHeaders?['Authorization'], isNull);
      });

      test('verifyEmail throws exception on invalid token', () async {
        final request = VerifyEmailRequest(token: 'bad-token');
        mockHttpClient.response = http.Response(
          'Invalid or expired email verification token',
          400,
        );

        expect(() => authClient.verifyEmail(request), throwsException);
      });
    });

    group('logout', () {
      test('successful logout completes without error', () async {
        mockTokenStorage.accessToken = 'test-token';
        mockTokenStorage.tokenType = 'Bearer';
        mockHttpClient.response = http.Response('', 204);

        await authClient.logout();

        expect(mockHttpClient.lastMethod, 'POST');
        expect(mockHttpClient.lastUri?.path, endsWith(ApiEndpoints.authLogout));
        expect(
          mockHttpClient.lastHeaders?['Authorization'],
          'Bearer test-token',
        );
      });

      test('logout requires authentication', () async {
        mockTokenStorage.accessToken = 'test-token';
        mockTokenStorage.tokenType = 'Bearer';
        mockHttpClient.response = http.Response('', 204);

        await authClient.logout();

        expect(mockHttpClient.lastHeaders?['Authorization'], isNotNull);
      });

      test('logout throws exception on error', () async {
        mockTokenStorage.accessToken = 'test-token';
        mockTokenStorage.tokenType = 'Bearer';
        mockHttpClient.response = http.Response(
          '{"message":"Server error"}',
          500,
        );

        expect(() => authClient.logout(), throwsException);
      });
    });

    group('refresh', () {
      test('successful token refresh returns new AuthResponse', () async {
        final request = RefreshTokenRequest(refreshToken: 'old-refresh-token');
        final responseBody = {
          'accessToken': 'new-access-token',
          'refreshToken': 'new-refresh-token',
          'tokenType': 'Bearer',
          'expiresIn': 3600,
        };
        mockHttpClient.response = http.Response(jsonEncode(responseBody), 200);

        final result = await authClient.refresh(request);

        expect(result.accessToken, 'new-access-token');
        expect(result.refreshToken, 'new-refresh-token');
        expect(result.tokenType, 'Bearer');
        expect(result.expiresIn, 3600);
        expect(mockHttpClient.lastMethod, 'POST');
        expect(
          mockHttpClient.lastUri?.path,
          endsWith(ApiEndpoints.authRefresh),
        );
        expect(mockHttpClient.lastBody, jsonEncode(request.toJson()));
      });

      test('refresh does not require authentication', () async {
        final request = RefreshTokenRequest(refreshToken: 'old-refresh-token');
        mockHttpClient.response = http.Response(
          '{"access_token":"token","refresh_token":"refresh","token_type":"Bearer","expires_in":3600}',
          200,
        );

        await authClient.refresh(request);

        expect(mockHttpClient.lastHeaders?['Authorization'], isNull);
      });

      test('refresh throws exception on invalid refresh token', () async {
        final request = RefreshTokenRequest(refreshToken: 'invalid-token');
        mockHttpClient.response = http.Response(
          '{"message":"Invalid refresh token"}',
          401,
        );

        expect(() => authClient.refresh(request), throwsException);
      });
    });

    group('initiatePasswordReset', () {
      test(
        'successful password reset initiation completes without error',
        () async {
          final request = PasswordResetRequest(email: 'user@example.com');
          mockHttpClient.response = http.Response('', 204);

          await authClient.initiatePasswordReset(request);

          expect(mockHttpClient.lastMethod, 'POST');
          expect(
            mockHttpClient.lastUri?.path,
            endsWith(ApiEndpoints.authPasswordReset),
          );
          expect(mockHttpClient.lastBody, jsonEncode(request.toJson()));
        },
      );

      test('initiatePasswordReset does not require authentication', () async {
        final request = PasswordResetRequest(email: 'user@example.com');
        mockHttpClient.response = http.Response('', 204);

        await authClient.initiatePasswordReset(request);

        expect(mockHttpClient.lastHeaders?['Authorization'], isNull);
      });

      test('initiatePasswordReset throws exception on error', () async {
        final request = PasswordResetRequest(email: 'nonexistent@example.com');
        mockHttpClient.response = http.Response(
          '{"message":"Email not found"}',
          404,
        );

        expect(
          () => authClient.initiatePasswordReset(request),
          throwsException,
        );
      });
    });

    group('completePasswordReset', () {
      test(
        'successful password reset completion completes without error',
        () async {
          final request = PasswordResetRequest(email: 'user@example.com');
          mockHttpClient.response = http.Response('', 204);

          await authClient.completePasswordReset(request);

          expect(mockHttpClient.lastMethod, 'PUT');
          expect(
            mockHttpClient.lastUri?.path,
            endsWith(ApiEndpoints.authPasswordReset),
          );
          expect(mockHttpClient.lastBody, jsonEncode(request.toJson()));
        },
      );

      test('completePasswordReset does not require authentication', () async {
        final request = PasswordResetRequest(email: 'user@example.com');
        mockHttpClient.response = http.Response('', 204);

        await authClient.completePasswordReset(request);

        expect(mockHttpClient.lastHeaders?['Authorization'], isNull);
      });

      test('completePasswordReset throws exception on invalid token', () async {
        final request = PasswordResetRequest(email: 'user@example.com');
        mockHttpClient.response = http.Response(
          '{"message":"Invalid or expired reset token"}',
          400,
        );

        expect(
          () => authClient.completePasswordReset(request),
          throwsException,
        );
      });
    });

    group('changePassword', () {
      test('successful password change completes without error', () async {
        final request = PasswordChangeRequest(
          currentPassword: 'oldPassword123',
          newPassword: 'newPassword456',
        );
        mockTokenStorage.accessToken = 'test-token';
        mockTokenStorage.tokenType = 'Bearer';
        mockHttpClient.response = http.Response('', 204);

        await authClient.changePassword(request);

        expect(mockHttpClient.lastMethod, 'PUT');
        expect(
          mockHttpClient.lastUri?.path,
          endsWith(ApiEndpoints.authPasswordChange),
        );
        expect(mockHttpClient.lastBody, jsonEncode(request.toJson()));
        expect(
          mockHttpClient.lastHeaders?['Authorization'],
          'Bearer test-token',
        );
      });

      test('changePassword requires authentication', () async {
        final request = PasswordChangeRequest(
          currentPassword: 'oldPassword123',
          newPassword: 'newPassword456',
        );
        mockTokenStorage.accessToken = 'test-token';
        mockTokenStorage.tokenType = 'Bearer';
        mockHttpClient.response = http.Response('', 204);

        await authClient.changePassword(request);

        expect(mockHttpClient.lastHeaders?['Authorization'], isNotNull);
      });

      test('changePassword throws exception on wrong old password', () async {
        final request = PasswordChangeRequest(
          currentPassword: 'wrongPassword',
          newPassword: 'newPassword456',
        );
        mockTokenStorage.accessToken = 'test-token';
        mockTokenStorage.tokenType = 'Bearer';
        mockHttpClient.response = http.Response(
          '{"message":"Old password is incorrect"}',
          400,
        );

        expect(() => authClient.changePassword(request), throwsException);
      });

      test('changePassword throws exception on weak new password', () async {
        final request = PasswordChangeRequest(
          currentPassword: 'oldPassword123',
          newPassword: '123',
        );
        mockTokenStorage.accessToken = 'test-token';
        mockTokenStorage.tokenType = 'Bearer';
        mockHttpClient.response = http.Response(
          '{"message":"New password does not meet security requirements"}',
          400,
        );

        expect(() => authClient.changePassword(request), throwsException);
      });
    });

    group('AuthClient initialization', () {
      test('uses provided ApiClient', () {
        final customApiClient = ApiClient(
          baseUrl: 'http://custom-url',
          httpClient: mockHttpClient,
          tokenStorage: mockTokenStorage,
        );
        final client = AuthClient(apiClient: customApiClient);

        expect(client, isNotNull);
      });

      test(
        'creates default ApiClient with auth base URL when not provided',
        () {
          final client = AuthClient();

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
