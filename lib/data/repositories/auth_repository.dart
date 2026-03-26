import 'package:wanderer_frontend/data/models/auth_models.dart';
import 'package:wanderer_frontend/data/services/auth_service.dart';

/// Repository for managing authentication operations
class AuthRepository {
  final AuthService _authService;

  AuthRepository({AuthService? authService})
      : _authService = authService ?? AuthService();

  /// Logs in a user with username or email and password
  Future<void> login(String identifier, String password) async {
    await _authService.login(
      LoginRequest(identifier: identifier, password: password),
    );
  }

  /// Registers a new user
  /// Returns a pending response; the user must verify their email before logging in
  Future<RegisterPendingResponse> register(
    String username,
    String email,
    String password,
  ) async {
    return await _authService.register(
      RegisterRequest(username: username, email: email, password: password),
    );
  }

  /// Verifies email with token received by email and logs the user in
  Future<void> verifyEmail(String token) async {
    await _authService.verifyEmail(VerifyEmailRequest(token: token));
  }

  /// Requests a password reset email
  Future<void> requestPasswordReset(String email) async {
    await _authService.requestPasswordReset(email);
  }
}
