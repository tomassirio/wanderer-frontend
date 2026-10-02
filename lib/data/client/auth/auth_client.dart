import '../../../core/constants/api_endpoints.dart';
import '../../models/auth_models.dart';
import '../api_client.dart';

/// Authentication client for auth service operations
class AuthClient {
  final ApiClient _apiClient;

  AuthClient({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient(baseUrl: ApiEndpoints.authBaseUrl);

  /// Login with username/password
  /// Returns access & refresh tokens
  /// No authentication required
  Future<AuthResponse> login(LoginRequest request) async {
    final response = await _apiClient.post(
      ApiEndpoints.authLogin,
      body: request.toJson(),
      requireAuth: false,
    );
    return _apiClient.handleResponse(response, AuthResponse.fromJson);
  }

  /// Register new user
  /// Returns 202 Accepted with a pending message; user must verify email
  /// No authentication required
  Future<RegisterPendingResponse> register(RegisterRequest request) async {
    final response = await _apiClient.post(
      ApiEndpoints.authRegister,
      body: request.toJson(),
      requireAuth: false,
    );
    return _apiClient.handleResponse(
      response,
      RegisterPendingResponse.fromJson,
    );
  }

  /// Verify email with token received by email
  /// Returns access & refresh tokens on success
  /// No authentication required
  Future<AuthResponse> verifyEmail(VerifyEmailRequest request) async {
    final response = await _apiClient.post(
      ApiEndpoints.authVerifyEmail,
      body: request.toJson(),
      requireAuth: false,
    );
    return _apiClient.handleResponse(response, AuthResponse.fromJson);
  }

  /// Logout user
  /// Invalidates access token and revokes refresh tokens
  /// Requires authentication (USER, ADMIN)
  Future<void> logout() async {
    final response = await _apiClient.post(
      ApiEndpoints.authLogout,
      body: {},
      requireAuth: true,
    );
    _apiClient.handleNoContentResponse(response);
  }

  /// Exchange refresh token for new access & refresh tokens
  /// No authentication required (uses refresh token in body)
  Future<AuthResponse> refresh(RefreshTokenRequest request) async {
    final response = await _apiClient.post(
      ApiEndpoints.authRefresh,
      body: request.toJson(),
      requireAuth: false,
    );
    return _apiClient.handleResponse(response, AuthResponse.fromJson);
  }

  /// Initiate password reset
  /// Generates reset token
  /// No authentication required
  Future<void> initiatePasswordReset(PasswordResetRequest request) async {
    final response = await _apiClient.post(
      ApiEndpoints.authPasswordReset,
      body: request.toJson(),
      requireAuth: false,
    );
    _apiClient.handleNoContentResponse(response);
  }

  /// Complete password reset with token
  /// No authentication required
  Future<void> completePasswordReset(
      PasswordResetConfirmRequest request) async {
    final response = await _apiClient.put(
      ApiEndpoints.authPasswordReset,
      body: request.toJson(),
      requireAuth: false,
    );
    _apiClient.handleNoContentResponse(response);
  }

  /// Exchange an SSO authorization code (+ PKCE verifier) for tokens
  /// No authentication required; code is single-use and burned on any attempt
  Future<AuthResponse> exchangeSsoCode(SsoExchangeRequest request) async {
    final response = await _apiClient.post(
      ApiEndpoints.authSsoExchange,
      body: request.toJson(),
      requireAuth: false,
    );
    return _apiClient.handleResponse(response, AuthResponse.fromJson);
  }

  /// Change password for authenticated user
  /// Requires authentication (USER, ADMIN)
  Future<void> changePassword(PasswordChangeRequest request) async {
    final response = await _apiClient.put(
      ApiEndpoints.authPasswordChange,
      body: request.toJson(),
      requireAuth: true,
    );
    _apiClient.handleNoContentResponse(response);
  }
}
