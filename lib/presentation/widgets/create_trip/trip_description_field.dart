import 'package:flutter/material.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';

/// Text field for trip description input
class TripDescriptionField extends StatelessWidget {
  final TextEditingController controller;

  const TripDescriptionField({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: l10n.tripDescriptionLabel,
        hintText: l10n.tripDescriptionHint,
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.description),
      ),
      maxLines: 3,
      textCapitalization: TextCapitalization.sentences,
    );
  }
}
