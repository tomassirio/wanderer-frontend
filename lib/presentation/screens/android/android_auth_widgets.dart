import 'package:flutter/material.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/l10n/locale_controller.dart';
import 'package:wanderer_frontend/core/theme/theme_controller.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/data/models/auth_models.dart'
    show SsoProvider;
import 'package:wanderer_frontend/presentation/widgets/auth/email_field.dart';
import 'package:wanderer_frontend/presentation/widgets/auth/error_message.dart';
import 'package:wanderer_frontend/presentation/widgets/auth/password_field.dart';
import 'package:wanderer_frontend/presentation/widgets/auth/sso_button.dart';
import 'package:wanderer_frontend/presentation/widgets/auth/username_field.dart';
import 'package:wanderer_frontend/presentation/widgets/auth/web_auth_layout.dart'
    show PasswordStrengthMeter;
import 'package:wanderer_frontend/presentation/widgets/common/toasts.dart';
import 'package:wanderer_frontend/presentation/widgets/common/wanderer_logo.dart';
import 'package:wanderer_frontend/presentation/widgets/common/wanderer_sheet.dart';

/// Orange 56dp primary button (one per screen).
Widget androidPrimaryButton(String label,
        {required VoidCallback? onPressed, bool busy = false}) =>
    SizedBox(
      height: 56,
      child: FilledButton(
        onPressed: busy ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: WandererTheme.trail,
          foregroundColor: Colors.white,
          disabledBackgroundColor: WandererTheme.trail.withValues(alpha: 0.6),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        child: busy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : Text(label),
      ),
    );

/// Language chip + theme toggle in the logged-out headers.
class AndroidAuthHeaderActions extends StatelessWidget {
  const AndroidAuthHeaderActions({super.key});

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final controller = LocaleController();
    return Row(mainAxisSize: MainAxisSize.min, children: [
      ValueListenableBuilder<Locale>(
        valueListenable: controller.locale,
        builder: (context, _, __) => PopupMenuButton<String>(
          tooltip: 'Change language',
          onSelected: (code) => controller.setLocale(Locale(code)),
          itemBuilder: (_) => [
            for (final loc in LocaleController.supportedLocales)
              PopupMenuItem(
                value: loc.languageCode,
                child: Text(l10n.languageNameFor(loc.languageCode)),
              ),
          ],
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: c.line),
            ),
            child: Text(
              LocaleController.localeLabels[controller.languageCode] ?? 'EN',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: c.textMuted),
            ),
          ),
        ),
      ),
      IconButton(
        iconSize: 22,
        constraints: const BoxConstraints.tightFor(width: 48, height: 48),
        tooltip: isDark ? l10n.switchToLightMode : l10n.switchToDarkMode,
        icon: Icon(
            isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            color: c.text),
        onPressed: () => ThemeController().setDarkMode(!isDark),
      ),
    ]);
  }
}

InputDecoration _decoration(WandererColors c, {String? hint}) {
  OutlineInputBorder border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: color, width: width),
      );
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: c.caption, fontSize: 16),
    filled: true,
    fillColor: c.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
    border: border(c.line),
    enabledBorder: border(c.line),
    focusedBorder: border(WandererTheme.trail, 2),
  );
}

Widget _labeled(WandererColors c, String label, Widget field,
        {Widget? trailing}) =>
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
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
        field,
      ],
    );

TextStyle _link(WandererColors c, [double size = 14]) =>
    TextStyle(fontSize: size, fontWeight: FontWeight.w700, color: c.accentText);

/// Android sign-in / create-account page (canvas: Sign in, Create account).
/// State and API calls stay in AuthScreen; this is layout only.
class AndroidAuthForm extends StatefulWidget {
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
  final VoidCallback onBack;

  /// Continue with Google; hidden when null.
  final VoidCallback? onSsoPressed;

  const AndroidAuthForm({
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
    required this.onBack,
    this.onSsoPressed,
  });

  @override
  State<AndroidAuthForm> createState() => _AndroidAuthFormState();
}

class _AndroidAuthFormState extends State<AndroidAuthForm> {
  @override
  void initState() {
    super.initState();
    widget.passwordController.addListener(_rebuild);
  }

