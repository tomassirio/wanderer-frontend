import 'package:flutter/material.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/presentation/widgets/home/enhanced_trip_card.dart';
import 'package:wanderer_frontend/presentation/widgets/home/relationship_badge.dart';

/// Responsive grid of [EnhancedTripCard]s, used by every tab of the home
/// feed (My Trips / Feed / Discover) and the guest discover section.
class TripGrid extends StatelessWidget {
  final List<Trip> trips;
  final String? currentUserId;
  final Set<String> friendIds;
  final Set<String> followingIds;
  final bool showDelete;
  final bool showRelationship;
  final RelationshipType? defaultRelationship;
  final ValueChanged<Trip> onTripTap;
  final ValueChanged<Trip> onDeleteTrip;

  const TripGrid({
    super.key,
    required this.trips,
    required this.currentUserId,
    required this.friendIds,
    required this.followingIds,
    required this.onTripTap,
    required this.onDeleteTrip,
    this.showDelete = false,
    this.showRelationship = false,
    this.defaultRelationship,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = 1;
        if (constraints.maxWidth > 1200) {
          crossAxisCount = 4;
        } else if (constraints.maxWidth > 800) {
          crossAxisCount = 3;
        } else if (constraints.maxWidth > 600) {
          crossAxisCount = 2;
        }

        // Adjust aspect ratio based on column count for better responsiveness
        final double childAspectRatio;
        if (crossAxisCount == 1) {
          childAspectRatio = 1.3; // Wider cards on mobile to avoid stretching
        } else if (crossAxisCount == 2) {
          childAspectRatio = 1.2;
        } else {
          childAspectRatio = 1.15;
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: childAspectRatio,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: trips.length,
          itemBuilder: (context, index) {
            final trip = trips[index];
            RelationshipType? relationship;

            if (showRelationship && trip.userId != currentUserId) {
              if (friendIds.contains(trip.userId)) {
                relationship = RelationshipType.friend;
              } else if (followingIds.contains(trip.userId)) {
                relationship = RelationshipType.following;
              } else if (defaultRelationship != null) {
                relationship = defaultRelationship;
              }
            }

            return EnhancedTripCard(
              key: ValueKey(trip.id), // Prevents unnecessary rebuilds
              trip: trip,
              onTap: () => onTripTap(trip),
              onDelete: showDelete && trip.userId == currentUserId
                  ? () => onDeleteTrip(trip)
                  : null,
              relationship: relationship,
              showAllBadges: true,
            );
          },
        );
      },
    );
  }
}
