import 'package:flutter/material.dart';
import 'package:wanderer_frontend/core/constants/enums.dart' show TripStatus;
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';

/// Badge widget that displays trip status with live indicator
class StatusBadge extends StatefulWidget {
  final TripStatus status;
  final bool compact;

  const StatusBadge({
    super.key,
    required this.status,
    this.compact = false,
  });

  @override
  State<StatusBadge> createState() => _StatusBadgeState();
}

class _StatusBadgeState extends State<StatusBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    if (widget.status == TripStatus.inProgress) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(StatusBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.status == TripStatus.inProgress &&
        oldWidget.status != TripStatus.inProgress) {
      _pulseController.repeat(reverse: true);
    } else if (widget.status != TripStatus.inProgress &&
        oldWidget.status == TripStatus.inProgress) {
      _pulseController.stop();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: widget.compact
          ? const EdgeInsets.symmetric(horizontal: 8, vertical: 4)
          : const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _getBorderColor(), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: _getIconColor().withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.status == TripStatus.inProgress)
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Container(
                  width: widget.compact ? 8 : 10,
                  height: widget.compact ? 8 : 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _getIconColor(),
                    boxShadow: [
                      BoxShadow(
                        color:
                            _getIconColor().withOpacity(_pulseController.value),
                        blurRadius: 6,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                );
              },
            )
          else
            Icon(
              _getIcon(),
              size: widget.compact ? 14 : 16,
              color: _getIconColor(),
            ),
          if (!widget.compact) ...[
            const SizedBox(width: 6),
            Text(
              _getLabel(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: _getIconColor(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  IconData _getIcon() {
    switch (widget.status) {
      case TripStatus.created:
        return Icons.edit_outlined;
      case TripStatus.inProgress:
        return Icons.circle;
      case TripStatus.paused:
        return Icons.pause;
      case TripStatus.finished:
        return Icons.check_circle_outline;
      case TripStatus.resting:
        return Icons.nightlight_round;
    }
  }

  String _getLabel() {
    switch (widget.status) {
      case TripStatus.created:
        return 'Draft';
      case TripStatus.inProgress:
        return 'Live';
      case TripStatus.paused:
        return 'Paused';
      case TripStatus.finished:
        return 'Completed';
      case TripStatus.resting:
        return 'Resting';
    }
  }

  Color _getBorderColor() {
    switch (widget.status) {
      case TripStatus.created:
        return Colors.grey.withOpacity(0.3);
      case TripStatus.inProgress:
        return Colors.green.withOpacity(0.3);
      case TripStatus.paused:
        return Colors.orange.withOpacity(0.3);
      case TripStatus.finished:
        return Colors.blue.withOpacity(0.3);
      case TripStatus.resting:
        return WandererTheme.statusResting.withOpacity(0.3);
    }
  }

  Color _getIconColor() {
    switch (widget.status) {
      case TripStatus.created:
        return Colors.grey.shade700;
      case TripStatus.inProgress:
        return Colors.green.shade700;
      case TripStatus.paused:
        return Colors.orange.shade700;
      case TripStatus.finished:
        return Colors.blue.shade700;
      case TripStatus.resting:
        return WandererTheme.statusResting;
    }
  }
}
