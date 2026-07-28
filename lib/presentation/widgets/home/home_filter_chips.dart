import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/constants/enums.dart'
    show TripStatus, Visibility;
import 'package:wanderer_frontend/presentation/helpers/ui_helpers.dart';
import 'package:wanderer_frontend/presentation/state/home_feed/home_feed_notifier.dart';
import 'package:wanderer_frontend/presentation/widgets/home/filter_chip_button.dart';

/// Status/visibility filter chip row shown above the home feed's tab
/// content. [isMyTripsTab] gates whether the visibility chip (and the
/// finished/draft status options) are shown — those only make sense for
/// the current user's own trips, not the public feed/discover tabs.
class HomeFilterChips extends ConsumerWidget {
  final bool isMyTripsTab;

  const HomeFilterChips({super.key, required this.isMyTripsTab});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final feed = ref.watch(homeFeedNotifierProvider);
    final notifier = ref.read(homeFeedNotifierProvider.notifier);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.inversePrimary.withOpacity(0.35),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Status filter chip
          FilterChipButton<TripStatus?>(
            value: feed.statusFilter,
            label: feed.statusFilter == null
                ? l10n.allStatus
                : UiHelpers.getStatusLabel(feed.statusFilter!, l10n),
            icon: feed.statusFilter == null
                ? Icons.all_inclusive
                : UiHelpers.getStatusIcon(feed.statusFilter!),
            iconColor: feed.statusFilter == null
                ? Colors.grey
                : UiHelpers.getStatusColor(feed.statusFilter!),
            isActive: feed.statusFilter != null,
            onSelected: notifier.setStatusFilter,
            items: [
              PopupMenuItem<TripStatus?>(
                value: null,
                onTap: () {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    notifier.setStatusFilter(null);
                  });
                },
                child: Row(
                  children: [
                    Icon(Icons.all_inclusive, size: 18, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(l10n.allStatus),
                  ],
                ),
              ),
              PopupMenuItem<TripStatus?>(
                value: TripStatus.inProgress,
                child: Row(
                  children: [
                    Icon(Icons.circle, size: 18, color: Colors.green),
                    const SizedBox(width: 8),
                    Text(l10n.live),
                  ],
                ),
              ),
              PopupMenuItem<TripStatus?>(
                value: TripStatus.paused,
                child: Row(
                  children: [
                    Icon(Icons.pause, size: 18, color: Colors.orange),
                    const SizedBox(width: 8),
                    Text(l10n.paused),
                  ],
                ),
              ),
              if (isMyTripsTab) ...[
                PopupMenuItem<TripStatus?>(
                  value: TripStatus.finished,
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 18,
                        color: Colors.blue,
                      ),
                      const SizedBox(width: 8),
                      Text(l10n.completed),
                    ],
                  ),
                ),
                PopupMenuItem<TripStatus?>(
                  value: TripStatus.created,
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 18, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(l10n.draft),
                    ],
                  ),
                ),
              ],
            ],
          ),
          // Visibility filter chip (My Trips tab only)
          if (isMyTripsTab) ...[
            const SizedBox(width: 8),
            FilterChipButton<Visibility?>(
              value: feed.visibilityFilter,
              label: feed.visibilityFilter == null
                  ? l10n.allVisibility
                  : UiHelpers.getVisibilityLabel(feed.visibilityFilter!, l10n),
              icon: feed.visibilityFilter == null
                  ? Icons.all_inclusive
                  : UiHelpers.getVisibilityIcon(feed.visibilityFilter!),
              iconColor: _visibilityColor(feed.visibilityFilter),
              isActive: feed.visibilityFilter != null,
              onSelected: notifier.setVisibilityFilter,
              items: [
                PopupMenuItem<Visibility?>(
                  value: null,
                  onTap: () {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      notifier.setVisibilityFilter(null);
                    });
                  },
                  child: Row(
                    children: [
                      Icon(Icons.all_inclusive, size: 18, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(l10n.allVisibility),
                    ],
                  ),
                ),
                PopupMenuItem<Visibility?>(
                  value: Visibility.public,
                  child: Row(
                    children: [
                      Icon(Icons.public, size: 18, color: Colors.green),
                      const SizedBox(width: 8),
                      Text(l10n.publicVisibility),
                    ],
                  ),
                ),
                PopupMenuItem<Visibility?>(
                  value: Visibility.protected,
                  child: Row(
                    children: [
                      Icon(Icons.lock_outline, size: 18, color: Colors.orange),
                      const SizedBox(width: 8),
                      Text(l10n.protectedVisibility),
                    ],
                  ),
                ),
                PopupMenuItem<Visibility?>(
                  value: Visibility.private,
                  child: Row(
                    children: [
                      Icon(Icons.lock, size: 18, color: Colors.red),
                      const SizedBox(width: 8),
                      Text(l10n.privateVisibility),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // Stays local: this filter chip uses flat Colors.green/.orange/.red, a
  // different (simpler) visual treatment than VisibilityBadge's
  // shade700+border scheme, and there's no UiHelpers.getVisibilityColor to
  // delegate to - not a literal duplicate, see plan Global Constraints for
  // why color isn't unified across both.
  Color _visibilityColor(Visibility? visibility) {
    if (visibility == null) return Colors.grey;
    switch (visibility) {
      case Visibility.public:
        return Colors.green;
      case Visibility.protected:
        return Colors.orange;
      case Visibility.private:
        return Colors.red;
    }
  }
}
