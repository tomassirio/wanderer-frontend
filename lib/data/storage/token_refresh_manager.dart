import 'dart:convert';
import 'package:flutter/foundation.dart' show VoidCallback, debugPrint;
import 'package:http/http.dart' as http;
import '../../core/constants/api_endpoints.dart';
import 'token_storage.dart';

/// Centralized token refresh manager to prevent race conditions.
///
/// Multiple ApiClient instances and the WebSocket client all need to refresh
/// tokens. Without coordination, concurrent refresh attempts with rotating
/// refresh tokens cause one to succeed and the others to invalidate the new
/// token, logging the user out.
///
/// This singleton ensures only one refresh happens at a time across the
/// entire app.
class TokenRefreshManager {
  TokenRefreshManager._();
  static final TokenRefreshManager instance = TokenRefreshManager._();

  /// Invoked after the refresh token is definitively rejected and the stored
  /// session has been cleared. The main isolate wires this to reset the UI to
  /// the guest view, so no screen keeps rendering a stale logged-in state.
  static VoidCallback? onSessionExpired;

  /// Shared future to coalesce concurrent refresh calls.
  Future<bool>? _refreshFuture;

  /// Attempt to refresh the access token.
  ///
  /// If a refresh is already in progress, returns the same future so callers
  /// wait for a single network call instead of firing duplicates.
  ///
  /// [tokenStorage] is the storage instance to read/write tokens from.
  /// [httpClient] is the HTTP client to use for the refresh request.
  Future<bool> refreshIfNeeded({
    TokenStorage? tokenStorage,
    http.Client? httpClient,
  }) async {
    if (_refreshFuture != null) {
      return _refreshFuture!;
    }

    _refreshFuture = _performRefresh(
      tokenStorage: tokenStorage ?? TokenStorage(),
      httpClient: httpClient,
    );

    try {
      return await _refreshFuture!;
    } finally {
      _refreshFuture = null;
    }
  }

  /// Perform the actual token refresh against the auth API.
  Future<bool> _performRefresh({
    required TokenStorage tokenStorage,
    http.Client? httpClient,
  }) async {
    final client = httpClient ?? http.Client();
    final shouldCloseClient = httpClient == null;

    try {
      await tokenStorage.reloadFromDisk();

      final refreshToken = await tokenStorage.getRefreshToken();
      if (refreshToken == null) {
        debugPrint('TokenRefreshManager: No refresh token — clearing tokens');
        await tokenStorage.clearTokens();
        return false;
      }

      debugPrint(
        'TokenRefreshManager: Refreshing token with '
        '${refreshToken.substring(0, refreshToken.length.clamp(0, 10))}...',
      );

      final uri = Uri.parse(
        '${ApiEndpoints.authBaseUrl}${ApiEndpoints.authRefresh}',
      );

      final response = await client.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'refreshToken': refreshToken}),
      );

      debugPrint(
        'TokenRefreshManager: Refresh response status: ${response.statusCode}',
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        final newAccessToken = data['accessToken'] ?? data['access_token'];
        final newRefreshToken =
            data['refreshToken'] ?? data['refresh_token'] ?? refreshToken;
        final tokenType = data['tokenType'] ?? data['token_type'] ?? 'Bearer';
        final expiresIn = data['expiresIn'] ?? data['expires_in'] ?? 3600;

        if (newAccessToken == null) {
          debugPrint(
            'TokenRefreshManager: Response missing accessToken — clearing',
          );
          await tokenStorage.clearTokens();
          return false;
        }

        await tokenStorage.saveTokens(
          accessToken: newAccessToken,
          refreshToken: newRefreshToken,
          tokenType: tokenType,
          expiresIn: expiresIn is int
              ? expiresIn
              : int.tryParse(expiresIn.toString()) ?? 3600,
        );
        debugPrint('TokenRefreshManager: ✅ Token refreshed successfully');
        return true;
      } else if (response.statusCode == 400 ||
          response.statusCode == 401 ||
          response.statusCode == 403) {
        // Definitive auth failure — refresh token is invalid, revoked or
        // expired. The auth service reports these as 400.
        debugPrint(
          'TokenRefreshManager: Refresh token rejected '
          '(${response.statusCode})',
        );
        return _handleRejected(tokenStorage, refreshToken);
      } else {
        // Transient server error (5xx, 429, etc.) — do NOT clear tokens.
        // The refresh token may still be valid; clearing would force an
        // unnecessary re-login.
        debugPrint(
          'TokenRefreshManager: Refresh failed with transient error '
          '${response.statusCode} — keeping tokens for retry',
        );
        return false;
      }
    } on http.ClientException catch (e) {
      // Network error (no connectivity, DNS failure, timeout, etc.)
      // Do NOT clear tokens — the user may regain connectivity.
      debugPrint(
        'TokenRefreshManager: Network error during refresh: $e — '
        'keeping tokens for retry',
      );
      return false;
    } on FormatException catch (e) {
      // Malformed response body
      debugPrint(
        'TokenRefreshManager: Malformed refresh response: $e — '
        'keeping tokens for retry',
      );
      return false;
    } catch (e) {
      // Unknown error — still do NOT aggressively clear tokens
      debugPrint('TokenRefreshManager: ❌ Unexpected refresh error: $e');
      return false;
    } finally {
      if (shouldCloseClient) {
        client.close();
      }
    }
  }

  /// Clears the session after [usedRefreshToken] was rejected, unless another
  /// tab or isolate rotated it in the meantime — then the stored token is
  /// fresh and the caller can retry with it.
  Future<bool> _handleRejected(
    TokenStorage tokenStorage,
    String usedRefreshToken,
  ) async {
    await tokenStorage.reloadFromDisk();
    final current = await tokenStorage.getRefreshToken();
    if (current != null && current != usedRefreshToken) {
      debugPrint('TokenRefreshManager: Token rotated elsewhere — reusing it');
      return true;
    }
    debugPrint('TokenRefreshManager: Clearing session');
    await tokenStorage.clearTokens();
    onSessionExpired?.call();
    return false;
  }

  /// Proactively ensure the access token is valid.
  ///
  /// Call this at app startup or before critical operations to silently
  /// refresh an expired access token when a valid refresh token is available.
  /// Returns true if the token is valid (either not expired, or refreshed
  /// successfully).
  Future<bool> ensureValidToken({
    TokenStorage? tokenStorage,
    http.Client? httpClient,
  }) async {
    final storage = tokenStorage ?? TokenStorage();
    try {
      await storage.reloadFromDisk();

      final isExpired = await storage.isAccessTokenExpired();
      if (!isExpired) return true;

      debugPrint('TokenRefreshManager: Token expired, attempting refresh...');
      return await refreshIfNeeded(
        tokenStorage: storage,
        httpClient: httpClient,
      );
    } catch (e) {
      debugPrint('TokenRefreshManager: Error in ensureValidToken: $e');
      return false;
    }
  }
}
