import 'package:flutter/material.dart';

/// A pill-shaped popup-menu filter chip used by the home feed's status and
/// visibility filters. Generic over the filter's value type [T].
class FilterChipButton<T> extends StatelessWidget {
  final T? value;
  final String label;
  final IconData icon;
  final Color iconColor;
  final List<PopupMenuEntry<T>> items;
  final ValueChanged<T?> onSelected;
  final bool isActive;

  const FilterChipButton({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.items,
    required this.onSelected,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chipColor = isActive
        ? theme.colorScheme.secondaryContainer
        : theme.colorScheme.surfaceContainerLow;
    final contentColor = isActive
        ? theme.colorScheme.onSecondaryContainer
        : theme.colorScheme.onSurfaceVariant;

    return PopupMenuButton<T>(
      onSelected: onSelected,
      itemBuilder: (_) => items,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      elevation: 2,
      child: Material(
        color: chipColor,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 32,
            padding: const EdgeInsets.only(left: 8, right: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: iconColor),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: contentColor,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.arrow_drop_down, size: 18, color: contentColor),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
