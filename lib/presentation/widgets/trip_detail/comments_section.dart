import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:wanderer_frontend/data/models/comment_models.dart';
import 'package:wanderer_frontend/presentation/widgets/trip_detail/comment_card.dart';
import 'package:wanderer_frontend/presentation/widgets/trip_detail/comment_input.dart';
import 'package:wanderer_frontend/presentation/screens/auth_screen.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';

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
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedCrossFade(
      duration: const Duration(milliseconds: 300),
      firstCurve: Curves.easeInOut,
      secondCurve: Curves.easeInOut,
      sizeCurve: Curves.easeInOut,
      alignment: Alignment.topLeft,
      crossFadeState:
          isCollapsed ? CrossFadeState.showFirst : CrossFadeState.showSecond,
      firstChild: _buildCollapsedBubble(context),
      secondChild: _buildExpandedSection(context),
    );
  }

  /// Collapsed state - floating bubble with comment icon and count badge
  Widget _buildCollapsedBubble(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 16, bottom: 16),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: WandererTheme.floatingShadow,
      ),
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: WandererTheme.glassBlurSigma,
            sigmaY: WandererTheme.glassBlurSigma,
          ),
          child: Material(
            color: WandererTheme.glassBackgroundFor(context),
            shape: CircleBorder(
              side: BorderSide(
                color: WandererTheme.glassBorderColorFor(context),
                width: 1,
              ),
            ),
            child: InkWell(
              onTap: onToggleCollapse,
              customBorder: const CircleBorder(),
              child: Stack(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.chat_bubble_outline,
                      size: 24,
                      color: WandererTheme.primaryOrange,
                    ),
                  ),
                  // Badge with count
                  if (comments.isNotEmpty)
                    Positioned(
                      right: 4,
                      top: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 4),
                        decoration: BoxDecoration(
                          color: WandererTheme.primaryOrange,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        child: Center(
                          child: Text(
                            comments.length > 99
                                ? '99+'
                                : '${comments.length}${hasMore ? '+' : ''}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Expanded state - full comments section
  Widget _buildExpandedSection(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(WandererTheme.glassRadius),
        boxShadow: WandererTheme.floatingShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(WandererTheme.glassRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: WandererTheme.glassBlurSigma,
            sigmaY: WandererTheme.glassBlurSigma,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: WandererTheme.glassBackgroundFor(context),
              borderRadius: BorderRadius.circular(WandererTheme.glassRadius),
              border: Border.all(
                color: WandererTheme.glassBorderColorFor(context),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Comments section header with glass styling
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.08),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(WandererTheme.glassRadius),
                      topRight: Radius.circular(WandererTheme.glassRadius),
                    ),
                    border: Border(
                      bottom: BorderSide(
                        color: WandererTheme.glassBorderColorFor(context),
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 18,
                        color: WandererTheme.primaryOrange,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${comments.length}${hasMore ? '+' : ''} Comments',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const Spacer(),
                      PopupMenuButton<CommentSortOption>(
                        icon: Icon(
                          Icons.sort,
                          size: 20,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.6),
                        ),
                        onSelected: onSortChanged,
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: CommentSortOption.latest,
                            child: Text('Latest first'),
                          ),
                          const PopupMenuItem(
                            value: CommentSortOption.oldest,
                            child: Text('Oldest first'),
                          ),
                          const PopupMenuItem(
                            value: CommentSortOption.mostReplies,
                            child: Text('Most replies'),
                          ),
                          const PopupMenuItem(
                            value: CommentSortOption.mostReactions,
                            child: Text('Most reactions'),
                          ),
                        ],
                      ),
                      const SizedBox(width: 4),
                      Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: IconButton(
                          icon: Icon(
                            Icons.remove,
                            size: 18,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.6),
                          ),
                          onPressed: onToggleCollapse,
                          tooltip: 'Minimize',
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ),
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
                              controller: scrollController,
                              shrinkWrap: true,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount:
                                  comments.length + (hasMore ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index == comments.length) {
                                  return _buildLoadMoreButton(context);
                                }
                                final comment = comments[index];
                                final isExpanded =
                                    expandedComments[comment.id] ?? false;
                                final commentReplies =
                                    replies[comment.id] ?? [];

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
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.08),
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
                        child: const Text(
                          'Please log in to comment',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadMoreButton(BuildContext context) {
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
                label: const Text(
                  'Load more comments',
                  style: TextStyle(color: WandererTheme.primaryOrange),
                ),
              ),
      ),
    );
  }

  Widget _buildEmptyCommentsState(BuildContext context) {
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
              'No comments yet',
              style: TextStyle(
                fontSize: 18,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isLoggedIn
                  ? 'Be the first to comment!'
                  : 'Log in to add a comment',
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
