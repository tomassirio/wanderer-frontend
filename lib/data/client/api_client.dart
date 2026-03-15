import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import '../storage/token_storage.dart';
import '../storage/token_refresh_manager.dart';

/// Exception thrown when user needs to authenticate
/// This is not an error - it's a signal to redirect to login without showing error messages
class AuthenticationRedirectException implements Exception {
  final String message;
  AuthenticationRedirectException([this.message = 'Authentication required']);

  @override
  String toString() => message;
}

/// Base API client with authentication support
class ApiClient {
  final http.Client _httpClient;
  final TokenStorage _tokenStorage;
  final String baseUrl;

  ApiClient({
    required this.baseUrl,
    http.Client? httpClient,
    TokenStorage? tokenStorage,
  })  : _httpClient = httpClient ?? http.Client(),
        _tokenStorage = tokenStorage ?? TokenStorage();

  /// GET request
  Future<http.Response> get(
    String endpoint, {
    bool requireAuth = false,
    Map<String, String>? headers,
  }) async {
    // Proactively refresh token if expired (OAuth2 best practice)
    if (requireAuth) {
      await _ensureValidToken();
    }

    final uri = Uri.parse('$baseUrl$endpoint');
    final requestHeaders = await _buildHeaders(requireAuth, headers);

    var response = await _httpClient.get(uri, headers: requestHeaders);

    // If unauthorized and we need auth, try to refresh token (fallback)
    if (response.statusCode == 401 && requireAuth) {
      final refreshed = await _refreshTokenIfNeeded();
      if (refreshed) {
        // Retry the request with new token
        final newHeaders = await _buildHeaders(requireAuth, headers);
        response = await _httpClient.get(uri, headers: newHeaders);
      } else {
        // Refresh failed, redirect to login
        _handleUnauthorized();
      }
    }

    return response;
  }

  /// POST request
  Future<http.Response> post(
    String endpoint, {
    required Map<String, dynamic> body,
    bool requireAuth = false,
    Map<String, String>? headers,
  }) async {
    // Proactively refresh token if expired (OAuth2 best practice)
    if (requireAuth) {
      await _ensureValidToken();
    }

    final uri = Uri.parse('$baseUrl$endpoint');
    final requestHeaders = await _buildHeaders(requireAuth, headers);

    var response = await _httpClient.post(
      uri,
      headers: requestHeaders,
      body: jsonEncode(body),
    );

    if (response.statusCode == 401 && requireAuth) {
      final refreshed = await _refreshTokenIfNeeded();
      if (refreshed) {
        final newHeaders = await _buildHeaders(requireAuth, headers);
        response = await _httpClient.post(
          uri,
          headers: newHeaders,
          body: jsonEncode(body),
        );
      } else {
        // Refresh failed, redirect to login
        _handleUnauthorized();
      }
    }

    return response;
  }

  /// POST request with raw body (for sending plain values like enums)
  Future<http.Response> postRaw(
    String endpoint, {
    required dynamic body,
    bool requireAuth = false,
    Map<String, String>? headers,
  }) async {
    // Proactively refresh token if expired (OAuth2 best practice)
    if (requireAuth) {
      await _ensureValidToken();
    }

    final uri = Uri.parse('$baseUrl$endpoint');
    final requestHeaders = await _buildHeaders(requireAuth, headers);

    var response = await _httpClient.post(
      uri,
      headers: requestHeaders,
      body: jsonEncode(body),
    );

    if (response.statusCode == 401 && requireAuth) {
      final refreshed = await _refreshTokenIfNeeded();
      if (refreshed) {
        final newHeaders = await _buildHeaders(requireAuth, headers);
        response = await _httpClient.post(
          uri,
          headers: newHeaders,
          body: jsonEncode(body),
        );
      } else {
        // Refresh failed, redirect to login
        _handleUnauthorized();
      }
    }

    return response;
  }

  /// PUT request
  Future<http.Response> put(
    String endpoint, {
    required Map<String, dynamic> body,
    bool requireAuth = false,
    Map<String, String>? headers,
  }) async {
    // Proactively refresh token if expired (OAuth2 best practice)
    if (requireAuth) {
      await _ensureValidToken();
    }

    final uri = Uri.parse('$baseUrl$endpoint');
    final requestHeaders = await _buildHeaders(requireAuth, headers);

    var response = await _httpClient.put(
      uri,
      headers: requestHeaders,
      body: jsonEncode(body),
    );

    if (response.statusCode == 401 && requireAuth) {
      final refreshed = await _refreshTokenIfNeeded();
      if (refreshed) {
        final newHeaders = await _buildHeaders(requireAuth, headers);
        response = await _httpClient.put(
          uri,
          headers: newHeaders,
          body: jsonEncode(body),
        );
      } else {
        // Refresh failed, redirect to login
        _handleUnauthorized();
      }
    }

    return response;
  }

  /// PATCH request
  Future<http.Response> patch(
    String endpoint, {
    required Map<String, dynamic> body,
    bool requireAuth = false,
    Map<String, String>? headers,
  }) async {
    // Proactively refresh token if expired (OAuth2 best practice)
    if (requireAuth) {
      await _ensureValidToken();
    }

    final uri = Uri.parse('$baseUrl$endpoint');
    final requestHeaders = await _buildHeaders(requireAuth, headers);

    var response = await _httpClient.patch(
      uri,
      headers: requestHeaders,
      body: jsonEncode(body),
    );

    if (response.statusCode == 401 && requireAuth) {
      final refreshed = await _refreshTokenIfNeeded();
      if (refreshed) {
        final newHeaders = await _buildHeaders(requireAuth, headers);
        response = await _httpClient.patch(
          uri,
          headers: newHeaders,
          body: jsonEncode(body),
        );
      } else {
        // Refresh failed, redirect to login
        _handleUnauthorized();
      }
    }

    return response;
  }

