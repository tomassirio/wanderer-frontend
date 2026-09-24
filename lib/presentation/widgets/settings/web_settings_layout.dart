import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/l10n/locale_controller.dart';
import 'package:wanderer_frontend/core/theme/theme_controller.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/presentation/helpers/ui_helpers.dart';
import 'package:wanderer_frontend/presentation/widgets/common/wanderer_dialog.dart';
import 'package:wanderer_frontend/presentation/widgets/common/web_page_header.dart';

/// Web settings page: header, section nav on the left, section cards on the
/// right. All actions come from the screen; theme and language are read from
/// their controllers directly.
class WebSettingsLayout extends StatefulWidget {
  final String? userId;
  final bool isAdmin;
  final String appVersion;
  final VoidCallback onChangePassword;
  final VoidCallback onResetPassword;
  final VoidCallback onContactSupport;
  final VoidCallback onResetTutorials;
  final VoidCallback onTerms;
  final VoidCallback onPrivacy;
  final VoidCallback onCloseAccount;
  final VoidCallback onVersionTap;
  final VoidCallback onLocaleChanged;

  const WebSettingsLayout({
    super.key,
    required this.userId,
    required this.isAdmin,
    required this.appVersion,
    required this.onChangePassword,
    required this.onResetPassword,
    required this.onContactSupport,
    required this.onResetTutorials,
    required this.onTerms,
    required this.onPrivacy,
    required this.onCloseAccount,
    required this.onVersionTap,
    required this.onLocaleChanged,
  });

  @override
  State<WebSettingsLayout> createState() => _WebSettingsLayoutState();
}

class _WebSettingsLayoutState extends State<WebSettingsLayout> {
  final _keys = List.generate(3, (_) => GlobalKey());
  int _selected = 0;

