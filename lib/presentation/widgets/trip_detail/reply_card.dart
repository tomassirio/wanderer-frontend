import 'package:flutter/material.dart';
import 'package:wanderer_frontend/data/models/comment_models.dart';
import 'package:wanderer_frontend/presentation/helpers/auth_navigation_helper.dart';
import 'package:wanderer_frontend/presentation/widgets/common/user_avatar.dart';

/// Widget displaying a reply card
class ReplyCard extends StatelessWidget {
  final Comment reply;

  const ReplyCard({super.key, required this.reply});

  void _navigateToProfile(BuildContext context) {
    AuthNavigationHelper.navigateToUserProfile(context, reply.userId);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 32, top: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InkWell(
                onTap: () => _navigateToProfile(context),
                child: UserAvatar(
                  userId: reply.userId,
                  avatarUrl: reply.userAvatarUrl,
                  username: reply.username,
                  radius: 12,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: () => _navigateToProfile(context),
                      child: Text(
                        '@${reply.username}',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                    Text(
                      _formatTimestamp(reply.createdAt),
                      style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(reply.message, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final local = timestamp.toLocal();
    final now = DateTime.now();
    final difference = now.difference(local);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${local.day}/${local.month}/${local.year}';
    }
  }
}
