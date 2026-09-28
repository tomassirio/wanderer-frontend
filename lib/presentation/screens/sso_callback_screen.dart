import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/providers/app_providers.dart';
import 'package:wanderer_frontend/data/repositories/auth_repository.dart';
import 'package:wanderer_frontend/data/services/sso/sso_service.dart';

enum _CallbackState { loading, failed, sessionExpired }

/// Screen that handles the web SSO callback: `/auth/sso-callback`.
///
/// The SSO provider redirects the browser here with either a `code` (on
/// success) or an `error` (on failure, e.g. cancel, unverified email). On
/// success, the code is exchanged for tokens using the PKCE verifier that
/// was stashed before the handshake started.
class SsoCallbackScreen extends ConsumerStatefulWidget {
  final String? code;
  final String? error;

  const SsoCallbackScreen({super.key, this.code, this.error});

  @override
  ConsumerState<SsoCallbackScreen> createState() => _SsoCallbackScreenState();
}

class _SsoCallbackScreenState extends ConsumerState<SsoCallbackScreen> {
  late final AuthRepository _repository;
  late final SsoService _ssoService;

  late _CallbackState _state;

  @override
  void initState() {
    super.initState();
    _repository = ref.read(authRepositoryProvider);
    _ssoService = ref.read(ssoServiceProvider);

    final code = widget.code;
    if (widget.error != null || code == null) {
      // Provider reported a failure, or the redirect is malformed — nothing
      // to exchange, but still clear the pending verifier so an abandoned
      // or failed flow doesn't leave it behind in storage.
      _state = _CallbackState.failed;
      unawaited(_ssoService.takePendingVerifier());
    } else {
      _state = _CallbackState.loading;
      WidgetsBinding.instance.addPostFrameCallback((_) => _exchange(code));
    }
  }

  Future<void> _exchange(String code) async {
    // Read-and-delete: the verifier is single-use regardless of outcome, so
    // a second callback for the same flow (e.g. a stale/replayed link)
    // always lands on the session-expired state instead of retrying.
    final verifier = await _ssoService.takePendingVerifier();
    if (verifier == null) {
      if (mounted) setState(() => _state = _CallbackState.sessionExpired);
      return;
    }

    try {
      await _repository.completeSsoLogin(code, verifier);
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
      }
    } catch (_) {
      if (mounted) setState(() => _state = _CallbackState.failed);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                    child: _state == _CallbackState.loading
                        ? _buildLoadingView()
                        : _buildErrorView(),
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
        Text(l10n.ssoSigningIn),
      ],
    );
  }

  Widget _buildErrorView() {
    final l10n = context.l10n;
    final message = _state == _CallbackState.sessionExpired
        ? l10n.ssoSessionExpired
        : l10n.ssoFailed;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
        const SizedBox(height: 24),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () =>
                Navigator.of(context).pushReplacementNamed('/auth'),
            child: Text(l10n.backToLogin),
          ),
        ),
      ],
    );
  }
}