  void _goTo(int i) {
    setState(() => _selected = i);
    final ctx = _keys[i].currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = WandererTheme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final phone = width < 600;
    final titles = [
      l10n.appearance,
      l10n.settingsAccountSecurity,
      l10n.settingsHelpLegal,
    ];

    final cards = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Card(key: _keys[0], title: titles[0], rows: [
          _Row(
            title: l10n.settingsTheme,
            caption: l10n.settingsThemeCaption,
            trailing: const _ThemeSegments(),
          ),
          _Row(
            title: l10n.language,
            caption: l10n.settingsLanguageCaption,
            trailing: _LanguageDropdown(onChanged: widget.onLocaleChanged),
          ),
        ]),
        const SizedBox(height: 24),
        _Card(key: _keys[1], title: titles[1], rows: [
          _Row(
            title: l10n.settingsPassword,
            caption: l10n.settingsPasswordCaption,
            trailing: OutlinedButton(
              onPressed: widget.onChangePassword,
              child: Text(l10n.settingsChangePasswordButton),
            ),
          ),
          _Row(
            title: l10n.settingsForgotPassword,
            caption: l10n.settingsForgotPasswordCaption,
            trailing: TextButton(
              onPressed: widget.onResetPassword,
              child: Text(l10n.settingsSendResetLinkButton),
            ),
          ),
          if (widget.userId != null && widget.userId!.isNotEmpty)
            _Row(
              title: l10n.settingsAccountId,
              caption: widget.userId!,
              monospaceCaption: true,
              trailing: OutlinedButton(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: widget.userId!));
                  if (context.mounted) {
                    UiHelpers.showSuccessMessage(
                        context, l10n.settingsAccountIdCopied);
                  }
                },
                child: Text(l10n.settingsCopy),
              ),
            ),
          _Row(
            title: l10n.closeAccount,
            caption: l10n.closeAccountSubtitle,
            trailing: TextButton(
              onPressed: widget.onCloseAccount,
              style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error),
              child: Text(l10n.settingsCloseAccountButton),
            ),
          ),
        ]),
        const SizedBox(height: 24),
        _Card(key: _keys[2], title: titles[2], rows: [
          _Row(
            title: l10n.contactSupport,
            caption: l10n.contactSupportSubtitle,
            onTap: widget.onContactSupport,
            trailing: Icon(Icons.arrow_outward, size: 16, color: c.caption),
          ),
          if (widget.isAdmin)
            _Row(
              title: l10n.resetTutorials,
              caption: l10n.resetTutorialsSubtitle,
              onTap: widget.onResetTutorials,
              trailing: Icon(Icons.replay, size: 16, color: c.caption),
            ),
          _Row(
            title: l10n.termsOfService,
            onTap: widget.onTerms,
            trailing: Icon(Icons.chevron_right, size: 18, color: c.caption),
          ),
          _Row(
            title: l10n.privacyPolicy,
            onTap: widget.onPrivacy,
            trailing: Icon(Icons.chevron_right, size: 18, color: c.caption),
          ),
        ]),
        const SizedBox(height: 24),
        if (widget.appVersion.isNotEmpty)
          Center(
            child: GestureDetector(
              onTap: widget.onVersionTap,
              child: Text(
                l10n.settingsVersion(widget.appVersion),
                style: TextStyle(fontSize: 13, color: c.caption),
              ),
            ),
          ),
      ],
    );

    return Container(
      color: c.ground,
      child: SingleChildScrollView(
        padding: phone
            ? const EdgeInsets.all(16)
            : const EdgeInsets.fromLTRB(40, 28, 40, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            WebPageHeader(
              title: l10n.settings,
              subtitle: l10n.settingsSubtitle,
              userId: widget.userId,
              isLoggedIn: widget.userId != null && widget.userId!.isNotEmpty,
            ),
            const SizedBox(height: 28),
            LayoutBuilder(builder: (context, box) {
              if (box.maxWidth < 760) return cards;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 200,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < titles.length; i++)
                          _NavItem(
                            label: titles[i],
                            selected: i == _selected,
                            onTap: () => _goTo(i),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 40),
                  Expanded(
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 820),
                        child: cards,
                      ),
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _NavItem(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? c.surface : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: selected ? c.line : Colors.transparent),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.centerLeft,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: selected ? c.text : c.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final List<_Row> rows;
  const _Card({super.key, required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    return Container(
      decoration: WandererTheme.cardDecoration(context),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 4),
              child: Text(title,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: c.text)),
            ),
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) Divider(height: 1, thickness: 1, color: c.lineSoft),
              rows[i],
            ],
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String title;
  final String? caption;
  final bool monospaceCaption;
  final Widget trailing;
  final VoidCallback? onTap;

  const _Row({
    required this.title,
    this.caption,
    this.monospaceCaption = false,
    required this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title,
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700, color: c.text)),
        if (caption != null) ...[
          const SizedBox(height: 2),
          Text(
            caption!,
            style: TextStyle(
              fontSize: 13,
              color: c.caption,
              fontFamily: monospaceCaption ? 'monospace' : null,
              fontFamilyFallback:
                  monospaceCaption ? const ['Menlo', 'Courier New'] : null,
            ),
          ),
        ],
      ],
    );
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      child: LayoutBuilder(builder: (context, box) {
        // Controls drop below the text when there's no room beside it.
        if (onTap == null && box.maxWidth < 520) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [text, const SizedBox(height: 12), trailing],
          );
        }
        return Row(
          children: [
            Expanded(child: text),
            const SizedBox(width: 24),
            trailing,
          ],
        );
      }),
    );
    return onTap == null ? row : InkWell(onTap: onTap, child: row);
  }
}

