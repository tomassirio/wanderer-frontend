import 'package:flutter/material.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';

/// A filter toggle button with an animated badge, used to show/hide the
/// profile screen's status filter panel.
///
/// [hasActive] (whether any status filters are currently selected) drives
/// the badge/color styling, while [isPanelOpen] (whether the filter panel
/// is currently expanded) independently drives which icon is shown - these
/// are two distinct pieces of state in the original `_buildFilterToggleButton`.
class ProfileFilterToggleButton extends StatelessWidget {
  final bool hasActive;
  final int count;
  final bool isPanelOpen;
  final VoidCallback onTap;

  const ProfileFilterToggleButton({
    super.key,
    required this.hasActive,
    required this.count,
    required this.isPanelOpen,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inactiveIconColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: hasActive
                ? WandererTheme.primaryOrange.withOpacity(0.12)
                : Colors.grey.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: hasActive
                  ? WandererTheme.primaryOrange.withOpacity(0.3)
                  : Colors.grey.withOpacity(0.2),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isPanelOpen
                    ? Icons.filter_list_off_rounded
                    : Icons.filter_list_rounded,
                size: 16,
                color:
                    hasActive ? WandererTheme.primaryOrange : inactiveIconColor,
              ),
              if (hasActive) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: WandererTheme.primaryOrange,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
