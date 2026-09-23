import 'package:flutter/material.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/l10n/locale_controller.dart';
import 'package:wanderer_frontend/core/theme/theme_controller.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/presentation/widgets/auth/email_field.dart';
import 'package:wanderer_frontend/presentation/widgets/auth/error_message.dart';
import 'package:wanderer_frontend/presentation/widgets/auth/password_field.dart';
import 'package:wanderer_frontend/presentation/widgets/auth/username_field.dart';
import 'package:wanderer_frontend/presentation/widgets/common/wanderer_logo.dart';

/// Web auth page: form column on the left, route image panel on the right
/// (panel only at >= 960px).
class WebAuthLayout extends StatelessWidget {
  final bool isLogin;
  final VoidCallback onLogoTap;
  final Widget child;

  const WebAuthLayout({
    super.key,
    required this.isLogin,
    required this.onLogoTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    return Scaffold(
      backgroundColor: c.ground,
      body: LayoutBuilder(builder: (context, box) {
        final wide = box.maxWidth >= 960;
        final form = Padding(
          padding: wide
              ? const EdgeInsets.symmetric(horizontal: 48, vertical: 32)
              : const EdgeInsets.all(16),
          child: Column(
            children: [
              _TopBar(onLogoTap: onLogoTap),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: child,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
        if (!wide) return form;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: form),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 20, 20, 20),
                child: _RoutePanel(isLogin: isLogin),
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _TopBar extends StatelessWidget {
  final VoidCallback onLogoTap;

  const _TopBar({required this.onLogoTap});

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    BoxDecoration box() => BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: c.line),
        );

    return Row(
      children: [
        Semantics(
          button: true,
          label: 'Wanderer',
          child: InkWell(
            onTap: onLogoTap,
            borderRadius: BorderRadius.circular(8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const WandererLogo(size: 36),
                const SizedBox(width: 10),
                Text('Wanderer',
                    style: WandererTheme.display(21, color: c.text)),
              ],
            ),
          ),
        ),
        const Spacer(),
        ValueListenableBuilder<Locale>(
          valueListenable: LocaleController().locale,
          builder: (context, _, __) {
            final controller = LocaleController();
            return PopupMenuButton<String>(
              tooltip: 'Change language',
              onSelected: (code) => controller.setLocale(Locale(code)),
              itemBuilder: (_) => LocaleController.supportedLocales.map((loc) {
                final code = loc.languageCode;
                return PopupMenuItem<String>(
                  value: code,
                  child: Text(
                      '${LocaleController.localeFlags[code] ?? ''}  ${LocaleController.localeLabels[code] ?? code}'),
                );
              }).toList(),
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.center,
                decoration: box(),
                child: Text(
                  LocaleController.localeLabels[controller.languageCode] ??
                      'EN',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: c.textMuted),
                ),
              ),
            );
          },
        ),
        const SizedBox(width: 8),
        Tooltip(
          message: isDark ? l10n.switchToLightMode : l10n.switchToDarkMode,
          child: InkWell(
            onTap: () => ThemeController().setDarkMode(!isDark),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 40,
              height: 40,
              decoration: box(),
              child: Icon(
                isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                size: 18,
                color: c.textMuted,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Rounded dark panel with the real route image and marketing copy. Always
/// dark (image + scrim), so the overlay colours are fixed in both themes.
class _RoutePanel extends StatelessWidget {
  final bool isLogin;

  const _RoutePanel({required this.isLogin});

  static const _headline = Color(0xFFF3EFE8);
  static const _body = Color(0xFFCFC8BF);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Color(0xFF1B1A17)),
          Image.asset(
            'assets/images/landing-route-backdrop.png',
            fit: BoxFit.cover,
            excludeFromSemantics: true,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x591B1A17), Color(0xE61B1A17)],
              ),
            ),
          ),
          Positioned(
            left: 40,
            right: 40,
            bottom: 40,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: isLogin
                  ? [
                      _achievementChip(l10n),
                      const SizedBox(height: 20),
                      Text(l10n.authWebSignInHeadline,
                          style: WandererTheme.display(40, color: _headline)),
                      const SizedBox(height: 20),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 460),
                        child: Text(l10n.authWebSignInBody,
                            style: const TextStyle(
                                fontSize: 16, height: 1.6, color: _body)),
                      ),
                    ]
                  : [
                      Text(l10n.authWebSignUpHeadline,
                          style: WandererTheme.display(40, color: _headline)),
                      const SizedBox(height: 22),
                      for (final point in [
                        l10n.authWebSignUpPoint1,
                        l10n.authWebSignUpPoint2,
                        l10n.authWebSignUpPoint3,
                      ])
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(children: [
                            const Icon(Icons.check_rounded,
                                size: 18, color: Color(0xFF7BCBA3)),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(point,
                                  style: const TextStyle(
                                      fontSize: 15, color: Color(0xFFE7E1D6))),
                            ),
                          ]),
                        ),
                    ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _achievementChip(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
              color: Color(0x4D000000), blurRadius: 30, offset: Offset(0, 12)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
                color: Color(0xFFF5B83D), shape: BoxShape.circle),
            child: const Icon(Icons.emoji_events_outlined,
                size: 18, color: Color(0xFF5B3A00)),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.authWebAchievementUnlocked,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1B1A17))),
              Text(l10n.authWebAchievementSample,
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF6B6560))),
            ],
          ),
        ],
      ),
    );
  }
}

