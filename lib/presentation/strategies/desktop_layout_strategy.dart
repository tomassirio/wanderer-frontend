import 'package:flutter/material.dart';
import 'package:wanderer_frontend/core/constants/enums.dart';
import 'package:wanderer_frontend/presentation/strategies/trip_detail_layout_strategy.dart';

/// Desktop layout strategy for trip detail screen
/// - Multiple panels can be open simultaneously
/// - Panels expand to fill available space
/// - Comments section uses Expanded when open
/// - Settings panel appears to the RIGHT of the info/comments column
class DesktopLayoutStrategy extends TripDetailLayoutStrategy {
  /// Width of the info bubble when collapsed (56px icon + 16px margin each side)
  static const double _collapsedWidth = 88.0;

  /// Extra width taken by the settings cog bubble (no left margin)
  static const double _settingsBubbleWidth = 72.0;

  /// Width of the expanded settings card (bounded so inner Rows render correctly)
  static const double _settingsCardWidth = 260.0;

  static const double _timelineWidth = 352.0;
  static const double _panelGap = 32.0;
  static const double _minExpandedWidth = 300.0;
  static const double _maxExpandedWidth = 500.0;

  /// Returns true when the settings panel has at least one section to show,
  /// matching the logic inside TripSettingsPanel._hasContent.
  bool _settingsHasContent(TripDetailLayoutData data) {
    return data.trip.hasPlannedRoute ||
        (data.currentUserId != null &&
            data.trip.userId == data.currentUserId &&
            data.trip.status == TripStatus.inProgress);
  }

  @override
  double calculateLeftPanelWidth(
      BoxConstraints constraints, TripDetailLayoutData data) {
    // How much extra space the settings panel needs beside the info column.
    final double settingsExtra = _settingsHasContent(data)
        ? (data.isTripSettingsCollapsed
            ? _settingsBubbleWidth
            : _settingsCardWidth)
        : 0.0;

    if (data.isTripInfoCollapsed && data.isCommentsCollapsed) {
      // Both panels collapsed: a row of small bubbles
      return _collapsedWidth + settingsExtra;
    }

    // Info or comments is expanded: give the info column its normal width
    // then add settings panel width beside it.
    final double infoWidth = (constraints.maxWidth - _timelineWidth - _panelGap)
        .clamp(_minExpandedWidth, _maxExpandedWidth);
    return infoWidth + settingsExtra;
  }

  @override
  double calculateInfoColumnWidth(
      BoxConstraints constraints, TripDetailLayoutData data) {
    if (data.isTripInfoCollapsed && data.isCommentsCollapsed) {
      return _collapsedWidth;
    }
    return (constraints.maxWidth - _timelineWidth - _panelGap)
        .clamp(_minExpandedWidth, _maxExpandedWidth);
  }

  @override
  bool shouldLeftPanelStretchToBottom(TripDetailLayoutData data) {
    return !(data.isTripInfoCollapsed && data.isCommentsCollapsed);
  }

  @override
  bool shouldTimelinePanelStretchToBottom(TripDetailLayoutData data) {
    return !data.isTimelineCollapsed;
  }

  @override
  Widget buildLeftPanel(BoxConstraints constraints, TripDetailLayoutData data) {
    final tripInfoCard = createTripInfoCard(data);
    final tripSettingsPanel = createTripSettingsPanel(data);
    final commentsSection = createCommentsSection(data);

    // Use a stable Row layout with flexible sizing
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Info + Comments column
        Flexible(
          child: AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                tripInfoCard,
                if (data.isCommentsCollapsed)
                  commentsSection
                else
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: constraints.maxHeight * 0.7,
                    ),
                    child: commentsSection,
                  ),
              ],
            ),
          ),
        ),
        // Settings panel on the right
        if (!data.isTripSettingsCollapsed || _settingsHasContent(data))
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topRight,
            child: data.isTripSettingsCollapsed || !_settingsHasContent(data)
                ? tripSettingsPanel
                : SizedBox(width: _settingsCardWidth, child: tripSettingsPanel),
          ),
      ],
    );
  }

  @override
  Widget buildTimelinePanel(
      BoxConstraints constraints, TripDetailLayoutData data) {
    final timelinePanel = createTimelinePanel(data);
    final tripUpdatePanel =
        data.showTripUpdatePanel ? createTripUpdatePanel(data) : null;

    if (tripUpdatePanel == null) {
      return timelinePanel;
    }

    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topRight, // Anchor to top-right to prevent jumping
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize:
            data.isTimelineCollapsed ? MainAxisSize.min : MainAxisSize.max,
        children: [
          if (data.isTimelineCollapsed)
            timelinePanel
          else
            Expanded(child: timelinePanel),
          tripUpdatePanel,
        ],
      ),
    );
  }
}
