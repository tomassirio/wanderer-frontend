import '../../../core/constants/enums.dart';

/// Types of WebSocket events
enum WebSocketEventType {
  // Trip events
  tripCreated,
  tripUpdated,
  tripDeleted,
  tripStatusChanged,
  tripVisibilityChanged,
  tripMetadataUpdated,

  // Trip update events
  tripUpdateCreated,
  polylineUpdated,

  // Comment events
  commentAdded,
  commentReaction,
  commentReactionReplaced,

  // Trip plan events
  tripPlanCreated,
  tripPlanUpdated,
  tripPlanDeleted,

  // User relationship events
  userFollowed,
  userUnfollowed,
  friendRequestSent,
  friendRequestAccepted,
  friendRequestDeclined,
  friendshipCreated,
  friendshipRemoved,

  // Trip settings events
  tripSettingsUpdated,

  // Notification events
  notificationCreated,

  // Legacy events for backwards compatibility
  commentReactionAdded,
  commentReactionRemoved,

  unknown,
}

/// Base WebSocket event class
class WebSocketEvent {
  final WebSocketEventType type;
  final String? tripId;
  final Map<String, dynamic> payload;
  final DateTime timestamp;

  WebSocketEvent({
    required this.type,
    this.tripId,
    required this.payload,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Parse event type from string
  static WebSocketEventType parseEventType(String? typeStr) {
    switch (typeStr?.toUpperCase()) {
      // Trip events
      case 'TRIP_CREATED':
        return WebSocketEventType.tripCreated;
      case 'TRIP_UPDATED':
        return WebSocketEventType.tripUpdated;
      case 'TRIP_DELETED':
        return WebSocketEventType.tripDeleted;
      case 'TRIP_STATUS_CHANGED':
        return WebSocketEventType.tripStatusChanged;
      case 'TRIP_VISIBILITY_CHANGED':
        return WebSocketEventType.tripVisibilityChanged;
      case 'TRIP_METADATA_UPDATED':
        return WebSocketEventType.tripMetadataUpdated;
      case 'TRIP_SETTINGS_UPDATED':
        return WebSocketEventType.tripSettingsUpdated;

      // Trip update events
      case 'TRIP_UPDATE_CREATED':
        return WebSocketEventType.tripUpdateCreated;
      case 'POLYLINE_UPDATED':
        return WebSocketEventType.polylineUpdated;

      // Comment events
      case 'COMMENT_ADDED':
        return WebSocketEventType.commentAdded;
      case 'COMMENT_REACTION':
        return WebSocketEventType.commentReaction;
      case 'COMMENT_REACTION_ADDED':
        return WebSocketEventType.commentReactionAdded;
      case 'COMMENT_REACTION_REMOVED':
        return WebSocketEventType.commentReactionRemoved;
      case 'COMMENT_REACTION_REPLACED':
        return WebSocketEventType.commentReactionReplaced;

      // Trip plan events
      case 'TRIP_PLAN_CREATED':
        return WebSocketEventType.tripPlanCreated;
      case 'TRIP_PLAN_UPDATED':
        return WebSocketEventType.tripPlanUpdated;
      case 'TRIP_PLAN_DELETED':
        return WebSocketEventType.tripPlanDeleted;

      // User relationship events
      case 'USER_FOLLOWED':
        return WebSocketEventType.userFollowed;
      case 'USER_UNFOLLOWED':
        return WebSocketEventType.userUnfollowed;
      case 'FRIEND_REQUEST_SENT':
        return WebSocketEventType.friendRequestSent;
      case 'FRIEND_REQUEST_ACCEPTED':
        return WebSocketEventType.friendRequestAccepted;
      case 'FRIEND_REQUEST_DECLINED':
        return WebSocketEventType.friendRequestDeclined;
      case 'FRIENDSHIP_CREATED':
        return WebSocketEventType.friendshipCreated;
      case 'FRIENDSHIP_REMOVED':
        return WebSocketEventType.friendshipRemoved;

      // Notification events
      case 'NOTIFICATION_CREATED':
        return WebSocketEventType.notificationCreated;

      default:
        return WebSocketEventType.unknown;
    }
  }

  /// Factory to create event from JSON message
  factory WebSocketEvent.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String?;
    final type = parseEventType(typeStr);

    return WebSocketEvent(
      type: type,
      tripId: json['tripId'] as String?,
      payload: json['payload'] as Map<String, dynamic>? ?? json,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'tripId': tripId,
        'payload': payload,
        'timestamp': timestamp.toIso8601String(),
      };
}

/// Event for trip status changes
class TripStatusChangedEvent extends WebSocketEvent {
  final TripStatus newStatus;
  final TripStatus? previousStatus;
  final int? currentDay;

  TripStatusChangedEvent({
    required String tripId,
    required this.newStatus,
    this.previousStatus,
    this.currentDay,
    required super.payload,
    super.timestamp,
  }) : super(type: WebSocketEventType.tripStatusChanged, tripId: tripId);

  factory TripStatusChangedEvent.fromJson(Map<String, dynamic> json) {
    final payload = json['payload'] as Map<String, dynamic>? ?? json;

    return TripStatusChangedEvent(
      tripId: json['tripId'] as String? ?? payload['tripId'] as String? ?? '',
      newStatus: TripStatus.fromJson(
        payload['newStatus'] as String? ?? 'CREATED',
      ),
      previousStatus: payload['previousStatus'] != null
          ? TripStatus.fromJson(payload['previousStatus'] as String)
          : null,
      currentDay: payload['currentDay'] as int?,
      payload: payload,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String)
          : null,
    );
  }
}

/// Event for new trip updates (location/battery/message)
class TripUpdatedEvent extends WebSocketEvent {
  final double? latitude;
  final double? longitude;
  final int? batteryLevel;
  final String? message;
  final String? city;
  final String? country;
  final double? temperatureCelsius;
  final String? weatherCondition;
  final String? updateType;