/// Web sign-in / create-account form: labels above 48px inputs, strength
/// meter on sign-up. Reuses the mobile field widgets for validation.
class WebAuthForm extends StatefulWidget {
  final GlobalKey<FormState> formKey;
  final bool isLogin;
  final bool isLoading;
  final String? errorMessage;
  final TextEditingController usernameController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final VoidCallback onSubmit;
  final VoidCallback onToggleMode;
  final VoidCallback onForgotPassword;
  final VoidCallback onNeedVerificationToken;

  const WebAuthForm({
    super.key,
    required this.formKey,
    required this.isLogin,
    required this.isLoading,
    this.errorMessage,
    required this.usernameController,
    required this.emailController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.onSubmit,
    required this.onToggleMode,
    required this.onForgotPassword,
    required this.onNeedVerificationToken,
  });

  @override
  State<WebAuthForm> createState() => _WebAuthFormState();
}

class _WebAuthFormState extends State<WebAuthForm> {
  @override
  void initState() {
    super.initState();
    widget.passwordController.addListener(_rebuild);
  }

  @override
  void didUpdateWidget(WebAuthForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.passwordController != widget.passwordController) {
      oldWidget.passwordController.removeListener(_rebuild);
      widget.passwordController.addListener(_rebuild);
    }
  }

  @override
  void dispose() {
    widget.passwordController.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  InputDecoration _decoration(WandererColors c, {String? hint}) {
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(WandererTheme.radiusControl),
          borderSide: BorderSide(color: color, width: width),
        );
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: c.caption, fontSize: 15),
      isDense: true,
      filled: true,
      fillColor: c.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: border(c.line, 1),
      enabledBorder: border(c.line, 1),
      focusedBorder: border(WandererTheme.trail, 2),
      suffixIconConstraints: const BoxConstraints(
          minWidth: 44, maxWidth: 44, minHeight: 36, maxHeight: 36),
    );
  }

  Widget _labeled(WandererColors c, String label, Widget field,
      {Widget? trailing}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700, color: c.text)),
          ),
          if (trailing != null) trailing,
        ]),
        const SizedBox(height: 8),
        _FocusRing(color: c.trailSoftBg, child: field),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    final isLogin = widget.isLogin;
    final busy = widget.isLoading;
    void submit() => busy ? null : widget.onSubmit();

    final username = _labeled(
      c,
      isLogin ? l10n.usernameOrEmailLabel : l10n.usernameLabel,
      UsernameField(
        controller: widget.usernameController,
        isLogin: isLogin,
        decoration: _decoration(c),
      ),
    );

    final password = _labeled(
      c,
      l10n.passwordLabel,
      PasswordField(
        controller: widget.passwordController,
        isLogin: isLogin,
        decoration: _decoration(c),
        textInputAction: isLogin ? TextInputAction.done : TextInputAction.next,
        onFieldSubmitted: isLogin ? (_) => submit() : null,
      ),
      trailing: isLogin
          ? TextButton(
              onPressed: busy ? null : widget.onForgotPassword,
              style: TextButton.styleFrom(
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              child: Text(l10n.authWebForgotPassword),
            )
          : null,
    );

    return AutofillGroup(
      child: Form(
        key: widget.formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isLogin ? l10n.authWebWelcomeBack : l10n.authWebCreateTitle,
              style: WandererTheme.display(38, color: c.text),
            ),
            const SizedBox(height: 8),
            Text(
              isLogin ? l10n.authWebSignInSubtitle : l10n.authWebCreateSubtitle,
              style: TextStyle(fontSize: 16, color: c.textMuted),
            ),
            const SizedBox(height: 28),
            if (isLogin) ...[
              username,
              const SizedBox(height: 18),
              password,
            ] else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: username),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _labeled(
                      c,
                      l10n.emailLabel,
                      EmailField(
                        controller: widget.emailController,
                        decoration: _decoration(c, hint: 'you@example.com'),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              password,
              const SizedBox(height: 16),
              _StrengthMeter(
                rules: passwordRules(l10n, widget.passwordController.text),
              ),
              const SizedBox(height: 16),
              _labeled(
                c,
                l10n.confirmPassword,
                PasswordField(
                  controller: widget.confirmPasswordController,
                  isLogin: false,
                  compareController: widget.passwordController,
                  decoration:
                      _decoration(c, hint: l10n.authWebConfirmPasswordHint),
                  onFieldSubmitted: (_) => submit(),
                ),
              ),
            ],
            if (widget.errorMessage != null) ...[
              const SizedBox(height: 18),
              ErrorMessage(message: widget.errorMessage!),
            ],
            const SizedBox(height: 28),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: busy ? null : widget.onSubmit,
                style: ElevatedButton.styleFrom(
                  textStyle: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
                child: busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(isLogin ? l10n.signIn : l10n.createAccount),
              ),
            ),
            if (isLogin) ...[
              const SizedBox(height: 14),
              SizedBox(
                height: 48,
                child: OutlinedButton(
                  onPressed: busy ? null : widget.onNeedVerificationToken,
                  child: Text(l10n.authWebHaveCode),
                ),
              ),
            ],
            const SizedBox(height: 28),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  isLogin ? l10n.authWebNewToWanderer : l10n.alreadyHaveAccount,
                  style: TextStyle(fontSize: 14, color: c.textMuted),
                ),
                TextButton(
                  onPressed: busy ? null : widget.onToggleMode,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    textStyle: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  child:
                      Text(isLogin ? l10n.authWebCreateAnAccount : l10n.signIn),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 4px soft ring behind the 48px input box while any descendant has focus.
/// Painted in a Stack so the validator error text below stays outside it.
class _FocusRing extends StatefulWidget {
  final Color color;
  final Widget child;

  const _FocusRing({required this.color, required this.child});

  @override
  State<_FocusRing> createState() => _FocusRingState();
}

class _FocusRingState extends State<_FocusRing> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (f) => setState(() => _focused = f),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (_focused)
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: 48,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius:
                      BorderRadius.circular(WandererTheme.radiusControl),
                  boxShadow: [
                    BoxShadow(color: widget.color, spreadRadius: 4),
                  ],
                ),
              ),
            ),
          widget.child,
        ],
      ),
    );
  }
}

