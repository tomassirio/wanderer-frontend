import 'package:flutter/material.dart';
import 'package:wanderer_frontend/presentation/strategies/trip_detail_layout_strategy.dart';

/// Mobile layout strategy for trip detail screen
/// - Only one panel can be open at a time
/// - Collapsed panels show as floating bubbles
/// - Expanded panels are constrained to leave map visible
class MobileLayoutStrategy extends TripDetailLayoutStrategy {
  // Wide enough to fit the info bubble (88 px) + settings bubble (72 px) side by side.
  static const double _collapsedWidth = 160.0;
  static const double _expandedWidthRatio = 0.85;
  static const double _maxHeightRatio = 0.7;
  @override
  double calculateLeftPanelWidth(
      BoxConstraints constraints, TripDetailLayoutData data) {
    if (data.isTripInfoCollapsed &&
        data.isCommentsCollapsed &&
        data.isTripSettingsCollapsed) {
      return _collapsedWidth;
    }
    return constraints.maxWidth * _expandedWidthRatio;
  }

  @override
  bool shouldLeftPanelStretchToBottom(TripDetailLayoutData data) => false;
  @override
  bool shouldTimelinePanelStretchToBottom(TripDetailLayoutData data) => false;
  @override
  Widget buildLeftPanel(BoxConstraints constraints, TripDetailLayoutData data) {
    final tripInfoCard = createTripInfoCard(data);
    final tripSettingsPanel = createTripSettingsPanel(data);
    final commentsSection = createCommentsSection(data);

    final allCollapsed = data.isTripInfoCollapsed &&
        data.isCommentsCollapsed &&
        data.isTripSettingsCollapsed;

    if (allCollapsed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Info bubble and settings bubble sit side-by-side in a Row.
          // Settings is only visible when it has content (_hasContent check
          // inside TripSettingsPanel), so when absent it collapses to zero.
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              tripInfoCard,
              tripSettingsPanel,
            ],
          ),
          commentsSection,
        ],
      );
    }
    if (!data.isTripInfoCollapsed &&
        data.isCommentsCollapsed &&
        data.isTripSettingsCollapsed) {
      // Trip info expanded: give the info card full width.
      // The settings cog is accessible from the all-collapsed state.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: constraints.maxHeight * _maxHeightRatio,
            ),
            child: SingleChildScrollView(child: tripInfoCard),
          ),
          commentsSection,
        ],
      );
    }
    if (data.isTripInfoCollapsed &&
        !data.isTripSettingsCollapsed &&
        data.isCommentsCollapsed) {
      // Settings expanded: show only the settings panel — info and comments
      // bubbles are hidden so the card stands alone (not sandwiched).
      return ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: constraints.maxHeight * _maxHeightRatio,
        ),
        child: SingleChildScrollView(child: tripSettingsPanel),
      );
    }
    // Comments expanded: keep info + settings bubbles side-by-side (same as
    // the all-collapsed case) so the ⚙ cog doesn't jump below the ⓘ bubble.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            tripInfoCard,
            tripSettingsPanel,
          ],
        ),
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: constraints.maxHeight * _maxHeightRatio,
          ),
          child: commentsSection,
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

    if (!data.isTimelineCollapsed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: constraints.maxHeight * 0.6,
                maxWidth: constraints.maxWidth * _expandedWidthRatio,
              ),
              child: timelinePanel,
            ),
          ),
          if (tripUpdatePanel != null) tripUpdatePanel,
        ],
      );
    }

    // Both collapsed - show as column of bubbles
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        timelinePanel,
        if (tripUpdatePanel != null) tripUpdatePanel,
      ],
    );
  }
}
