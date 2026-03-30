import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:wanderer_frontend/data/client/websocket_client.dart';
import 'package:wanderer_frontend/data/models/websocket/websocket_event.dart';
import 'package:wanderer_frontend/core/constants/api_endpoints.dart';

/// Singleton service for managing WebSocket connections and subscriptions
class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;

  WebSocketService._internal();

  WebSocketClient? _client;
  StreamSubscription? _messageSubscription;
  StreamSubscription<WebSocketConnectionState>? _connectionStateSubscription;

  final _eventController = StreamController<WebSocketEvent>.broadcast();
  final _tripEventControllers = <String, StreamController<WebSocketEvent>>{};
  final _userEventControllers = <String, StreamController<WebSocketEvent>>{};
  final Set<String> _subscribedTrips = {};
  final Set<String> _subscribedUsers = {};

  bool _isInitialized = false;

  /// Stream of all WebSocket events
  Stream<WebSocketEvent> get events => _eventController.stream;

  /// Connection state stream
  Stream<WebSocketConnectionState> get connectionState =>
      _client?.connectionState ?? const Stream.empty();

  /// Whether the service is connected
  bool get isConnected => _client?.isConnected ?? false;

  /// Initialize the WebSocket service
  Future<void> initialize() async {
    if (_isInitialized) return;

    _client = WebSocketClient();

    _messageSubscription = _client!.messages.listen(_handleMessage);

    // Listen for connection state changes to resubscribe when reconnected
    _connectionStateSubscription = _client!.connectionState.listen(
      _handleConnectionStateChange,
    );

    _isInitialized = true;
    debugPrint('WebSocketService: Initialized');
  }

  void _handleConnectionStateChange(WebSocketConnectionState state) {
    debugPrint('WebSocketService: Connection state changed to $state');
    if (state == WebSocketConnectionState.connected) {
      // Subscribe to all pending subscriptions when connection is established
      _subscribeToAllPendingTrips();
      _subscribeToAllPendingUsers();
    }
  }

  void _subscribeToAllPendingTrips() {
    if (_subscribedTrips.isEmpty) return;
    
    for (final tripId in _subscribedTrips) {
      _client?.subscribe(ApiEndpoints.wsTripTopic(tripId));
    }
    
    if (kDebugMode) {
      debugPrint('WebSocketService: Resubscribed to ${_subscribedTrips.length} trips');
    }
  }

  void _subscribeToAllPendingUsers() {
    if (_subscribedUsers.isEmpty) return;
    
    for (final userId in _subscribedUsers) {
      _client?.subscribe(ApiEndpoints.wsUserTopic(userId));
    }
    
    if (kDebugMode) {
      debugPrint('WebSocketService: Resubscribed to ${_subscribedUsers.length} users');
    }
  }

  /// Connect to the WebSocket server
  Future<void> connect() async {
    if (!_isInitialized) {
      await initialize();
    }

    await _client?.connect();
    // Note: Subscriptions are handled by _handleConnectionStateChange
    // when the connection is established
  }

  /// Disconnect from the WebSocket server
  Future<void> disconnect() async {
    await _client?.disconnect();
  }

  /// Subscribe to events for a specific trip
  Stream<WebSocketEvent> subscribeToTrip(String tripId) {
    if (kDebugMode) {
      debugPrint('WebSocketService: subscribeToTrip called for $tripId');
    }

    if (!_tripEventControllers.containsKey(tripId)) {
      _tripEventControllers[tripId] =
          StreamController<WebSocketEvent>.broadcast();
    }

    if (!_subscribedTrips.contains(tripId)) {
      _subscribedTrips.add(tripId);
      if (isConnected) {
        _client?.subscribe(ApiEndpoints.wsTripTopic(tripId));
        if (kDebugMode) {
          debugPrint('WebSocketService: Subscribed to trip $tripId');
        }
      } else {
        if (kDebugMode) {
          debugPrint(
            'WebSocketService: NOT connected, cannot subscribe to trip $tripId',
          );
        }
      }
    }

    return _tripEventControllers[tripId]!.stream;
  }

  /// Unsubscribe from events for a specific trip
  void unsubscribeFromTrip(String tripId) {
    if (kDebugMode) {
      debugPrint('WebSocketService: unsubscribeFromTrip called for $tripId');
    }

    if (_subscribedTrips.contains(tripId)) {
      _subscribedTrips.remove(tripId);
      // Always call unsubscribe to clean up client-side tracking,
      // even if not connected (the client will handle it gracefully)
      _client?.unsubscribe(ApiEndpoints.wsTripTopic(tripId));
    }

    // Close and remove the controller
    if (_tripEventControllers.containsKey(tripId)) {
      _tripEventControllers[tripId]?.close();
      _tripEventControllers.remove(tripId);
    }
  }

  /// Subscribe to multiple trips at once
  void subscribeToTrips(List<String> tripIds) {
    for (final tripId in tripIds) {
      subscribeToTrip(tripId);
    }
  }

  /// Unsubscribe from all trips
  void unsubscribeFromAllTrips() {
    final tripIds = List<String>.from(_subscribedTrips);
    for (final tripId in tripIds) {
      unsubscribeFromTrip(tripId);
    }
  }

  /// Subscribe to events for a specific user
  Stream<WebSocketEvent> subscribeToUser(String userId) {
    if (kDebugMode) {
      debugPrint('WebSocketService: subscribeToUser called for $userId');
    }

    if (!_userEventControllers.containsKey(userId)) {
      _userEventControllers[userId] =
          StreamController<WebSocketEvent>.broadcast();
    }

    if (!_subscribedUsers.contains(userId)) {
      _subscribedUsers.add(userId);
      if (isConnected) {
        _client?.subscribe(ApiEndpoints.wsUserTopic(userId));
        if (kDebugMode) {
          debugPrint('WebSocketService: Subscribed to user $userId');
        }
      }
    }

    return _userEventControllers[userId]!.stream;
  }

  /// Unsubscribe from events for a specific user
  void unsubscribeFromUser(String userId) {
    if (_subscribedUsers.contains(userId)) {
      _subscribedUsers.remove(userId);
      // Always call unsubscribe to clean up client-side tracking,
      // even if not connected (the client will handle it gracefully)
      _client?.unsubscribe(ApiEndpoints.wsUserTopic(userId));
      if (kDebugMode) {
        debugPrint('WebSocketService: Unsubscribed from user $userId');
      }
    }

    // Close and remove the controller
    _userEventControllers[userId]?.close();
    _userEventControllers.remove(userId);
  }

  /// Unsubscribe from all users
  void unsubscribeFromAllUsers() {
    final userIds = List<String>.from(_subscribedUsers);
    for (final userId in userIds) {
      unsubscribeFromUser(userId);
    }
  }

  void _handleMessage(Map<String, dynamic> data) {
    try {
      final event = _parseEvent(data);

      // Emit to global stream
      _eventController.add(event);

      // For user profile events (avatar, profile updates), the tripId field contains the userId
      if (event.type == WebSocketEventType.userAvatarUploaded ||
          event.type == WebSocketEventType.userAvatarDeleted ||
          event.type == WebSocketEventType.userProfileUpdated) {
        final userId = event
            .tripId; // The tripId field actually contains userId for user events
        if (userId != null && userId.isNotEmpty) {
          _emitToUserStream(userId, event);
        }
        return; // Don't process as trip event
      }

      // Determine the effective trip ID for routing.
      // Some events (e.g. TRIP_UPDATE_CREATED) only carry tripId inside
      // the payload, not at the top level.  Fall back to the raw JSON
      // payload when the parsed event has a null/empty tripId.
      String? effectiveTripId = event.tripId;
      if (effectiveTripId == null || effectiveTripId.isEmpty) {
        final payload = data['payload'] as Map<String, dynamic>?;
        effectiveTripId =
            data['tripId'] as String? ?? payload?['tripId'] as String?;
      }

      // Emit to trip-specific stream if applicable
      if (effectiveTripId != null &&
          effectiveTripId.isNotEmpty &&
          _tripEventControllers.containsKey(effectiveTripId)) {
        _tripEventControllers[effectiveTripId]!.add(event);
      }

      // Emit to user-specific streams for user relationship events
      if (event is UserFollowedEvent) {
        // Send to both follower and followed users
        _emitToUserStream(event.followerId, event);
        _emitToUserStream(event.followedId, event);
      } else if (event is FriendRequestSentEvent) {
        // Send to both sender and receiver
        _emitToUserStream(event.senderId, event);
        _emitToUserStream(event.receiverId, event);
      } else if (event is NotificationCreatedEvent) {
        _emitToUserStream(event.recipientId, event);
      }
    } catch (e) {
      debugPrint('WebSocketService: Error handling message: $e');
    }
  }

  void _emitToUserStream(String userId, WebSocketEvent event) {
    if (_userEventControllers.containsKey(userId)) {
      _userEventControllers[userId]!.add(event);
    }
  }

  WebSocketEvent _parseEvent(Map<String, dynamic> data) {
    final typeStr = data['type'] as String?;
    final type = WebSocketEvent.parseEventType(typeStr);

    switch (type) {
      // Trip events
      case WebSocketEventType.tripCreated:
        return TripCreatedEvent.fromJson(data);
      case WebSocketEventType.tripUpdated:
        return TripUpdatedEvent.fromJson(data);
      case WebSocketEventType.tripDeleted:
        return TripDeletedEvent.fromJson(data);
      case WebSocketEventType.tripStatusChanged:
        return TripStatusChangedEvent.fromJson(data);
      case WebSocketEventType.tripVisibilityChanged:
        return TripVisibilityChangedEvent.fromJson(data);
      case WebSocketEventType.tripSettingsUpdated:
        return TripSettingsUpdatedEvent.fromJson(data);

      // Trip update events
      case WebSocketEventType.tripUpdateCreated:
        return TripUpdateCreatedEvent.fromJson(data);
      case WebSocketEventType.polylineUpdated:
        return PolylineUpdatedEvent.fromJson(data);

      // Comment events
      case WebSocketEventType.commentAdded:
        return CommentAddedEvent.fromJson(data);
      case WebSocketEventType.commentReaction:
        // Check if it's an addition or removal
        final payload = data['payload'] as Map<String, dynamic>? ?? data;
        final added = payload['added'] as bool? ?? true;
        return CommentReactionEvent.fromJson(data, isRemoval: !added);
      case WebSocketEventType.commentReactionAdded:
        return CommentReactionEvent.fromJson(data, isRemoval: false);
      case WebSocketEventType.commentReactionRemoved:
        return CommentReactionEvent.fromJson(data, isRemoval: true);
      case WebSocketEventType.commentReactionReplaced:
        return CommentReactionEvent.fromJson(data, isRemoval: false);

      // Trip plan events
      case WebSocketEventType.tripPlanCreated:
        return TripPlanCreatedEvent.fromJson(data);
      case WebSocketEventType.tripPlanUpdated:
        return TripPlanUpdatedEvent.fromJson(data);
      case WebSocketEventType.tripPlanDeleted:
        return TripPlanDeletedEvent.fromJson(data);

      // User relationship events
      case WebSocketEventType.userFollowed:
        return UserFollowedEvent.fromJson(data);
      case WebSocketEventType.friendRequestSent:
        return FriendRequestSentEvent.fromJson(data);

      // Notification events
      case WebSocketEventType.notificationCreated:
        return NotificationCreatedEvent.fromJson(data);

      default:
        return WebSocketEvent.fromJson(data);
    }
  }

  /// Dispose of the service
  void dispose() {
    _messageSubscription?.cancel();
    _connectionStateSubscription?.cancel();
    _client?.dispose();
    _eventController.close();

    for (final controller in _tripEventControllers.values) {
      controller.close();
    }
    _tripEventControllers.clear();
    _subscribedTrips.clear();

    for (final controller in _userEventControllers.values) {
      controller.close();
    }
    _userEventControllers.clear();
    _subscribedUsers.clear();

    _isInitialized = false;
    debugPrint('WebSocketService: Disposed');
  }
}
