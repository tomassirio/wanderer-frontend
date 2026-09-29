import 'package:flutter/material.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/data/models/auth_models.dart';
import 'package:wanderer_frontend/presentation/widgets/auth/google_logo.dart';

/// Outlined "Continue with Google"-style button for SSO login.
class SsoButton extends StatelessWidget {
  final SsoProvider provider;
  final VoidCallback? onPressed;

  const SsoButton({
    super.key,
    required this.provider,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final label =
        provider == SsoProvider.google ? l10n.continueWithGoogle : provider.id;
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
      child: provider == SsoProvider.google
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const GoogleLogo(size: 18),
                const SizedBox(width: 10),
                Text(label),
              ],
            )
          : Text(label),
    );
  }
}

/// Horizontal "—— or ——" separator between password and SSO login.
class OrDivider extends StatelessWidget {
  const OrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).textTheme.bodySmall?.color;
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(context.l10n.orDivider,
              style: TextStyle(fontSize: 13, color: color)),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}