  TripUpdatedEvent({
    required String tripId,
    this.latitude,
    this.longitude,
    this.batteryLevel,
    this.message,
    this.city,
    this.country,
    this.temperatureCelsius,
    this.weatherCondition,
    this.updateType,
    required super.payload,
    super.timestamp,
  }) : super(type: WebSocketEventType.tripUpdated, tripId: tripId);

  factory TripUpdatedEvent.fromJson(Map<String, dynamic> json) {
    final payload = json['payload'] as Map<String, dynamic>? ?? json;

    return TripUpdatedEvent(
      tripId: json['tripId'] as String? ?? payload['tripId'] as String? ?? '',
      latitude: (payload['latitude'] as num?)?.toDouble(),
      longitude: (payload['longitude'] as num?)?.toDouble(),
      batteryLevel: payload['batteryLevel'] as int?,
      message: payload['message'] as String?,
      city: payload['city'] as String?,
      country: payload['country'] as String?,
      temperatureCelsius: (payload['temperatureCelsius'] as num?)?.toDouble(),
      weatherCondition: payload['weatherCondition'] as String?,
      updateType: payload['updateType'] as String?,
      payload: payload,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String)
          : null,
    );
  }
}

/// Event for polyline updates (async after route computation)
class PolylineUpdatedEvent extends WebSocketEvent {
  final String encodedPolyline;

  PolylineUpdatedEvent({
    required String tripId,
    required this.encodedPolyline,
    required super.payload,
    super.timestamp,
  }) : super(type: WebSocketEventType.polylineUpdated, tripId: tripId);

  factory PolylineUpdatedEvent.fromJson(Map<String, dynamic> json) {
    final payload = json['payload'] as Map<String, dynamic>? ?? json;

    return PolylineUpdatedEvent(
      tripId: json['tripId'] as String? ?? payload['tripId'] as String? ?? '',
      encodedPolyline: payload['encodedPolyline'] as String? ?? '',
      payload: payload,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String)
          : null,
    );
  }
}

/// Event for new comments
class CommentAddedEvent extends WebSocketEvent {
  final String commentId;
  final String userId;
  final String username;
  final String message;
  final String? parentCommentId;

  CommentAddedEvent({
    required String tripId,
    required this.commentId,
    required this.userId,
    required this.username,
    required this.message,
    this.parentCommentId,
    required super.payload,
    super.timestamp,
  }) : super(type: WebSocketEventType.commentAdded, tripId: tripId);

  factory CommentAddedEvent.fromJson(Map<String, dynamic> json) {
    final payload = json['payload'] as Map<String, dynamic>? ?? json;

    return CommentAddedEvent(
      tripId: json['tripId'] as String? ?? payload['tripId'] as String? ?? '',
      commentId:
          payload['commentId'] as String? ?? payload['id'] as String? ?? '',
      userId: payload['userId'] as String? ?? '',
      username: payload['username'] as String? ?? 'Unknown',
      message: payload['message'] as String? ?? '',
      parentCommentId: payload['parentCommentId'] as String?,
      payload: payload,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String)
          : null,
    );
  }
}

