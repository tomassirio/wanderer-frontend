import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/constants/enums.dart' show TripStatus;
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/presentation/state/home_feed/home_feed_notifier.dart';
import 'package:wanderer_frontend/presentation/state/user_chrome/user_chrome_notifier.dart';
import 'package:wanderer_frontend/presentation/widgets/home/feed_section_header.dart';
import 'package:wanderer_frontend/presentation/widgets/home/trip_grid.dart';

/// "My Trips" tab content: the current user's own trips grouped by status
/// (active/resting, paused, draft, completed).
class MyTripsTabContent extends ConsumerWidget {
  final Future<void> Function() onRefresh;
  final ValueChanged<Trip> onTripTap;
  final ValueChanged<Trip> onDeleteTrip;

  const MyTripsTabContent({
    super.key,
    required this.onRefresh,
    required this.onTripTap,
    required this.onDeleteTrip,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(homeFeedNotifierProvider);
    final currentUserId = ref.watch(userChromeNotifierProvider).userId;
    final filteredTrips = feed.filtered(feed.myTrips);
    final l10n = context.l10n;

    // Group trips by status
    // Resting trips are shown alongside active trips (like live, but with a resting badge)
    final activeTrips = filteredTrips
        .where(
          (t) =>
              t.status == TripStatus.inProgress ||
              t.status == TripStatus.resting,
        )
        .toList();
    final pausedTrips =
        filteredTrips.where((t) => t.status == TripStatus.paused).toList();
    final draftTrips =
        filteredTrips.where((t) => t.status == TripStatus.created).toList();
    final completedTrips =
        filteredTrips.where((t) => t.status == TripStatus.finished).toList();

    if (filteredTrips.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.explore_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.noTripsYet,
              style: TextStyle(
                fontSize: 18,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.createYourFirstTrip,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: 80 + MediaQuery.of(context).padding.bottom,
        ),
        children: [
          if (activeTrips.isNotEmpty) ...[
            FeedSectionHeader(
              title: l10n.activeTripsSection,
              icon: Icons.location_on,
              count: activeTrips.length,
              subtitle: l10n.currentlyInProgress,
            ),
            const SizedBox(height: 12),
            TripGrid(
              trips: activeTrips,
              currentUserId: currentUserId,
              friendIds: feed.friendIds,
              followingIds: feed.followingIds,
              showDelete: true,
              onTripTap: onTripTap,
              onDeleteTrip: onDeleteTrip,
            ),
            const SizedBox(height: 24),
          ],
          if (pausedTrips.isNotEmpty) ...[
            FeedSectionHeader(
              title: l10n.pausedTripsSection,
              icon: Icons.pause_circle_outline,
              count: pausedTrips.length,
              subtitle: l10n.temporarilyStopped,
            ),
            const SizedBox(height: 12),
            TripGrid(
              trips: pausedTrips,
              currentUserId: currentUserId,
              friendIds: feed.friendIds,
              followingIds: feed.followingIds,
              showDelete: true,
              onTripTap: onTripTap,
              onDeleteTrip: onDeleteTrip,
            ),
            const SizedBox(height: 24),
          ],
          if (draftTrips.isNotEmpty) ...[
            FeedSectionHeader(
              title: l10n.draftTripsSection,
              icon: Icons.edit_outlined,
              count: draftTrips.length,
              subtitle: l10n.notYetStarted,
            ),
            const SizedBox(height: 12),
            TripGrid(
              trips: draftTrips,
              currentUserId: currentUserId,
              friendIds: feed.friendIds,
              followingIds: feed.followingIds,
              showDelete: true,
              onTripTap: onTripTap,
              onDeleteTrip: onDeleteTrip,
            ),
            const SizedBox(height: 24),
          ],
          if (completedTrips.isNotEmpty) ...[
            FeedSectionHeader(
              title: l10n.completedTripsSection,
              icon: Icons.check_circle_outline,
              count: completedTrips.length,
              subtitle: l10n.finishedAdventures,
            ),
            const SizedBox(height: 12),
            TripGrid(
              trips: completedTrips,
              currentUserId: currentUserId,
              friendIds: feed.friendIds,
              followingIds: feed.followingIds,
              showDelete: true,
              onTripTap: onTripTap,
              onDeleteTrip: onDeleteTrip,
            ),
          ],
        ],
      ),
    );
  }
}
