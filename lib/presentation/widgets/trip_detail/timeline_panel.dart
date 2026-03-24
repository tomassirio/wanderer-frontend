import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/presentation/widgets/trip_detail/trip_timeline.dart';

/// Widget displaying the collapsible timeline panel with glassmorphism design
/// This panel floats as a detached card for the "anti-gravity" effect
/// Collapses to a floating bubble
class TimelinePanel extends StatelessWidget {
  final List<TripLocation> updates;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final bool isCollapsed;
  final VoidCallback onToggleCollapse;
  final VoidCallback onRefresh;
  final VoidCallback? onLoadMore;
  final Function(TripLocation)? onUpdateTap;
  final double? totalDistanceKm;

  const TimelinePanel({
    super.key,
    required this.updates,
    required this.isLoading,
    this.isLoadingMore = false,
    this.hasMore = false,
    required this.isCollapsed,
    required this.onToggleCollapse,
    required this.onRefresh,
    this.onLoadMore,
    this.onUpdateTap,
    this.totalDistanceKm,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedCrossFade(
      duration: const Duration(milliseconds: 300),
      firstCurve: Curves.easeInOut,
      secondCurve: Curves.easeInOut,
      sizeCurve: Curves.easeInOut,
      alignment: Alignment.topRight,
      crossFadeState:
          isCollapsed ? CrossFadeState.showFirst : CrossFadeState.showSecond,
      firstChild: _buildCollapsedBubble(context),
      secondChild: _buildExpandedPanel(context),
    );
  }

  /// Collapsed state - floating bubble with timeline icon and count badge
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
              child: Stack(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.timeline,
                      size: 24,
                      color: WandererTheme.primaryOrange,
                    ),
                  ),
                  // Badge with count
                  if (updates.isNotEmpty)
                    Positioned(
                      right: 4,
                      top: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 4),
                        decoration: BoxDecoration(
                          color: WandererTheme.primaryOrange,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        child: Center(
                          child: Text(
                            updates.length > 99
                                ? '99+'
                                : '${updates.length}${hasMore ? '+' : ''}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Expanded state - floating detached card
  Widget _buildExpandedPanel(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      width: 320,
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
            decoration: BoxDecoration(
              color: WandererTheme.glassBackgroundFor(context),
              borderRadius: BorderRadius.circular(WandererTheme.glassRadius),
              border: Border.all(
                color: WandererTheme.glassBorderColorFor(context),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with glass styling
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.08),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(WandererTheme.glassRadius),
                      topRight: Radius.circular(WandererTheme.glassRadius),
                    ),
                    border: Border(
                      bottom: BorderSide(
                        color: WandererTheme.glassBorderColorFor(context),
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: WandererTheme.primaryOrange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.timeline,
                          size: 18,
                          color: WandererTheme.primaryOrange,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Timeline',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            if (totalDistanceKm != null && totalDistanceKm! > 0)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  '${totalDistanceKm!.toStringAsFixed(1)} km',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: WandererTheme.primaryOrange,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: IconButton(
                          icon: Icon(
                            Icons.remove,
                            size: 18,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.6),
                          ),
                          onPressed: onToggleCollapse,
                          tooltip: 'Minimize',
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ),
                // Timeline content
                Flexible(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 380),
                    child: ClipRect(
                      child: TripTimeline(
                        updates: updates,
                        isLoading: isLoading,
                        isLoadingMore: isLoadingMore,
                        hasMore: hasMore,
                        onRefresh: onRefresh,
                        onLoadMore: onLoadMore,
                        onUpdateTap: onUpdateTap,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
