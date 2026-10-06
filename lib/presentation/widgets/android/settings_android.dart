import 'package:flutter/material.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/l10n/locale_controller.dart';
import 'package:wanderer_frontend/core/theme/theme_controller.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/presentation/widgets/android/android_ui.dart';
import 'package:wanderer_frontend/presentation/widgets/auth/password_field.dart';
import 'package:wanderer_frontend/presentation/widgets/common/wanderer_sheet.dart';

/// Android settings building blocks and sheets (canvas "AndroidSettings").

/// Caps label above a white card of rows separated by soft dividers.
class SettingsGroup extends StatelessWidget {
  final String? label;
  final List<Widget> children;

  const SettingsGroup({super.key, this.label, required this.children});

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text(label!.toUpperCase(),
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    color: c.label)),
          ),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: c.surface,
            border: Border.all(color: c.line),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: Column(children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) Divider(height: 1, thickness: 1, color: c.lineSoft),
                children[i],
              ],
            ]),
          ),
        ),
      ],
    );
  }
}

/// One settings row: bold title, optional caption, trailing control or a
/// chevron when tappable.
class SettingsRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool chevron;
  final Color? color;

  /// Shown right after the title (e.g. an unread dot).
  final Widget? titleTrailing;

  const SettingsRow({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.chevron = true,
    this.color,
    this.titleTrailing,
  });

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 60),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(
                    child: Text(title,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: color ?? c.text)),
                  ),
                  if (titleTrailing != null) ...[
                    const SizedBox(width: 8),
                    titleTrailing!,
                  ],
                ]),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!,
                      style: TextStyle(fontSize: 13, color: c.textMuted)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 14),
          if (trailing != null)
            trailing!
          else if (onTap != null && chevron)
            Icon(Icons.chevron_right, color: c.caption),
        ]),
      ),
    );
    return onTap == null ? row : InkWell(onTap: onTap, child: row);
  }
}

/// Light / Dark / Auto segmented selector backed by [ThemeController].
class SettingsThemeSelector extends StatelessWidget {
  const SettingsThemeSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    final controller = ThemeController();
    final options = [
      (ThemeMode.light, l10n.settingsThemeLight),
      (ThemeMode.dark, l10n.settingsThemeDark),
      (ThemeMode.system, l10n.settingsThemeAuto),
    ];
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: controller.themeMode,
      builder: (context, mode, _) => Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
            color: c.ground, borderRadius: BorderRadius.circular(10)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          for (final (value, label) in options)
            Semantics(
              button: true,
              selected: mode == value,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => controller.setThemeMode(value),
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: mode == value ? c.surface : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            mode == value ? FontWeight.w700 : FontWeight.w600,
                        color: mode == value ? c.text : c.textMuted,
                      )),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

/// Language picker sheet; resolves when a language was picked.
Future<void> showSettingsLanguageSheet(BuildContext context) {
  final l10n = context.l10n;
  final controller = LocaleController();
  return showWandererSheet<void>(
    context,
    title: l10n.language,
    builder: (ctx) {
      final c = WandererTheme.of(ctx);
      return Column(mainAxisSize: MainAxisSize.min, children: [
        for (final locale in LocaleController.supportedLocales)
          ListTile(
            contentPadding: EdgeInsets.zero,
            minTileHeight: 52,
            title: Text(l10n.languageNameFor(locale.languageCode),
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: locale.languageCode == controller.languageCode
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: c.text)),
            trailing: locale.languageCode == controller.languageCode
                ? const Icon(Icons.check, color: WandererTheme.trail)
                : null,
            onTap: () async {
              await controller.setLocale(Locale(locale.languageCode));
              if (ctx.mounted) Navigator.pop(ctx);
            },
          ),
      ]);
    },
  );
}

Widget _primaryButton(String label, VoidCallback? onPressed, {Color? color}) =>
    SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? WandererTheme.trail,
          foregroundColor: Colors.white,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        child: Text(label),
      ),
    );