class _ThemeSegments extends StatelessWidget {
  const _ThemeSegments();

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    final controller = ThemeController();
    // Icons don't fit beside three labels on phones.
    final showIcons = MediaQuery.sizeOf(context).width >= 600;
    final options = [
      (ThemeMode.light, Icons.light_mode_outlined, l10n.settingsThemeLight),
      (ThemeMode.dark, Icons.dark_mode_outlined, l10n.settingsThemeDark),
      (
        ThemeMode.system,
        Icons.desktop_windows_outlined,
        l10n.settingsThemeSystem
      ),
    ];
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: controller.themeMode,
      builder: (context, mode, _) => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: c.neutralBg,
          borderRadius: BorderRadius.circular(WandererTheme.radiusControl),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (value, icon, label) in options)
              Semantics(
                button: true,
                selected: mode == value,
                child: InkWell(
                  borderRadius: BorderRadius.circular(9),
                  onTap: () => controller.setThemeMode(value),
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: mode == value ? c.surface : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                      boxShadow: mode == value
                          ? const [
                              BoxShadow(
                                  color: Color(0x141B1A17),
                                  blurRadius: 3,
                                  offset: Offset(0, 1)),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (showIcons) ...[
                          Icon(icon,
                              size: 15,
                              color: mode == value ? c.text : c.textMuted),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: mode == value
                                ? FontWeight.w700
                                : FontWeight.w600,
                            color: mode == value ? c.text : c.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LanguageDropdown extends StatelessWidget {
  final VoidCallback onChanged;
  const _LanguageDropdown({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    final controller = LocaleController();
    return Container(
      height: 44,
      constraints: const BoxConstraints(minWidth: 200),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.line),
        borderRadius: BorderRadius.circular(WandererTheme.radiusControl),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: controller.languageCode,
          dropdownColor: c.surface,
          borderRadius: BorderRadius.circular(WandererTheme.radiusControl),
          icon: Icon(Icons.expand_more, color: c.textMuted),
          style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600, color: c.text),
          items: [
            for (final locale in LocaleController.supportedLocales)
              DropdownMenuItem(
                value: locale.languageCode,
                child: Text(l10n.languageNameFor(locale.languageCode)),
              ),
          ],
          onChanged: (code) async {
            if (code == null) return;
            await controller.setLocale(Locale(code));
            onChanged();
          },
        ),
      ),
    );
  }
}

/// Web "Change password" form. Returns true when the user submits.
Future<bool?> showWebChangePasswordDialog(
  BuildContext context, {
  required TextEditingController current,
  required TextEditingController next,
  required TextEditingController confirm,
}) {
  final l10n = context.l10n;
  Widget field(TextEditingController ctrl, String label, IconData icon) =>
      TextField(
        controller: ctrl,
        obscureText: true,
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      );
  return WandererDialog.show<bool>(
    context,
    width: WandererDialog.formWidth,
    builder: (context) => WandererFormDialog(
      title: l10n.changePasswordTitle,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          field(current, l10n.currentPassword, Icons.lock_outline),
          const SizedBox(height: 12),
          field(next, l10n.newPassword, Icons.lock),
          const SizedBox(height: 12),
          field(confirm, l10n.confirmNewPassword, Icons.lock),
        ],
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.cancel),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(l10n.settingsChangePasswordButton),
        ),
      ],
    ),
  );
}

/// Web "Reset password" form. Returns true when the user submits.
Future<bool?> showWebResetPasswordDialog(
  BuildContext context, {
  required TextEditingController email,
}) {
  final l10n = context.l10n;
  return WandererDialog.show<bool>(
    context,
    width: WandererDialog.formWidth,
    builder: (context) => WandererFormDialog(
      title: l10n.resetPassword,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.enterEmailForReset,
              style: TextStyle(
                  fontSize: 14, color: WandererTheme.of(context).textMuted)),
          const SizedBox(height: 16),
          TextField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: l10n.emailLabel,
              prefixIcon: const Icon(Icons.email_outlined),
            ),
          ),
        ],
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.cancel),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(l10n.settingsSendResetLinkButton),
        ),
      ],
    ),
  );
}

/// Web second step of closing the account: type DELETE.
Future<bool?> showWebTypeDeleteDialog(
  BuildContext context, {
  required TextEditingController controller,
}) {
  final l10n = context.l10n;
  final danger = Theme.of(context).colorScheme.error;
  return WandererDialog.show<bool>(
    context,
    width: WandererDialog.formWidth,
    builder: (context) => WandererFormDialog(
      title: l10n.confirmAccountDeletion,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.typeDELETEConfirm,
              style: TextStyle(
                  fontSize: 14, color: WandererTheme.of(context).textMuted)),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            decoration: InputDecoration(hintText: l10n.typeDELETE),
          ),
        ],
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.cancel),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
              backgroundColor: danger, foregroundColor: Colors.white),
          child: Text(l10n.deleteMyAccount),
        ),
      ],
    ),
  );
}
