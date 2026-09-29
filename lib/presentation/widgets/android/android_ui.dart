import 'package:flutter/material.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';

/// Android top bar from the canvas: 64dp, back arrow, Bricolage 20 title on
/// the sand ground, no elevation. Use on every pushed Android screen.
class AndroidTopBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;

  /// Tab roots have no back arrow.
  final bool showBack;

  /// Creation flows (New trip, New plan) close with ✕ instead of a back arrow.
  final bool close;

  const AndroidTopBar(
      {super.key,
      required this.title,
      this.actions,
      this.showBack = true,
      this.close = false});

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    return AppBar(
      toolbarHeight: 64,
      backgroundColor: c.ground,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: showBack,
      leading: !showBack
          ? null
          : close
              ? const CloseButton()
              : const BackButton(),
      titleSpacing: showBack ? 4 : 20,
      title: Text(title, style: WandererTheme.display(20, color: c.text)),
      actions: actions,
    );
  }
}

/// Text field with its label above it (never placeholder-only labels):
/// 54dp tall, 14dp corners, trail focus ring.
class LabeledField extends StatelessWidget {
  final String label;
  final TextEditingController? controller;
  final String? hint;
  final String? helper;
  final bool obscureText;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final int maxLines;
  final Iterable<String>? autofillHints;

  const LabeledField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.helper,
    this.obscureText = false,
    this.suffix,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.maxLines = 1,
    this.autofillHints,
  });

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color, width: width),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700, color: c.text)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          validator: validator,
          onChanged: onChanged,
          onFieldSubmitted: onSubmitted,
          maxLines: obscureText ? 1 : maxLines,
          autofillHints: autofillHints,
          style: TextStyle(fontSize: 16, color: c.text),
          decoration: InputDecoration(
            hintText: hint,
            helperText: helper,
            helperMaxLines: 2,
            helperStyle: TextStyle(fontSize: 12, color: c.caption),
            filled: true,
            fillColor: c.surface,
            suffixIcon: suffix,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: border(c.line),
            enabledBorder: border(c.line),
            focusedBorder: border(WandererTheme.trail, 2),
          ),
        ),
      ],
    );
  }
}