class _StrengthMeter extends StatelessWidget {
  final List<(String, bool)> rules;

  const _StrengthMeter({required this.rules});

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    final met = rules.where((r) => r.$2).length;
    final (label, color) = switch (met) {
      0 => ('', c.caption),
      1 || 2 => (l10n.authWebStrengthWeak, c.accentText),
      3 => (l10n.authWebStrengthFair, c.goldFg),
      4 => (l10n.authWebStrengthAlmost, c.forestFg),
      _ => (l10n.authWebStrengthStrong, c.forestFg),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(WandererTheme.radiusControl),
        border: Border.all(color: c.lineSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            for (var i = 0; i < rules.length; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              Expanded(
                child: Container(
                  height: 5,
                  decoration: BoxDecoration(
                    color: i < met ? c.forestFg : c.line,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ],
            if (label.isNotEmpty) ...[
              const SizedBox(width: 10),
              Text(label,
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700, color: color)),
            ],
          ]),
          const SizedBox(height: 10),
          LayoutBuilder(builder: (context, box) {
            final itemWidth = (box.maxWidth - 12) / 2;
            return Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                for (final (text, ok) in rules)
                  SizedBox(
                    width: itemWidth,
                    child: Row(children: [
                      Icon(
                        ok ? Icons.check_rounded : Icons.circle_outlined,
                        size: 14,
                        color: ok ? c.forestFg : c.caption,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(text,
                            style: TextStyle(
                                fontSize: 13,
                                color: ok ? c.forestFg : c.textMuted)),
                      ),
                    ]),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }
}
