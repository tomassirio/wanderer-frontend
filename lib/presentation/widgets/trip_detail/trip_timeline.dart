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
          final isDayMarker = update.updateType == TripUpdateType.dayStart ||
              update.updateType == TripUpdateType.dayEnd ||
              update.updateType == TripUpdateType.tripStarted ||
              update.updateType == TripUpdateType.tripEnded;

          if (isDayMarker) {
            final dayNumber = _computeDayNumber(index);
            return _buildDayMarkerEntry(
                context, update, isFirst, isLast, dayNumber);
          }

          return _buildRegularEntry(context, update, isFirst, isLast);
        },
      ),
    );
  }

  /// Compute which day number a marker at [markerIndex] belongs to.
  /// We walk the updates list in chronological order (reverse of display)
  /// and count DAY_START events to track the current day.
  /// Day 1 = trip start. Each DAY_START bumps the day number.
  int _computeDayNumber(int markerIndex) {
    // Walk in reverse (chronological order, oldest first)
    int day = 1;
    for (int i = updates.length - 1; i >= 0; i--) {
      final t = updates[i].updateType;
      // DAY_START means a new day begins → increment before checking
      if (t == TripUpdateType.dayStart) {
        day++;
      }
      if (i == markerIndex) return day;
    }
    return day;
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
                  color: isFirst
                      ? WandererTheme.primaryOrange
                      : WandererTheme.timelineConnector,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isFirst
                        ? WandererTheme.primaryOrange
                        : Colors.grey.shade400,
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
                color: isFirst
                    ? Theme.of(context).colorScheme.surface
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius:
                    BorderRadius.circular(WandererTheme.glassRadiusSmall),
                border: Border.all(
                  color: isFirst
                      ? WandererTheme.primaryOrange.withOpacity(0.3)
                      : WandererTheme.glassBorderColorFor(context),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header: timestamp, weather, and battery
                  Row(
                    children: [
                      Text(
                        _formatTimestamp(context, update.timestamp),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isFirst
                              ? WandererTheme.primaryOrange
                              : Theme.of(context)
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
                  const SizedBox(height: 8),
                  // Location
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
                  // Message if present
                  if (update.message != null && update.message!.isNotEmpty) ...[
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

  /// Build a day/trip marker timeline entry (Day Start / Day End / Trip Started / Trip Ended)
  Widget _buildDayMarkerEntry(BuildContext context, TripLocation update,
      bool isFirst, bool isLast, int dayNumber) {
    final Color markerColor;
    final IconData markerIcon;
    final String label;

    switch (update.updateType) {
      case TripUpdateType.dayStart:
        markerColor = WandererTheme.dayStartColor;
        markerIcon = Icons.wb_sunny_rounded;
        label = 'Day $dayNumber Started';
      case TripUpdateType.dayEnd:
        markerColor = WandererTheme.dayEndColor;
        markerIcon = Icons.nightlight_round;
        label = 'Day $dayNumber Ended';
      case TripUpdateType.tripStarted:
        markerColor = WandererTheme.tripStartedColor;
        markerIcon = Icons.flag_rounded;
        label = 'Trip Started';
      case TripUpdateType.tripEnded:
        markerColor = WandererTheme.tripEndedColor;
        markerIcon = Icons.sports_score_rounded;
        label = 'Trip Ended';
      case TripUpdateType.regular:
        // Should not reach here; fall back to neutral styling
        markerColor = Theme.of(context).colorScheme.onSurface.withOpacity(0.6);
        markerIcon = Icons.location_on;
        label = 'Update';
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline connector with themed node
        SizedBox(
          width: 24,
          child: Column(
            children: [
              if (!isFirst)
                Container(
                  width: 2,
                  height: 8,
                  color: WandererTheme.timelineConnector,
                ),
              // Larger themed node for day markers
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: markerColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: markerColor,
                    width: 2,
                  ),
                ),
                child: Icon(
                  markerIcon,
                  size: 10,
                  color: Colors.white,
                ),
              ),
              if (!isLast)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Container(
                    width: 2,
                    height: 40,
                    color: WandererTheme.timelineConnector,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // Day marker card — not tappable (lifecycle markers have no real location)
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: markerColor.withOpacity(0.08),
              borderRadius:
                  BorderRadius.circular(WandererTheme.glassRadiusSmall),
              border: Border.all(
                color: markerColor.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  markerIcon,
                  size: 18,
                  color: markerColor,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: markerColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatTimestamp(context, update.timestamp),
                        style: TextStyle(
                          fontSize: 11,
                          color: markerColor.withOpacity(0.7),
                        ),
                      ),
                      if (update.message != null &&
                          update.message!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
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
                      ],
                    ],
                  ),
                ),
                if (update.city != null) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.location_on,
                    size: 12,
                    color: markerColor.withOpacity(0.5),
                  ),
                  const SizedBox(width: 2),
                  Flexible(
                    child: Text(
                      update.city!,
                      style: TextStyle(
                        fontSize: 11,
                        color: markerColor.withOpacity(0.7),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
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
