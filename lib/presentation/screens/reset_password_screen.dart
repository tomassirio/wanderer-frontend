import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wanderer_frontend/core/errors/app_exception.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/providers/app_providers.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/presentation/widgets/auth/error_message.dart';
import 'package:wanderer_frontend/presentation/widgets/auth/password_field.dart';
import 'package:wanderer_frontend/presentation/widgets/auth/web_auth_layout.dart'
    show PasswordStrengthMeter;
import 'package:wanderer_frontend/presentation/widgets/common/wanderer_logo.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  final String token;
  const ResetPasswordScreen({super.key, required this.token});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  bool _busy = false;
  bool _saved = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .completePasswordReset(widget.token, _password.text);
      if (mounted) {
        _password.clear();
        setState(() {
          _saved = true;
          _busy = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e is ApiException
              ? e.userMessage
              : context.l10n.mobileWebResetError;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: c.ground,
      body: SafeArea(
          child: Center(
              child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Form(
            key: _form,
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(24),
              children: [
                const Align(
                    alignment: Alignment.centerLeft,
                    child: WandererLogo(size: 40)),
                const SizedBox(height: 28),
                Text(
                    _saved
                        ? l10n.msgPasswordChanged
                        : l10n.settingsAndroidNewPassword,
                    style: WandererTheme.display(30, color: c.text)),
                const SizedBox(height: 24),
                if (!_saved && widget.token.isNotEmpty) ...[
                  PasswordField(
                      controller: _password,
                      isLogin: false,
                      label: l10n.newPassword,
                      onFieldSubmitted: (_) => _save()),
                  const SizedBox(height: 16),
                  ValueListenableBuilder(
                    valueListenable: _password,
                    builder: (context, value, child) => PasswordStrengthMeter(
                        rules: passwordRules(l10n, value.text)),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    ErrorMessage(message: _error!),
                  ],
                  const SizedBox(height: 32),
                  FilledButton(
                    style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 54),
                        backgroundColor: WandererTheme.trail,
                        foregroundColor: Colors.white),
                    onPressed: _busy ? null : _save,
                    child: _busy
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(l10n.save),
                  ),
                ],
                if (widget.token.isEmpty)
                  Text(l10n.mobileWebResetMissingToken,
                      style: TextStyle(color: c.textMuted)),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () =>
                          Navigator.of(context).pushReplacementNamed('/login'),
                  child: Text(l10n.backToLogin),
                ),
              ],
            )),
      ))),
    );
  }
}
