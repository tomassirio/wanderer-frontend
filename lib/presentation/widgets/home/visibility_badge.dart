import 'package:flutter/material.dart' hide Visibility;
import 'package:wanderer_frontend/core/constants/enums.dart' show Visibility;

/// Badge widget that displays trip visibility status
class VisibilityBadge extends StatelessWidget {
  final Visibility visibility;
  final bool compact;

  const VisibilityBadge({
    super.key,
    required this.visibility,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: compact
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
          Icon(
            _getIcon(),
            size: compact ? 14 : 16,
            color: _getIconColor(),
          ),
          if (!compact) ...[
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
    switch (visibility) {
      case Visibility.public:
        return Icons.public;
      case Visibility.protected:
        return Icons.lock_outline;
      case Visibility.private:
        return Icons.lock;
    }
  }

  String _getLabel() {
    switch (visibility) {
      case Visibility.public:
        return 'Public';
      case Visibility.protected:
        return 'Protected';
      case Visibility.private:
        return 'Private';
    }
  }

  Color _getBorderColor() {
    switch (visibility) {
      case Visibility.public:
        return Colors.green.withOpacity(0.3);
      case Visibility.protected:
        return Colors.orange.withOpacity(0.3);
      case Visibility.private:
        return Colors.red.withOpacity(0.3);
    }
  }

  Color _getIconColor() {
    switch (visibility) {
      case Visibility.public:
        return Colors.green.shade700;
      case Visibility.protected:
        return Colors.orange.shade700;
      case Visibility.private:
        return Colors.red.shade700;
    }
  }
}
