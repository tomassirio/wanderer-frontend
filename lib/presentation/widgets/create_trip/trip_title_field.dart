import 'package:flutter/material.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';

/// Text field for trip title input
class TripTitleField extends StatelessWidget {
  final TextEditingController controller;

  const TripTitleField({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: l10n.tripTitleLabel,
        hintText: l10n.tripTitleHint,
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.title),
      ),
      textCapitalization: TextCapitalization.words,
      textInputAction: TextInputAction.next,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return l10n.pleaseEnterTitle;
        }
        return null;
      },
    );
  }
}
