/// Notification type enum matching backend NotificationType
enum NotificationType {
  friendRequestReceived,
  friendRequestAccepted,
  friendRequestDeclined,
  commentOnTrip,
  replyToComment,
  commentReaction,
  newFollower,
  achievementUnlocked,
  tripStatusChanged,
  tripUpdatePosted;

  /// Convert notification type to string for API
  String toJson() {
    switch (this) {
      case NotificationType.friendRequestReceived:
        return 'FRIEND_REQUEST_RECEIVED';
      case NotificationType.friendRequestAccepted:
        return 'FRIEND_REQUEST_ACCEPTED';
      case NotificationType.friendRequestDeclined:
        return 'FRIEND_REQUEST_DECLINED';
      case NotificationType.commentOnTrip:
        return 'COMMENT_ON_TRIP';
      case NotificationType.replyToComment:
        return 'REPLY_TO_COMMENT';
      case NotificationType.commentReaction:
        return 'COMMENT_REACTION';
      case NotificationType.newFollower:
        return 'NEW_FOLLOWER';
      case NotificationType.achievementUnlocked:
        return 'ACHIEVEMENT_UNLOCKED';
      case NotificationType.tripStatusChanged:
        return 'TRIP_STATUS_CHANGED';
      case NotificationType.tripUpdatePosted:
        return 'TRIP_UPDATE_POSTED';
    }
  }

  /// Parse notification type from API response
  static NotificationType fromJson(String value) {
    switch (value.toUpperCase()) {
      case 'FRIEND_REQUEST_RECEIVED':
        return NotificationType.friendRequestReceived;
      case 'FRIEND_REQUEST_ACCEPTED':
        return NotificationType.friendRequestAccepted;
      case 'FRIEND_REQUEST_DECLINED':
        return NotificationType.friendRequestDeclined;
      case 'COMMENT_ON_TRIP':
        return NotificationType.commentOnTrip;
      case 'REPLY_TO_COMMENT':
        return NotificationType.replyToComment;
      case 'COMMENT_REACTION':
        return NotificationType.commentReaction;
      case 'NEW_FOLLOWER':
        return NotificationType.newFollower;
      case 'ACHIEVEMENT_UNLOCKED':
        return NotificationType.achievementUnlocked;
      case 'TRIP_STATUS_CHANGED':
        return NotificationType.tripStatusChanged;
      case 'TRIP_UPDATE_POSTED':
        return NotificationType.tripUpdatePosted;
      default:
        throw ArgumentError('Invalid notification type value: $value');
    }
  }
}