  /// DELETE request
  Future<http.Response> delete(
    String endpoint, {
    Map<String, dynamic>? body,
    bool requireAuth = false,
    Map<String, String>? headers,
  }) async {
    // Proactively refresh token if expired (OAuth2 best practice)
    if (requireAuth) {
      await _ensureValidToken();
    }

    final uri = Uri.parse('$baseUrl$endpoint');
    final requestHeaders = await _buildHeaders(requireAuth, headers);

    var response = await _httpClient.delete(
      uri,
      headers: requestHeaders,
      body: body != null ? jsonEncode(body) : null,
    );

    if (response.statusCode == 401 && requireAuth) {
      final refreshed = await _refreshTokenIfNeeded();
      if (refreshed) {
        final newHeaders = await _buildHeaders(requireAuth, headers);
        response = await _httpClient.delete(
          uri,
          headers: newHeaders,
          body: body != null ? jsonEncode(body) : null,
        );
      } else {
        // Refresh failed, redirect to login
        _handleUnauthorized();
      }
    }

    return response;
  }

  /// Build headers with auth token if required
  Future<Map<String, String>> _buildHeaders(
    bool requireAuth,
    Map<String, String>? additionalHeaders,
  ) async {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      ...?additionalHeaders,
    };

    if (requireAuth) {
      final accessToken = await _tokenStorage.getAccessToken();
      final tokenType = await _tokenStorage.getTokenType() ?? 'Bearer';

      if (accessToken != null) {
        headers['Authorization'] = '$tokenType $accessToken';
      }
    }

    return headers;
  }

  /// Ensure access token is valid, refreshing proactively if expired
  /// This follows OAuth2 best practices by checking expiration before making requests
  /// The reload() call ensures background isolates read fresh token data
  Future<void> _ensureValidToken() async {
    try {
      // Delegate to the centralized manager so that all ApiClient instances
      // and the WebSocket client share a single in-flight refresh call.
      final valid = await TokenRefreshManager.instance.ensureValidToken(
        tokenStorage: _tokenStorage,
        httpClient: _httpClient,
      );
      debugPrint('ApiClient: ensureValidToken result: $valid');
    } catch (e) {
      debugPrint('ApiClient: Error in _ensureValidToken: $e');
      // Fallback to 401 handling will still work
    }
  }

  /// Refresh the access token using refresh token
  /// Uses the centralized TokenRefreshManager to prevent concurrent refresh
  /// attempts across multiple ApiClient instances (OAuth2 best practice)
  Future<bool> _refreshTokenIfNeeded() async {
    return TokenRefreshManager.instance.refreshIfNeeded(
      tokenStorage: _tokenStorage,
      httpClient: _httpClient,
    );
  }

  /// Handle unauthorized access
  /// Throws AuthenticationRedirectException to signal that
  /// the user needs to authenticate. The UI layer is responsible
  /// for handling navigation to the auth screen.
  void _handleUnauthorized() {
    throw AuthenticationRedirectException();
  }

  /// Handle API response with type conversion
  T handleResponse<T>(
    http.Response response,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = jsonDecode(response.body);
      return fromJson(data);
    } else {
      throw _handleError(response);
    }
  }

  /// Handle list response
  List<T> handleListResponse<T>(
    http.Response response,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((item) => fromJson(item)).toList();
    } else {
      throw _handleError(response);
    }
  }

  /// Handle no content response (for DELETE operations)
  void handleNoContentResponse(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _handleError(response);
    }
    // Success - no content to return
  }

  /// Handle 202 Accepted response from async operations
  /// Returns the ID from the response body - supports both plain string ID
  /// and JSON object { "id": "..." } formats
  /// Also handles empty responses (common for DELETE operations) by returning empty string
  String handleAcceptedResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final body = response.body.trim();

      // Handle empty body (common for DELETE operations like unfollow)
      if (body.isEmpty) {
        return '';
      }

      // Try to decode as JSON first
      final decoded = jsonDecode(body);

      // If it's a plain string (UUID directly), return it
      if (decoded is String) {
        return decoded;
      }

      // If it's a Map, extract the id field
      if (decoded is Map<String, dynamic>) {
        final id = decoded['id'] as String?;
        if (id != null && id.isNotEmpty) {
          return id;
        }
        // Return empty string if no id field but response was successful
        return '';
      }

      // For any other valid JSON, return empty string
      return '';
    } else {
      throw _handleError(response);
    }
  }

  /// Handle errors from API
  Exception _handleError(http.Response response) {
    try {
      // Try to parse as JSON first
      final error = jsonDecode(response.body);
      final message = error['message'] ?? error['error'] ?? 'Unknown error';
      return Exception('API Error (${response.statusCode}): $message');
    } catch (e) {
      // If not JSON, return the raw body (backend might return plain text)
      final body = response.body.trim();
      if (body.isNotEmpty && body.length < 200) {
        return Exception('API Error (${response.statusCode}): $body');
      }
      return Exception('API Error (${response.statusCode})');
    }
  }
}
