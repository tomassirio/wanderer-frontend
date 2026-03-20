import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import '../storage/token_storage.dart';
import '../storage/token_refresh_manager.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/config/api_endpoints_stub.dart'
    if (dart.library.js_interop) '../../core/config/api_endpoints_web.dart'
    as config;

/// Connection state for the WebSocket client
enum WebSocketConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
}

/// WebSocket client for real-time communication
class WebSocketClient {
  final TokenStorage _tokenStorage;
  final http.Client _httpClient;
  final String _baseUrl;

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;

  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final _connectionStateController =
      StreamController<WebSocketConnectionState>.broadcast();

  WebSocketConnectionState _connectionState =
      WebSocketConnectionState.disconnected;
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  static const Duration _reconnectDelay = Duration(seconds: 5);
  static const Duration _pingInterval = Duration(seconds: 30);

  bool _shouldReconnect = true;

  // Track subscription IDs for STOMP protocol
  int _nextSubscriptionId = 0;
  final Map<String, String> _topicSubscriptions =
      {}; // topic -> subscription ID

  WebSocketClient({
    TokenStorage? tokenStorage,
    http.Client? httpClient,
    String? baseUrl,
  })  : _tokenStorage = tokenStorage ?? TokenStorage(),
        _httpClient = httpClient ?? http.Client(),
        _baseUrl = baseUrl ?? ApiEndpoints.wsBaseUrl;

  /// Stream of incoming messages
  Stream<Map<String, dynamic>> get messages => _messageController.stream;

  /// Stream of connection state changes
  Stream<WebSocketConnectionState> get connectionState =>
      _connectionStateController.stream;

  /// Current connection state
  WebSocketConnectionState get currentState => _connectionState;

  /// Whether the client is connected
  bool get isConnected =>
      _connectionState == WebSocketConnectionState.connected;

  /// Connect to the WebSocket server
  Future<void> connect() async {
    if (_connectionState == WebSocketConnectionState.connected ||
        _connectionState == WebSocketConnectionState.connecting) {
      return;
    }

    _shouldReconnect = true;
    await _establishConnection();
  }

