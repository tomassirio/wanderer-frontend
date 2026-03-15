import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' hide Visibility;
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/data/models/achievement_models.dart';
import 'package:wanderer_frontend/presentation/helpers/auth_navigation_helper.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/core/constants/enums.dart';
import 'package:wanderer_frontend/presentation/widgets/trip_detail/trip_share_dialog.dart';

/// Widget displaying trip information card with glassmorphism design
/// Supports collapsible state that shows as a floating bubble
class TripInfoCard extends StatelessWidget {
  final Trip trip;
  final bool isCollapsed;
  final VoidCallback onToggleCollapse;
  final String? currentUserId;
  final VoidCallback? onFollowUser;
  final VoidCallback? onSendFriendRequest;
  final bool isFollowing;
  final bool hasSentFriendRequest;
  final bool isAlreadyFriends;
  final bool isPromoted;
  final List<UserAchievement> tripAchievements;
  final Function(Visibility)? onVisibilityChange;

  const TripInfoCard({
    super.key,
    required this.trip,
    required this.isCollapsed,
    required this.onToggleCollapse,
    this.currentUserId,
    this.onFollowUser,
    this.onSendFriendRequest,
    this.isFollowing = false,
    this.hasSentFriendRequest = false,
    this.isAlreadyFriends = false,
    this.isPromoted = false,
    this.tripAchievements = const [],
    this.onVisibilityChange,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedCrossFade(
      duration: const Duration(milliseconds: 300),
      firstCurve: Curves.easeInOut,
      secondCurve: Curves.easeInOut,
      sizeCurve: Curves.easeInOut,
      alignment: Alignment.topLeft,
      crossFadeState:
          isCollapsed ? CrossFadeState.showFirst : CrossFadeState.showSecond,
      firstChild: _buildCollapsedBubble(context),
      secondChild: _buildExpandedCard(context),
    );
  }

  /// Collapsed state - floating bubble with info icon
  Widget _buildCollapsedBubble(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: WandererTheme.floatingShadow,
      ),
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: WandererTheme.glassBlurSigma,
            sigmaY: WandererTheme.glassBlurSigma,
          ),
          child: Material(
            color: WandererTheme.glassBackgroundFor(context),
            shape: CircleBorder(
              side: BorderSide(
                color: WandererTheme.glassBorderColorFor(context),
                width: 1,
              ),
            ),
            child: InkWell(
              onTap: onToggleCollapse,
              customBorder: const CircleBorder(),
              child: Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.info_outline,
                  size: 24,
                  color: WandererTheme.primaryOrange,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Expanded state - full info card
  Widget _buildExpandedCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(WandererTheme.glassRadius),
        boxShadow: WandererTheme.floatingShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(WandererTheme.glassRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: WandererTheme.glassBlurSigma,
            sigmaY: WandererTheme.glassBlurSigma,
          ),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: WandererTheme.glassBackgroundFor(context),
              borderRadius: BorderRadius.circular(WandererTheme.glassRadius),
              border: Border.all(
                color: WandererTheme.glassBorderColorFor(context),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title row with status chip and collapse button
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        trip.name,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      height: 28,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: WandererTheme.statusChipDecoration(
                          trip.status.toJson()),
                      child: Text(
                        trip.status.displayLabel,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: WandererTheme.statusTextColor(
                              trip.status.toJson()),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Share / QR code button
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.qr_code,
                          size: 16,
                          color: WandererTheme.primaryOrange,
                        ),
                        onPressed: () => TripShareDialog.show(
                          context,
                          tripId: trip.id,
                          tripName: trip.name,
                        ),
                        tooltip: 'Share trip',
                        padding: EdgeInsets.zero,
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Collapse button
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.remove,
                          size: 16,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        ),
                        onPressed: onToggleCollapse,
                        tooltip: 'Minimize',
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // User info row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          AuthNavigationHelper.navigateToUserProfile(
                            context,
                            trip.userId,
                          );
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 12,
                                backgroundColor: WandererTheme.primaryOrange,
                                child: Text(
                                  trip.username.isNotEmpty
                                      ? trip.username[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '@${trip.username}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: WandererTheme.primaryOrange,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.chevron_right,
                                size: 14,
                                color: WandererTheme.primaryOrange,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Promoted badge on the right side of the user row
                    if (isPromoted) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade700,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.star,
                              size: 13,
                              color: Colors.white,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Promoted',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    // Show follow/friend buttons if viewing another user's trip
                    if (onFollowUser != null ||
                        onSendFriendRequest != null) ...[
                      const SizedBox(width: 8),
                      if (onFollowUser != null)
                        Container(
                          height: 28,
                          decoration: BoxDecoration(
                            color: isFollowing
                                ? Colors.blue.withOpacity(0.7)
                                : Theme.of(context).colorScheme.onSurface.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: IconButton(
                            icon: Icon(
                              isFollowing
                                  ? Icons.person_remove
                                  : Icons.person_add,
                              size: 16,
                              color: isFollowing ? Colors.white : null,
                            ),
                            onPressed: onFollowUser,
                            tooltip: isFollowing ? 'Unfollow' : 'Follow',
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            constraints: const BoxConstraints(),
                          ),
                        ),
                      if (onSendFriendRequest != null) ...[
                        const SizedBox(width: 4),
                        Container(
                          height: 28,
                          decoration: BoxDecoration(
                            color: isAlreadyFriends
                                ? Colors.green.withOpacity(0.7)
                                : hasSentFriendRequest
                                    ? Colors.orange.withOpacity(0.7)
                                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: isAlreadyFriends
                              ? InkWell(
                                  onTap: onSendFriendRequest,
                                  borderRadius: BorderRadius.circular(6),
                                  child: Tooltip(
                                    message: 'Unfriend',
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.people,
                                            size: 16,
                                            color: Colors.white,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Friends',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.white,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                )
                              : IconButton(
                                  icon: Icon(
                                    hasSentFriendRequest
                                        ? Icons.person_add_disabled
                                        : Icons.person_add_alt,
                                    size: 16,
                                    color: hasSentFriendRequest
                                        ? Colors.white
                                        : null,
                                  ),
                                  onPressed: onSendFriendRequest,
                                  tooltip: hasSentFriendRequest
                                      ? 'Cancel Friend Request'
                                      : 'Send Friend Request',
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 8),
                                  constraints: const BoxConstraints(),
                                ),
                        ),
                      ],
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                // Stats row - comments and visibility together, day on the right for multi-day
                Row(
                  children: [
                    // Comments
                    _buildStatChip(
                      context,
                      Icons.comment_outlined,
                      '${trip.commentsCount} comments',
                    ),
                    const SizedBox(width: 16),
                    // Visibility
                    if (onVisibilityChange != null)
                      _buildTappableVisibilityItem(context)
                    else
                      _buildStatChip(
                        context,
                        _getVisibilityIcon(trip.visibility.toJson()),
                        trip.visibility.toJson(),
                      ),
                    // Day badge pushed to the right for multi-day trips
                    if (trip.tripModality == TripModality.multiDay &&
                        trip.currentDay != null) ...[
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.deepPurple.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          'Day ${trip.currentDay}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.deepPurple,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                // Description if present
                if (trip.description != null &&
                    trip.description!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: WandererTheme.glassBorderColorFor(context),
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      trip.description!,
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
                // Trip achievements
                if (tripAchievements.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: WandererTheme.glassBorderColorFor(context),
                        width: 0.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.emoji_events,
                              size: 14,
                              color: Colors.amber.shade700,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Achievements Earned',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: tripAchievements
                              .map(
                                (ua) => _buildAchievementBadge(context, ua),
                              )
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAchievementBadge(
    BuildContext context,
    UserAchievement userAchievement,
  ) {
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.amber.shade300,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.emoji_events,
            size: 12,
            color: Colors.amber.shade700,
          ),
          const SizedBox(width: 4),
          Text(
            userAchievement.achievement.name,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.amber.shade900,
            ),
          ),
        ],
      ),
    );

    final description = userAchievement.achievement.description;

    if (kIsWeb) {
      return Tooltip(
        message: description,
        preferBelow: true,
        verticalOffset: 16,
        decoration: BoxDecoration(
          color: Colors.grey.shade800,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(
          color: Colors.white,
          fontSize: 12,
        ),
        child: GestureDetector(
          onTap: () => _showAchievementDescription(context, userAchievement),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: badge,
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () => _showAchievementDescription(context, userAchievement),
      child: badge,
    );
  }

  void _showAchievementDescription(
    BuildContext context,
    UserAchievement userAchievement,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(
              Icons.emoji_events,
              color: Colors.amber.shade700,
              size: 24,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                userAchievement.achievement.name,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.amber.shade900,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          userAchievement.achievement.description,
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'OK',
              style: TextStyle(color: Colors.amber.shade700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTappableVisibilityItem(BuildContext context) {
    return InkWell(
      onTap: () => _showVisibilityPicker(context),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _getVisibilityIcon(trip.visibility.toJson()),
              size: 16,
              color: WandererTheme.primaryOrange,
            ),
            const SizedBox(width: 4),
            Text(
              trip.visibility.toJson(),
              style: TextStyle(
                fontSize: 13,
                color: WandererTheme.primaryOrange,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.edit,
              size: 12,
              color: WandererTheme.primaryOrange,
            ),
          ],
        ),
      ),
    );
  }

  void _showVisibilityPicker(BuildContext context) {
    showModalBottomSheet<Visibility>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Change Visibility',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.public, color: Colors.green),
              title: const Text('Public'),
              subtitle: const Text('Visible to everyone'),
              selected: trip.visibility == Visibility.public,
              onTap: () => Navigator.pop(context, Visibility.public),
            ),
            ListTile(
              leading: Icon(Icons.shield, color: Colors.orange.shade700),
              title: const Text('Protected'),
              subtitle: const Text('Visible to friends only'),
              selected: trip.visibility == Visibility.protected,
              onTap: () => Navigator.pop(context, Visibility.protected),
            ),
            ListTile(
              leading: const Icon(Icons.lock, color: Colors.red),
              title: const Text('Private'),
              subtitle: const Text('Only visible to you'),
              selected: trip.visibility == Visibility.private,
              onTap: () => Navigator.pop(context, Visibility.private),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ).then((selectedVisibility) {
      if (selectedVisibility != null &&
          selectedVisibility != trip.visibility &&
          onVisibilityChange != null) {
        onVisibilityChange!(selectedVisibility);
      }
    });
  }

  Widget _buildStatChip(BuildContext context, IconData icon, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
        ),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      ],
    );
  }

  IconData _getVisibilityIcon(String visibility) {
    switch (visibility.toLowerCase()) {
      case 'public':
        return Icons.public;
      case 'private':
        return Icons.lock;
      case 'protected':
        return Icons.shield;
      default:
        return Icons.visibility;
    }
  }
}
