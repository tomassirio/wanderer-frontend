import 'package:flutter/material.dart' hide Visibility;
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/constants/enums.dart';

/// Visibility selector widget with segmented buttons
class VisibilitySelector extends StatelessWidget {
  final Visibility selectedVisibility;
  final ValueChanged<Visibility> onVisibilityChanged;

  const VisibilitySelector({
    super.key,
    required this.selectedVisibility,
    required this.onVisibilityChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.visibility,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        SegmentedButton<Visibility>(
          segments: [
            ButtonSegment(
              value: Visibility.private,
              label: Text(l10n.privateVisibility),
              icon: const Icon(Icons.lock),
            ),
            ButtonSegment(
              value: Visibility.protected,
              label: Text(l10n.protectedVisibility),
              icon: const Icon(Icons.group),
            ),
            ButtonSegment(
              value: Visibility.public,
              label: Text(l10n.publicVisibility),
              icon: const Icon(Icons.public),
            ),
          ],
          selected: {selectedVisibility},
          onSelectionChanged: (Set<Visibility> newSelection) {
            onVisibilityChanged(newSelection.first);
          },
        ),
        const SizedBox(height: 8),
        Text(
          _getVisibilityDescription(selectedVisibility, l10n),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  String _getVisibilityDescription(Visibility visibility, AppLocalizations l10n) {
    switch (visibility) {
      case Visibility.private:
        return l10n.privateVisibilityHint;
      case Visibility.protected:
        return l10n.protectedVisibilityHint;
      case Visibility.public:
        return l10n.publicVisibilityHint;
    }
  }
}
