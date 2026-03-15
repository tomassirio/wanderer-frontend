import 'package:flutter/material.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/presentation/widgets/home/trip_card.dart';
import 'package:wanderer_frontend/presentation/widgets/home/empty_trips_view.dart';
import 'package:wanderer_frontend/presentation/widgets/home/error_view.dart';

class HomeContent extends StatelessWidget {
  final bool isLoading;
  final String? error;
  final List<Trip> trips;
  final bool isLoggedIn;
  final String? currentUserId;
  final Future<void> Function() onRefresh;
  final Function(Trip) onTripTap;
  final Function(Trip)? onDeleteTrip;
  final VoidCallback? onLoginPressed;

  const HomeContent({
    super.key,
    required this.isLoading,
    this.error,
    required this.trips,
    required this.isLoggedIn,
    this.currentUserId,
    required this.onRefresh,
    required this.onTripTap,
    this.onDeleteTrip,
    this.onLoginPressed,
  });

  List<Trip> _filterMyTrips() {
    if (!isLoggedIn || currentUserId == null) return [];
    return trips.where((trip) => trip.userId == currentUserId).toList();
  }

  List<Trip> _filterFriendsTrips() {
    if (!isLoggedIn || currentUserId == null) return [];
    // For now, friends trips are those from other users that are not public
    // This logic can be enhanced when friend relationships are implemented
    return trips
        .where(
          (trip) =>
              trip.userId != currentUserId &&
              trip.visibility.toJson() == 'FRIENDS',
        )
        .toList();
  }

  List<Trip> _filterPublicTrips() {
    if (!isLoggedIn || currentUserId == null) {
      // Show all trips when not logged in
      return trips;
    }
    return trips
        .where(
          (trip) =>
              trip.userId != currentUserId &&
              trip.visibility.toJson() == 'PUBLIC',
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null) {
      return ErrorView(error: error!, onRetry: onRefresh);
    }

    if (trips.isEmpty) {
      return EmptyTripsView(
        isLoggedIn: isLoggedIn,
        onLoginPressed: onLoginPressed,
      );
    }

    final myTrips = _filterMyTrips();
    final friendsTrips = _filterFriendsTrips();
    final publicTrips = _filterPublicTrips();

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Calculate number of columns based on screen width
          int crossAxisCount = 1;
          if (constraints.maxWidth > 1200) {
            crossAxisCount = 4;
          } else if (constraints.maxWidth > 900) {
            crossAxisCount = 3;
          } else if (constraints.maxWidth > 600) {
            crossAxisCount = 2;
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Welcome header for guests
              if (!isLoggedIn) ...[
                _buildGuestWelcomeHeader(context),
                const SizedBox(height: 24),
              ],
              // My Trips Section
              if (myTrips.isNotEmpty) ...[
                _buildSectionHeader(
                  context,
                  'My Trips',
                  myTrips.length,
                  Icons.person_outline,
                  WandererTheme.primaryOrange,
                ),
                const SizedBox(height: 12),
                _buildTripGrid(myTrips, crossAxisCount),
                const SizedBox(height: 32),
              ],
              // Friends Trips Section
              if (friendsTrips.isNotEmpty) ...[
                _buildSectionHeader(
                  context,
                  'Friends Trips',
                  friendsTrips.length,
                  Icons.people_outline,
                  Colors.blue,
                ),
                const SizedBox(height: 12),
                _buildTripGrid(friendsTrips, crossAxisCount),
                const SizedBox(height: 32),
              ],
              // Public/Discover Trips Section
              if (publicTrips.isNotEmpty) ...[
                _buildSectionHeader(
                  context,
                  isLoggedIn ? 'Discover' : 'Discover',
                  publicTrips.length,
                  Icons.explore,
                  Colors.green,
                ),
                const SizedBox(height: 4),
                Text(
                  'Explore public trips from the community',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.45),
                  ),
                ),
                const SizedBox(height: 12),
                _buildTripGrid(publicTrips, crossAxisCount),
              ],
            ],
          );
        },
      ),
    );
  }

  /// Build a welcoming header for guest users
  Widget _buildGuestWelcomeHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            WandererTheme.primaryOrange.withOpacity(0.05),
            WandererTheme.primaryOrangeLight.withOpacity(0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: WandererTheme.primaryOrange.withOpacity(0.15),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Welcome icon
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: WandererTheme.primaryOrange.withOpacity(0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              Icons.login,
              size: 32,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.45),
            ),
          ),
          const SizedBox(height: 16),
          // Welcome text
          const Text(
            'Welcome to Wanderer',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please log in to see personalized content',
            style: TextStyle(
              fontSize: 14,
              color:
                  Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          // Login button
          if (onLoginPressed != null)
            ElevatedButton(
              onPressed: onLoginPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: WandererTheme.primaryOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Log In',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(height: 12),
          Text(
            'Or explore public trips:',
            style: TextStyle(
              fontSize: 13,
              color:
                  Theme.of(context).colorScheme.onSurface.withOpacity(0.45),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    int count,
    IconData icon,
    Color accentColor,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 20,
            color: accentColor,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: accentColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTripGrid(List<Trip> trips, int crossAxisCount) {
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
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: trips.length,
      itemBuilder: (context, index) {
        final trip = trips[index];
        // Only show delete button for user's own trips
        final canDelete = isLoggedIn &&
            currentUserId != null &&
            trip.userId == currentUserId &&
            onDeleteTrip != null;
        return TripCard(
          trip: trip,
          onTap: () => onTripTap(trip),
          onDelete: canDelete ? () => onDeleteTrip!(trip) : null,
        );
      },
    );
  }
}
