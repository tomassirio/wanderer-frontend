import 'package:flutter/material.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';

/// Username/Email input field with validation
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
        labelText: isLogin ? l10n.usernameOrEmailLabel : l10n.usernameLabel,
        hintText: isLogin ? l10n.usernameOrEmailHint : null,
        prefixIcon: const Icon(Icons.person),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      keyboardType: isLogin ? TextInputType.emailAddress : TextInputType.text,
      textCapitalization: TextCapitalization.none,
      textInputAction: textInputAction ?? TextInputAction.next,
      onFieldSubmitted: onFieldSubmitted,
      autofillHints: isLogin
          ? const [AutofillHints.username, AutofillHints.email]
          : const [AutofillHints.username, AutofillHints.newUsername],
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return isLogin
              ? l10n.pleaseEnterUsernameOrEmail
              : l10n.pleaseEnterUsername;
        }
        if (!isLogin && value.trim().length < 3) {
          return l10n.usernameMinLength;
        }
        return null;
      },
    );
  }
}
