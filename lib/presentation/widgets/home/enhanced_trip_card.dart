import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/constants/enums.dart';
import '../../../core/theme/wanderer_theme.dart';
import '../../helpers/auth_navigation_helper.dart';
import '../common/user_avatar.dart';
import 'visibility_badge.dart';
import 'status_badge.dart';
import 'relationship_badge.dart';

class EnhancedTripCard extends StatefulWidget {
  final Trip trip;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final RelationshipType? relationship;
  final bool showAllBadges;
  final bool isPromoted;
  final PromotedTrip? promotedTrip;

  const EnhancedTripCard({
    super.key,
    required this.trip,
    required this.onTap,
    this.onDelete,
    this.relationship,
    this.showAllBadges = true,
    this.isPromoted = false,
    this.promotedTrip,
  });

  @override
  State<EnhancedTripCard> createState() => _EnhancedTripCardState();
}

class _EnhancedTripCardState extends State<EnhancedTripCard> {
  @override
  void initState() {
    super.initState();
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    final l10n = context.l10n;

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return l10n.justNow;
        }
        return difference.inMinutes == 1
            ? l10n.minuteAgo
            : l10n.minutesAgo(difference.inMinutes);
      }
      return difference.inHours == 1
          ? l10n.hourAgo
          : l10n.hoursAgo(difference.inHours);
    } else if (difference.inDays < 7) {
      return difference.inDays == 1
          ? l10n.dayAgo
          : l10n.daysAgo(difference.inDays);
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return weeks == 1 ? l10n.weekAgo : l10n.weeksAgo(weeks);
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return months == 1 ? l10n.monthAgo : l10n.monthsAgo(months);
    } else {
      return DateFormat('MMM d, yyyy').format(date);
    }
  }

  /// Whether this card should show the coming-soon blur+countdown overlay.
  bool get _isPreAnnouncedCreated =>
      widget.promotedTrip != null &&
      widget.promotedTrip!.isPreAnnounced &&
      widget.trip.status == TripStatus.created;

  /// Formats a countdown string: "X days", "Today", or "Starts [date]".
  String _formatCountdown(DateTime startDate) {
    final localStart = startDate.toLocal();
    final startDay =
        DateTime(localStart.year, localStart.month, localStart.day);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = startDay.difference(today).inDays;
    if (days <= 0) return context.l10n.startingToday;
    if (days == 1) return context.l10n.startsTomorrow;
    if (days < 30) return context.l10n.startsInDays(days);
    return 'Starts ${DateFormat('MMM d, yyyy').format(localStart)}';
  }

  /// Builds the "Pre Announced" badge shown instead of "Draft" for
  /// promoted pre-announced trips.
  Widget _buildPreAnnouncedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.deepPurple.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.campaign, size: 16, color: Colors.deepPurple.shade700),
          const SizedBox(width: 6),
          Text(
            context.l10n.preAnnounced,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayBadge(int day) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: WandererTheme.primaryOrange.withOpacity(0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: WandererTheme.primaryOrange.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.calendar_today,
              size: 12, color: WandererTheme.primaryOrange),
          const SizedBox(width: 4),
          Text(
            context.l10n.dayNumber(day),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: WandererTheme.primaryOrange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoContent(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    if (isMobile) {
      final colorScheme = Theme.of(context).colorScheme;
      final onSurface = colorScheme.onSurface;
      // Mobile: compact 2-row layout (title + username/metadata row)
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.trip.name,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              height: 1.2,
              letterSpacing: -0.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => AuthNavigationHelper.navigateToUserProfile(
                      context, widget.trip.userId),
                  borderRadius: BorderRadius.circular(4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      UserAvatar(
                        avatarUrl: widget.trip.avatarUrl,
                        username: widget.trip.username,
                        radius: 8,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          '@${widget.trip.username}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.primary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Icon(Icons.access_time,
                  size: 11, color: onSurface.withOpacity(0.5)),
              const SizedBox(width: 3),
              Text(_formatDate(widget.trip.createdAt),
                  style: TextStyle(
                      fontSize: 11, color: onSurface.withOpacity(0.5))),
              const SizedBox(width: 8),
              Icon(Icons.comment_outlined,
                  size: 11, color: onSurface.withOpacity(0.5)),
              const SizedBox(width: 3),
              Text('${widget.trip.commentsCount}',
                  style: TextStyle(
                      fontSize: 11, color: onSurface.withOpacity(0.5))),
            ],
          ),
        ],
      );
    }

    // Web/desktop: original 3-row layout matching production
    final colorScheme = Theme.of(context).colorScheme;
    final onSurface = colorScheme.onSurface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Title
        Text(
          widget.trip.name,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            height: 1.3,
            letterSpacing: -0.5,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
        // Username row
        InkWell(
          onTap: () => AuthNavigationHelper.navigateToUserProfile(
              context, widget.trip.userId),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                UserAvatar(
                  avatarUrl: widget.trip.avatarUrl,
                  username: widget.trip.username,
                  radius: 10,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    '@${widget.trip.username}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.primary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Metadata row
        Row(
          children: [
            Icon(Icons.access_time,
                size: 14, color: onSurface.withOpacity(0.5)),
            const SizedBox(width: 4),
            Text(
              _formatDate(widget.trip.createdAt),
              style: TextStyle(
                fontSize: 13,
                color: onSurface.withOpacity(0.5),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 12),
            Icon(Icons.comment_outlined,
                size: 14, color: onSurface.withOpacity(0.5)),
            const SizedBox(width: 4),
            Text(
              '${widget.trip.commentsCount}',
              style: TextStyle(
                fontSize: 13,
                color: onSurface.withOpacity(0.5),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 3,
      shadowColor: Colors.black.withOpacity(0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: widget.onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Static map preview with gradient overlay
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (widget.trip.thumbnailUrl.isNotEmpty)
                    Image.network(
                      ApiEndpoints.resolveThumbnailUrl(
                          widget.trip.thumbnailUrl),
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) {
                          return child;
                        }
                        return Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Theme.of(context).colorScheme.surface,
                                Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                              ],
                            ),
                          ),
                          child: Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Theme.of(context).colorScheme.surface,
                                Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                              ],
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.map,
                              size: 48,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.4),
                            ),
                          ),
                        );
                      },
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Theme.of(context).colorScheme.surface,
                            Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                          ],
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.map_outlined,
                          size: 48,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.4),
                        ),
                      ),
                    ),

                  // Subtle gradient overlay for better badge visibility
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.3),
                          Colors.transparent,
                          Colors.transparent,
                          Colors.black.withOpacity(0.3),
                        ],
                        stops: const [0.0, 0.25, 0.75, 1.0],
                      ),
                    ),
                  ),

                  // Pre-announced blur + countdown overlay
                  if (_isPreAnnouncedCreated)
                    Positioned.fill(
                      child: ClipRect(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                          child: Container(
                            color: Colors.black.withOpacity(0.45),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.access_time,
                                  color: Colors.white,
                                  size: 28,
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Coming Soon',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                if (widget.promotedTrip!.countdownStartDate !=
                                    null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatCountdown(
                                      widget.promotedTrip!.countdownStartDate!,
                                    ),
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Top badges overlay with shadow for visibility
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (widget.showAllBadges)
                          _isPreAnnouncedCreated
                              ? _buildPreAnnouncedBadge()
                              : StatusBadge(
                                  status: widget.trip.status, compact: false),
                        if (widget.relationship != null)
                          RelationshipBadge(
                            type: widget.relationship!,
                            compact: false,
                          ),
                      ],
                    ),
                  ),

                  // Promoted badge overlay (bottom right corner)
                  if (widget.isPromoted)
                    Positioned(
                      bottom: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade700,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star,
                              size: 14,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              context.l10n.promoted,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Visibility badge overlay
                  if (widget.showAllBadges)
                    Positioned(
                      bottom: 10,
                      left: 10,
                      child: Wrap(
                        spacing: 6,
                        children: [
                          VisibilityBadge(
                            visibility: widget.trip.visibility,
                            compact: false,
                          ),
                          if (widget.trip.currentDay != null &&
                              widget.trip.tripModality == TripModality.multiDay)
                            _buildDayBadge(widget.trip.currentDay!),
                        ],
                      ),
                    ),

                  // Delete button overlay with better contrast
                  if (widget.onDelete != null)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.red.shade600,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(24),
                            onTap: widget.onDelete,
                            child: const Padding(
                              padding: EdgeInsets.all(8),
                              child: Icon(
                                Icons.delete_outline,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Trip info section
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).dividerColor,
                    width: 1,
                  ),
                ),
              ),
              child: _buildInfoContent(context),
            ),
          ],
        ),
      ),
    );
  }
}
