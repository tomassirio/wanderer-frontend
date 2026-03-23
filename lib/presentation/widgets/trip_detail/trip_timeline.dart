import 'package:flutter/material.dart';
import 'package:wanderer_frontend/core/constants/enums.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/presentation/helpers/battery_helpers.dart';
import 'package:wanderer_frontend/presentation/helpers/weather_helpers.dart';

/// Widget displaying the timeline of trip updates
class TripTimeline extends StatelessWidget {
  final List<TripLocation> updates;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final VoidCallback onRefresh;
  final VoidCallback? onLoadMore;
  final Function(TripLocation)? onUpdateTap;

  const TripTimeline({
    super.key,
    required this.updates,
    required this.isLoading,
    this.isLoadingMore = false,
    this.hasMore = false,
    required this.onRefresh,
    this.onLoadMore,
    this.onUpdateTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: WandererTheme.primaryOrange,
              strokeWidth: 2,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.loadingTimeline,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    if (updates.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: WandererTheme.primaryOrange.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.timeline,
                  size: 48,
                  color: WandererTheme.primaryOrange,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                l10n.noUpdatesYet,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.tripUpdatesWillAppear,
                style: TextStyle(
                  fontSize: 14,
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(l10n.refresh),
                style: TextButton.styleFrom(
                  foregroundColor: WandererTheme.primaryOrange,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      color: WandererTheme.primaryOrange,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: updates.length + (hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == updates.length) {
            return _buildLoadMoreButton(context);
          }
          final update = updates[index];
          final isLast = index == updates.length - 1;
          final isFirst = index == 0;

          return _buildRegularEntry(context, update, isFirst, isLast);
        },
      ),
    );
  }

  /// Returns the accent color for lifecycle markers, or null for regular updates.
  /// Matches the colors used in CustomInfoWindow and map markers.
  Color? _getLifecycleColor(TripUpdateType? updateType) {
    switch (updateType) {
      case TripUpdateType.tripStarted:
        return WandererTheme.tripStartedColor;
      case TripUpdateType.tripEnded:
        return WandererTheme.tripEndedColor;
      case TripUpdateType.dayStart:
        return WandererTheme.dayStartColor;
      case TripUpdateType.dayEnd:
        return WandererTheme.dayEndColor;
      default:
        return null;
    }
  }

  /// Returns the icon for lifecycle markers, or null for regular updates.
  IconData? _getLifecycleIcon(TripUpdateType? updateType) {
    switch (updateType) {
      case TripUpdateType.tripStarted:
        return Icons.flag_rounded;
      case TripUpdateType.tripEnded:
        return Icons.sports_score_rounded;
      case TripUpdateType.dayStart:
        return Icons.wb_sunny_rounded;
      case TripUpdateType.dayEnd:
        return Icons.nightlight_round;
      default:
        return null;
    }
  }

  /// Build the "Load older updates" button at the bottom of the timeline
  Widget _buildLoadMoreButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: isLoadingMore
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: WandererTheme.primaryOrange,
                  strokeWidth: 2,
                ),
              )
            : TextButton.icon(
                onPressed: onLoadMore,
                icon: const Icon(
                  Icons.expand_more,
                  color: WandererTheme.primaryOrange,
                ),
                label: Text(
                  context.l10n.loadOlderUpdates,
                  style: const TextStyle(color: WandererTheme.primaryOrange),
                ),
              ),
      ),
    );
  }

  /// Build a regular timeline entry (location update)
  Widget _buildRegularEntry(
      BuildContext context, TripLocation update, bool isFirst, bool isLast) {
    final lifecycleColor = _getLifecycleColor(update.updateType);
    final lifecycleIcon = _getLifecycleIcon(update.updateType);
    final isLifecycleMarker = lifecycleColor != null;
    final nodeColor = lifecycleColor ??
        (isFirst
            ? WandererTheme.primaryOrange
            : WandererTheme.timelineConnector);
    final borderColor = lifecycleColor?.withOpacity(0.3) ??
        (isFirst
            ? WandererTheme.primaryOrange.withOpacity(0.3)
            : WandererTheme.glassBorderColorFor(context));
    final accentColor =
        lifecycleColor ?? (isFirst ? WandererTheme.primaryOrange : null);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline connector
        SizedBox(
          width: 24,
          child: Column(
            children: [
              // Connector line above (if not first)
              if (!isFirst)
                Container(
                  width: 2,
                  height: 8,
                  color: WandererTheme.timelineConnector,
                ),
              // Timeline node
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: nodeColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: nodeColor,
                    width: 2,
                  ),
                ),
              ),
              // Connector line below (if not last)
              if (!isLast)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Container(
                    width: 2,
                    height: 80,
                    color: WandererTheme.timelineConnector,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // Update card
        Expanded(
          child: GestureDetector(
            onTap: onUpdateTap != null ? () => onUpdateTap!(update) : null,
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isLifecycleMarker || isFirst
                    ? Theme.of(context).colorScheme.surface
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius:
                    BorderRadius.circular(WandererTheme.glassRadiusSmall),
                border: Border.all(
                  color: borderColor,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Lifecycle label (for non-regular updates)
                  // Use the message (e.g., "Day 6 started!") if available
                  if (isLifecycleMarker) ...[
                    Row(
                      children: [
                        Icon(
                          lifecycleIcon,
                          size: 14,
                          color: lifecycleColor,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            (update.message != null &&
                                    update.message!.isNotEmpty)
                                ? update.message!
                                : update.updateType.displayLabel,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: lifecycleColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],
                  // Header: timestamp, weather, and battery
                  Row(
                    children: [
                      Text(
                        _formatTimestamp(context, update.timestamp),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: accentColor ??
                              Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.6),
                        ),
                      ),
                      Expanded(
                        child: (update.temperatureCelsius != null ||
                                update.weatherCondition != null)
                            ? Center(
                                child: _buildWeatherBadge(context, update),
                              )
                            : const SizedBox.shrink(),
                      ),
                      if (update.battery != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: BatteryHelpers.getBatteryColor(
                              update.battery!,
                            ).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                BatteryHelpers.getBatteryIcon(update.battery!),
                                size: 12,
                                color: BatteryHelpers.getBatteryColor(
                                    update.battery!),
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '${update.battery}%',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: BatteryHelpers.getBatteryColor(
                                      update.battery!),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  // Location (hide raw coordinates for lifecycle markers)
                  if (!isLifecycleMarker || update.city != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 14,
                          color: WandererTheme.primaryOrange,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            update.displayLocation,
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: update.city != null
                                  ? FontWeight.w500
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  // Message if present (only for regular updates)
                  // Lifecycle markers show the message in the top label instead
                  if (!isLifecycleMarker &&
                      update.message != null &&
                      update.message!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        update.message!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.6),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                  // Reactions if present
                  if (update.reactionCount > 0) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.favorite,
                          size: 12,
                          color: Colors.red.shade400,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${update.reactionCount}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWeatherBadge(BuildContext context, TripLocation update) {
    final condition = update.weatherCondition;
    final temp = update.temperatureCelsius;
    final weatherColor =
        condition != null ? WeatherHelpers.getWeatherColor(condition) : null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (condition != null)
          Icon(
            WeatherHelpers.getWeatherIcon(condition),
            size: 11,
            color: weatherColor,
          ),
        if (temp != null) ...[
          const SizedBox(width: 2),
          Text(
            WeatherHelpers.formatTemperature(temp),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: weatherColor ??
                  Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ],
    );
  }

  String _formatTimestamp(BuildContext context, DateTime timestamp) {
    final local = timestamp.toLocal();
    final now = DateTime.now();
    final difference = now.difference(local);
    final l10n = context.l10n;

    if (difference.inMinutes < 1) {
      return l10n.justNow;
    } else if (difference.inHours < 1) {
      return l10n.minutesAgoCompact(difference.inMinutes);
    } else if (difference.inDays < 1) {
      return l10n.hoursAgoCompact(difference.inHours);
    } else if (difference.inDays < 7) {
      return l10n.daysAgoCompact(difference.inDays);
    } else {
      return '${local.day}/${local.month}/${local.year} ${local.hour}:${local.minute.toString().padLeft(2, '0')}';
    }
  }
}
