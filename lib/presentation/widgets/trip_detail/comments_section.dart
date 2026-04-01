import 'package:flutter/material.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/data/models/comment_models.dart';
import 'package:wanderer_frontend/presentation/widgets/trip_detail/comment_card.dart';
import 'package:wanderer_frontend/presentation/widgets/trip_detail/comment_input.dart';
import 'package:wanderer_frontend/presentation/screens/auth_screen.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/presentation/widgets/trip_detail/base_panel.dart';

enum CommentSortOption { latest, oldest, mostReplies, mostReactions }

/// Widget displaying the full comments section with glassmorphism design
/// Supports collapsible bubble state
class CommentsSection extends StatelessWidget {
  final List<Comment> comments;
  final Map<String, List<Comment>> replies;
  final Map<String, bool> expandedComments;
  final String tripUserId;
  final String? currentUserId;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final bool isLoggedIn;
  final bool isAddingComment;
  final bool isCollapsed;
  final CommentSortOption sortOption;
  final TextEditingController commentController;
  final ScrollController scrollController;
  final String? replyingToCommentId;
  final VoidCallback onToggleCollapse;
  final Function(CommentSortOption) onSortChanged;
  final Function(String) onReact;
  final Function(String, ReactionType) onReactionChipTap;
  final Function(String) onReply;
  final Function(String, bool) onToggleReplies;
  final VoidCallback onSendComment;
  final VoidCallback onCancelReply;
  final VoidCallback? onLoadMore;
  final Widget? bottomWidget;

  const CommentsSection({
    super.key,
    required this.comments,
    required this.replies,
    required this.expandedComments,
    required this.tripUserId,
    this.currentUserId,
    required this.isLoading,
    this.isLoadingMore = false,
    this.hasMore = false,
    required this.isLoggedIn,
    required this.isAddingComment,
    required this.isCollapsed,
    required this.sortOption,
    required this.commentController,
    required this.scrollController,
    this.replyingToCommentId,
    required this.onToggleCollapse,
    required this.onSortChanged,
    required this.onReact,
    required this.onReactionChipTap,
    required this.onReply,
    required this.onToggleReplies,
    required this.onSendComment,
    required this.onCancelReply,
    this.onLoadMore,
    this.bottomWidget,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final badgeText = comments.isEmpty
        ? null
        : (comments.length > 99
            ? '99+'
            : '${comments.length}${hasMore ? '+' : ''}');

    return BasePanel(
      isCollapsed: isCollapsed,
      collapsedMargin: const EdgeInsets.only(left: 16, bottom: 16),
      expandedMargin: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
      collapsedChild: CollapsedBubble(
        icon: Icons.chat_bubble_outline,
        onTap: onToggleCollapse,
        badgeText: badgeText,
        margin: const EdgeInsets.only(left: 16, bottom: 16),
      ),
      expandedChild: ExpandedCard(
        margin: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Comments section header — compact style matching TripInfoCard
            Row(
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  size: 18,
                  color: WandererTheme.primaryOrange,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${comments.length}${hasMore ? '+' : ''} ${l10n.comments}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                PopupMenuButton<CommentSortOption>(
                  icon: Icon(
                    Icons.sort,
                    size: 16,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.6),
                  ),
                  onSelected: onSortChanged,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: CommentSortOption.latest,
                      child: Text(l10n.latestFirst),
                    ),
                    PopupMenuItem(
                      value: CommentSortOption.oldest,
                      child: Text(l10n.oldestFirst),
                    ),
                    PopupMenuItem(
                      value: CommentSortOption.mostReplies,
                      child: Text(l10n.mostReplies),
                    ),
                    PopupMenuItem(
                      value: CommentSortOption.mostReactions,
                      child: Text(l10n.mostReactions),
                    ),
                  ],
                ),
                const SizedBox(width: 6),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.remove,
                      size: 16,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.6),
                    ),
                    onPressed: onToggleCollapse,
                    tooltip: 'Minimize',
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Comments list
            Flexible(
              child: isLoading
                  ? const SizedBox(
                      height: 100,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: WandererTheme.primaryOrange,
                        ),
                      ),
                    )
                  : comments.isEmpty
                      ? _buildEmptyCommentsState(context)
                      : ListView.builder(
                          key: const PageStorageKey('trip_comments_list'),
                          controller: scrollController,
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: comments.length + (hasMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == comments.length) {
                              return _buildLoadMoreButton(context);
                            }
                            final comment = comments[index];
                            final isExpanded =
                                expandedComments[comment.id] ?? false;
                            final commentReplies = replies[comment.id] ?? [];

                            return CommentCard(
                              comment: comment,
                              tripUserId: tripUserId,
                              currentUserId: currentUserId,
                              isExpanded: isExpanded,
                              replies: commentReplies,
                              onReact: () => onReact(comment.id),
                              onReactionChipTap: (type) =>
                                  onReactionChipTap(comment.id, type),
                              onReply: () => onReply(comment.id),
                              onToggleReplies: () =>
                                  onToggleReplies(comment.id, isExpanded),
                              isLoggedIn: isLoggedIn,
                            );
                          },
                        ),
            ),
            // Comment input (disabled if not logged in)
            if (isLoggedIn)
              CommentInput(
                controller: commentController,
                isAddingComment: isAddingComment,
                isReplyMode: replyingToCommentId != null,
                onSend: onSendComment,
                onCancelReply: onCancelReply,
              )
            else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.08),
                  border: Border(
                    top: BorderSide(
                      color: WandererTheme.glassBorderColorFor(context),
                      width: 0.5,
                    ),
                  ),
                ),
                child: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AuthScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: WandererTheme.primaryOrange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      l10n.pleaseLogInToComment,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            if (bottomWidget != null)
              Padding(
                padding: const EdgeInsets.only(
                  left: 12,
                  right: 12,
                  bottom: 12,
                ),
                child: Center(child: bottomWidget!),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadMoreButton(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: isLoadingMore
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: WandererTheme.primaryOrange,
                  strokeWidth: 2,
                ),
              )
            : TextButton.icon(
                onPressed: onLoadMore,
                icon: const Icon(
                  Icons.expand_more,
                  color: WandererTheme.primaryOrange,
                ),
                label: Text(
                  l10n.loadMoreComments,
                  style: const TextStyle(color: WandererTheme.primaryOrange),
                ),
              ),
      ),
    );
  }

  Widget _buildEmptyCommentsState(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.comment_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.45),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.noCommentsYet,
              style: TextStyle(
                fontSize: 18,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isLoggedIn ? l10n.beFirstToComment : l10n.loginToAddComment,
              style: TextStyle(
                fontSize: 14,
                color:
                    Theme.of(context).colorScheme.onSurface.withOpacity(0.45),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
