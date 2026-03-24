import 'dart:js_interop';

/// Web-specific implementation using JavaScript interop
/// Reads configuration from window.appConfig injected by Docker

@JS('window.appConfig')
external JSAny? get _appConfig;

@JS('window.location.protocol')
external JSString get _locationProtocol;

@JS('window.location.host')
external JSString get _locationHost;

String getConfigValue(String key, String defaultValue) {
  try {
    final config = _appConfig;
    if (config != null && config.isA<JSObject>()) {
      final jsObj = config as JSObject;
      final value = jsObj[key.toJS];
      if (value != null && value.isA<JSString>()) {
        final strValue = (value as JSString).toDart;
        // Check if value is not empty and not an unsubstituted placeholder
        if (strValue.isNotEmpty && !strValue.contains('{{')) {
          return strValue;
        }
      }
    }
  } catch (e) {
    // Fall back to default if any error occurs
  }
  return defaultValue;
}

/// Gets the base app URL for the web platform
/// First checks window.appConfig.appBaseUrl, then falls back to window.location
String getAppBaseUrl() {
  try {
    // First try to get from appConfig (Docker/Makefile injection)
    final configuredAppBaseUrl = getConfigValue('appBaseUrl', '');
    if (configuredAppBaseUrl.isNotEmpty) {
      return configuredAppBaseUrl;
    }

    final protocol = _locationProtocol.toDart;
    final host = _locationHost.toDart;
    return '$protocol//$host';
  } catch (e) {
    return 'https://wanderer.localwanderer-dev.com';
  }
}

/// Gets the WebSocket URL for web platform
/// First checks window.appConfig.wsBaseUrl, then uses window.location
String getWebSocketUrl(String relativePath) {
  try {
    // First try to get from appConfig (Docker injection)
    final configuredWsUrl = getConfigValue('wsBaseUrl', '');

    // Check if it's a valid URL:
    // - Not empty
    // - Not a relative path (starts with /)
    // - Not an unsubstituted placeholder (contains {{)
    // - Starts with ws:// or wss://
    if (configuredWsUrl.isNotEmpty &&
        !configuredWsUrl.contains('{{') &&
        (configuredWsUrl.startsWith('ws://') ||
            configuredWsUrl.startsWith('wss://'))) {
      return configuredWsUrl.endsWith('/')
          ? configuredWsUrl.substring(0, configuredWsUrl.length - 1) +
              relativePath
          : configuredWsUrl + relativePath;
    }

    // If it's a relative path like /ws, construct full URL from window.location
    if (configuredWsUrl.isNotEmpty &&
        configuredWsUrl.startsWith('/') &&
        !configuredWsUrl.contains('{{')) {
      final protocol = _locationProtocol.toDart;
      final host = _locationHost.toDart;
      final wsProtocol = protocol == 'https:' ? 'wss:' : 'ws:';
      return '$wsProtocol//$host$configuredWsUrl';
    }

    // Fall back to constructing from window.location with the provided relativePath
    final protocol = _locationProtocol.toDart;
    final host = _locationHost.toDart;

    // Use wss for https, ws for http
    final wsProtocol = protocol == 'https:' ? 'wss:' : 'ws:';

    return '$wsProtocol//$host$relativePath';
  } catch (e) {
    // Fallback if location access fails
    return 'ws://localhost:8080$relativePath';
  }
}

@JS()
extension _JSObjectExtension on JSObject {
  external JSAny? operator [](JSString key);
}
