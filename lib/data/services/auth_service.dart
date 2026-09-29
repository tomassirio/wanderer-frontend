import '../models/auth_models.dart';
import '../client/clients.dart';
import '../storage/token_storage.dart';
import '../storage/token_refresh_manager.dart';

/// Service for authentication operations
class AuthService {
  final AuthClient _authClient;
  final UserQueryClient _userQueryClient;
  final TokenStorage _tokenStorage;

  AuthService({
    AuthClient? authClient,
    UserQueryClient? userQueryClient,
    TokenStorage? tokenStorage,
  })  : _authClient = authClient ?? AuthClient(),
        _userQueryClient = userQueryClient ?? UserQueryClient(),
        _tokenStorage = tokenStorage ?? TokenStorage();

  /// Register a new user
  /// Returns a pending response; user must verify email before logging in
  Future<RegisterPendingResponse> register(RegisterRequest request) async {
    return await _authClient.register(request);
  }

  /// Verify email address with token received by email
  /// Returns AuthResponse with tokens and logs the user in
  Future<AuthResponse> verifyEmail(VerifyEmailRequest request) async {
    final authResponse = await _authClient.verifyEmail(request);
    await _persistSession(authResponse);
    return authResponse;
  }

  /// Login with email and password
  Future<AuthResponse> login(LoginRequest request) async {
    final authResponse = await _authClient.login(request);
    await _persistSession(authResponse);
    return authResponse;
  }

  /// Exchange an SSO authorization code (+ PKCE verifier) for tokens
  /// and log the user in
  Future<AuthResponse> completeSsoLogin({
    required String code,
    required String codeVerifier,
  }) async {
    final authResponse = await _authClient.exchangeSsoCode(
      SsoExchangeRequest(code: code, codeVerifier: codeVerifier),
    );
    await _persistSession(authResponse);
    return authResponse;
  }

  /// Save tokens and fetch/persist the user profile (userId, username,
  /// displayName, avatar). Shared by [login], [verifyEmail] and
  /// [completeSsoLogin].
  Future<void> _persistSession(AuthResponse authResponse) async {
    // Save tokens first
    await _tokenStorage.saveTokens(
      accessToken: authResponse.accessToken,
      refreshToken: authResponse.refreshToken,
      tokenType: authResponse.tokenType,
      expiresIn: authResponse.expiresIn,
    );

    // Fetch user profile to get userId and username
    try {
      final profile = await _userQueryClient.getCurrentUser();

      // Update tokens with user info
      await _tokenStorage.saveTokens(
        accessToken: authResponse.accessToken,
        refreshToken: authResponse.refreshToken,
        tokenType: authResponse.tokenType,
        expiresIn: authResponse.expiresIn,
        userId: profile.id,
        username: profile.username,
        displayName: profile.displayName,
      );
      await _tokenStorage.saveAvatarUrl(profile.avatarUrl);
    } catch (e) {
      // If profile fetch fails, continue with just tokens
      // Error is silently ignored in production
    }
  }

  /// Logout and invalidate token
  Future<void> logout() async {
    try {
      // Try to call logout endpoint (best effort)
      await _authClient.logout();
    } catch (e) {
      // Continue even if API call fails
    } finally {
      // Always clear local tokens
      await _tokenStorage.clearTokens();
    }
  }

  /// Request password reset email
  Future<void> requestPasswordReset(String email) async {
    final request = PasswordResetRequest(email: email);
    await _authClient.initiatePasswordReset(request);
  }

  /// Change password (when logged in)
  Future<void> changePassword(PasswordChangeRequest request) async {
    await _authClient.changePassword(request);
  }

  /// Check if user is currently logged in
  Future<bool> isLoggedIn() async {
    return await _tokenStorage.isLoggedIn();
  }

  /// Get current user ID
  Future<String?> getCurrentUserId() async {
    return await _tokenStorage.getUserId();
  }

  /// Get current username
  Future<String?> getCurrentUsername() async {
    return await _tokenStorage.getUsername();
  }

  /// Get current user's display name
  Future<String?> getCurrentDisplayName() async {
    return await _tokenStorage.getDisplayName();
  }

  /// Get current user's avatar URL
  Future<String?> getCurrentAvatarUrl() async {
    return await _tokenStorage.getAvatarUrl();
  }

  /// Refresh user details (displayName, avatarUrl) from the API
  /// and save them to local storage. Returns true if successful.
  Future<bool> refreshUserDetails() async {
    try {
      final profile = await _userQueryClient.getCurrentUser();
      await _tokenStorage.saveDisplayName(profile.displayName);
      await _tokenStorage.saveAvatarUrl(profile.avatarUrl);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Check if current user is admin
  Future<bool> isAdmin() async {
    return await _tokenStorage.isAdmin();
  }

  /// Refresh access token using refresh token
  /// Returns true if refresh was successful, false otherwise
  /// Delegates to the centralized TokenRefreshManager to prevent race
  /// conditions when multiple components try to refresh simultaneously.
  Future<bool> refreshAccessToken() async {
    return TokenRefreshManager.instance.refreshIfNeeded();
  }

  /// Check if the current access token is expired
  Future<bool> isTokenExpired() async {
    return await _tokenStorage.isAccessTokenExpired();
  }
}