/// Event for comment reactions
class CommentReactionEvent extends WebSocketEvent {
  final String commentId;
  final String reactionType;
  final String userId;
  final bool isRemoval;
  final String? previousReactionType; // For COMMENT_REACTION_REPLACED events

  CommentReactionEvent({
    required String tripId,
    required this.commentId,
    required this.reactionType,
    required this.userId,
    required this.isRemoval,
    this.previousReactionType,
    required super.payload,
    super.timestamp,
  }) : super(
          type: previousReactionType != null
              ? WebSocketEventType.commentReactionReplaced
              : (isRemoval
                  ? WebSocketEventType.commentReactionRemoved
                  : WebSocketEventType.commentReactionAdded),
          tripId: tripId,
        );

  factory CommentReactionEvent.fromJson(
    Map<String, dynamic> json, {
    bool isRemoval = false,
  }) {
    final payload = json['payload'] as Map<String, dynamic>? ?? json;

    return CommentReactionEvent(
      tripId: json['tripId'] as String? ?? payload['tripId'] as String? ?? '',
      commentId: payload['commentId'] as String? ?? '',
      reactionType: payload['reactionType'] as String? ?? '',
      userId: payload['userId'] as String? ?? '',
      isRemoval: isRemoval,
      previousReactionType: payload['previousReactionType'] as String?,
      payload: payload,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String)
          : null,
    );
  }
}

/// Event for trip creation
class TripCreatedEvent extends WebSocketEvent {
  final String tripName;
  final String ownerId;
  final String visibility;

  TripCreatedEvent({
    required String tripId,
    required this.tripName,
    required this.ownerId,
    required this.visibility,
    required super.payload,
    super.timestamp,
  }) : super(type: WebSocketEventType.tripCreated, tripId: tripId);

  factory TripCreatedEvent.fromJson(Map<String, dynamic> json) {
    final payload = json['payload'] as Map<String, dynamic>? ?? json;

    return TripCreatedEvent(
      tripId: json['tripId'] as String? ?? payload['tripId'] as String? ?? '',
      tripName: payload['tripName'] as String? ?? '',
      ownerId: payload['ownerId'] as String? ?? '',
      visibility: payload['visibility'] as String? ?? 'PRIVATE',
      payload: payload,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String)
          : null,
    );
  }
}

/// Event for trip deletion
class TripDeletedEvent extends WebSocketEvent {
  TripDeletedEvent({
    required String tripId,
    required super.payload,
    super.timestamp,
  }) : super(type: WebSocketEventType.tripDeleted, tripId: tripId);

  factory TripDeletedEvent.fromJson(Map<String, dynamic> json) {
    final payload = json['payload'] as Map<String, dynamic>? ?? json;

    return TripDeletedEvent(
      tripId: json['tripId'] as String? ?? payload['tripId'] as String? ?? '',
      payload: payload,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String)
          : null,
    );
  }
}

/// Event for trip visibility changes
class TripVisibilityChangedEvent extends WebSocketEvent {
  final String newVisibility;
  final String? previousVisibility;

  TripVisibilityChangedEvent({
    required String tripId,
    required this.newVisibility,
    this.previousVisibility,
    required super.payload,
    super.timestamp,
  }) : super(type: WebSocketEventType.tripVisibilityChanged, tripId: tripId);

  factory TripVisibilityChangedEvent.fromJson(Map<String, dynamic> json) {
    final payload = json['payload'] as Map<String, dynamic>? ?? json;

    return TripVisibilityChangedEvent(
      tripId: json['tripId'] as String? ?? payload['tripId'] as String? ?? '',
      newVisibility: payload['newVisibility'] as String? ?? 'PRIVATE',
      previousVisibility: payload['previousVisibility'] as String?,
      payload: payload,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String)
          : null,
    );
  }
}

/// Event for trip settings changes (automatic updates, update refresh interval)
class TripSettingsUpdatedEvent extends WebSocketEvent {
  final bool? automaticUpdates;
  final int? updateRefresh;

  TripSettingsUpdatedEvent({
    required String tripId,
    this.automaticUpdates,
    this.updateRefresh,
    required super.payload,
    super.timestamp,
  }) : super(type: WebSocketEventType.tripSettingsUpdated, tripId: tripId);

