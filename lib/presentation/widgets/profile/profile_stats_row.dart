import 'package:flutter/material.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';

/// The trips/followers/following/friends stat-card row shown under the
/// profile header. Followers/following/friends cards are tappable (navigate
/// to the friends/followers screen) only when viewing your own profile.
class ProfileStatsRow extends StatelessWidget {
  final int tripsCount;
  final int followersCount;
  final int followingCount;
  final int friendsCount;
  final bool isViewingOwnProfile;
  final VoidCallback? onFollowersFollowingFriendsTap;

  const ProfileStatsRow({
    super.key,
    required this.tripsCount,
    required this.followersCount,
    required this.followingCount,
    required this.friendsCount,
    required this.isViewingOwnProfile,
    required this.onFollowersFollowingFriendsTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tapCallback =
        isViewingOwnProfile ? onFollowersFollowingFriendsTap : null;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStatCard(l10n.trips, tripsCount.toString(), null),
        _buildStatCard(l10n.followers, followersCount.toString(), tapCallback),
        _buildStatCard(l10n.following, followingCount.toString(), tapCallback),
        _buildStatCard(l10n.friends, friendsCount.toString(), tapCallback),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, VoidCallback? onTap) {
    final card = Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );

    return Expanded(
      child: onTap != null
          ? InkWell(
              onTap: onTap,
              child: card,
            )
          : card,
    );
  }
}
