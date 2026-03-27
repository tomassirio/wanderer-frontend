import 'package:flutter/material.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/theme/wanderer_theme.dart';
import '../../helpers/avatar_helper.dart';

/// A reusable widget for displaying user avatars with fallback to initials
class UserAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String? userId;
  final String username;
  final String? displayName;
  final double radius;
  final Color? backgroundColor;
  final Color? textColor;

  const UserAvatar({
    super.key,
    this.avatarUrl,
    this.userId,
    required this.username,
    this.displayName,
    this.radius = 16,
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor =
        backgroundColor ?? WandererTheme.primaryOrange.withOpacity(0.15);
    final txtColor = textColor ?? WandererTheme.primaryOrange;
    final initials = AvatarHelper.getInitials(displayName, username);

    // Priority 1: Use avatarUrl if provided (e.g., from UserProfile)
    // Priority 2: Try to load profile picture from userId if available
    // Priority 3: Fallback to initials

    String? imageUrl = avatarUrl;

    // If no avatarUrl but userId is provided, construct profile picture URL
    if ((imageUrl == null || imageUrl.isEmpty) && userId != null) {
      imageUrl =
          ApiEndpoints.resolveThumbnailUrl('/thumbnails/profiles/$userId.png');
    }

    // If we have a valid image URL, try to display it
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: bgColor,
        foregroundImage: NetworkImage(imageUrl),
        onForegroundImageError: (_, __) {
          // Fallback to showing initials
        },
        child: Text(
          initials,
          style: TextStyle(
            color: txtColor,
            fontSize: radius * 0.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    // Fallback to displayName/username initials
    return CircleAvatar(
      radius: radius,
      backgroundColor: bgColor,
      child: Text(
        initials,
        style: TextStyle(
          color: txtColor,
          fontSize: radius * 0.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
