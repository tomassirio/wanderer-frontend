import 'package:flutter/material.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';

/// Sign-up password rules as (label, met) pairs; mirrors the validator below.
List<(String, bool)> passwordRules(AppLocalizations l10n, String password) => [
      (l10n.passwordRequirement8Chars, password.length >= 8),
      (l10n.passwordRequirementUppercase, RegExp(r'[A-Z]').hasMatch(password)),
      (l10n.passwordRequirementLowercase, RegExp(r'[a-z]').hasMatch(password)),
      (l10n.passwordRequirementNumber, RegExp(r'\d').hasMatch(password)),
      (
        l10n.passwordRequirementSpecial,
        RegExp(r'[@$!%*?&#]').hasMatch(password)
      ),
    ];

/// Password input field with visibility toggle
class PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String? label;
  final bool isLogin;
  final TextEditingController? compareController;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;

  /// Web redesign: base decoration (label rendered above by the caller);
  /// the visibility toggle is added as the suffix icon.
  final InputDecoration? decoration;

  const PasswordField({
    super.key,
    required this.controller,
    this.label,
    this.isLogin = true,
    this.compareController,
    this.textInputAction,
    this.onFieldSubmitted,
    this.decoration,
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

    // Determine autofill hints based on context
    List<String> autofillHints;
    if (widget.compareController != null) {
      // This is the confirm password field
      autofillHints = const [AutofillHints.newPassword];
    } else if (widget.isLogin) {
      // This is the login password field
      autofillHints = const [AutofillHints.password];
    } else {
      // This is the registration password field
      autofillHints = const [AutofillHints.newPassword];
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: widget.controller,
          decoration: widget.decoration?.copyWith(
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 18,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ) ??
              InputDecoration(
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
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
          obscureText: _obscurePassword,
          textInputAction: widget.textInputAction ?? TextInputAction.done,
          onFieldSubmitted: widget.onFieldSubmitted,
          autofillHints: autofillHints,
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
