import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:wanderer_frontend/data/client/api_client.dart';
import 'package:wanderer_frontend/data/storage/token_storage.dart';

import 'api_client_test.mocks.dart';

@GenerateMocks([http.Client, TokenStorage])
void main() {
  group('ApiClient', () {
    late MockClient mockHttpClient;
    late MockTokenStorage mockTokenStorage;
    late ApiClient apiClient;

    setUp(() {
      mockHttpClient = MockClient();
      mockTokenStorage = MockTokenStorage();
      apiClient = ApiClient(
        baseUrl: 'https://api.example.com',
        httpClient: mockHttpClient,
        tokenStorage: mockTokenStorage,
      );
    });

    group('GET requests', () {
      test('successful GET without auth', () async {
        final uri = Uri.parse('https://api.example.com/test');
        when(
          mockHttpClient.get(uri, headers: anyNamed('headers')),
        ).thenAnswer((_) async => http.Response('{"data": "test"}', 200));

        final response = await apiClient.get('/test');

        expect(response.statusCode, 200);
        expect(response.body, '{"data": "test"}');
        verify(mockHttpClient.get(uri, headers: anyNamed('headers'))).called(1);
        verifyNever(mockTokenStorage.getAccessToken());
      });

      test('successful GET with auth', () async {
        when(
          mockTokenStorage.isAccessTokenExpired(),
        ).thenAnswer((_) async => false);
        when(
          mockTokenStorage.getAccessToken(),
        ).thenAnswer((_) async => 'test-token');
        when(mockTokenStorage.getTokenType()).thenAnswer((_) async => 'Bearer');

        final uri = Uri.parse('https://api.example.com/test');
        when(
          mockHttpClient.get(uri, headers: anyNamed('headers')),
        ).thenAnswer((_) async => http.Response('{"data": "test"}', 200));

        final response = await apiClient.get('/test', requireAuth: true);

        expect(response.statusCode, 200);
        verify(mockTokenStorage.isAccessTokenExpired()).called(1);
        verify(mockTokenStorage.getAccessToken()).called(1);
      });

      test('GET with 401 triggers token refresh and retry', () async {
        when(
          mockTokenStorage.isAccessTokenExpired(),
        ).thenAnswer((_) async => false);
        when(
          mockTokenStorage.getAccessToken(),
        ).thenAnswer((_) async => 'old-token');
        when(mockTokenStorage.getTokenType()).thenAnswer((_) async => 'Bearer');
        when(
          mockTokenStorage.getRefreshToken(),
        ).thenAnswer((_) async => 'refresh-token');

        final uri = Uri.parse('https://api.example.com/test');
        final refreshUri =
            Uri.parse('http://localhost:8083/api/1/auth/refresh');

        // First request returns 401, then retry returns 200
        var getCallCount = 0;
        when(mockHttpClient.get(uri, headers: anyNamed('headers'))).thenAnswer((
          _,
        ) async {
          getCallCount++;
          if (getCallCount == 1) {
            return http.Response('Unauthorized', 401);
          } else {
            return http.Response('{"data": "success"}', 200);
          }
        });

        // Refresh token request succeeds
        when(
          mockHttpClient.post(
            refreshUri,
            headers: anyNamed('headers'),
            body: anyNamed('body'),
          ),
        ).thenAnswer(
          (_) async => http.Response(
            jsonEncode({
              'accessToken': 'new-token',
              'refreshToken': 'new-refresh-token',
              'tokenType': 'Bearer',
              'expiresIn': 3600,
            }),
            200,
          ),
        );

        when(
          mockTokenStorage.saveTokens(
            accessToken: anyNamed('accessToken'),
            refreshToken: anyNamed('refreshToken'),
            tokenType: anyNamed('tokenType'),
            expiresIn: anyNamed('expiresIn'),
          ),
        ).thenAnswer((_) async => {});

        final response = await apiClient.get('/test', requireAuth: true);

        expect(response.statusCode, 200);
        verify(
          mockTokenStorage.saveTokens(
            accessToken: 'new-token',
            refreshToken: 'new-refresh-token',
            tokenType: 'Bearer',
            expiresIn: 3600,
          ),
        ).called(1);
      });

      test('GET with custom headers', () async {
        final uri = Uri.parse('https://api.example.com/test');
        when(
          mockHttpClient.get(uri, headers: anyNamed('headers')),
        ).thenAnswer((_) async => http.Response('{"data": "test"}', 200));

        await apiClient.get(
          '/test',
          headers: {'X-Custom-Header': 'custom-value'},
        );

        verify(
          mockHttpClient.get(
            uri,
            headers: argThat(
              containsPair('X-Custom-Header', 'custom-value'),
              named: 'headers',
            ),
          ),
        ).called(1);
      });

      test('GET with expired token triggers proactive refresh', () async {
        when(
          mockTokenStorage.isAccessTokenExpired(),
        ).thenAnswer((_) async => true);
        when(
          mockTokenStorage.getRefreshToken(),
        ).thenAnswer((_) async => 'refresh-token');

        final refreshUri =
            Uri.parse('http://localhost:8083/api/1/auth/refresh');
        when(
          mockHttpClient.post(
            refreshUri,
            headers: anyNamed('headers'),
            body: anyNamed('body'),
          ),
        ).thenAnswer(
          (_) async => http.Response(
            jsonEncode({
              'accessToken': 'new-token',
              'refreshToken': 'refresh-token',
              'tokenType': 'Bearer',
              'expiresIn': 3600,
            }),
            200,
          ),
        );

        when(
          mockTokenStorage.saveTokens(
            accessToken: anyNamed('accessToken'),
            refreshToken: anyNamed('refreshToken'),
            tokenType: anyNamed('tokenType'),
            expiresIn: anyNamed('expiresIn'),
          ),
        ).thenAnswer((_) async => {});

        when(
          mockTokenStorage.getAccessToken(),
        ).thenAnswer((_) async => 'new-token');
        when(mockTokenStorage.getTokenType()).thenAnswer((_) async => 'Bearer');

        final uri = Uri.parse('https://api.example.com/test');
        when(
          mockHttpClient.get(uri, headers: anyNamed('headers')),
        ).thenAnswer((_) async => http.Response('{"data": "test"}', 200));

        await apiClient.get('/test', requireAuth: true);

        verify(mockTokenStorage.isAccessTokenExpired()).called(1);
        verify(
          mockTokenStorage.saveTokens(
            accessToken: 'new-token',
            refreshToken: 'refresh-token',
            tokenType: 'Bearer',
            expiresIn: 3600,
          ),
        ).called(1);
      });
    });

    group('POST requests', () {
      test('successful POST without auth', () async {
        final uri = Uri.parse('https://api.example.com/test');
        when(
          mockHttpClient.post(
            uri,
            headers: anyNamed('headers'),
            body: anyNamed('body'),
          ),
        ).thenAnswer((_) async => http.Response('{"id": "123"}', 201));

        final response = await apiClient.post('/test', body: {'name': 'test'});

        expect(response.statusCode, 201);
        verify(
          mockHttpClient.post(
            uri,
            headers: anyNamed('headers'),
            body: jsonEncode({'name': 'test'}),
          ),
        ).called(1);
      });

      test('POST with auth and 401 retry', () async {
        when(
          mockTokenStorage.isAccessTokenExpired(),
        ).thenAnswer((_) async => false);
        when(
          mockTokenStorage.getAccessToken(),
        ).thenAnswer((_) async => 'old-token');
        when(mockTokenStorage.getTokenType()).thenAnswer((_) async => 'Bearer');
        when(
          mockTokenStorage.getRefreshToken(),
        ).thenAnswer((_) async => 'refresh-token');

        final uri = Uri.parse('https://api.example.com/test');
        final refreshUri =
            Uri.parse('http://localhost:8083/api/1/auth/refresh');

        // Setup POST to test endpoint: first 401, then retry with 201
        var postCallCount = 0;
        when(
          mockHttpClient.post(
            uri,
            headers: anyNamed('headers'),
            body: anyNamed('body'),
          ),
        ).thenAnswer((_) async {
          postCallCount++;
          if (postCallCount == 1) {
            return http.Response('Unauthorized', 401);
          } else {
            return http.Response('{"id": "123"}', 201);
          }
        });

        // Refresh endpoint succeeds
        when(
          mockHttpClient.post(
            refreshUri,
            headers: anyNamed('headers'),
            body: anyNamed('body'),
          ),
        ).thenAnswer(
          (_) async => http.Response(
            jsonEncode({
              'accessToken': 'new-token',
              'refreshToken': 'refresh-token',
            }),
            200,
          ),
        );

        when(
          mockTokenStorage.saveTokens(
            accessToken: anyNamed('accessToken'),
            refreshToken: anyNamed('refreshToken'),
            tokenType: anyNamed('tokenType'),
            expiresIn: anyNamed('expiresIn'),
          ),
        ).thenAnswer((_) async => {});

        final response = await apiClient.post(
          '/test',
          body: {'name': 'test'},
          requireAuth: true,
        );

        expect(response.statusCode, 201);
      });
    });

    group('PUT requests', () {
      test('successful PUT without auth', () async {
        final uri = Uri.parse('https://api.example.com/test/123');
        when(
          mockHttpClient.put(
            uri,
            headers: anyNamed('headers'),
            body: anyNamed('body'),
          ),
        ).thenAnswer((_) async => http.Response('{"id": "123"}', 200));

        final response = await apiClient.put(
          '/test/123',
          body: {'name': 'updated'},
        );

        expect(response.statusCode, 200);
      });

      test('PUT with 401 triggers refresh and retry', () async {
        when(
          mockTokenStorage.isAccessTokenExpired(),
        ).thenAnswer((_) async => false);
        when(
          mockTokenStorage.getAccessToken(),
        ).thenAnswer((_) async => 'old-token');
        when(mockTokenStorage.getTokenType()).thenAnswer((_) async => 'Bearer');
        when(
          mockTokenStorage.getRefreshToken(),
        ).thenAnswer((_) async => 'refresh-token');

        final uri = Uri.parse('https://api.example.com/test/123');
        final refreshUri =
            Uri.parse('http://localhost:8083/api/1/auth/refresh');

        // PUT endpoint: first 401, then retry with 200
        var putCallCount = 0;
        when(
          mockHttpClient.put(
            uri,
            headers: anyNamed('headers'),
            body: anyNamed('body'),
          ),
        ).thenAnswer((_) async {
          putCallCount++;
          if (putCallCount == 1) {
            return http.Response('Unauthorized', 401);
          } else {
            return http.Response('{"id": "123"}', 200);
          }
        });

        when(
          mockHttpClient.post(
            refreshUri,
            headers: anyNamed('headers'),
            body: anyNamed('body'),
          ),
        ).thenAnswer(
          (_) async => http.Response(
            jsonEncode({
              'access_token': 'new-token',
              'refresh_token': 'refresh-token',
              'token_type': 'Bearer',
              'expires_in': 7200,
            }),
            200,
          ),
        );

        when(
          mockTokenStorage.saveTokens(
            accessToken: anyNamed('accessToken'),
            refreshToken: anyNamed('refreshToken'),
            tokenType: anyNamed('tokenType'),
            expiresIn: anyNamed('expiresIn'),
          ),
        ).thenAnswer((_) async => {});

        final response = await apiClient.put(
          '/test/123',
          body: {'name': 'updated'},
          requireAuth: true,
        );

        expect(response.statusCode, 200);
        verify(
          mockTokenStorage.saveTokens(
            accessToken: 'new-token',
            refreshToken: 'refresh-token',
            tokenType: 'Bearer',
            expiresIn: 7200,
          ),
        ).called(1);
      });
    });

    group('PATCH requests', () {
      test('successful PATCH without auth', () async {
        final uri = Uri.parse('https://api.example.com/test/123');
        when(
          mockHttpClient.patch(
            uri,
            headers: anyNamed('headers'),
            body: anyNamed('body'),
          ),
        ).thenAnswer((_) async => http.Response('{"id": "123"}', 200));

        final response = await apiClient.patch(
          '/test/123',
          body: {'status': 'active'},
        );

        expect(response.statusCode, 200);
      });

      test('PATCH with 401 triggers refresh and retry', () async {
        when(
          mockTokenStorage.isAccessTokenExpired(),
        ).thenAnswer((_) async => false);
        when(
          mockTokenStorage.getAccessToken(),
        ).thenAnswer((_) async => 'old-token');
        when(mockTokenStorage.getTokenType()).thenAnswer((_) async => 'Bearer');
        when(
          mockTokenStorage.getRefreshToken(),
        ).thenAnswer((_) async => 'refresh-token');

        final uri = Uri.parse('https://api.example.com/test/123');
        final refreshUri =
            Uri.parse('http://localhost:8083/api/1/auth/refresh');

        // PATCH endpoint: first 401, then retry with 200
        var patchCallCount = 0;
        when(
          mockHttpClient.patch(
            uri,
            headers: anyNamed('headers'),
            body: anyNamed('body'),
          ),
        ).thenAnswer((_) async {
          patchCallCount++;
          if (patchCallCount == 1) {
            return http.Response('Unauthorized', 401);
          } else {
            return http.Response('{"id": "123"}', 200);
          }
        });

        when(
          mockHttpClient.post(
            refreshUri,
            headers: anyNamed('headers'),
            body: anyNamed('body'),
          ),
        ).thenAnswer(
          (_) async =>
              http.Response(jsonEncode({'accessToken': 'new-token'}), 200),
        );

        when(
          mockTokenStorage.saveTokens(
            accessToken: anyNamed('accessToken'),
            refreshToken: anyNamed('refreshToken'),
            tokenType: anyNamed('tokenType'),
            expiresIn: anyNamed('expiresIn'),
          ),
        ).thenAnswer((_) async => {});

        final response = await apiClient.patch(
          '/test/123',
          body: {'status': 'active'},
          requireAuth: true,
        );

        expect(response.statusCode, 200);
      });
    });

    group('DELETE requests', () {
      test('successful DELETE without auth', () async {
        final uri = Uri.parse('https://api.example.com/test/123');
        when(
          mockHttpClient.delete(uri, headers: anyNamed('headers')),
        ).thenAnswer((_) async => http.Response('', 204));

        final response = await apiClient.delete('/test/123');

        expect(response.statusCode, 204);
      });

      test('DELETE with 401 triggers refresh and retry', () async {
        when(
          mockTokenStorage.isAccessTokenExpired(),
        ).thenAnswer((_) async => false);
        when(
          mockTokenStorage.getAccessToken(),
        ).thenAnswer((_) async => 'old-token');
        when(mockTokenStorage.getTokenType()).thenAnswer((_) async => 'Bearer');
        when(
          mockTokenStorage.getRefreshToken(),
        ).thenAnswer((_) async => 'refresh-token');

        final uri = Uri.parse('https://api.example.com/test/123');
        final refreshUri =
            Uri.parse('http://localhost:8083/api/1/auth/refresh');

        // DELETE endpoint: first 401, then retry with 204
        var deleteCallCount = 0;
        when(
          mockHttpClient.delete(uri, headers: anyNamed('headers')),
        ).thenAnswer((_) async {
          deleteCallCount++;
          if (deleteCallCount == 1) {
            return http.Response('Unauthorized', 401);
          } else {
            return http.Response('', 204);
          }
        });

        when(
          mockHttpClient.post(
            refreshUri,
            headers: anyNamed('headers'),
            body: anyNamed('body'),
          ),
        ).thenAnswer(
          (_) async => http.Response(
            jsonEncode({
              'accessToken': 'new-token',
              'refreshToken': 'refresh-token',
            }),
            200,
          ),
        );

        when(
          mockTokenStorage.saveTokens(
            accessToken: anyNamed('accessToken'),
            refreshToken: anyNamed('refreshToken'),
            tokenType: anyNamed('tokenType'),
            expiresIn: anyNamed('expiresIn'),
          ),
        ).thenAnswer((_) async => {});

        final response = await apiClient.delete('/test/123', requireAuth: true);

        expect(response.statusCode, 204);
      });
    });

    group('Token refresh', () {
      test('refresh token success with snake_case response', () async {
        when(
          mockTokenStorage.isAccessTokenExpired(),
        ).thenAnswer((_) async => true);
        when(
          mockTokenStorage.getRefreshToken(),
        ).thenAnswer((_) async => 'refresh-token');

        final refreshUri =
            Uri.parse('http://localhost:8083/api/1/auth/refresh');
        when(
          mockHttpClient.post(
            refreshUri,
            headers: anyNamed('headers'),
            body: anyNamed('body'),
          ),
        ).thenAnswer(
          (_) async => http.Response(
            jsonEncode({
              'access_token': 'new-token',
              'refresh_token': 'new-refresh',
              'token_type': 'Bearer',
              'expires_in': '3600',
            }),
            200,
          ),
        );

        when(
          mockTokenStorage.saveTokens(
            accessToken: anyNamed('accessToken'),
            refreshToken: anyNamed('refreshToken'),
            tokenType: anyNamed('tokenType'),
            expiresIn: anyNamed('expiresIn'),
          ),
        ).thenAnswer((_) async => {});

        when(
          mockTokenStorage.getAccessToken(),
        ).thenAnswer((_) async => 'new-token');
        when(mockTokenStorage.getTokenType()).thenAnswer((_) async => 'Bearer');

        final uri = Uri.parse('https://api.example.com/test');
        when(
          mockHttpClient.get(uri, headers: anyNamed('headers')),
        ).thenAnswer((_) async => http.Response('{"data": "test"}', 200));

        await apiClient.get('/test', requireAuth: true);

        verify(
          mockTokenStorage.saveTokens(
            accessToken: 'new-token',
            refreshToken: 'new-refresh',
            tokenType: 'Bearer',
            expiresIn: 3600,
          ),
        ).called(1);
      });

      test('refresh token fails with no refresh token', () async {
        when(
          mockTokenStorage.isAccessTokenExpired(),
        ).thenAnswer((_) async => true);
        when(mockTokenStorage.getRefreshToken()).thenAnswer((_) async => null);
        when(mockTokenStorage.clearTokens()).thenAnswer((_) async => {});

        when(mockTokenStorage.getAccessToken()).thenAnswer((_) async => null);
        when(mockTokenStorage.getTokenType()).thenAnswer((_) async => 'Bearer');

        final uri = Uri.parse('https://api.example.com/test');
        when(
          mockHttpClient.get(uri, headers: anyNamed('headers')),
        ).thenAnswer((_) async => http.Response('{"data": "test"}', 200));

        await apiClient.get('/test', requireAuth: true);

        verify(mockTokenStorage.clearTokens()).called(1);
      });

      test('refresh token fails with invalid response', () async {
        when(
          mockTokenStorage.isAccessTokenExpired(),
        ).thenAnswer((_) async => true);
        when(
          mockTokenStorage.getRefreshToken(),
        ).thenAnswer((_) async => 'refresh-token');

        final refreshUri =
            Uri.parse('http://localhost:8083/api/1/auth/refresh');
        when(
          mockHttpClient.post(
            refreshUri,
            headers: anyNamed('headers'),
            body: anyNamed('body'),
          ),
        ).thenAnswer(
          (_) async => http.Response(jsonEncode({'error': 'invalid'}), 200),
        );

        when(mockTokenStorage.clearTokens()).thenAnswer((_) async => {});
        when(mockTokenStorage.getAccessToken()).thenAnswer((_) async => null);
        when(mockTokenStorage.getTokenType()).thenAnswer((_) async => 'Bearer');

        final uri = Uri.parse('https://api.example.com/test');
        when(
          mockHttpClient.get(uri, headers: anyNamed('headers')),
        ).thenAnswer((_) async => http.Response('{"data": "test"}', 200));

        await apiClient.get('/test', requireAuth: true);

        verify(mockTokenStorage.clearTokens()).called(1);
      });

      test('refresh token fails with 401 response', () async {
        when(
          mockTokenStorage.isAccessTokenExpired(),
        ).thenAnswer((_) async => true);
        when(
          mockTokenStorage.getRefreshToken(),
        ).thenAnswer((_) async => 'refresh-token');

        final refreshUri =
            Uri.parse('http://localhost:8083/api/1/auth/refresh');
        when(
          mockHttpClient.post(
            refreshUri,
            headers: anyNamed('headers'),
            body: anyNamed('body'),
          ),
        ).thenAnswer((_) async => http.Response('Unauthorized', 401));

        when(mockTokenStorage.clearTokens()).thenAnswer((_) async => {});
        when(mockTokenStorage.getAccessToken()).thenAnswer((_) async => null);
        when(mockTokenStorage.getTokenType()).thenAnswer((_) async => 'Bearer');

        final uri = Uri.parse('https://api.example.com/test');
        when(
          mockHttpClient.get(uri, headers: anyNamed('headers')),
        ).thenAnswer((_) async => http.Response('{"data": "test"}', 200));

        await apiClient.get('/test', requireAuth: true);

        verify(mockTokenStorage.clearTokens()).called(1);
      });

      test('refresh token fails with exception does not clear tokens',
          () async {
        when(
          mockTokenStorage.isAccessTokenExpired(),
        ).thenAnswer((_) async => true);
        when(
          mockTokenStorage.getRefreshToken(),
        ).thenAnswer((_) async => 'refresh-token');

        final refreshUri =
            Uri.parse('http://localhost:8083/api/1/auth/refresh');
        when(
          mockHttpClient.post(
            refreshUri,
            headers: anyNamed('headers'),
            body: anyNamed('body'),
          ),
        ).thenThrow(Exception('Network error'));

        when(mockTokenStorage.clearTokens()).thenAnswer((_) async => {});
        when(mockTokenStorage.getAccessToken()).thenAnswer((_) async => null);
        when(mockTokenStorage.getTokenType()).thenAnswer((_) async => 'Bearer');

        final uri = Uri.parse('https://api.example.com/test');
        when(
          mockHttpClient.get(uri, headers: anyNamed('headers')),
        ).thenAnswer((_) async => http.Response('{"data": "test"}', 200));

        await apiClient.get('/test', requireAuth: true);

        // Tokens should NOT be cleared on transient/network errors
        // to avoid logging out users due to temporary connectivity issues
        verifyNever(mockTokenStorage.clearTokens());
      });

      test(
        'concurrent refresh requests share the same refresh operation',
        () async {
          when(
            mockTokenStorage.isAccessTokenExpired(),
          ).thenAnswer((_) async => true);
          when(
            mockTokenStorage.getRefreshToken(),
          ).thenAnswer((_) async => 'refresh-token');

          final refreshUri =
              Uri.parse('http://localhost:8083/api/1/auth/refresh');
          when(
            mockHttpClient.post(
              refreshUri,
              headers: anyNamed('headers'),
              body: anyNamed('body'),
            ),
          ).thenAnswer((_) async {
            await Future.delayed(Duration(milliseconds: 100));
            return http.Response(
              jsonEncode({
                'accessToken': 'new-token',
                'refreshToken': 'refresh-token',
              }),
              200,
            );
          });

          when(
            mockTokenStorage.saveTokens(
              accessToken: anyNamed('accessToken'),
              refreshToken: anyNamed('refreshToken'),
              tokenType: anyNamed('tokenType'),
              expiresIn: anyNamed('expiresIn'),
            ),
          ).thenAnswer((_) async => {});

          when(
            mockTokenStorage.getAccessToken(),
          ).thenAnswer((_) async => 'new-token');
          when(
            mockTokenStorage.getTokenType(),
          ).thenAnswer((_) async => 'Bearer');

          final uri = Uri.parse('https://api.example.com/test');
          when(
            mockHttpClient.get(uri, headers: anyNamed('headers')),
          ).thenAnswer((_) async => http.Response('{"data": "test"}', 200));

          // Fire off two concurrent requests
          await Future.wait([
            apiClient.get('/test', requireAuth: true),
            apiClient.get('/test', requireAuth: true),
          ]);

          // Should only refresh once despite two concurrent requests
          verify(
            mockHttpClient.post(
              refreshUri,
              headers: anyNamed('headers'),
              body: anyNamed('body'),
            ),
          ).called(1);
        },
      );

      test('uses default Bearer token type when none provided', () async {
        when(
          mockTokenStorage.isAccessTokenExpired(),
        ).thenAnswer((_) async => false);
        when(
          mockTokenStorage.getAccessToken(),
        ).thenAnswer((_) async => 'test-token');
        when(mockTokenStorage.getTokenType()).thenAnswer((_) async => null);

        final uri = Uri.parse('https://api.example.com/test');
        when(
          mockHttpClient.get(uri, headers: anyNamed('headers')),
        ).thenAnswer((_) async => http.Response('{"data": "test"}', 200));

        await apiClient.get('/test', requireAuth: true);

        verify(
          mockHttpClient.get(
            uri,
            headers: argThat(
              containsPair('Authorization', 'Bearer test-token'),
              named: 'headers',
            ),
          ),
        ).called(1);
      });
    });

    group('Response handling', () {
      test('handleResponse with valid JSON', () {
        final response = http.Response('{"id": "123", "name": "test"}', 200);

        final result = apiClient.handleResponse(
          response,
          (json) => TestModel.fromJson(json),
        );

        expect(result.id, '123');
        expect(result.name, 'test');
      });

      test('handleResponse with 201 status', () {
        final response = http.Response('{"id": "456", "name": "created"}', 201);

        final result = apiClient.handleResponse(
          response,
          (json) => TestModel.fromJson(json),
        );

        expect(result.id, '456');
        expect(result.name, 'created');
      });

      test('handleResponse throws on 400 error with JSON', () {
        final response = http.Response(
          '{"message": "Bad request", "error": "validation_error"}',
          400,
        );

        expect(
          () => apiClient.handleResponse(
            response,
            (json) => TestModel.fromJson(json),
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Bad request'),
            ),
          ),
        );
      });

      test('handleResponse throws on 404 error with JSON error field', () {
        final response = http.Response('{"error": "Not found"}', 404);

        expect(
          () => apiClient.handleResponse(
            response,
            (json) => TestModel.fromJson(json),
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Not found'),
            ),
          ),
        );
      });

      test('handleResponse throws on 500 error with plain text', () {
        final response = http.Response('Internal Server Error', 500);

        expect(
          () => apiClient.handleResponse(
            response,
            (json) => TestModel.fromJson(json),
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Internal Server Error'),
            ),
          ),
        );
      });

      test('handleResponse throws on error with long plain text', () {
        final longBody = 'x' * 300;
        final response = http.Response(longBody, 500);

        expect(
          () => apiClient.handleResponse(
            response,
            (json) => TestModel.fromJson(json),
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              allOf(contains('API Error (500)'), isNot(contains(longBody))),
            ),
          ),
        );
      });

      test('handleListResponse with valid JSON array', () {
        final response = http.Response(
          '[{"id": "1", "name": "first"}, {"id": "2", "name": "second"}]',
          200,
        );

        final result = apiClient.handleListResponse(
          response,
          (json) => TestModel.fromJson(json),
        );

        expect(result, hasLength(2));
        expect(result[0].id, '1');
        expect(result[1].name, 'second');
      });

      test('handleListResponse throws on error', () {
        final response = http.Response('{"error": "Bad request"}', 400);

        expect(
          () => apiClient.handleListResponse(
            response,
            (json) => TestModel.fromJson(json),
          ),
          throwsA(isA<Exception>()),
        );
      });

      test('handleNoContentResponse with 204', () {
        final response = http.Response('', 204);

        expect(
          () => apiClient.handleNoContentResponse(response),
          returnsNormally,
        );
      });

      test('handleNoContentResponse with 200', () {
        final response = http.Response('', 200);

        expect(
          () => apiClient.handleNoContentResponse(response),
          returnsNormally,
        );
      });

      test('handleNoContentResponse throws on error', () {
        final response = http.Response('{"error": "Not found"}', 404);

        expect(
          () => apiClient.handleNoContentResponse(response),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('Edge cases', () {
      test('handles isAccessTokenExpired throwing exception', () async {
        when(
          mockTokenStorage.isAccessTokenExpired(),
        ).thenThrow(UnimplementedError());
        when(
          mockTokenStorage.getAccessToken(),
        ).thenAnswer((_) async => 'test-token');
        when(mockTokenStorage.getTokenType()).thenAnswer((_) async => 'Bearer');

        final uri = Uri.parse('https://api.example.com/test');
        when(
          mockHttpClient.get(uri, headers: anyNamed('headers')),
        ).thenAnswer((_) async => http.Response('{"data": "test"}', 200));

        final response = await apiClient.get('/test', requireAuth: true);

        expect(response.statusCode, 200);
        // Should still work, falling back to 401 handling
      });

      test(
        'refresh keeps old refresh token if not provided in response',
        () async {
          when(
            mockTokenStorage.isAccessTokenExpired(),
          ).thenAnswer((_) async => true);
          when(
            mockTokenStorage.getRefreshToken(),
          ).thenAnswer((_) async => 'old-refresh-token');

          final refreshUri =
              Uri.parse('http://localhost:8083/api/1/auth/refresh');
          when(
            mockHttpClient.post(
              refreshUri,
              headers: anyNamed('headers'),
              body: anyNamed('body'),
            ),
          ).thenAnswer(
            (_) async => http.Response(
              jsonEncode({
                'accessToken': 'new-access-token',
                // No refreshToken in response
              }),
              200,
            ),
          );

          when(
            mockTokenStorage.saveTokens(
              accessToken: anyNamed('accessToken'),
              refreshToken: anyNamed('refreshToken'),
              tokenType: anyNamed('tokenType'),
              expiresIn: anyNamed('expiresIn'),
            ),
          ).thenAnswer((_) async => {});

          when(
            mockTokenStorage.getAccessToken(),
          ).thenAnswer((_) async => 'new-access-token');
          when(
            mockTokenStorage.getTokenType(),
          ).thenAnswer((_) async => 'Bearer');

          final uri = Uri.parse('https://api.example.com/test');
          when(
            mockHttpClient.get(uri, headers: anyNamed('headers')),
          ).thenAnswer((_) async => http.Response('{"data": "test"}', 200));

          await apiClient.get('/test', requireAuth: true);

          verify(
            mockTokenStorage.saveTokens(
              accessToken: 'new-access-token',
              refreshToken: 'old-refresh-token',
              tokenType: 'Bearer',
              expiresIn: 3600,
            ),
          ).called(1);
        },
      );
    });
  });
}

// Test model for response handling tests
class TestModel {
  final String id;
  final String name;

  TestModel({required this.id, required this.name});

  factory TestModel.fromJson(Map<String, dynamic> json) {
    return TestModel(id: json['id'] as String, name: json['name'] as String);
  }
}
