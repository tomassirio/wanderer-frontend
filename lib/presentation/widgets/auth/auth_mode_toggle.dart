import 'package:flutter/material.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';

/// Toggle between login and registration modes
class AuthModeToggle extends StatelessWidget {
  final bool isLogin;
  final bool isLoading;
  final VoidCallback onToggle;

  const AuthModeToggle({
    super.key,
    required this.isLogin,
    required this.isLoading,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            isLogin ? l10n.dontHaveAccount : l10n.alreadyHaveAccount,
            style: TextStyle(color: Colors.grey[600]),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        TextButton(
          onPressed: isLoading ? null : onToggle,
          child: Text(
            isLogin ? l10n.signUp : l10n.signIn,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
