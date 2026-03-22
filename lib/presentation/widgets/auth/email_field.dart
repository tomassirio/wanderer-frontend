import 'package:flutter/material.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';

/// Email input field with validation
class EmailField extends StatelessWidget {
  final TextEditingController controller;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;

  const EmailField({
    super.key,
    required this.controller,
    this.textInputAction,
    this.onFieldSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: l10n.emailLabel,
        prefixIcon: const Icon(Icons.email),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      keyboardType: TextInputType.emailAddress,
      textCapitalization: TextCapitalization.none,
      textInputAction: textInputAction ?? TextInputAction.next,
      onFieldSubmitted: onFieldSubmitted,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return l10n.pleaseEnterEmail;
        }
        if (!value.contains('@') || !value.contains('.')) {
          return l10n.pleaseEnterValidEmail;
        }
        return null;
      },
    );
  }
}
