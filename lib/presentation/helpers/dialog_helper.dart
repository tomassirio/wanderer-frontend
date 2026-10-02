import 'package:wanderer_frontend/presentation/helpers/adaptive_layout.dart';
import 'package:flutter/material.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/presentation/widgets/common/wanderer_dialog.dart';
import 'package:wanderer_frontend/presentation/widgets/common/wanderer_sheet.dart';

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
    if (AdaptiveLayout.usesDesktopLayout(context)) {
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
    // Android: bottom sheet instead of a centered popup (canvas rule).
    final l10n = context.l10n;
    final result = await showWandererSheet<bool>(
      context,
      title: l10n.dialogLogoutTitle,
      builder: (context) {
        final c = WandererTheme.of(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.dialogLogoutMessage,
                style: TextStyle(fontSize: 15, color: c.textMuted)),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
                minimumSize: const Size.fromHeight(56),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(l10n.dialogLogoutAction),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              style: TextButton.styleFrom(
                  foregroundColor: c.text,
                  minimumSize: const Size.fromHeight(48)),
              child: Text(l10n.cancel),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }
}
