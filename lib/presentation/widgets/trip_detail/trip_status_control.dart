import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/constants/enums.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';

/// Widget for controlling trip status (start/pause/resume/finish)
/// Only shown on mobile (not web) and only for trip owners
/// Respects the backend status transition matrix:
///   CREATED → IN_PROGRESS, FINISHED
///   IN_PROGRESS → PAUSED, RESTING (multi-day only via toggle-day), FINISHED
///   PAUSED → IN_PROGRESS, FINISHED
///   RESTING → IN_PROGRESS (via toggle-day), FINISHED
///   FINISHED → (terminal)
class TripStatusControl extends StatelessWidget {
  final TripStatus currentStatus;
  final bool isOwner;
  final bool isLoading;
  final Function(TripStatus) onStatusChange;

  /// Trip modality — affects which buttons are shown.
  /// For MULTI_DAY trips, RESTING→IN_PROGRESS is handled by the day toggle button,
  /// not by the status control. Also, Pause is not available for MULTI_DAY IN_PROGRESS.
  final TripModality? tripModality;

  /// Whether running on web platform. Defaults to [kIsWeb].
  /// Can be overridden for testing purposes.
  final bool? isWeb;

  const TripStatusControl({
    super.key,
    required this.currentStatus,
    required this.isOwner,
    required this.isLoading,
    required this.onStatusChange,
    this.tripModality,
    this.isWeb,
  });

  bool get _isMultiDay => tripModality == TripModality.multiDay;

  @override
  Widget build(BuildContext context) {
    final effectiveIsWeb = isWeb ?? kIsWeb;

    // Only show on mobile (not web)
    if (effectiveIsWeb) {
      return const SizedBox.shrink();
    }

    // Only show for trip owners
    if (!isOwner) {
      return const SizedBox.shrink();
    }

    // Don't show controls if trip is finished
    if (currentStatus == TripStatus.finished) {
      return const SizedBox.shrink();
    }

    final l10n = context.l10n;

    return Row(
      children: [
        // Start / Resume button
        if (currentStatus == TripStatus.created)
          _buildButton(
            context: context,
            label: l10n.startTrip,
            icon: Icons.play_arrow,
            color: WandererTheme.statusCreated,
            onPressed: () => onStatusChange(TripStatus.inProgress),
          ),
        if (currentStatus == TripStatus.paused)
          _buildButton(
            context: context,
            label: l10n.resume,
            icon: Icons.play_arrow,
            color: WandererTheme.statusCreated,
            onPressed: () => onStatusChange(TripStatus.inProgress),
          ),
        // For RESTING multi-day trips, Resume is handled by the day toggle button,
        // so only show Resume here for non-multi-day resting (shouldn't normally happen)
        if (currentStatus == TripStatus.resting && !_isMultiDay)
          _buildButton(
            context: context,
            label: l10n.resume,
            icon: Icons.play_arrow,
            color: WandererTheme.statusCreated,
            onPressed: () => onStatusChange(TripStatus.inProgress),
          ),
        // Pause button — available for all trips when IN_PROGRESS
        if (currentStatus == TripStatus.inProgress) ...[
          _buildButton(
            context: context,
            label: l10n.pause,
            icon: Icons.pause,
            color: WandererTheme.statusInProgress,
            onPressed: () => onStatusChange(TripStatus.paused),
          ),
          const SizedBox(width: 8),
        ],
        // Finish button — always available from IN_PROGRESS, PAUSED, RESTING
        if (currentStatus == TripStatus.inProgress ||
            currentStatus == TripStatus.paused ||
            currentStatus == TripStatus.resting)
          _buildButton(
            context: context,
            label: l10n.finish,
            icon: Icons.check,
            color: WandererTheme.statusCompleted,
            onPressed: () => _showFinishConfirmation(context),
          ),
      ],
    );
  }

  Widget _buildButton({
    required BuildContext context,
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: isLoading ? null : onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: const Size(0, 32),
        textStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Future<void> _showFinishConfirmation(BuildContext context) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.finishTrip),
        content: Text(l10n.finishTripConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            key: const Key('confirm_finish_button'),
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: WandererTheme.statusCompleted,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.finish),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      onStatusChange(TripStatus.finished);
    }
  }
}
