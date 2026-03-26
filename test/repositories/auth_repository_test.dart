import 'package:flutter_test/flutter_test.dart';
import 'package:wanderer_frontend/data/models/auth_models.dart';
import 'package:wanderer_frontend/data/repositories/auth_repository.dart';
import 'package:wanderer_frontend/data/services/auth_service.dart';

void main() {
  group('AuthRepository', () {
    late MockAuthService mockAuthService;
    late AuthRepository authRepository;

    setUp(() {
      mockAuthService = MockAuthService();
      authRepository = AuthRepository(authService: mockAuthService);
    });

    group('login', () {
      test(
        'successful login calls auth service with correct credentials',
        () async {
          final username = 'testuser';
          final password = 'password123';

          await authRepository.login(username, password);

          expect(mockAuthService.lastLoginRequest?.identifier, username);
          expect(mockAuthService.lastLoginRequest?.password, password);
          expect(mockAuthService.loginCalled, true);
        },
      );

      test('login passes through service errors', () async {
        mockAuthService.shouldThrowError = true;

        expect(() => authRepository.login('user', 'pass'), throwsException);
      });

      test('login with empty username', () async {
        final username = '';
        final password = 'password123';

        await authRepository.login(username, password);

        expect(mockAuthService.lastLoginRequest?.identifier, username);
        expect(mockAuthService.loginCalled, true);
      });

      test('login with empty password', () async {
        final username = 'testuser';
        final password = '';

        await authRepository.login(username, password);

        expect(mockAuthService.lastLoginRequest?.password, password);
        expect(mockAuthService.loginCalled, true);
      });
    });

    group('register', () {
      test(
        'successful registration calls auth service with correct data',
        () async {
          final username = 'newuser';
          final email = 'newuser@example.com';
          final password = 'password123';

          await authRepository.register(username, email, password);

          expect(mockAuthService.lastRegisterRequest?.username, username);
          expect(mockAuthService.lastRegisterRequest?.email, email);
          expect(mockAuthService.lastRegisterRequest?.password, password);
          expect(mockAuthService.registerCalled, true);
        },
      );

      test('register passes through service errors', () async {
        mockAuthService.shouldThrowError = true;

        expect(
          () => authRepository.register('user', 'email@test.com', 'pass'),
          throwsException,
        );
      });

      test('register with all fields populated', () async {
        final username = 'testuser';
        final email = 'test@example.com';
        final password = 'strongPassword123!';

        await authRepository.register(username, email, password);

        expect(mockAuthService.lastRegisterRequest?.username, username);
        expect(mockAuthService.lastRegisterRequest?.email, email);
        expect(mockAuthService.lastRegisterRequest?.password, password);
      });
    });

    group('requestPasswordReset', () {
      test('successful password reset request calls auth service', () async {
        final email = 'user@example.com';

        await authRepository.requestPasswordReset(email);

        expect(mockAuthService.lastPasswordResetEmail, email);
        expect(mockAuthService.passwordResetCalled, true);
      });

      test('requestPasswordReset passes through service errors', () async {
        mockAuthService.shouldThrowError = true;

        expect(
          () => authRepository.requestPasswordReset('email@test.com'),
          throwsException,
        );
      });

      test('requestPasswordReset with valid email', () async {
        final email = 'test@example.com';

        await authRepository.requestPasswordReset(email);

        expect(mockAuthService.lastPasswordResetEmail, email);
      });

      test('requestPasswordReset with empty email', () async {
        final email = '';

        await authRepository.requestPasswordReset(email);

        expect(mockAuthService.lastPasswordResetEmail, email);
        expect(mockAuthService.passwordResetCalled, true);
      });
    });

    group('AuthRepository initialization', () {
      test('creates with provided AuthService', () {
        final customService = MockAuthService();
        final repo = AuthRepository(authService: customService);

        expect(repo, isNotNull);
      });

      test('creates with default AuthService when not provided', () {
        final repo = AuthRepository();

        expect(repo, isNotNull);
      });
    });
  });
}

// Mock AuthService
class MockAuthService extends AuthService {
  LoginRequest? lastLoginRequest;
  RegisterRequest? lastRegisterRequest;
  String? lastPasswordResetEmail;
  bool loginCalled = false;
  bool registerCalled = false;
  bool passwordResetCalled = false;
  bool shouldThrowError = false;

  @override
  Future<AuthResponse> login(LoginRequest request) async {
    loginCalled = true;
    lastLoginRequest = request;

    if (shouldThrowError) {
      throw Exception('Login failed');
    }

    return AuthResponse(
      accessToken: 'test-token',
      refreshToken: 'test-refresh',
      tokenType: 'Bearer',
      expiresIn: 3600,
    );
  }

  @override
  Future<RegisterPendingResponse> register(RegisterRequest request) async {
    registerCalled = true;
    lastRegisterRequest = request;

    if (shouldThrowError) {
      throw Exception('Registration failed');
    }

    return RegisterPendingResponse(
      message:
          'Registration pending. Please check your email to verify your account.',
    );
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    passwordResetCalled = true;
    lastPasswordResetEmail = email;

    if (shouldThrowError) {
      throw Exception('Password reset failed');
    }
  }
}