  factory TripSettingsUpdatedEvent.fromJson(Map<String, dynamic> json) {
    final payload = json['payload'] as Map<String, dynamic>? ?? json;

    return TripSettingsUpdatedEvent(
      tripId: json['tripId'] as String? ?? payload['tripId'] as String? ?? '',
      automaticUpdates: payload['automaticUpdates'] as bool?,
      updateRefresh: payload['updateRefresh'] as int?,
      payload: payload,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String)
          : null,
    );
  }
}

/// Event for trip update creation (location updates)
class TripUpdateCreatedEvent extends WebSocketEvent {
  final String tripUpdateId;
  final double? latitude;
  final double? longitude;
  final int? batteryLevel;
  final String? message;

  TripUpdateCreatedEvent({
    required String tripId,
    required this.tripUpdateId,
    this.latitude,
    this.longitude,
    this.batteryLevel,
    this.message,
    required super.payload,
    super.timestamp,
  }) : super(type: WebSocketEventType.tripUpdateCreated, tripId: tripId);

  factory TripUpdateCreatedEvent.fromJson(Map<String, dynamic> json) {
    final payload = json['payload'] as Map<String, dynamic>? ?? json;
    final location = payload['location'] as Map<String, dynamic>?;

    return TripUpdateCreatedEvent(
      tripId: json['tripId'] as String? ?? payload['tripId'] as String? ?? '',
      tripUpdateId: payload['tripUpdateId'] as String? ?? '',
      latitude: location != null
          ? (location['latitude'] as num?)?.toDouble()
          : (payload['latitude'] as num?)?.toDouble(),
      longitude: location != null
          ? (location['longitude'] as num?)?.toDouble()
          : (payload['longitude'] as num?)?.toDouble(),
      batteryLevel: payload['batteryLevel'] as int?,
      message: payload['message'] as String?,
      payload: payload,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String)
          : null,
    );
  }
}

/// Event for trip plan creation
class TripPlanCreatedEvent extends WebSocketEvent {
  final String tripPlanId;
  final String planName;
  final String ownerId;

  TripPlanCreatedEvent({
    required this.tripPlanId,
    required this.planName,
    required this.ownerId,
    required super.payload,
    super.timestamp,
  }) : super(type: WebSocketEventType.tripPlanCreated);

  factory TripPlanCreatedEvent.fromJson(Map<String, dynamic> json) {
    final payload = json['payload'] as Map<String, dynamic>? ?? json;

    return TripPlanCreatedEvent(
      tripPlanId:
          payload['tripPlanId'] as String? ?? payload['id'] as String? ?? '',
      planName: payload['planName'] as String? ?? '',
      ownerId: payload['ownerId'] as String? ?? '',
      payload: payload,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String)
          : null,
    );
  }
}

/// Event for trip plan update
class TripPlanUpdatedEvent extends WebSocketEvent {
  final String tripPlanId;

  TripPlanUpdatedEvent({
    required this.tripPlanId,
    required super.payload,
    super.timestamp,
  }) : super(type: WebSocketEventType.tripPlanUpdated);

  factory TripPlanUpdatedEvent.fromJson(Map<String, dynamic> json) {
    final payload = json['payload'] as Map<String, dynamic>? ?? json;

    return TripPlanUpdatedEvent(
      tripPlanId:
          payload['tripPlanId'] as String? ?? payload['id'] as String? ?? '',
      payload: payload,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String)
          : null,
    );
  }
}

/// Event for trip plan deletion
class TripPlanDeletedEvent extends WebSocketEvent {
  final String tripPlanId;

  TripPlanDeletedEvent({
    required this.tripPlanId,
    required super.payload,
    super.timestamp,
  }) : super(type: WebSocketEventType.tripPlanDeleted);

  factory TripPlanDeletedEvent.fromJson(Map<String, dynamic> json) {
    final payload = json['payload'] as Map<String, dynamic>? ?? json;

    return TripPlanDeletedEvent(
      tripPlanId:
          payload['tripPlanId'] as String? ?? payload['id'] as String? ?? '',
      payload: payload,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String)
          : null,
    );
  }
}

/// Event for user follow
class UserFollowedEvent extends WebSocketEvent {
  final String followerId;
  final String followedId;

  UserFollowedEvent({
    required this.followerId,
    required this.followedId,
    required super.payload,
    super.timestamp,
  }) : super(type: WebSocketEventType.userFollowed);

  factory UserFollowedEvent.fromJson(Map<String, dynamic> json) {
    final payload = json['payload'] as Map<String, dynamic>? ?? json;

    return UserFollowedEvent(
      followerId:
          payload['followerId'] as String? ?? payload['id'] as String? ?? '',
      followedId: payload['followedId'] as String? ?? '',
      payload: payload,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String)
          : null,
    );
  }
}

