import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../models/auth_models.dart';

/// Builds SSO authorization URLs and persists the PKCE verifier while the
/// browser/system redirects away for the provider's login flow.
class SsoService {
  static const String _pendingVerifierKey = 'sso_pending_code_verifier';

  final String _authBaseUrl;
  final String _appBaseUrl;
  final String? _webOrigin;

  SsoService({String? authBaseUrl, String? appBaseUrl, String? webOrigin})
      : _authBaseUrl = authBaseUrl ?? ApiEndpoints.authBaseUrl,
        _appBaseUrl = appBaseUrl ?? ApiEndpoints.appBaseUrl,
        _webOrigin = webOrigin;

  String get _trimmedAppBaseUrl {
    var url = _appBaseUrl;
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  /// Builds the browser-navigation URL that starts the SSO handshake.
  Uri buildAuthorizationUri({
    required SsoProvider provider,
    required String returnTo,
    required String codeChallenge,
  }) {
    final path = ApiEndpoints.ssoAuthorizationPath(provider.id);
    final base = _authBaseUrl.startsWith('/')
        ? '$_trimmedAppBaseUrl$_authBaseUrl'
        : _authBaseUrl;

    return Uri.parse('$base$path').replace(queryParameters: {
      'return_to': returnTo,
      'code_challenge': codeChallenge,
      'code_challenge_method': 'S256',
    });
  }

  /// The `return_to` value used on web, where the callback is handled by
  /// an in-app route rather than a custom URL scheme.
  ///
  /// Built from the origin actually serving the page (`Uri.base.origin`),
  /// not the configured `appBaseUrl`, so the PKCE verifier — stored
  /// per-origin in localStorage — and the callback always land on the same
  /// origin, even when the site is reachable under an alias/alternate host.
  String webReturnUri() =>
      '${_webOrigin ?? Uri.base.origin}${ApiEndpoints.ssoWebCallbackPath}';

  /// Extracts the authorization `code` from an SSO callback URL, or `null`
  /// when the provider reported an `error` or the URL carries neither.
  static String? codeFromCallback(String callbackUrl) {
    final params = Uri.parse(callbackUrl).queryParameters;
    return params.containsKey('error') ? null : params['code'];
  }

  /// Persists the PKCE verifier for the pending SSO login until the
  /// callback completes.
  Future<void> savePendingVerifier(String verifier) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingVerifierKey, verifier);
  }

  /// Reads and clears the pending PKCE verifier, if any.
  Future<String?> takePendingVerifier() async {
    final prefs = await SharedPreferences.getInstance();
    final verifier = prefs.getString(_pendingVerifierKey);
    if (verifier != null) {
      await prefs.remove(_pendingVerifierKey);
    }
    return verifier;
  }
}
