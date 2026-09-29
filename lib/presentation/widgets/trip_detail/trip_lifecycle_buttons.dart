import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:wanderer_frontend/core/constants/enums.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';

/// Circular overlay buttons for trip lifecycle management (Start / Pause /
/// Resume / Finish / Finish Day / Begin Day). Displayed on the right side of
/// the map, above the native Google Maps zoom controls. Only shown on mobile
/// and only for trip owners when the trip has not yet finished.
class TripLifecycleButtons extends StatelessWidget {
  final TripStatus currentStatus;
  final TripModality? tripModality;
  final bool isOwner;
  final bool isLoading;
  final Function(TripStatus) onStatusChange;

  /// Whether to show the "Finish Day / Begin Day" button (multi-day trips only)
  final bool showDayButton;

  /// Current day number for the day button label
  final int currentDay;

  /// Whether the trip is in resting state (affects day button label)
  final bool isResting;

  /// Callback when the day button (Finish Day / Begin Day) is tapped
  final VoidCallback? onDayButtonTap;

  /// Override for tests — defaults to [kIsWeb]
  final bool? isWeb;

  /// Whether the Start button should be greyed out because the user
  /// already has another trip IN_PROGRESS (backend allows only one at a time).
  final bool blockStart;

  /// Called instead of [onStatusChange] when Start is tapped while
  /// [blockStart] is true. Should surface a notification to the user.
  final VoidCallback? onStartBlocked;

  const TripLifecycleButtons({
    super.key,
    required this.currentStatus,
    required this.isOwner,
    required this.isLoading,
    required this.onStatusChange,
    this.tripModality,
    this.showDayButton = false,
    this.currentDay = 1,
    this.isResting = false,
    this.onDayButtonTap,
    this.isWeb,
    this.blockStart = false,
    this.onStartBlocked,
  });

  bool get _isMultiDay => tripModality == TripModality.multiDay;

  @override
  Widget build(BuildContext context) {
    final effectiveIsWeb = isWeb ?? kIsWeb;

    // Only show on mobile, for owners, when trip is not finished
    if (effectiveIsWeb) return const SizedBox.shrink();
    if (!isOwner) return const SizedBox.shrink();
    if (currentStatus == TripStatus.finished) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: _buildButtons(context),
    );
  }

  List<Widget> _buildButtons(BuildContext context) {
    final buttons = <Widget>[];

    // Start Trip (CREATED status)
    if (currentStatus == TripStatus.created) {
      buttons.add(
        _buildCircleButton(
          context: context,
          icon: Icons.play_arrow,
          color: WandererTheme.statusCreated,
          tooltip: 'Start Trip',
          onPressed: blockStart
              ? (onStartBlocked ?? () {})
              : () => onStatusChange(TripStatus.inProgress),
          greyedOut: blockStart,
        ),
      );
    }

    // Resume (PAUSED status, or RESTING for non-multi-day)
    if (currentStatus == TripStatus.paused ||
        (currentStatus == TripStatus.resting && !_isMultiDay)) {
      buttons.add(
        _buildCircleButton(
          context: context,
          icon: Icons.play_arrow,
          color: WandererTheme.statusCreated,
          tooltip: 'Resume',
          onPressed: () => onStatusChange(TripStatus.inProgress),
        ),
      );
    }

    // Pause (IN_PROGRESS, all trip types)
    if (currentStatus == TripStatus.inProgress) {
      if (buttons.isNotEmpty) buttons.add(const SizedBox(height: 8));
      buttons.add(
        _buildCircleButton(
          context: context,
          icon: Icons.pause,
          color: WandererTheme.statusInProgress,
          tooltip: 'Pause',
          onPressed: () => onStatusChange(TripStatus.paused),
        ),
      );
    }

    // Finish Day / Begin Day (multi-day trips only)
    if (showDayButton && onDayButtonTap != null) {
      if (buttons.isNotEmpty) buttons.add(const SizedBox(height: 8));
      final dayIcon =
          isResting ? Icons.wb_sunny_outlined : Icons.nightlight_round;
      final dayColor =
          isResting ? WandererTheme.dayStartColor : WandererTheme.dayEndColor;
      final dayTooltip =
          isResting ? 'Begin Day ${currentDay + 1}' : 'Finish Day $currentDay';

      buttons.add(
        _buildCircleButton(
          context: context,
          icon: dayIcon,
          color: dayColor,
          tooltip: dayTooltip,
          onPressed: onDayButtonTap!,
        ),
      );
    }

    // Finish (IN_PROGRESS, PAUSED, or RESTING)
    if (currentStatus == TripStatus.inProgress ||
        currentStatus == TripStatus.paused ||
        currentStatus == TripStatus.resting) {
      if (buttons.isNotEmpty) buttons.add(const SizedBox(height: 8));
      buttons.add(
        _buildCircleButton(
          context: context,
          icon: Icons.check,
          color: WandererTheme.statusCompleted,
          tooltip: 'Finish',
          onPressed: () => _showFinishConfirmation(context),
        ),
      );
    }

    return buttons;
  }

  Widget _buildCircleButton({
    required BuildContext context,
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onPressed,
    bool greyedOut = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: FloatingActionButton(
        heroTag: 'lifecycle_$tooltip',
        onPressed: isLoading ? null : onPressed,
        backgroundColor:
            (isLoading || greyedOut) ? color.withOpacity(0.5) : color,
        foregroundColor: Colors.white,
        elevation: 4,
        mini: false,
        child: Icon(icon, size: 26),
      ),
    );
  }

  Future<void> _showFinishConfirmation(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Finish Trip'),
        content: const Text(
          'Are you sure you want to finish this trip? This will mark the trip as completed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            key: const Key('confirm_finish_button'),
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: WandererTheme.statusCompleted,
              foregroundColor: Colors.white,
            ),
            child: const Text('Finish'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      onStatusChange(TripStatus.finished);
    }
  }
}
