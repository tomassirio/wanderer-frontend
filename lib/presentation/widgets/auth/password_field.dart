import 'package:flutter/material.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';

/// Password input field with visibility toggle
class PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String? label;
  final bool isLogin;
  final TextEditingController? compareController;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;

  const PasswordField({
    super.key,
    required this.controller,
    this.label,
    this.isLogin = true,
    this.compareController,
    this.textInputAction,
    this.onFieldSubmitted,
  });

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final labelText = widget.label ?? l10n.passwordLabel;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: widget.controller,
          decoration: InputDecoration(
            labelText: labelText,
            prefixIcon: Icon(
              widget.compareController == null
                  ? Icons.lock
                  : Icons.lock_outline,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off : Icons.visibility,
              ),
              onPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          obscureText: _obscurePassword,
          textInputAction: widget.textInputAction ?? TextInputAction.done,
          onFieldSubmitted: widget.onFieldSubmitted,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return l10n.pleaseEnterPassword;
            }
            if (!widget.isLogin) {
              // For registration/password change, enforce complexity
              if (value.length < 8) {
                return l10n.passwordMinLength8;
              }
              if (!RegExp(r'(?=.*[a-z])').hasMatch(value)) {
                return l10n.passwordRequiresLowercase;
              }
              if (!RegExp(r'(?=.*[A-Z])').hasMatch(value)) {
                return l10n.passwordRequiresUppercase;
              }
              if (!RegExp(r'(?=.*\d)').hasMatch(value)) {
                return l10n.passwordRequiresNumber;
              }
              if (!RegExp(r'(?=.*[@$!%*?&#])').hasMatch(value)) {
                return l10n.passwordRequiresSpecial;
              }
            }
            if (widget.compareController != null &&
                value != widget.compareController!.text) {
              return l10n.passwordsDoNotMatch;
            }
            return null;
          },
        ),
      ],
    );
  }
}
