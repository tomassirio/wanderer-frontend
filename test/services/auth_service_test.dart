import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:wanderer_frontend/data/models/auth_models.dart';
import 'package:wanderer_frontend/data/models/user_models.dart';
import 'package:wanderer_frontend/data/services/auth_service.dart';
import 'package:wanderer_frontend/data/client/auth/auth_client.dart';
import 'package:wanderer_frontend/data/client/query/user_query_client.dart';
import 'package:wanderer_frontend/data/storage/token_storage.dart';

import 'auth_service_test.mocks.dart';

@GenerateMocks([AuthClient, UserQueryClient, TokenStorage])
void main() {
  group('AuthService', () {
    late MockAuthClient mockAuthClient;
    late MockUserQueryClient mockUserQueryClient;
    late MockTokenStorage mockTokenStorage;
    late AuthService authService;

    setUp(() {
      mockAuthClient = MockAuthClient();
      mockUserQueryClient = MockUserQueryClient();
      mockTokenStorage = MockTokenStorage();
      authService = AuthService(
        authClient: mockAuthClient,
        userQueryClient: mockUserQueryClient,
        tokenStorage: mockTokenStorage,
      );
    });

    group('register', () {
      test('registers user and returns pending response', () async {
        final request = RegisterRequest(
          username: 'testuser',
          email: 'test@example.com',
          password: 'password123',
        );

        final pendingResponse = RegisterPendingResponse(
          message:
              'Registration pending. Please check your email to verify your account.',
        );

        when(
          mockAuthClient.register(request),
        ).thenAnswer((_) async => pendingResponse);

        final result = await authService.register(request);

        expect(result.message, contains('check your email'));
        verify(mockAuthClient.register(request)).called(1);
        verifyNever(mockTokenStorage.saveTokens(
          accessToken: anyNamed('accessToken'),
          refreshToken: anyNamed('refreshToken'),
          tokenType: anyNamed('tokenType'),
          expiresIn: anyNamed('expiresIn'),
        ));
      });

      test('passes through registration errors', () async {
        final request = RegisterRequest(
          username: 'testuser',
          email: 'test@example.com',
          password: 'password123',
        );
        when(
          mockAuthClient.register(request),
        ).thenThrow(Exception('Registration failed'));

        expect(() => authService.register(request), throwsException);
      });
    });

    group('verifyEmail', () {
      test('verifies email, saves tokens and fetches user profile', () async {
        final request = VerifyEmailRequest(token: 'valid-token');

        final authResponse = AuthResponse(
          accessToken: 'access-token',
          refreshToken: 'refresh-token',
          tokenType: 'Bearer',
          expiresIn: 3600,
        );

        final userProfile = UserProfile(
          id: 'user-123',
          username: 'testuser',
          email: 'test@example.com',
          createdAt: DateTime.now(),
          followersCount: 0,
          followingCount: 0,
          tripsCount: 0,
        );

        when(
          mockAuthClient.verifyEmail(request),
        ).thenAnswer((_) async => authResponse);
        when(
          mockUserQueryClient.getCurrentUser(),
        ).thenAnswer((_) async => userProfile);
        when(
          mockTokenStorage.saveTokens(
            accessToken: anyNamed('accessToken'),
            refreshToken: anyNamed('refreshToken'),
            tokenType: anyNamed('tokenType'),
            expiresIn: anyNamed('expiresIn'),
            userId: anyNamed('userId'),
            username: anyNamed('username'),
          ),
        ).thenAnswer((_) async => {});

        final result = await authService.verifyEmail(request);

        expect(result.accessToken, 'access-token');
        verify(mockAuthClient.verifyEmail(request)).called(1);
        verify(mockUserQueryClient.getCurrentUser()).called(1);
      });

      test('verifyEmail passes through errors', () async {
        final request = VerifyEmailRequest(token: 'invalid-token');
        when(
          mockAuthClient.verifyEmail(request),
        ).thenThrow(
          Exception('Invalid or expired email verification token'),
        );

        expect(() => authService.verifyEmail(request), throwsException);
      });
    });

    group('login', () {
      test('logs in user and saves tokens with user info', () async {
        final request = LoginRequest(
          identifier: 'testuser',
          password: 'password123',
        );

        final authResponse = AuthResponse(
          accessToken: 'access-token',
          refreshToken: 'refresh-token',
          tokenType: 'Bearer',
          expiresIn: 3600,
        );

        final userProfile = UserProfile(
          id: 'user-123',
          username: 'testuser',
          email: 'test@example.com',
          createdAt: DateTime.now(),
          followersCount: 0,
          followingCount: 0,
          tripsCount: 0,
        );

        when(
          mockAuthClient.login(request),
        ).thenAnswer((_) async => authResponse);
        when(
          mockUserQueryClient.getCurrentUser(),
        ).thenAnswer((_) async => userProfile);
        when(
          mockTokenStorage.saveTokens(
            accessToken: anyNamed('accessToken'),
            refreshToken: anyNamed('refreshToken'),
            tokenType: anyNamed('tokenType'),
            expiresIn: anyNamed('expiresIn'),
            userId: anyNamed('userId'),
            username: anyNamed('username'),
          ),
        ).thenAnswer((_) async => {});

        final result = await authService.login(request);

        expect(result.accessToken, 'access-token');
        verify(mockAuthClient.login(request)).called(1);
        verify(mockUserQueryClient.getCurrentUser()).called(1);
        verify(
          mockTokenStorage.saveTokens(
            accessToken: 'access-token',
            refreshToken: 'refresh-token',
            tokenType: 'Bearer',
            expiresIn: 3600,
            userId: 'user-123',
            username: 'testuser',
          ),
        ).called(1);
      });

      test(
        'logs in user and saves tokens even if profile fetch fails',
        () async {
          final request = LoginRequest(
            identifier: 'testuser',
            password: 'password123',
          );
          final authResponse = AuthResponse(
            accessToken: 'access-token',
            refreshToken: 'refresh-token',
            tokenType: 'Bearer',
            expiresIn: 3600,
          );

          when(
            mockAuthClient.login(request),
          ).thenAnswer((_) async => authResponse);
          when(
            mockUserQueryClient.getCurrentUser(),
          ).thenThrow(Exception('Profile fetch failed'));

          final result = await authService.login(request);

          expect(result.accessToken, 'access-token');
          verify(mockAuthClient.login(request)).called(1);
          verify(
            mockTokenStorage.saveTokens(
              accessToken: 'access-token',
              refreshToken: 'refresh-token',
              tokenType: 'Bearer',
              expiresIn: 3600,
              userId: anyNamed('userId'),
              username: anyNamed('username'),
            ),
          ).called(1);
        },
      );

      test('passes through login errors', () async {
        final request =
            LoginRequest(identifier: 'testuser', password: 'wrong');
        when(
          mockAuthClient.login(request),
        ).thenThrow(Exception('Login failed'));

        expect(() => authService.login(request), throwsException);
      });
    });

    group('logout', () {
      test('calls logout endpoint and clears tokens', () async {
        when(mockAuthClient.logout()).thenAnswer((_) async => {});
        when(mockTokenStorage.clearTokens()).thenAnswer((_) async => {});

        await authService.logout();

        verify(mockAuthClient.logout()).called(1);
        verify(mockTokenStorage.clearTokens()).called(1);
      });

      test('clears tokens even if logout endpoint fails', () async {
        when(mockAuthClient.logout()).thenThrow(Exception('Logout failed'));
        when(mockTokenStorage.clearTokens()).thenAnswer((_) async => {});

        await authService.logout();

        verify(mockTokenStorage.clearTokens()).called(1);
      });
    });

    group('isLoggedIn', () {
      test('returns true when access token exists', () async {
        when(mockTokenStorage.isLoggedIn()).thenAnswer((_) async => true);

        final result = await authService.isLoggedIn();

        expect(result, true);
      });

      test('returns false when no access token', () async {
        when(mockTokenStorage.isLoggedIn()).thenAnswer((_) async => false);

        final result = await authService.isLoggedIn();

        expect(result, false);
      });
    });

    group('getCurrentUsername', () {
      test('returns username from token storage', () async {
        when(
          mockTokenStorage.getUsername(),
        ).thenAnswer((_) async => 'testuser');

        final result = await authService.getCurrentUsername();

        expect(result, 'testuser');
      });
    });

    group('getCurrentUserId', () {
      test('returns user ID from token storage', () async {
        when(mockTokenStorage.getUserId()).thenAnswer((_) async => 'user-123');

        final result = await authService.getCurrentUserId();

        expect(result, 'user-123');
      });
    });
  });
}
