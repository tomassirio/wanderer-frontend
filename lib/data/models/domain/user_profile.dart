/// User profile model
class UserProfile {
  final String id;
  final String username;
  final String email;
  final String? displayName;
  final String? bio;
  final int followersCount;
  final int followingCount;
  final int friendsCount;
  final int tripsCount;
  final bool isFollowing;
  final DateTime createdAt;

  /// Generate avatar URL based on user ID
  String get avatarUrl => '/thumbnails/profiles/$id.png';

  UserProfile({
    required this.id,
    required this.username,
    required this.email,
    this.displayName,
    this.bio,
    required this.followersCount,
    required this.followingCount,
    this.friendsCount = 0,
    required this.tripsCount,
    this.isFollowing = false,
    required this.createdAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    // Backend nests displayName, bio under 'userDetails'.
    // Fall back to flat fields for backward compatibility.
    final userDetails = json['userDetails'] as Map<String, dynamic>?;

    return UserProfile(
      id: json['id'] as String? ?? json['userId'] as String? ?? '',
      username: json['username'] as String? ?? '',
      email: json['email'] as String? ?? '',
      displayName: userDetails?['displayName'] as String? ??
          json['displayName'] as String?,
      bio: userDetails?['bio'] as String? ?? json['bio'] as String?,
      followersCount: json['followersCount'] as int? ?? 0,
      followingCount: json['followingCount'] as int? ?? 0,
      friendsCount: json['friendsCount'] as int? ?? 0,
      tripsCount: json['tripsCount'] as int? ?? 0,
      isFollowing: json['isFollowing'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'email': email,
        if (displayName != null) 'displayName': displayName,
        if (bio != null) 'bio': bio,
        'followersCount': followersCount,
        'followingCount': followingCount,
        'friendsCount': friendsCount,
        'tripsCount': tripsCount,
        'isFollowing': isFollowing,
        'createdAt': createdAt.toIso8601String(),
      };
}
