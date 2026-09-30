import 'package:flutter/material.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';

/// Android bottom sheet from the canvas: 28dp top corners, drag handle,
/// optional Bricolage title, and it rises above the keyboard. Use instead
/// of centered dialogs on Android (password, close account, start from
/// plan, check-in detail).
Future<T?> showWandererSheet<T>(
  BuildContext context, {
  String? title,
  required WidgetBuilder builder,
}) {
  final c = WandererTheme.of(context);
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: c.surface,
    barrierColor: const Color(0x731B1A17),
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                    color: c.line, borderRadius: BorderRadius.circular(999)),
              ),
            ),
            if (title != null) ...[
              Text(title, style: WandererTheme.display(22, color: c.text)),
              const SizedBox(height: 16),
            ],
            builder(context),
          ],
        ),
      ),
    ),
  );
}
