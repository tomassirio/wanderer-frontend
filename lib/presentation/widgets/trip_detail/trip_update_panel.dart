import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';

/// Widget for sending trip updates (location + battery + optional message)
/// Displays as a floating bubble that expands to show message input
/// Only shown on Android, for trip owner, when trip is IN_PROGRESS
class TripUpdatePanel extends StatefulWidget {
  final bool isCollapsed;
  final bool isLoading;
  final VoidCallback onToggleCollapse;
  final Future<void> Function(String? message) onSendUpdate;

  const TripUpdatePanel({
    super.key,
    required this.isCollapsed,
    required this.isLoading,
    required this.onToggleCollapse,
    required this.onSendUpdate,
  });

  @override
  State<TripUpdatePanel> createState() => _TripUpdatePanelState();
}

class _TripUpdatePanelState extends State<TripUpdatePanel> {
  final TextEditingController _messageController = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _handleSend() async {
    if (_isSending) return;

    setState(() => _isSending = true);

    try {
      final message = _messageController.text.trim().isEmpty
          ? null
          : _messageController.text.trim();
      await widget.onSendUpdate(message);
      _messageController.clear();
      // Collapse after successful send
      widget.onToggleCollapse();
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeInOut,
      switchOutCurve: Curves.easeInOut,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
      child: widget.isCollapsed
          ? KeyedSubtree(
              key: const ValueKey('collapsed'),
              child: _buildCollapsedBubble(),
            )
          : KeyedSubtree(
              key: const ValueKey('expanded'),
              child: _buildExpandedPanel(),
            ),
    );
  }

  /// Collapsed state - floating bubble with send icon
  Widget _buildCollapsedBubble() {
    final icon = Icons.send_rounded;
    return Container(
      margin: const EdgeInsets.all(16),
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
              onTap: widget.onToggleCollapse,
              customBorder: const CircleBorder(),
              child: Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 24,
                  color: WandererTheme.primaryOrange,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Expanded state - message input, send button, and optional day button
  Widget _buildExpandedPanel() {
    return Container(
      width: 300,
      margin: const EdgeInsets.all(16),
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
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header — compact style matching other panels
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 18,
                      color: WandererTheme.primaryOrange,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.l10n.sendUpdate,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
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
                        onPressed: widget.onToggleCollapse,
                        tooltip: 'Minimize',
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Info text
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 14,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.6),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        context.l10n.locationShared,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.6),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Message input
                TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: context.l10n.addMessageOptional,
                    hintStyle: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.45),
                      fontSize: 14,
                    ),
                    filled: true,
                    fillColor: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.08),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: WandererTheme.glassBorderColorFor(context),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: WandererTheme.glassBorderColorFor(context),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: WandererTheme.primaryOrange,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _handleSend(),
                ),
                const SizedBox(height: 12),

                // Send update button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: (_isSending || widget.isLoading)
                        ? null
                        : _handleSend,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: WandererTheme.primaryOrange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: _isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white),
                            ),
                          )
                        : const Icon(Icons.send, size: 18),
                    label: Text(_isSending
                        ? context.l10n.sending
                        : context.l10n.sendUpdate),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
