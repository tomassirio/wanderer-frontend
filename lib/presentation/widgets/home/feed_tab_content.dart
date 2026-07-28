import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/constants/enums.dart' show TripStatus;
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/presentation/state/home_feed/home_feed_notifier.dart';
import 'package:wanderer_frontend/presentation/state/user_chrome/user_chrome_notifier.dart';
import 'package:wanderer_frontend/presentation/widgets/home/feed_section_header.dart';
import 'package:wanderer_frontend/presentation/widgets/home/load_more_trips_button.dart';
import 'package:wanderer_frontend/presentation/widgets/home/relationship_badge.dart';
import 'package:wanderer_frontend/presentation/widgets/home/trip_grid.dart';

/// "Feed" tab content: live trips first, then friends' trips, then trips
/// from users the current user follows (but isn't friends with).
class FeedTabContent extends ConsumerWidget {
  final Future<void> Function() onRefresh;
  final VoidCallback onLoadMore;
  final ValueChanged<Trip> onTripTap;
  final ValueChanged<Trip> onDeleteTrip;

  const FeedTabContent({
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
    final filteredTrips = feed.filtered(feed.feedTrips);
    final l10n = context.l10n;

    // Group by live (including resting) and other
    final liveTrips = filteredTrips
        .where(
          (t) =>
              t.status == TripStatus.inProgress ||
              t.status == TripStatus.resting,
        )
        .toList();
    final friendsTrips = filteredTrips
        .where(
          (t) =>
              feed.friendIds.contains(t.userId) &&
              t.status != TripStatus.inProgress &&
              t.status != TripStatus.resting,
        )
        .toList();
    final followingTrips = filteredTrips
        .where(
          (t) =>
              feed.followingIds.contains(t.userId) &&
              !feed.friendIds.contains(t.userId) &&
              t.status != TripStatus.inProgress &&
              t.status != TripStatus.resting,
        )
        .toList();

    if (filteredTrips.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.noTripsInYourFeed,
              style: TextStyle(
                fontSize: 18,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.followUsersToSeeFeed,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
              textAlign: TextAlign.center,
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
          if (liveTrips.isNotEmpty) ...[
            FeedSectionHeader(
              title: l10n.liveNow,
              icon: Icons.flash_on,
              count: liveTrips.length,
              subtitle: l10n.happeningRightNow,
            ),
            const SizedBox(height: 12),
            TripGrid(
              trips: liveTrips,
              currentUserId: currentUserId,
              friendIds: feed.friendIds,
              followingIds: feed.followingIds,
              showRelationship: true,
              onTripTap: onTripTap,
              onDeleteTrip: onDeleteTrip,
            ),
            const SizedBox(height: 24),
          ],
          if (friendsTrips.isNotEmpty) ...[
            FeedSectionHeader(
              title: l10n.friendsTripsSection,
              icon: Icons.people,
              count: friendsTrips.length,
              subtitle: l10n.fromYourFriends,
            ),
            const SizedBox(height: 12),
            TripGrid(
              trips: friendsTrips,
              currentUserId: currentUserId,
              friendIds: feed.friendIds,
              followingIds: feed.followingIds,
              showRelationship: true,
              defaultRelationship: RelationshipType.friend,
              onTripTap: onTripTap,
              onDeleteTrip: onDeleteTrip,
            ),
            const SizedBox(height: 24),
          ],
          if (followingTrips.isNotEmpty) ...[
            FeedSectionHeader(
              title: l10n.following,
              icon: Icons.person_add_alt_1,
              count: followingTrips.length,
              subtitle: l10n.fromUsersYouFollow,
            ),
            const SizedBox(height: 12),
            TripGrid(
              trips: followingTrips,
              currentUserId: currentUserId,
              friendIds: feed.friendIds,
              followingIds: feed.followingIds,
              showRelationship: true,
              defaultRelationship: RelationshipType.following,
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
