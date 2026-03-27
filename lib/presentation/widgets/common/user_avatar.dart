import 'package:flutter/material.dart';
import '../../../core/theme/wanderer_theme.dart';
import '../../helpers/avatar_helper.dart';

/// A reusable widget for displaying user avatars with fallback to initials
class UserAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String username;
  final String? displayName;
  final double radius;
  final Color? backgroundColor;
  final Color? textColor;

  const UserAvatar({
    super.key,
    this.avatarUrl,
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

    // If avatar URL is provided and valid, use it
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: bgColor,
        foregroundImage: NetworkImage(avatarUrl!),
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
