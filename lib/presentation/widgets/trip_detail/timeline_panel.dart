import 'package:flutter/material.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/presentation/widgets/trip_detail/trip_timeline.dart';
import 'package:wanderer_frontend/presentation/widgets/trip_detail/base_panel.dart';

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
    final badgeText = updates.isEmpty
        ? null
        : (updates.length > 99
            ? '99+'
            : '${updates.length}${hasMore ? '+' : ''}');

    return BasePanel(
      isCollapsed: isCollapsed,
      collapsedChild: CollapsedBubble(
        icon: Icons.timeline,
        onTap: onToggleCollapse,
        badgeText: badgeText,
      ),
      expandedChild: ExpandedCard(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PanelHeader(
              icon: Icons.timeline,
              title: 'Timeline',
              onMinimize: onToggleCollapse,
              trailing: Text.rich(
                TextSpan(
                  text: 'Timeline',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  children: [
                    if (totalDistanceKm != null && totalDistanceKm! > 0) ...[
                      const TextSpan(text: '  '),
                      TextSpan(
                        text: '${totalDistanceKm!.toStringAsFixed(1)} km',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: WandererTheme.primaryOrange,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
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
    );
  }
}