  @override
  void dispose() {
    widget.passwordController.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

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
          ? InkWell(
              onTap: busy ? null : widget.onForgotPassword,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(l10n.authForgotShort, style: _link(c, 13)),
              ),
            )
          : null,
    );

    final fields = isLogin
        ? [
            const WandererLogo(size: 56),
            const SizedBox(height: 14),
            Text(l10n.authWebWelcomeBack,
                style: WandererTheme.display(32, color: c.text)),
            const SizedBox(height: 14),
            Text(l10n.authWebSignInSubtitle,
                style: TextStyle(fontSize: 16, color: c.textMuted)),
            const SizedBox(height: 26),
            username,
            const SizedBox(height: 18),
            password,
            const SizedBox(height: 26),
            Align(
              alignment: Alignment.centerLeft,
              child: InkWell(
                onTap: busy ? null : widget.onNeedVerificationToken,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(l10n.authWebHaveCode, style: _link(c)),
                ),
              ),
            ),
          ]
        : [
            Text(l10n.authWebCreateTitle,
                style: WandererTheme.display(30, color: c.text)),
            const SizedBox(height: 12),
            username,
            const SizedBox(height: 12),
            _labeled(
              c,
              l10n.emailLabel,
              EmailField(
                controller: widget.emailController,
                decoration: _decoration(c, hint: 'you@example.com'),
              ),
            ),
            const SizedBox(height: 12),
            password,
            const SizedBox(height: 12),
            PasswordStrengthMeter(
                rules: passwordRules(l10n, widget.passwordController.text)),
            const SizedBox(height: 12),
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
          ];

    return Scaffold(
      backgroundColor: c.ground,
      appBar: AppBar(
        toolbarHeight: 64,
        backgroundColor: c.ground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: BackButton(onPressed: widget.onBack),
        actions: isLogin
            ? const [AndroidAuthHeaderActions(), SizedBox(width: 8)]
            : null,
      ),
      body: SafeArea(
        top: false,
        child: AutofillGroup(
          child: Form(
            key: widget.formKey,
            child: Column(children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(24, isLogin ? 12 : 0, 24, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ...fields,
                      if (widget.errorMessage != null) ...[
                        const SizedBox(height: 16),
                        ErrorMessage(message: widget.errorMessage!),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    androidPrimaryButton(
                      isLogin ? l10n.signIn : l10n.createAccount,
                      onPressed: widget.onSubmit,
                      busy: busy,
                    ),
                    if (widget.onSsoPressed != null) ...[
                      const SizedBox(height: 14),
                      const OrDivider(),
                      const SizedBox(height: 14),
                      SsoButton(
                        provider: SsoProvider.google,
                        onPressed: busy ? null : widget.onSsoPressed,
                      ),
                    ],
                    const SizedBox(height: 6),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          isLogin
                              ? l10n.authWebNewToWanderer
                              : l10n.alreadyHaveAccount,
                          style: TextStyle(fontSize: 14, color: c.textMuted),
                        ),
                        TextButton(
                          onPressed: busy ? null : widget.onToggleMode,
                          style: TextButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 6)),
                          child: Text(
                            isLogin ? l10n.authWebCreateAnAccount : l10n.signIn,
                            style: _link(c),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Forgot-password bottom sheet (canvas: Reset password). Shows a success
/// toast and closes once the reset email is requested.
Future<void> showAndroidForgotPasswordSheet(
  BuildContext context, {
  required Future<void> Function(String email) onSubmit,
  String initialEmail = '',
}) {
  return showWandererSheet(
    context,
    builder: (_) =>
        _ForgotSheet(onSubmit: onSubmit, initialEmail: initialEmail),
  );
}

class _ForgotSheet extends StatefulWidget {
  final Future<void> Function(String email) onSubmit;
  final String initialEmail;

  const _ForgotSheet({required this.onSubmit, required this.initialEmail});

  @override
  State<_ForgotSheet> createState() => _ForgotSheetState();
}

class _ForgotSheetState extends State<_ForgotSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.initialEmail);
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = context.l10n;
    final email = _email.text.trim();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSubmit(email);
      if (!mounted) return;
      Navigator.of(context).pop();
      Toasts.show(ToastData(
        kind: ToastKind.success,
        title: l10n.checkYourEmail,
        body: l10n.passwordResetEmailSent(email),
      ));
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.authResetSheetTitle,
              style: WandererTheme.display(22, color: c.text)),
          const SizedBox(height: 4),
          Text(l10n.authResetSheetBody,
              style: TextStyle(fontSize: 14, height: 1.5, color: c.textMuted)),
          const SizedBox(height: 16),
          _labeled(
            c,
            l10n.emailLabel,
            EmailField(
              controller: _email,
              decoration: _decoration(c, hint: 'you@example.com'),
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _busy ? null : _send(),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            ErrorMessage(message: _error!),
          ],
          const SizedBox(height: 20),
          androidPrimaryButton(l10n.sendResetLink,
              onPressed: _send, busy: _busy),
          const SizedBox(height: 8),
          SizedBox(
            height: 48,
            child: TextButton(
              onPressed: _busy ? null : () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: c.text,
                textStyle:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              child: Text(l10n.cancel),
            ),
          ),
        ],
      ),
    );
  }
}
