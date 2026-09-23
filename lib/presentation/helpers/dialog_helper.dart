import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/presentation/widgets/common/wanderer_dialog.dart';

/// Reusable confirmation dialog helper
class DialogHelper {
  /// Shows a logout confirmation dialog
  static Future<bool> showLogoutConfirmation(BuildContext context) async {
    if (kIsWeb) {
      final l10n = context.l10n;
      return WandererDialog.confirm(
        context,
        title: l10n.dialogLogoutTitle,
        message: l10n.dialogLogoutMessage,
        confirmLabel: l10n.dialogLogoutAction,
        icon: Icons.logout,
        destructive: true,
      );
    }
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
