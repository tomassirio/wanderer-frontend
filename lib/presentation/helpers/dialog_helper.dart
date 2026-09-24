import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/presentation/widgets/common/wanderer_dialog.dart';

/// One row of [DialogHelper.showWebOptions].
class DialogOption<T> {
  final IconData icon;
  final String label;
  final String? subtitle;
  final T value;
  final Color? color;

  const DialogOption({
    required this.icon,
    required this.label,
    required this.value,
    this.subtitle,
    this.color,
  });
}

/// Reusable confirmation dialog helper
class DialogHelper {
  /// Web picker popup (440 wide, bottom sheet on phones): title, close
  /// button and one row per option. Returns the tapped option's value.
  static Future<T?> showWebOptions<T>(
    BuildContext context, {
    required String title,
    required List<DialogOption<T>> options,
    T? selected,
  }) {
    return WandererDialog.show<T>(
      context,
      builder: (context) {
        final c = WandererTheme.of(context);
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(title,
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: c.text)),
                  ),
                  const DialogCloseButton(),
                ],
              ),
              const SizedBox(height: 12),
              for (final o in options)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Material(
                    color: o.value == selected ? c.trailSoftBg : c.raised,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(WandererTheme.radiusControl),
                      side: BorderSide(color: c.lineSoft),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      leading:
                          Icon(o.icon, size: 20, color: o.color ?? c.textMuted),
                      title: Text(o.label,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: o.color ?? c.text)),
                      subtitle: o.subtitle == null
                          ? null
                          : Text(o.subtitle!,
                              style:
                                  TextStyle(fontSize: 12, color: c.textMuted)),
                      trailing: o.value == selected
                          ? Icon(Icons.check, size: 18, color: c.accentText)
                          : null,
                      onTap: () => Navigator.of(context).pop(o.value),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

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
