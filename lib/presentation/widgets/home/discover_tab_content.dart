import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/presentation/state/home_feed/home_feed_notifier.dart';
import 'package:wanderer_frontend/presentation/state/user_chrome/user_chrome_notifier.dart';
import 'package:wanderer_frontend/presentation/widgets/home/feed_section_header.dart';
import 'package:wanderer_frontend/presentation/widgets/home/load_more_trips_button.dart';
import 'package:wanderer_frontend/presentation/widgets/home/trip_grid.dart';

/// "Discover" tab content: featured (promoted) public trips, then the rest
/// of the public trip catalog.
class DiscoverTabContent extends ConsumerWidget {
  final Future<void> Function() onRefresh;
  final VoidCallback onLoadMore;
  final ValueChanged<Trip> onTripTap;
  final ValueChanged<Trip> onDeleteTrip;

  const DiscoverTabContent({
    super.key,
    required this.onRefresh,
    required this.onLoadMore,
    required this.onTripTap,
    required this.onDeleteTrip,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(homeFeedNotifierProvider);
    final currentUserId = ref.watch(userChromeNotifierProvider).userId;
    final l10n = context.l10n;
    final filteredTrips = feed.filtered(feed.discoverTrips);

    // Separate promoted trips (featured) from regular public trips.
    // Backend now includes isPromoted field in Trip model
    final promotedTripsList = filteredTrips.where((t) => t.isPromoted).toList();
    final nonPromotedTrips = filteredTrips.where((t) => !t.isPromoted).toList();

    if (nonPromotedTrips.isEmpty && promotedTripsList.isEmpty) {
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
              l10n.noPublicTripsFound,
              style: TextStyle(
                fontSize: 18,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.checkBackLater,
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
      onRefresh: () async {
        await onRefresh();
        // Reload trips to get latest data (including promoted status)
        await onRefresh();
      },
      child: ListView(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: 80 + MediaQuery.of(context).padding.bottom,
        ),
        children: [
          if (promotedTripsList.isNotEmpty) ...[
            FeedSectionHeader(
              title: l10n.featuredTrips,
              icon: Icons.star,
              subtitle: l10n.highlightedAdventures,
            ),
            const SizedBox(height: 12),
            TripGrid(
              trips: promotedTripsList,
              currentUserId: currentUserId,
              friendIds: feed.friendIds,
              followingIds: feed.followingIds,
              showRelationship: true,
              onTripTap: onTripTap,
              onDeleteTrip: onDeleteTrip,
            ),
            const SizedBox(height: 24),
          ],
          if (nonPromotedTrips.isNotEmpty) ...[
            FeedSectionHeader(
              title: l10n.discover,
              icon: Icons.public,
              count: nonPromotedTrips.length,
              subtitle: l10n.explorePublicTripsSubtitle,
            ),
            const SizedBox(height: 12),
            TripGrid(
              trips: nonPromotedTrips,
              currentUserId: currentUserId,
              friendIds: feed.friendIds,
              followingIds: feed.followingIds,
              showRelationship: true,
              onTripTap: onTripTap,
              onDeleteTrip: onDeleteTrip,
            ),
          ],
          if (feed.hasMoreTrips)
            LoadMoreTripsButton(
              isLoading: feed.isLoadingMoreTrips,
              onLoadMore: onLoadMore,
            ),
        ],
      ),
    );
  }
}
