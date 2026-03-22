import 'package:flutter/material.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';

/// Badge widget that displays relationship with the trip owner
class RelationshipBadge extends StatelessWidget {
  final RelationshipType type;
  final bool compact;

  const RelationshipBadge({
    super.key,
    required this.type,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
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

  IconData _getIcon() {
    switch (type) {
      case RelationshipType.friend:
        return Icons.people;
      case RelationshipType.following:
        return Icons.person_add_alt_1;
    }
  }

  String _getLabel(AppLocalizations l10n) {
    switch (type) {
      case RelationshipType.friend:
        return l10n.friend;
      case RelationshipType.following:
        return l10n.following;
    }
  }

  Color _getBorderColor() {
    switch (type) {
      case RelationshipType.friend:
        return Colors.blue.withOpacity(0.3);
      case RelationshipType.following:
        return Colors.purple.withOpacity(0.3);
    }
  }

  Color _getIconColor() {
    switch (type) {
      case RelationshipType.friend:
        return Colors.blue.shade700;
      case RelationshipType.following:
        return Colors.purple.shade700;
    }
  }
}

enum RelationshipType {
  friend,
  following,
}
