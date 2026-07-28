import 'package:flutter/material.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/core/constants/enums.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/presentation/helpers/ui_helpers.dart';

/// Pill-shaped status filter buttons shown in the profile screen's trips
/// filter panel, one per [TripStatus] present in [userTrips].
class ProfileStatusFilterPills extends StatelessWidget {
  final List<Trip> userTrips;
  final Set<TripStatus> selectedStatusFilters;
  final ValueChanged<TripStatus> onToggleStatus;
  final VoidCallback onClearAll;

  const ProfileStatusFilterPills({
    super.key,
    required this.userTrips,
    required this.selectedStatusFilters,
    required this.onToggleStatus,
    required this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // Gather statuses that have trips
    final statusCounts = <TripStatus, int>{};
    for (final trip in userTrips) {
      statusCounts[trip.status] = (statusCounts[trip.status] ?? 0) + 1;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Clear all button row
        if (selectedStatusFilters.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GestureDetector(
              onTap: onClearAll,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.close_rounded,
                      size: 14, color: WandererTheme.primaryOrange),
                  const SizedBox(width: 4),
                  Text(
                    l10n.clearAllFilters,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: WandererTheme.primaryOrange,
                    ),
                  ),
                ],
              ),
            ),
          ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: TripStatus.values
              .where((s) => (statusCounts[s] ?? 0) > 0)
              .map((status) {
            final isSelected = selectedStatusFilters.contains(status);
            final count = statusCounts[status]!;
            final statusColor = UiHelpers.getStatusColor(status);

            return GestureDetector(
              onTap: () => onToggleStatus(status),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color:
                      isSelected ? statusColor : statusColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color:
                        isSelected ? statusColor : statusColor.withOpacity(0.3),
                    width: 1.5,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: statusColor.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      UiHelpers.getStatusIcon(status),
                      size: 14,
                      color: isSelected ? Colors.white : statusColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      UiHelpers.getStatusLabel(status, l10n),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : statusColor.withOpacity(0.9),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white.withOpacity(0.25)
                            : statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
