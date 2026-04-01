import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';

/// Base panel component for trip detail panels
/// Provides unified styling with instant show/hide (no animation)
class BasePanel extends StatelessWidget {
  final bool isCollapsed;
  final Widget collapsedChild;
  final Widget expandedChild;
  final EdgeInsets collapsedMargin;
  final EdgeInsets expandedMargin;
  final double? expandedWidth;

  const BasePanel({
    super.key,
    required this.isCollapsed,
    required this.collapsedChild,
    required this.expandedChild,
    this.collapsedMargin = const EdgeInsets.all(16),
    this.expandedMargin = const EdgeInsets.all(16),
    this.expandedWidth,
  });

  @override
  Widget build(BuildContext context) {
    // Simply switch between collapsed and expanded with no animation
    return isCollapsed ? collapsedChild : expandedChild;
  }
}

/// Collapsed floating bubble with icon and optional badge
class CollapsedBubble extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? badgeText;
  final EdgeInsets margin;

  const CollapsedBubble({
    super.key,
    required this.icon,
    required this.onTap,
    this.badgeText,
    this.margin = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
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
              onTap: onTap,
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
                      icon,
                      size: 24,
                      color: WandererTheme.primaryOrange,
                    ),
                  ),
                  if (badgeText != null)
                    Positioned(
                      right: 4,
                      top: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 4,
                        ),
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
                            badgeText!,
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
}

/// Expanded glass card with header
class ExpandedCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets margin;
  final double? width;

  const ExpandedCard({
    super.key,
    required this.child,
    this.margin = const EdgeInsets.all(16),
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      width: width,
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
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: WandererTheme.glassBackgroundFor(context),
              borderRadius: BorderRadius.circular(WandererTheme.glassRadius),
              border: Border.all(
                color: WandererTheme.glassBorderColorFor(context),
                width: 1,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Standard panel header with icon, title, and minimize button
class PanelHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onMinimize;
  final Widget? trailing;

  const PanelHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.onMinimize,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: WandererTheme.primaryOrange,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: trailing ??
              Text(
                title,
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
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.08),
            borderRadius: BorderRadius.circular(6),
          ),
          child: IconButton(
            icon: Icon(
              Icons.remove,
              size: 16,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
            onPressed: onMinimize,
            tooltip: 'Minimize',
            padding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }
}
