import 'package:flutter/material.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';

/// Widget for input field to add comments with glassmorphism styling
class CommentInput extends StatelessWidget {
  final TextEditingController controller;
  final bool isAddingComment;
  final bool isReplyMode;
  final VoidCallback onSend;
  final VoidCallback onCancelReply;

  const CommentInput({
    super.key,
    required this.controller,
    required this.isAddingComment,
    required this.isReplyMode,
    required this.onSend,
    required this.onCancelReply,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.08),
        border: Border(
          top: BorderSide(
            color: WandererTheme.glassBorderColorFor(context),
            width: 0.5,
          ),
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isReplyMode) ...[
            Row(
              children: [
                Icon(
                  Icons.reply,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
                const SizedBox(width: 8),
                Text(
                  'Replying to comment',
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    Icons.close,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                  onPressed: onCancelReply,
                  tooltip: 'Cancel reply',
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText:
                        isReplyMode ? 'Write a reply...' : 'Write a comment...',
                    hintStyle: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.45),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(WandererTheme.glassRadiusSmall),
                      borderSide: BorderSide(
                        color: WandererTheme.glassBorderColorFor(context),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(WandererTheme.glassRadiusSmall),
                      borderSide: BorderSide(
                        color: WandererTheme.glassBorderColorFor(context),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(WandererTheme.glassRadiusSmall),
                      borderSide: BorderSide(
                        color: WandererTheme.primaryOrange,
                        width: 1.5,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: WandererTheme.primaryOrange,
                  borderRadius:
                      BorderRadius.circular(WandererTheme.glassRadiusSmall),
                ),
                child: IconButton(
                  icon: isAddingComment
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.send,
                          color: Colors.white,
                        ),
                  onPressed: isAddingComment ? null : onSend,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
