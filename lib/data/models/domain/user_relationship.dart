/// Model representing a user with their relationship status to the current user.
/// Returned by the GET /api/1/users/{userId}/associated endpoint.
class UserRelationship {
  final String id;
  final String username;
  final String? displayName;
  final String? profilePictureUrl;
  final bool isFriend;
  final bool isFollowing;
  final bool isFollowedBy;

  /// Generate avatar URL based on user ID
  String get avatarUrl => '/thumbnails/profiles/$id.png';

  UserRelationship({
    required this.id,
    required this.username,
    this.displayName,
    this.profilePictureUrl,
    required this.isFriend,
    required this.isFollowing,
    required this.isFollowedBy,
  });

  factory UserRelationship.fromJson(Map<String, dynamic> json) {
    return UserRelationship(
      id: json['id'] as String? ?? json['userId'] as String? ?? '',
      username: json['username'] as String? ?? '',
      displayName: json['displayName'] as String?,
      profilePictureUrl: json['profilePictureUrl'] as String?,
      isFriend: json['isFriend'] as bool? ?? false,
      isFollowing: json['isFollowing'] as bool? ?? false,
      isFollowedBy: json['isFollowedBy'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        if (displayName != null) 'displayName': displayName,
        if (profilePictureUrl != null) 'profilePictureUrl': profilePictureUrl,
        'isFriend': isFriend,
        'isFollowing': isFollowing,
        'isFollowedBy': isFollowedBy,
      };
}
