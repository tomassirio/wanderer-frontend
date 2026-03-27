import 'package:flutter/material.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/data/models/comment_models.dart';
import 'package:wanderer_frontend/presentation/widgets/trip_detail/reply_card.dart';
import 'package:wanderer_frontend/presentation/helpers/auth_navigation_helper.dart';
import 'package:wanderer_frontend/presentation/widgets/common/user_avatar.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';

/// Widget displaying a comment card with glassmorphism styling
class CommentCard extends StatelessWidget {
  final Comment comment;
  final String tripUserId;
  final String? currentUserId;
  final bool isExpanded;
  final List<Comment> replies;
  final VoidCallback onReact;
  final Function(ReactionType) onReactionChipTap;
  final VoidCallback onReply;
  final VoidCallback onToggleReplies;
  final bool isLoggedIn;

  const CommentCard({
    super.key,
    required this.comment,
    required this.tripUserId,
    this.currentUserId,
    required this.isExpanded,
    required this.replies,
    required this.onReact,
    required this.onReactionChipTap,
    required this.onReply,
    required this.onToggleReplies,
    required this.isLoggedIn,
  });

  void _navigateToProfile(BuildContext context) {
    AuthNavigationHelper.navigateToUserProfile(context, comment.userId);
  }

  @override
  Widget build(BuildContext context) {
    final isAuthor = comment.userId == tripUserId;
    final l10n = context.l10n;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isAuthor
            ? WandererTheme.primaryOrange.withOpacity(0.08)
            : Theme.of(context).colorScheme.onSurface.withOpacity(0.08),
        border: Border.all(
          color: isAuthor
              ? WandererTheme.primaryOrange.withOpacity(0.3)
              : WandererTheme.glassBorderColorFor(context),
        ),
        borderRadius: BorderRadius.circular(WandererTheme.glassRadiusSmall),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InkWell(
                onTap: () => _navigateToProfile(context),
                child: UserAvatar(
                  userId: comment.userId,
                  avatarUrl: comment.userAvatarUrl,
                  username: comment.username,
                  radius: 16,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        InkWell(
                          onTap: () => _navigateToProfile(context),
                          child: Text(
                            '@${comment.username}',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                        if (isAuthor) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  WandererTheme.primaryOrange.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              l10n.author,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: WandererTheme.primaryOrange,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      _formatTimestamp(comment.createdAt, l10n),
                      style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.6)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(comment.message, style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 8),
          // Display reactions by type
          if (comment.reactions != null && comment.reactions!.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: comment.reactions!.entries
                  .where((entry) => entry.value > 0)
                  .map((entry) => _buildReactionChip(entry.key, entry.value))
                  .toList(),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              if (isLoggedIn) ...[
                InkWell(
                  onTap: onReact,
                  child: Row(
                    children: [
                      Icon(
                        Icons.add_reaction_outlined,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        l10n.react,
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                InkWell(
                  onTap: onReply,
                  child: Row(
                    children: [
                      Icon(Icons.reply, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(l10n.reply, style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ],
              if (comment.responsesCount > 0) ...[
                const SizedBox(width: 16),
                InkWell(
                  onTap: onToggleReplies,
                  child: Row(
                    children: [
                      Icon(
                        isExpanded ? Icons.expand_less : Icons.expand_more,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${comment.responsesCount} ${comment.responsesCount == 1 ? 'reply' : 'replies'}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          if (isExpanded && replies.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Divider(),
            ...replies.map((reply) => ReplyCard(reply: reply)),
          ],
        ],
      ),
    );
  }

  Widget _buildReactionChip(String reactionType, int count) {
    final emoji = _getReactionEmoji(reactionType);
    final type = _getReactionType(reactionType);

    // Check if current user has this reaction
    final userHasReaction = currentUserId != null &&
        comment.individualReactions != null &&
        comment.individualReactions!.any((r) =>
            r.userId == currentUserId &&
            r.reactionType.toJson().toUpperCase() ==
                reactionType.toUpperCase());

    // Get list of usernames who reacted with this emoji
    final reactedUsernames = comment.individualReactions
            ?.where((r) =>
                r.reactionType.toJson().toUpperCase() ==
                reactionType.toUpperCase())
            .map((r) => r.username.isNotEmpty ? r.username : 'Unknown')
            .toList() ??
        [];

    final tooltipMessage = reactedUsernames.isEmpty
        ? '$count ${count == 1 ? 'person' : 'people'} reacted with $emoji'
        : reactedUsernames.length <= 3
            ? '${reactedUsernames.join(', ')} reacted with $emoji'
            : '${reactedUsernames.take(3).join(', ')}, and ${reactedUsernames.length - 3} others reacted with $emoji';

    return Tooltip(
      message: tooltipMessage,
      child: InkWell(
        onTap: isLoggedIn ? () => onReactionChipTap(type) : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: userHasReaction
                ? WandererTheme.primaryOrange.withOpacity(0.2)
                : Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: userHasReaction
                  ? WandererTheme.primaryOrange
                  : Colors.grey[300]!,
              width: userHasReaction ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 4),
              Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight:
                      userHasReaction ? FontWeight.bold : FontWeight.w600,
                  color: userHasReaction
                      ? WandererTheme.primaryOrange
                      : Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  ReactionType _getReactionType(String reactionType) {
    switch (reactionType.toUpperCase()) {
      case 'HEART':
        return ReactionType.heart;
      case 'SMILEY':
        return ReactionType.smiley;
      case 'LAUGH':
        return ReactionType.laugh;
      case 'SAD':
        return ReactionType.sad;
      case 'ANGER':
        return ReactionType.anger;
      default:
        return ReactionType.heart;
    }
  }

  String _getReactionEmoji(String reactionType) {
    switch (reactionType.toUpperCase()) {
      case 'HEART':
        return '❤️';
      case 'SMILEY':
        return '😊';
      case 'LAUGH':
        return '😂';
      case 'SAD':
        return '😢';
      case 'ANGER':
        return '😡';
      default:
        return '👍';
    }
  }

  String _formatTimestamp(DateTime timestamp, AppLocalizations l10n) {
    final local = timestamp.toLocal();
    final now = DateTime.now();
    final difference = now.difference(local);

    if (difference.inMinutes < 1) {
      return l10n.justNow;
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
