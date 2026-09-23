import 'package:flutter/material.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';

/// Web popup pattern (canvas "Popups & dialogs"): card with 22px corners on a
/// 45% ink scrim, close button top-right, actions bottom-right. Widths: 440
/// for info and confirms, 560 for forms. On narrow screens the same content
/// slides up as a bottom sheet.
///
/// Web only: mobile callers keep their existing dialogs for now.
class WandererDialog {
  WandererDialog._();

  static const double infoWidth = 440;
  static const double formWidth = 560;
  static const double radius = 22;
  static const Color scrim = Color(0x731B1A17); // ink at 45%

  /// Shows [builder] as a centred card (≥ 600px wide) or a bottom sheet.
  static Future<T?> show<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    double width = infoWidth,
    bool barrierDismissible = true,
  }) {
    final c = WandererTheme.of(context);
    if (MediaQuery.sizeOf(context).width < 600) {
      return showModalBottomSheet<T>(
        context: context,
        isScrollControlled: true,
        isDismissible: barrierDismissible,
        backgroundColor: c.surface,
        barrierColor: scrim,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radius)),
        ),
        builder: (context) => SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(context).bottom),
            child: builder(context),
          ),
        ),
      );
    }
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierColor: scrim,
      builder: (context) => Dialog(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: c.line),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: width),
          child: builder(context),
        ),
      ),
    );
  }

  /// "Confirm a risky action": tinted icon, title, message, secondary +
  /// main action on the right. [destructive] makes the main action red and
  /// should say exactly what happens ("Delete plan", never "OK").
  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    String? cancelLabel,
    IconData icon = Icons.help_outline,
    bool destructive = false,
  }) async {
    final result = await show<bool>(
      context,
      builder: (context) {
        final c = WandererTheme.of(context);
        final danger = Theme.of(context).colorScheme.error;
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: destructive
                          ? danger.withOpacity(0.12)
                          : c.trailSoftBg,
                      borderRadius:
                          BorderRadius.circular(WandererTheme.radiusControl),
                    ),
                    child: Icon(icon,
                        size: 20, color: destructive ? danger : c.trailSoftFg),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: c.text)),
                        const SizedBox(height: 6),
                        Text(message,
                            style: TextStyle(
                                fontSize: 14, height: 1.5, color: c.textMuted)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DialogActions(children: [
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(cancelLabel ?? context.l10n.cancel),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: destructive
                      ? ElevatedButton.styleFrom(
                          backgroundColor: danger,
                          foregroundColor: Colors.white)
                      : null,
                  child: Text(confirmLabel),
                ),
              ]),
            ],
          ),
        );
      },
    );
    return result ?? false;
  }
}

/// Actions row: right-aligned, secondary before the main action.
class DialogActions extends StatelessWidget {
  final List<Widget> children;
  const DialogActions({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.end,
      spacing: 10,
      runSpacing: 10,
      children: children,
    );
  }
}

/// 40px close button used top-right in every popup.
class DialogCloseButton extends StatelessWidget {
  /// Background; pass `c.surface` when placed on a tinted hero.
  final Color? background;
  const DialogCloseButton({super.key, this.background});

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    return IconButton(
      tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
      onPressed: () => Navigator.of(context).maybePop(),
      style: IconButton.styleFrom(
        fixedSize: const Size(40, 40),
        minimumSize: const Size(40, 40),
        backgroundColor: background ?? c.raised,
        foregroundColor: c.neutralFg,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(WandererTheme.radiusControl)),
      ),
      icon: const Icon(Icons.close, size: 16),
    );
  }
}

/// "Short form" popup: title bar with close button, body, raised footer
/// with actions. Show it with `WandererDialog.show(width: formWidth)`.
class WandererFormDialog extends StatelessWidget {
  final String title;
  final Widget body;
  final List<Widget> actions;

  const WandererFormDialog({
    super.key,
    required this.title,
    required this.body,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(24, 18, 20, 18),
          decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: c.lineSoft))),
          child: Row(
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
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
            child: body,
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 14),
          decoration: BoxDecoration(
            color: c.raised,
            border: Border(top: BorderSide(color: c.lineSoft)),
          ),
          child: DialogActions(children: actions),
        ),
      ],
    );
  }
}
