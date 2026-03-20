// Stub implementation for non-web platforms (mobile, VM, tests, etc.)
// Returns default values (relative paths) unless overridden via --dart-define.
//
// For mobile builds targeting production, use:
// flutter build apk --dart-define=COMMAND_BASE_URL=https://wanderer.tomassir.io/api/command \
//                   --dart-define=QUERY_BASE_URL=https://wanderer.tomassir.io/api/query \
//                   --dart-define=AUTH_BASE_URL=https://wanderer.tomassir.io/api/auth

import 'package:flutter/foundation.dart';

// Compile-time constants from --dart-define (empty string means use default)
const String _commandBaseUrl = String.fromEnvironment('COMMAND_BASE_URL');
const String _queryBaseUrl = String.fromEnvironment('QUERY_BASE_URL');
const String _authBaseUrl = String.fromEnvironment('AUTH_BASE_URL');

// Google Maps API key can be overridden at build time:
// flutter build apk --dart-define=GOOGLE_MAPS_API_KEY=your_key
const String _googleMapsApiKey = String.fromEnvironment(
  'GOOGLE_MAPS_API_KEY',
  defaultValue: 'YOUR_GOOGLE_MAPS_API_KEY_HERE',
);

String getConfigValue(String key, String defaultValue) {
  // Use compile-time constants if defined, otherwise fall back to defaultValue
  switch (key) {
    case 'commandBaseUrl':
      return _commandBaseUrl.isNotEmpty ? _commandBaseUrl : defaultValue;
    case 'queryBaseUrl':
      return _queryBaseUrl.isNotEmpty ? _queryBaseUrl : defaultValue;
    case 'authBaseUrl':
      return _authBaseUrl.isNotEmpty ? _authBaseUrl : defaultValue;
    case 'googleMapsApiKey':
      return _googleMapsApiKey.isNotEmpty ? _googleMapsApiKey : defaultValue;
    default:
      return defaultValue;
  }
}

/// Gets the base app URL for non-web platforms
/// Returns the APP_BASE_URL dart-define or defaults to the production URL
const String _appBaseUrl = String.fromEnvironment('APP_BASE_URL');

String getAppBaseUrl() {
  return _appBaseUrl.isNotEmpty ? _appBaseUrl : 'https://wanderer.tomassir.io';
}

/// Gets the WebSocket URL for non-web platforms
/// For relative paths, constructs full URL using localhost as default
String getWebSocketUrl(String relativePath) {
  // For mobile/desktop, use localhost as default for development
  // In production, this should be configured via --dart-define
  const wsBaseUrl = String.fromEnvironment('WS_BASE_URL');

  debugPrint('getWebSocketUrl: WS_BASE_URL from environment: "$wsBaseUrl"');
  debugPrint('getWebSocketUrl: relativePath: "$relativePath"');

  if (wsBaseUrl.isNotEmpty) {
    final fullUrl = wsBaseUrl + relativePath;
    debugPrint('getWebSocketUrl: Using environment WS_BASE_URL: $fullUrl');
    return fullUrl;
  }

  // Default for Android emulator development
  // 10.0.2.2 is the special IP for "host machine" from Android emulator
  final defaultUrl = 'ws://10.0.2.2:8080$relativePath';
  debugPrint(
      'getWebSocketUrl: No WS_BASE_URL set, using default for Android emulator: $defaultUrl');
  debugPrint(
      'getWebSocketUrl: ⚠️  For physical Android device, set WS_BASE_URL to ws://YOUR_COMPUTER_IP:8080');

  return defaultUrl;
}
