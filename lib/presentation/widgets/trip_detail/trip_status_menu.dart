import 'package:flutter/material.dart';
import 'package:wanderer_frontend/core/constants/enums.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/presentation/helpers/ui_helpers.dart';

/// AppBar actions for changing trip status.
/// Respects the backend transition matrix:
///   CREATED → IN_PROGRESS, FINISHED
///   IN_PROGRESS → PAUSED, FINISHED (RESTING via toggle-day for MULTI_DAY)
///   PAUSED → IN_PROGRESS, FINISHED
///   RESTING → IN_PROGRESS (via toggle-day), FINISHED
///   FINISHED → (terminal)
class TripStatusMenu extends StatelessWidget {
  final Function(TripStatus) onStatusChanged;
  final TripStatus currentStatus;
  final TripModality? tripModality;

  const TripStatusMenu({
    super.key,
    required this.onStatusChanged,
    required this.currentStatus,
    this.tripModality,
  });

  bool get _isMultiDay => tripModality == TripModality.multiDay;

  /// Returns the allowed status transitions based on current status and modality
  List<TripStatus> get _allowedTransitions {
    switch (currentStatus) {
      case TripStatus.created:
        return [TripStatus.inProgress, TripStatus.finished];
      case TripStatus.inProgress:
        // RESTING is only reachable via toggle-day endpoint, not shown here
        return [TripStatus.paused, TripStatus.finished];
      case TripStatus.paused:
        return [TripStatus.inProgress, TripStatus.finished];
      case TripStatus.resting:
        // IN_PROGRESS from RESTING is via toggle-day for multi-day
        if (_isMultiDay) {
          return [TripStatus.finished];
        }
        return [TripStatus.inProgress, TripStatus.finished];
      case TripStatus.finished:
        return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final transitions = _allowedTransitions;
    if (transitions.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;

    return PopupMenuButton<TripStatus>(
      icon: const Icon(Icons.more_vert),
      onSelected: onStatusChanged,
      itemBuilder: (context) => transitions.map((status) {
        return PopupMenuItem(
          value: status,
          child: Row(
            children: [
              Icon(
                UiHelpers.getStatusIcon(status),
                color: _getStatusColor(status),
              ),
              const SizedBox(width: 8),
              Text(_getStatusLabel(status, l10n)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Color _getStatusColor(TripStatus status) {
    switch (status) {
      case TripStatus.inProgress:
        return Colors.green;
      case TripStatus.paused:
        return Colors.orange;
      case TripStatus.resting:
        return WandererTheme.statusResting;
      case TripStatus.finished:
        return Colors.grey;
      case TripStatus.created:
        return Colors.blue;
    }
  }

  String _getStatusLabel(TripStatus status, AppLocalizations l10n) {
    switch (status) {
      case TripStatus.inProgress:
        return currentStatus == TripStatus.created
            ? l10n.startTrip
            : l10n.resumeTrip;
      case TripStatus.paused:
        return l10n.pauseTrip;
      case TripStatus.resting:
        return l10n.restForNight;
      case TripStatus.finished:
        return l10n.finishTrip;
      case TripStatus.created:
        return l10n.draft;
    }
  }
}
