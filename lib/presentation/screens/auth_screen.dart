import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/l10n/locale_controller.dart';
import 'package:wanderer_frontend/core/theme/theme_controller.dart';
import 'package:wanderer_frontend/data/repositories/auth_repository.dart';
import 'package:wanderer_frontend/presentation/widgets/auth/auth_form.dart';
import 'package:wanderer_frontend/presentation/widgets/auth/forgot_password_form.dart';

/// Authentication screen for login and registration
class AuthScreen extends StatefulWidget {
  final bool startInSignup;
  final String? initialUsername;

  const AuthScreen(
      {super.key, this.startInSignup = false, this.initialUsername});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final AuthRepository _repository = AuthRepository();
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // State
  late bool _isLogin = !widget.startInSignup;
  bool _isLoading = false;
  String? _errorMessage;
  bool _registrationPending = false;
  bool _isForgotPassword = false;
  bool _passwordResetSent = false;

  @override
  void initState() {
    super.initState();
    _prefillUsername();
  }

  void _prefillUsername() {
    // First check widget parameter
    if (widget.initialUsername != null && widget.initialUsername!.isNotEmpty) {
      _usernameController.text = widget.initialUsername!;
      return;
    }

    // On web, also check URL query parameters
    if (kIsWeb) {
      final uri = Uri.base;
      final username = uri.queryParameters['username'];
      if (username != null && username.isNotEmpty) {
        _usernameController.text = username;
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_isLogin) {
        await _repository.login(
          _usernameController.text.trim(),
          _passwordController.text,
        );

        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } else {
        await _repository.register(
          _usernameController.text.trim(),
          _emailController.text.trim(),
          _passwordController.text,
        );

        if (mounted) {
          setState(() {
            _registrationPending = true;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _forgotPassword() {
    setState(() {
      _isForgotPassword = true;
      _errorMessage = null;
      _passwordResetSent = false;
    });
  }

  Future<void> _submitForgotPassword() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your email address';
      });
      return;
    }

    if (!email.contains('@') || !email.contains('.')) {
      setState(() {
        _errorMessage = 'Please enter a valid email address';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _repository.requestPasswordReset(email);

      if (mounted) {
        setState(() {
          _passwordResetSent = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  void _backToLogin() {
    setState(() {
      _isForgotPassword = false;
      _passwordResetSent = false;
      _errorMessage = null;
      _emailController.clear();
    });
  }

  void _toggleMode() {
    setState(() {
      _isLogin = !_isLogin;
      _errorMessage = null;
      _registrationPending = false;
      _formKey.currentState?.reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          _buildLanguageToggle(),
          _buildThemeToggle(),
          const SizedBox(width: 4),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.secondary,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 450),
                child: _registrationPending
                    ? _buildRegistrationPendingView()
                    : _isForgotPassword
                        ? ForgotPasswordForm(
                            emailController: _emailController,
                            isLoading: _isLoading,
                            errorMessage: _errorMessage,
                            passwordResetSent: _passwordResetSent,
                            onSubmit: _submitForgotPassword,
                            onBackToLogin: _backToLogin,
                          )
                        : AuthForm(
                            formKey: _formKey,
                            isLogin: _isLogin,
                            isLoading: _isLoading,
                            errorMessage: _errorMessage,
                            usernameController: _usernameController,
                            emailController: _emailController,
                            passwordController: _passwordController,
                            confirmPasswordController:
                                _confirmPasswordController,
                            onSubmit: _submit,
                            onToggleMode: _toggleMode,
                            onForgotPassword: _forgotPassword,
                          ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThemeToggle() {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController().themeMode,
      builder: (context, mode, _) {
        final isDark = mode == ThemeMode.dark;
        final l10n = context.l10n;
        return IconButton(
          icon: Icon(
            isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            color: Colors.white,
            size: 20,
          ),
          tooltip: isDark ? l10n.switchToLightMode : l10n.switchToDarkMode,
          onPressed: () => ThemeController().setDarkMode(!isDark),
          visualDensity: VisualDensity.compact,
        );
      },
    );
  }

  Widget _buildLanguageToggle() {
    return ValueListenableBuilder<Locale>(
      valueListenable: LocaleController().locale,
      builder: (context, locale, _) {
        final controller = LocaleController();
        final currentCode = controller.languageCode;
        final flag = LocaleController.localeFlags[currentCode] ?? '🌐';
        final label = LocaleController.localeLabels[currentCode] ?? 'EN';
        return PopupMenuButton<String>(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          tooltip: 'Change language',
          onSelected: (code) => controller.setLocale(Locale(code)),
          itemBuilder: (_) => LocaleController.supportedLocales.map((loc) {
            final code = loc.languageCode;
            final locFlag = LocaleController.localeFlags[code] ?? '🌐';
            final locLabel = LocaleController.localeLabels[code] ?? code;
            return PopupMenuItem<String>(
              value: code,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(locFlag, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Text(locLabel),
                ],
              ),
            );
          }).toList(),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(flag, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Icon(Icons.arrow_drop_down, color: Colors.white, size: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRegistrationPendingView() {
    final l10n = context.l10n;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.mark_email_unread_outlined,
                size: 64, color: Colors.blueAccent),
            const SizedBox(height: 24),
            Text(
              l10n.checkYourEmail,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              'We sent a verification link to ${_emailController.text.trim()}. '
              'Click the link in the email to complete your registration.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () {
                setState(() {
                  _registrationPending = false;
                  _isLogin = true;
                  _errorMessage = null;
                  _formKey.currentState?.reset();
                });
              },
              child: Text(l10n.backToLogin),
            ),
          ],
        ),
      ),
    );
  }
}
