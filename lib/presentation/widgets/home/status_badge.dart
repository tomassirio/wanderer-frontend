import 'package:flutter/material.dart';
import 'package:wanderer_frontend/core/constants/enums.dart' show TripStatus;
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/presentation/helpers/ui_helpers.dart';

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
    final l10n = context.l10n;
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
              _getLabel(l10n),
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

  IconData _getIcon() => UiHelpers.getStatusIcon(widget.status);

  String _getLabel(AppLocalizations l10n) {
    switch (widget.status) {
      case TripStatus.created:
        return l10n.draft;
      case TripStatus.inProgress:
        return l10n.live;
      case TripStatus.paused:
        return l10n.paused;
      case TripStatus.finished:
        return l10n.completed;
      case TripStatus.resting:
        return l10n.resting;
    }
  }

  Color _getBorderColor() =>
      UiHelpers.getStatusColor(widget.status).withOpacity(0.3);

  Color _getIconColor() => UiHelpers.getStatusColor(widget.status);
}
