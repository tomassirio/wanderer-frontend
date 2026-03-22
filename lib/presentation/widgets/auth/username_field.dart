import 'package:flutter/material.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';

/// Username input field with validation
class UsernameField extends StatelessWidget {
  final TextEditingController controller;
  final bool isLogin;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;

  const UsernameField({
    super.key,
    required this.controller,
    required this.isLogin,
    this.textInputAction,
    this.onFieldSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: l10n.usernameLabel,
        prefixIcon: const Icon(Icons.person),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      textCapitalization: TextCapitalization.none,
      textInputAction: textInputAction ?? TextInputAction.next,
      onFieldSubmitted: onFieldSubmitted,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return l10n.pleaseEnterUsername;
        }
        if (!isLogin && value.trim().length < 3) {
          return l10n.usernameMinLength;
        }
        return null;
      },
    );
  }
}
