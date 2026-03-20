import 'package:flutter/material.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/core/constants/api_endpoints.dart';
import 'package:wanderer_frontend/core/constants/enums.dart';
import 'package:intl/intl.dart';

import '../../helpers/auth_navigation_helper.dart';
import '../common/user_avatar.dart';

class TripCard extends StatefulWidget {
  final Trip trip;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const TripCard({
    super.key,
    required this.trip,
    required this.onTap,
    this.onDelete,
  });

  @override
  State<TripCard> createState() => _TripCardState();
}

class _TripCardState extends State<TripCard> {
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

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Theme.of(context).colorScheme.surface,
          child: InkWell(
            onTap: widget.onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Map preview section with overlays
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Map or placeholder
                      if (widget.trip.thumbnailUrl != null)
                        Image.network(
                          ApiEndpoints.resolveThumbnailUrl(
                              widget.trip.thumbnailUrl),
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) {
                              return child;
                            }
                            return _buildLoadingPlaceholder();
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return _buildNoMapPlaceholder();
                          },
                        )
                      else
                        _buildNoMapPlaceholder(),

                      // Gradient overlay at bottom for better text readability
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        height: 60,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.4),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Status badge overlay (bottom left)
                      Positioned(
                        bottom: 8,
                        left: 8,
                        child: _buildStatusBadge(),
                      ),

                      // Visibility badge overlay (bottom right)
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Wrap(
                          spacing: 6,
                          children: [
                            _buildVisibilityBadge(),
                            if (widget.trip.currentDay != null &&
                                widget.trip.tripModality ==
                                    TripModality.multiDay)
                              _buildDayBadge(context, widget.trip.currentDay!),
                          ],
                        ),
                      ),

                      // Delete button overlay (top right)
                      if (widget.onDelete != null)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: _buildDeleteButton(),
                        ),

                      // Edit indicator for own trips (top left)
                      if (widget.onDelete != null)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: _buildEditIndicator(),
                        ),
                    ],
                  ),
                ),
                // Trip info section
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: _buildInfoContent(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoContent(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    if (isMobile) {
      // Mobile: compact 2-row layout
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.trip.name,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: onSurface,
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
                            fontWeight: FontWeight.w500,
                            color: onSurface.withOpacity(0.7),
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
              Icon(Icons.chat_bubble_outline,
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

    // Web/desktop: original 3-row layout
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.trip.name,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: onSurface,
            letterSpacing: -0.3,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: () => AuthNavigationHelper.navigateToUserProfile(
              context, widget.trip.userId),
          borderRadius: BorderRadius.circular(4),
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
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    '@${widget.trip.username}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: onSurface.withOpacity(0.7),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.access_time,
                size: 12, color: onSurface.withOpacity(0.5)),
            const SizedBox(width: 4),
            Text(
              _formatDate(widget.trip.createdAt),
              style: TextStyle(fontSize: 11, color: onSurface.withOpacity(0.5)),
            ),
            const SizedBox(width: 12),
            Icon(Icons.chat_bubble_outline,
                size: 12, color: onSurface.withOpacity(0.5)),
            const SizedBox(width: 4),
            Text(
              '${widget.trip.commentsCount}',
              style: TextStyle(fontSize: 11, color: onSurface.withOpacity(0.5)),
            ),
          ],
        ),
      ],
    );
  }

  /// Build a loading placeholder with shimmer effect
  Widget _buildLoadingPlaceholder() {
    final surface = Theme.of(context).colorScheme.surface;
    final surfaceHigh = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [surface, surfaceHigh, surface],
        ),
      ),
      child: Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(
            WandererTheme.primaryOrange.withOpacity(0.5),
          ),
        ),
      ),
    );
  }

  /// Build a stylish placeholder for trips without map data
  Widget _buildNoMapPlaceholder() {
    final surface = Theme.of(context).colorScheme.surface;
    final surfaceHigh = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [surfaceHigh, surface],
        ),
      ),
      child: Stack(
        children: [
          // Pattern background
          Positioned.fill(
            child: CustomPaint(
              painter: _MapPatternPainter(),
            ),
          ),
          // Center icon
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface.withOpacity(0.8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.map_outlined,
                size: 32,
                color: WandererTheme.primaryOrange.withOpacity(0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build colored status badge
  Widget _buildStatusBadge() {
    final l10n = context.l10n;
    final statusColor = _getStatusColor(widget.trip.status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.9),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getStatusIcon(widget.trip.status),
            size: 10,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            _formatStatus(widget.trip.status, l10n),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  /// Build visibility badge
  Widget _buildVisibilityBadge() {
    final visibility = widget.trip.visibility.toJson();
    IconData icon;
    Color color;

    switch (visibility) {
      case 'PUBLIC':
        icon = Icons.public;
        color = Colors.green;
        break;
      case 'FRIENDS':
        icon = Icons.people;
        color = Colors.blue;
        break;
      default:
        icon = Icons.lock;
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        icon,
        size: 14,
        color: color,
      ),
    );
  }

  /// Build day badge for multi-day trips
  Widget _buildDayBadge(BuildContext context, int day) {
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
            'Day $day',
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

  /// Build delete button
  Widget _buildDeleteButton() {
    return Material(
      color: Colors.red.withOpacity(0.9),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: widget.onDelete,
        child: const Padding(
          padding: EdgeInsets.all(6),
          child: Icon(
            Icons.delete_outline,
            color: Colors.white,
            size: 18,
          ),
        ),
      ),
    );
  }

  /// Build edit indicator for own trips
  Widget _buildEditIndicator() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: WandererTheme.primaryOrange.withOpacity(0.9),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: WandererTheme.primaryOrange.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Icon(
        Icons.edit,
        size: 14,
        color: Colors.white,
      ),
    );
  }

  /// Get status color based on trip status
  Color _getStatusColor(TripStatus status) {
    switch (status) {
      case TripStatus.created:
        return const Color(0xFF6C757D); // Gray
      case TripStatus.inProgress:
        return const Color(0xFF28A745); // Green
      case TripStatus.paused:
        return const Color(0xFFFFC107); // Yellow/Amber
      case TripStatus.finished:
        return const Color(0xFF007BFF); // Blue
      case TripStatus.resting:
        return WandererTheme.statusResting; // Indigo
    }
  }

  /// Get status icon
  IconData _getStatusIcon(TripStatus status) {
    switch (status) {
      case TripStatus.created:
        return Icons.pending_outlined;
      case TripStatus.inProgress:
        return Icons.play_arrow;
      case TripStatus.paused:
        return Icons.pause;
      case TripStatus.finished:
        return Icons.check_circle_outline;
      case TripStatus.resting:
        return Icons.nightlight_round;
    }
  }

  /// Format status text for display
  String _formatStatus(TripStatus status, AppLocalizations l10n) {
    switch (status) {
      case TripStatus.created:
        return l10n.draft.toUpperCase();
      case TripStatus.inProgress:
        return l10n.live.toUpperCase();
      case TripStatus.paused:
        return l10n.paused.toUpperCase();
      case TripStatus.finished:
        return l10n.completed.toUpperCase();
      case TripStatus.resting:
        return l10n.resting.toUpperCase();
    }
  }
}

/// Custom painter for map pattern background
class _MapPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey[300]!.withOpacity(0.5)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Draw grid pattern
    const spacing = 20.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
