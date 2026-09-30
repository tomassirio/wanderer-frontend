import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wanderer_frontend/core/constants/api_endpoints.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/providers/app_providers.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/data/repositories/auth_repository.dart';
import 'package:wanderer_frontend/presentation/helpers/page_transitions.dart';
import 'package:wanderer_frontend/presentation/screens/android/android_auth_widgets.dart';
import 'package:wanderer_frontend/presentation/screens/initial_screen.dart';
import 'package:wanderer_frontend/data/models/auth_models.dart';
import 'package:wanderer_frontend/data/services/sso/pkce.dart';
import 'package:wanderer_frontend/data/services/sso/sso_service.dart';
import 'package:wanderer_frontend/presentation/screens/verify_email_screen.dart';
import 'package:wanderer_frontend/presentation/widgets/auth/forgot_password_form.dart';
import 'package:wanderer_frontend/presentation/widgets/auth/web_auth_layout.dart';

/// Authentication screen for login and registration
class AuthScreen extends ConsumerStatefulWidget {
  final bool startInSignup;
  final String? initialUsername;

  /// Android Welcome's "Continue with Google": start the Google flow as
  /// soon as the screen opens (the sign-in form stays behind it).
  final bool autoStartSso;

  /// Mobile SSO: opens the authorization [Uri] in a system browser session
  /// and returns the callback URL. Defaults to `flutter_web_auth_2`;
  /// overridable for tests.
  final Future<String> Function(Uri url)? ssoAuthenticate;

  const AuthScreen({
    super.key,
    this.startInSignup = false,
    this.initialUsername,
    this.ssoAuthenticate,
    this.autoStartSso = false,
  });

  static Future<String> _browserAuthenticate(Uri url) =>
      FlutterWebAuth2.authenticate(
        url: url.toString(),
        callbackUrlScheme: ApiEndpoints.ssoMobileCallbackScheme,
      );

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  late final AuthRepository _repository;
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
    _repository = ref.read(authRepositoryProvider);
    _prefillUsername();
    if (widget.autoStartSso) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _startSso(SsoProvider.google));
    }
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
          if (kIsWeb) {
            Navigator.of(context).pop(true);
          } else {
            // Android: land on the shell (InitialScreen routes there).
            Navigator.of(context).pushAndRemoveUntil(
                PageTransitions.fade(const InitialScreen()), (_) => false);
          }
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

  Future<void> _startSso(SsoProvider provider) async {
    if (_isLoading) return;
    final sso = ref.read(ssoServiceProvider);
    final pkce = PkcePair.generate();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (kIsWeb) {
        // The page navigates away; SsoCallbackScreen finishes the flow.
        await sso.savePendingVerifier(pkce.verifier);
        final launched = await launchUrl(
          sso.buildAuthorizationUri(
            provider: provider,
            returnTo: sso.webReturnUri(),
            codeChallenge: pkce.challenge,
          ),
          webOnlyWindowName: '_self',
        );
        if (!launched) throw Exception('Could not open SSO page');
        // The browser back-forward cache can restore this page without a
        // reload if the user navigates back, so reset the loading state
        // rather than leaving the form permanently disabled.
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final callback =
          await (widget.ssoAuthenticate ?? AuthScreen._browserAuthenticate)(
        sso.buildAuthorizationUri(
          provider: provider,
          returnTo: ApiEndpoints.ssoMobileCallbackUrl,
          codeChallenge: pkce.challenge,
        ),
      );
      final code = SsoService.codeFromCallback(callback);
      if (code == null) throw Exception('SSO callback without code');
      await _repository.completeSsoLogin(code, pkce.verifier);
      // Mobile only (web returned above): land on the Android shell, like
      // a password login.
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
            PageTransitions.fade(const InitialScreen()), (_) => false);
      }
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        if (e.code != 'CANCELED') _errorMessage = context.l10n.ssoFailed;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = context.l10n.ssoFailed;
      });
    }
  }

  void _forgotPassword() {
    if (!kIsWeb) {
      showAndroidForgotPasswordSheet(
        context,
        initialEmail: _usernameController.text.contains('@')
            ? _usernameController.text.trim()
            : '',
        onSubmit: _repository.requestPasswordReset,
      );
      return;
    }
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

  void _navigateToManualVerification() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const VerifyEmailScreen()),
    );
  }

  void _toggleMode() {
    setState(() {
      _isLogin = !_isLogin;
      _errorMessage = null;
      _registrationPending = false;
      _formKey.currentState?.reset();
    });
  }

  Widget _buildForgotPasswordForm() => ForgotPasswordForm(
        emailController: _emailController,
        isLoading: _isLoading,
        errorMessage: _errorMessage,
        passwordResetSent: _passwordResetSent,
        onSubmit: _submitForgotPassword,
        onBackToLogin: _backToLogin,
      );

  void _goBackOrHome() {
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
    } else {
      nav.pushNamedAndRemoveUntil('/', (_) => false);
    }
  }

  Widget _buildWeb(BuildContext context) {
    return WebAuthLayout(
      isLogin: _isLogin,
      onLogoTap: _goBackOrHome,
      child: _registrationPending
          ? _buildRegistrationPendingView()
          : _isForgotPassword
              ? _buildForgotPasswordForm()
              : WebAuthForm(
                  formKey: _formKey,
                  isLogin: _isLogin,
                  isLoading: _isLoading,
                  errorMessage: _errorMessage,
                  usernameController: _usernameController,
                  emailController: _emailController,
                  passwordController: _passwordController,
                  confirmPasswordController: _confirmPasswordController,
                  onSubmit: _submit,
                  onToggleMode: _toggleMode,
                  onForgotPassword: _forgotPassword,
                  onNeedVerificationToken: _navigateToManualVerification,
                  onSsoPressed: () => _startSso(SsoProvider.google),
                ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return _buildWeb(context);
    if (_registrationPending) {
      final c = WandererTheme.of(context);
      return Scaffold(
        backgroundColor: c.ground,
        appBar: AppBar(
          backgroundColor: c.ground,
          elevation: 0,
          leading: BackButton(onPressed: _goBackOrHome),
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _buildRegistrationPendingView(),
          ),
        ),
      );
    }
    return AndroidAuthForm(
      formKey: _formKey,
      isLogin: _isLogin,
      isLoading: _isLoading,
      errorMessage: _errorMessage,
      usernameController: _usernameController,
      emailController: _emailController,
      passwordController: _passwordController,
      onSubmit: _submit,
      onToggleMode: _toggleMode,
      onForgotPassword: _forgotPassword,
      onNeedVerificationToken: _navigateToManualVerification,
      onBack: _goBackOrHome,
      onSsoPressed: () => _startSso(SsoProvider.google),
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
              'Click the link in the email to complete your registration. '
              "It also includes a verification token you can enter manually if the link doesn't work.",
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
            TextButton(
              onPressed: _navigateToManualVerification,
              child: const Text('Enter verification token manually'),
            ),
          ],
        ),
      ),
    );
  }
}