Widget _cancelButton(BuildContext context, String label) {
  final c = WandererTheme.of(context);
  return SizedBox(
    height: 48,
    child: TextButton(
      onPressed: () => Navigator.pop(context),
      style: TextButton.styleFrom(
        foregroundColor: c.text,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
      child: Text(label),
    ),
  );
}

/// Change password sheet. Returns (current, new) when saved.
Future<(String, String)?> showSettingsChangePasswordSheet(
        BuildContext context) =>
    showWandererSheet<(String, String)>(
      context,
      title: context.l10n.settingsChangePasswordButton,
      builder: (_) => const _ChangePasswordForm(),
    );

class _ChangePasswordForm extends StatefulWidget {
  const _ChangePasswordForm();

  @override
  State<_ChangePasswordForm> createState() => _ChangePasswordFormState();
}

class _ChangePasswordFormState extends State<_ChangePasswordForm> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  final _visible = [false, false, false];

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Widget _field(int i, String label, TextEditingController controller,
      {String? hint, String? helper}) {
    final l10n = context.l10n;
    return LabeledField(
      label: label,
      controller: controller,
      hint: hint,
      helper: helper,
      obscureText: !_visible[i],
      onChanged: (_) => setState(() {}),
      suffix: IconButton(
        tooltip: _visible[i]
            ? l10n.settingsAndroidHidePassword
            : l10n.settingsAndroidShowPassword,
        icon: Icon(_visible[i]
            ? Icons.visibility_off_outlined
            : Icons.visibility_outlined),
        onPressed: () => setState(() => _visible[i] = !_visible[i]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    final met = passwordRules(l10n, _next.text).where((r) => r.$2).length;
    final (strength, strengthColor) = switch (met) {
      0 => ('', c.caption),
      1 || 2 => (l10n.authWebStrengthWeak, c.accentText),
      3 => (l10n.authWebStrengthFair, c.goldFg),
      4 => (l10n.authWebStrengthAlmost, c.forestFg),
      _ => (l10n.authWebStrengthStrong, c.forestFg),
    };
    final mismatch =
        _confirm.text.isNotEmpty && _confirm.text.trim() != _next.text.trim();
    final canSave = _current.text.trim().isNotEmpty &&
        _next.text.trim().length >= 8 &&
        _confirm.text.trim() == _next.text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _field(0, l10n.settingsAndroidCurrentPassword, _current),
        const SizedBox(height: 16),
        _field(1, l10n.settingsAndroidNewPassword, _next),
        const SizedBox(height: 6),
        Text.rich(
          TextSpan(children: [
            if (strength.isNotEmpty)
              TextSpan(
                  text: '$strength · ',
                  style: TextStyle(
                      color: strengthColor, fontWeight: FontWeight.w700)),
            TextSpan(text: l10n.settingsAndroidPasswordRules),
          ]),
          style: TextStyle(fontSize: 12, color: c.textMuted),
        ),
        const SizedBox(height: 16),
        _field(2, l10n.settingsAndroidConfirmPassword, _confirm,
            hint: l10n.authWebConfirmPasswordHint,
            helper: mismatch ? l10n.msgPasswordsDontMatch : null),
        const SizedBox(height: 20),
        _primaryButton(
          l10n.settingsAndroidSavePassword,
          canSave
              ? () => Navigator.pop(
                  context, (_current.text.trim(), _next.text.trim()))
              : null,
        ),
        const SizedBox(height: 8),
        _cancelButton(context, l10n.cancel),
      ],
    );
  }
}

/// Forgot password sheet. Returns the email when sent.
Future<String?> showSettingsResetPasswordSheet(BuildContext context) =>
    showWandererSheet<String>(
      context,
      title: context.l10n.settingsForgotPassword,
      builder: (_) => const _ResetPasswordForm(),
    );

class _ResetPasswordForm extends StatefulWidget {
  const _ResetPasswordForm();

  @override
  State<_ResetPasswordForm> createState() => _ResetPasswordFormState();
}

class _ResetPasswordFormState extends State<_ResetPasswordForm> {
  final _email = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    final email = _email.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Transform.translate(
          offset: const Offset(0, -12),
          child: Text(l10n.settingsForgotPasswordCaption,
              style: TextStyle(fontSize: 14, height: 1.5, color: c.textMuted)),
        ),
        LabeledField(
          label: l10n.emailLabel,
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 20),
        _primaryButton(l10n.settingsSendResetLinkButton,
            email.isEmpty ? null : () => Navigator.pop(context, email)),
        const SizedBox(height: 8),
        _cancelButton(context, l10n.cancel),
      ],
    );
  }
}

/// Close account sheet: lists what gets deleted and asks for the username
/// (or DELETE when it isn't known). Returns true when confirmed.
Future<bool> showSettingsCloseAccountSheet(BuildContext context,
    {String? username}) async {
  final result = await showWandererSheet<bool>(
    context,
    builder: (_) => _CloseAccountForm(expected: username ?? 'DELETE'),
  );
  return result == true;
}

class _CloseAccountForm extends StatefulWidget {
  final String expected;
  const _CloseAccountForm({required this.expected});

  @override
  State<_CloseAccountForm> createState() => _CloseAccountFormState();
}

class _CloseAccountFormState extends State<_CloseAccountForm> {
  final _typed = TextEditingController();

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    final danger = Theme.of(context).colorScheme.error;
    final matches = _typed.text.trim() == widget.expected;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
                color: danger.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14)),
            child: Icon(Icons.delete_forever_outlined, color: danger),
          ),
          const SizedBox(width: 14),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l10n.settingsAndroidCloseTitle,
                  style: WandererTheme.display(22, color: c.text)),
              const SizedBox(height: 4),
              Text(l10n.settingsAndroidCloseMessage,
                  style:
                      TextStyle(fontSize: 14, height: 1.5, color: c.textMuted)),
            ]),
          ),
        ]),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
              color: danger.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (i, line) in [
                l10n.settingsAndroidCloseTrips,
                l10n.settingsAndroidClosePlans,
                l10n.settingsAndroidCloseAchievements,
                l10n.settingsAndroidCloseSocial,
              ].indexed)
                Padding(
                  padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.only(top: 7, right: 10),
                          decoration: BoxDecoration(
                              color: danger, shape: BoxShape.circle),
                        ),
                        Expanded(
                            child: Text(line,
                                style: TextStyle(
                                    fontSize: 14, color: c.neutralFg))),
                      ]),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        LabeledField(
          label: widget.expected == 'DELETE'
              ? l10n.typeDELETEConfirm
              : l10n.settingsAndroidCloseTypeUsername,
          controller: _typed,
          hint: widget.expected,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 20),
        _primaryButton(l10n.settingsAndroidCloseConfirm,
            matches ? () => Navigator.pop(context, true) : null,
            color: danger),
        const SizedBox(height: 8),
        _cancelButton(context, l10n.settingsAndroidCloseKeep),
      ],
    );
  }
}