/// Event for friend request
class FriendRequestSentEvent extends WebSocketEvent {
  final String requestId;
  final String senderId;
  final String receiverId;

  FriendRequestSentEvent({
    required this.requestId,
    required this.senderId,
    required this.receiverId,
    required super.payload,
    super.timestamp,
  }) : super(type: WebSocketEventType.friendRequestSent);

  factory FriendRequestSentEvent.fromJson(Map<String, dynamic> json) {
    final payload = json['payload'] as Map<String, dynamic>? ?? json;

    return FriendRequestSentEvent(
      requestId:
          payload['requestId'] as String? ?? payload['id'] as String? ?? '',
      senderId: payload['senderId'] as String? ?? '',
      receiverId: payload['receiverId'] as String? ?? '',
      payload: payload,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String)
          : null,
    );
  }
}

/// Event for user unfollow
class UserUnfollowedEvent extends WebSocketEvent {
  final String followerId;
  final String followedId;

  UserUnfollowedEvent({
    required this.followerId,
    required this.followedId,
    required super.payload,
    super.timestamp,
  }) : super(type: WebSocketEventType.userUnfollowed);

  factory UserUnfollowedEvent.fromJson(Map<String, dynamic> json) {
    final payload = json['payload'] as Map<String, dynamic>? ?? json;

    return UserUnfollowedEvent(
      followerId:
          payload['followerId'] as String? ?? payload['id'] as String? ?? '',
      followedId: payload['followedId'] as String? ?? '',
      payload: payload,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String)
          : null,
    );
  }
}

/// Event for friend request accepted
class FriendRequestAcceptedEvent extends WebSocketEvent {
  final String requestId;
  final String senderId;
  final String receiverId;

  FriendRequestAcceptedEvent({
    required this.requestId,
    required this.senderId,
    required this.receiverId,
    required super.payload,
    super.timestamp,
  }) : super(type: WebSocketEventType.friendRequestAccepted);

  factory FriendRequestAcceptedEvent.fromJson(Map<String, dynamic> json) {
    final payload = json['payload'] as Map<String, dynamic>? ?? json;

    return FriendRequestAcceptedEvent(
      requestId:
          payload['requestId'] as String? ?? payload['id'] as String? ?? '',
      senderId: payload['senderId'] as String? ?? '',
      receiverId: payload['receiverId'] as String? ?? '',
      payload: payload,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String)
          : null,
    );
  }
}

/// Event for friend request declined
class FriendRequestDeclinedEvent extends WebSocketEvent {
  final String requestId;
  final String senderId;
  final String receiverId;

  FriendRequestDeclinedEvent({
    required this.requestId,
    required this.senderId,
    required this.receiverId,
    required super.payload,
    super.timestamp,
  }) : super(type: WebSocketEventType.friendRequestDeclined);

  factory FriendRequestDeclinedEvent.fromJson(Map<String, dynamic> json) {
    final payload = json['payload'] as Map<String, dynamic>? ?? json;

    return FriendRequestDeclinedEvent(
      requestId:
          payload['requestId'] as String? ?? payload['id'] as String? ?? '',
      senderId: payload['senderId'] as String? ?? '',
      receiverId: payload['receiverId'] as String? ?? '',
      payload: payload,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String)
          : null,
    );
  }
}

/// Event for a new in-app notification created by the backend
class NotificationCreatedEvent extends WebSocketEvent {
  final String notificationId;
  final String recipientId;
  final String? actorId;
  final String notificationType;
  final String? referenceId;
  final String message;

  NotificationCreatedEvent({
    required this.notificationId,
    required this.recipientId,
    this.actorId,
    required this.notificationType,
    this.referenceId,
    required this.message,
    required super.payload,
    super.timestamp,
  }) : super(type: WebSocketEventType.notificationCreated);

  factory NotificationCreatedEvent.fromJson(Map<String, dynamic> json) {
    final payload = json['payload'] as Map<String, dynamic>? ?? json;

    return NotificationCreatedEvent(
      notificationId: payload['id'] as String? ??
          payload['notificationId'] as String? ??
          '',
      recipientId: payload['recipientId'] as String? ?? '',
      actorId: payload['actorId'] as String?,
      notificationType: payload['type'] as String? ?? '',
      referenceId: payload['referenceId'] as String?,
      message: payload['message'] as String? ?? '',
      payload: payload,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String)
          : null,
    );
  }
}