  Future<void> _establishConnection({bool isRetryAfterRefresh = false}) async {
    _updateConnectionState(WebSocketConnectionState.connecting);

    try {
      // Ensure token is valid before connecting
      await _ensureValidToken();

      final token = await _tokenStorage.getAccessToken();

      if (token == null || token.isEmpty) {
        debugPrint('WebSocket: No access token available, cannot connect');
        _updateConnectionState(WebSocketConnectionState.disconnected);
        _shouldReconnect = false;
        return;
      }

      final wsUrl = _buildWebSocketUrl(token);

      // Skip connection if URL appears to be pointing to Flutter dev server
      // (typically localhost with high port numbers used by Flutter)
      final uri = Uri.tryParse(wsUrl);
      if (uri != null && uri.host == 'localhost' && uri.port > 50000) {
        debugPrint(
            'WebSocket: Skipping connection - dev server detected ($wsUrl)');
        debugPrint(
            'WebSocket: Configure WS_BASE_URL or wsBaseUrl for real WebSocket connection');
        _updateConnectionState(WebSocketConnectionState.disconnected);
        _shouldReconnect = false;
        return;
      }

      debugPrint(
          'WebSocket: Connecting to $wsUrl (platform: ${kIsWeb ? "web" : "mobile"})');
      debugPrint(
          'WebSocket: Protocol: ${wsUrl.startsWith("wss://") ? "WSS (secure)" : "WS (insecure)"}');
      debugPrint('WebSocket: Base URL from config: $_baseUrl');

      // Use platform-specific WebSocket implementation
      // IOWebSocketChannel works on mobile (Android/iOS)
      // WebSocketChannel.connect works on web
      if (kIsWeb) {
        _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      } else {
        // Use IOWebSocketChannel for mobile platforms with custom headers
        debugPrint('WebSocket: Using IOWebSocketChannel for mobile');

        try {
          _channel = IOWebSocketChannel.connect(
            wsUrl,
            pingInterval: const Duration(seconds: 30),
          );
        } catch (e) {
          debugPrint('WebSocket: IOWebSocketChannel.connect failed: $e');
          rethrow;
        }
      }

      debugPrint('WebSocket: Channel created, waiting for ready state...');

      // Wait for the connection to be established
      await _channel!.ready;

      debugPrint('WebSocket: Channel ready!');

      _updateConnectionState(WebSocketConnectionState.connected);
      _reconnectAttempts = 0;

      _subscription = _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDone,
        cancelOnError: false,
      );

      _startPingTimer();

      debugPrint('WebSocket: Connected successfully');
      debugPrint('WebSocket: Starting message listener...');
    } catch (e, stackTrace) {
      final errorStr = e.toString();
      debugPrint('WebSocket: Connection error: $errorStr');
      debugPrint('WebSocket: Stack trace: $stackTrace');

      // Check if this is a 401 error and we haven't already retried
      if (!isRetryAfterRefresh && errorStr.contains('401')) {
        debugPrint('WebSocket: Got 401, attempting token refresh and retry');
        final refreshed = await _refreshToken();
        if (refreshed) {
          // Retry connection with new token
          await _establishConnection(isRetryAfterRefresh: true);
          return;
        }
      }

      _updateConnectionState(WebSocketConnectionState.disconnected);
      _scheduleReconnect();
    }
  }

  /// Ensure access token is valid, refreshing proactively if expired
  Future<void> _ensureValidToken() async {
    try {
      await TokenRefreshManager.instance
          .ensureValidToken(httpClient: _httpClient);
    } catch (e) {
      debugPrint('WebSocket: Error checking token expiration: $e');
    }
  }

  /// Refresh the access token using the centralized TokenRefreshManager
  Future<bool> _refreshToken() async {
    return TokenRefreshManager.instance
        .refreshIfNeeded(httpClient: _httpClient);
  }

  String _buildWebSocketUrl(String? token) {
    // Determine if we need ws:// or wss://
    String wsUrl = _baseUrl;

    // If baseUrl is a relative path, we need to construct the full URL
    if (wsUrl.startsWith('/')) {
      // Use the config helper to get the proper WebSocket URL
      wsUrl = config.getWebSocketUrl(wsUrl);
    }

    // Convert http(s) to ws(s) if needed
    if (wsUrl.startsWith('http://')) {
      wsUrl = wsUrl.replaceFirst('http://', 'ws://');
    } else if (wsUrl.startsWith('https://')) {
      wsUrl = wsUrl.replaceFirst('https://', 'wss://');
    }

    // Add token as query parameter if available
    if (token != null && token.isNotEmpty) {
      final separator = wsUrl.contains('?') ? '&' : '?';
      wsUrl = '$wsUrl${separator}token=$token';
    }

    return wsUrl;
  }

  void _handleMessage(dynamic message) {
    try {
      final String messageStr =
          message is String ? message : message.toString();

      debugPrint(
          'WebSocket: Raw message received (length: ${messageStr.length}, platform: ${kIsWeb ? "web" : "mobile"})');

      // Handle ping/pong
      if (messageStr == 'PONG' || messageStr == 'pong') {
        debugPrint('WebSocket: Received pong');
        return;
      }

      // Detect if we received HTML instead of JSON (wrong routing - frontend served instead of backend)
      if (messageStr.trimLeft().startsWith('<!DOCTYPE') ||
          messageStr.trimLeft().startsWith('<html')) {
        debugPrint(
            'WebSocket: ERROR - Received HTML instead of JSON. The /ws endpoint is being served by the frontend nginx instead of the backend WebSocket server. Check your ingress/proxy configuration.');
        _handleError('WebSocket endpoint misconfigured - receiving HTML');
        return;
      }

      debugPrint('WebSocket: Parsing JSON message...');
      final Map<String, dynamic> data = jsonDecode(messageStr);
      debugPrint(
          'WebSocket: Received message type: ${data['type']} (platform: ${kIsWeb ? "web" : "mobile"})');
      _messageController.add(data);
    } catch (e, stackTrace) {
      debugPrint('WebSocket: Error parsing message: $e');
      debugPrint('WebSocket: Stack trace: $stackTrace');
    }
  }

  void _handleError(dynamic error) {
    debugPrint(
        'WebSocket: Error occurred: $error (platform: ${kIsWeb ? "web" : "mobile"})');
    debugPrint('WebSocket: Connection state before error: $_connectionState');
    _updateConnectionState(WebSocketConnectionState.disconnected);
    // Clear subscription tracking on disconnection so they can be reestablished
    _topicSubscriptions.clear();
    debugPrint(
        'WebSocket: Cleared ${_topicSubscriptions.length} topic subscriptions');
    _scheduleReconnect();
  }

  void _handleDone() {
    debugPrint(
        'WebSocket: Connection closed (platform: ${kIsWeb ? "web" : "mobile"})');
    debugPrint('WebSocket: Connection state before close: $_connectionState');
    _updateConnectionState(WebSocketConnectionState.disconnected);
    _stopPingTimer();
    // Clear subscription tracking on disconnection so they can be reestablished
    _topicSubscriptions.clear();
    debugPrint(
        'WebSocket: Cleared ${_topicSubscriptions.length} topic subscriptions');
    _scheduleReconnect();
  }

  void _updateConnectionState(WebSocketConnectionState state) {
    if (_connectionState != state) {
      _connectionState = state;
      _connectionStateController.add(state);
    }
  }

  void _scheduleReconnect() {
    if (!_shouldReconnect) return;
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint('WebSocket: Max reconnection attempts reached');
      return;
    }

    _reconnectTimer?.cancel();
    _reconnectAttempts++;

    final delay = _reconnectDelay * _reconnectAttempts;
    debugPrint(
        'WebSocket: Reconnecting in ${delay.inSeconds}s (attempt $_reconnectAttempts)');

    _updateConnectionState(WebSocketConnectionState.reconnecting);

    _reconnectTimer = Timer(delay, () {
      if (_shouldReconnect) {
        _establishConnection();
      }
    });
  }

  void _startPingTimer() {
    _stopPingTimer();
    _pingTimer = Timer.periodic(_pingInterval, (_) {
      if (isConnected) {
        send({'type': 'PING'});
      }
    });
  }

  void _stopPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = null;
  }

  /// Send a message to the server
  void send(Map<String, dynamic> message) {
    if (!isConnected || _channel == null) {
      debugPrint(
          'WebSocket: Cannot send message - not connected (isConnected: $isConnected, channel: ${_channel != null})');
      return;
    }

    try {
      final jsonStr = jsonEncode(message);
      debugPrint(
          'WebSocket: Sending message: ${message['type']} (platform: ${kIsWeb ? "web" : "mobile"})');
      _channel!.sink.add(jsonStr);
      debugPrint('WebSocket: Message sent successfully');
    } catch (e) {
      debugPrint('WebSocket: Error sending message: $e');
    }
  }

  /// Subscribe to a topic
  void subscribe(String topic) {
    debugPrint(
        'WebSocket: subscribe() called for topic: $topic (platform: ${kIsWeb ? "web" : "mobile"})');
    debugPrint('WebSocket: Current connection state: $_connectionState');
    debugPrint('WebSocket: Channel exists: ${_channel != null}');

    // Check if already subscribed to this topic
    if (_topicSubscriptions.containsKey(topic)) {
      debugPrint(
          'WebSocket: Already subscribed to $topic with ID ${_topicSubscriptions[topic]}, skipping duplicate subscription');
      return;
    }

    // Check if we're actually connected before subscribing
    if (!isConnected || _channel == null) {
      debugPrint(
          'WebSocket: Cannot subscribe to $topic - not connected (isConnected: $isConnected, channel: ${_channel != null})');
      return;
    }

    // Generate a unique subscription ID for this topic
    final subscriptionId = 'sub-${_nextSubscriptionId++}';
    _topicSubscriptions[topic] = subscriptionId;

    final message = {
      'type': 'SUBSCRIBE',
      'destination': topic,
      'id': subscriptionId,
    };

    debugPrint('WebSocket: Sending SUBSCRIBE message: $message');
    send(message);
    debugPrint('WebSocket: Subscribed to $topic with ID $subscriptionId');
  }

  /// Unsubscribe from a topic
  void unsubscribe(String topic) {
    final subscriptionId = _topicSubscriptions[topic];
    if (subscriptionId != null) {
      send({
        'type': 'UNSUBSCRIBE',
        'id': subscriptionId,
      });
      _topicSubscriptions.remove(topic);
      debugPrint('WebSocket: Unsubscribed from $topic (ID: $subscriptionId)');
    } else {
      debugPrint(
          'WebSocket: Cannot unsubscribe from $topic - no subscription ID found');
    }
  }

  /// Disconnect from the WebSocket server
  Future<void> disconnect() async {
    debugPrint('WebSocket: Disconnecting');
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _stopPingTimer();

    await _subscription?.cancel();
    await _channel?.sink.close();

    _channel = null;
    _subscription = null;
    _topicSubscriptions.clear(); // Clear subscription tracking
    _nextSubscriptionId = 0; // Reset subscription ID counter

    _updateConnectionState(WebSocketConnectionState.disconnected);
  }

  /// Dispose resources
  void dispose() {
    disconnect();
    _messageController.close();
    _connectionStateController.close();
  }
}
