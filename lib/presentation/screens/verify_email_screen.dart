import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/data/repositories/auth_repository.dart';

/// Screen that handles the email verification flow.
///
/// On web: automatically extracts the `token` query parameter from the URL
/// and calls the verify-email endpoint.
///
/// On mobile: displays a text field so the user can paste the token manually.
class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final AuthRepository _repository = AuthRepository();
  final _tokenController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  bool _verified = false;

  @override
  void initState() {
    super.initState();
    // On web, read the token from the URL query string automatically
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _tryVerifyFromUrl();
      });
    }
  }

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  /// Extracts the token from the current web URL and verifies it.
  void _tryVerifyFromUrl() {
    final uri = Uri.base;
    final token = uri.queryParameters['token'];
    if (token != null && token.isNotEmpty) {
      _verifyToken(token);
    }
  }

  Future<void> _verifyToken(String token) async {
    if (token.isEmpty) {
      setState(() => _errorMessage = 'Please enter a verification token.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _repository.verifyEmail(token);

      if (mounted) {
        setState(() {
          _verified = true;
          _isLoading = false;
        });

        // Navigate to home after a short delay so the user sees the success message
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
        }
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
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 450),
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: _verified
                        ? _buildSuccessView()
                        : _isLoading
                            ? _buildLoadingView()
                            : _buildVerifyView(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingView() {
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 24),
        Text(l10n.verifyingEmail),
      ],
    );
  }

  Widget _buildSuccessView() {
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
        const SizedBox(height: 24),
        Text(
          l10n.emailVerified,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Text(
          l10n.accountNowActive,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildVerifyView() {
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.verified_user_outlined,
          size: 64,
          color: Colors.blueAccent,
        ),
        const SizedBox(height: 24),
        Text(
          l10n.verifyYourEmail,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Text(
          l10n.enterVerificationToken,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        if (_errorMessage != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.red.shade700),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        TextField(
          controller: _tokenController,
          decoration: InputDecoration(
            labelText: l10n.verificationToken,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.vpn_key_outlined),
          ),
          onSubmitted: (_) => _verifyToken(_tokenController.text.trim()),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => _verifyToken(_tokenController.text.trim()),
            child: Text(l10n.verifyEmail),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => Navigator.of(context).pushReplacementNamed('/auth'),
          child: Text(l10n.backToLogin),
        ),
      ],
    );
  }
}
