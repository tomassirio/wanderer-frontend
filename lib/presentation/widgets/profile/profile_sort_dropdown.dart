import 'package:flutter/material.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/presentation/state/profile/profile_state.dart';
import 'package:wanderer_frontend/presentation/screens/profile_screen.dart'
    show TripSortOptionUi;

/// A sleek dropdown-style button that opens a bottom sheet of trip sort
/// options for the profile screen's trips section.
class ProfileSortDropdown extends StatelessWidget {
  final TripSortOption currentOption;
  final ValueChanged<TripSortOption> onSelect;

  const ProfileSortDropdown({
    super.key,
    required this.currentOption,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return InkWell(
      onTap: () => _showSortBottomSheet(context),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: WandererTheme.primaryOrange.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: WandererTheme.primaryOrange.withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            Icon(
              currentOption.icon,
              size: 16,
              color: WandererTheme.primaryOrange,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                currentOption.labelFor(l10n),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.unfold_more_rounded,
              size: 16,
              color: WandererTheme.primaryOrange.withOpacity(0.7),
            ),
          ],
        ),
      ),
    );
  }

  /// Shows a bottom sheet with sort options.
  void _showSortBottomSheet(BuildContext context) {
    final l10n = context.l10n;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        final sheetBg =
            isDark ? const Color(0xFF1E1E1E) : WandererTheme.backgroundCard;
        final handleColor = isDark ? Colors.grey[600] : Colors.grey[300];
        final titleColor = theme.colorScheme.onSurface;
        final unselectedTextColor = theme.colorScheme.onSurface;
        final unselectedIconColor =
            isDark ? Colors.grey[400] : Colors.grey[500];

        return Container(
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: handleColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Icon(Icons.sort_rounded,
                        size: 20, color: WandererTheme.primaryOrange),
                    const SizedBox(width: 8),
                    Text(
                      l10n.sortTripsBy,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: titleColor,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ...TripSortOption.values.map((option) {
                final isSelected = currentOption == option;
                return ListTile(
                  leading: Icon(
                    option.icon,
                    color: isSelected
                        ? WandererTheme.primaryOrange
                        : unselectedIconColor,
                    size: 20,
                  ),
                  title: Text(
                    option.labelFor(l10n),
                    style: TextStyle(
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected
                          ? WandererTheme.primaryOrange
                          : unselectedTextColor,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle_rounded,
                          color: WandererTheme.primaryOrange, size: 20)
                      : null,
                  onTap: () {
                    onSelect(option);
                    Navigator.pop(context);
                  },
                  dense: true,
                  visualDensity: VisualDensity.compact,
                );
              }),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}
