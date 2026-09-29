import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wanderer_frontend/data/models/auth_models.dart';
import 'package:wanderer_frontend/data/services/sso/sso_service.dart';

void main() {
  group('SsoService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test(
      'buildAuthorizationUri resolves an absolute authBaseUrl with all query params',
      () {
        final service = SsoService(
          authBaseUrl: 'http://localhost:8083/api/1/auth',
          appBaseUrl: 'https://wanderer.example.com',
        );

        final uri = service.buildAuthorizationUri(
          provider: SsoProvider.google,
          returnTo: 'wanderer://auth/sso-callback',
          codeChallenge: 'test-challenge',
        );

        expect(uri.scheme, 'http');
        expect(uri.host, 'localhost');
        expect(uri.port, 8083);
        expect(uri.path, '/api/1/auth/oauth2/authorization/google');
        expect(
          uri.queryParameters['return_to'],
          'wanderer://auth/sso-callback',
        );
        expect(uri.queryParameters['code_challenge'], 'test-challenge');
        expect(uri.queryParameters['code_challenge_method'], 'S256');
        expect(
            uri.toString(), contains('wanderer%3A%2F%2Fauth%2Fsso-callback'));
      },
    );

    test(
      'buildAuthorizationUri resolves a relative authBaseUrl against appBaseUrl',
      () {
        final service = SsoService(
          authBaseUrl: '/api/auth',
          appBaseUrl: 'https://wanderer.example.com/',
        );

        final uri = service.buildAuthorizationUri(
          provider: SsoProvider.google,
          returnTo: 'https://wanderer.example.com/auth/sso-callback',
          codeChallenge: 'abc',
        );

        expect(
          uri.toString(),
          startsWith(
            'https://wanderer.example.com/api/auth/oauth2/authorization/google',
          ),
        );
      },
    );

    test(
        'webReturnUri builds from the serving origin (not appBaseUrl) and '
        'appends the callback path', () {
      final service = SsoService(
        appBaseUrl: 'https://wanderer.example.com/',
        webOrigin: 'https://alias.example.com',
      );

      expect(
        service.webReturnUri(),
        'https://alias.example.com/auth/sso-callback',
      );
    });

    test('savePendingVerifier / takePendingVerifier round-trip and clear',
        () async {
      final service = SsoService();

      await service.savePendingVerifier('verifier-123');
      final result = await service.takePendingVerifier();

      expect(result, 'verifier-123');
      expect(await service.takePendingVerifier(), isNull);
    });

    group('codeFromCallback', () {
      test('returns the code on success', () {
        expect(
          SsoService.codeFromCallback('wanderer://auth/sso-callback?code=abc'),
          'abc',
        );
      });

      test('returns null when the provider reported an error', () {
        expect(
          SsoService.codeFromCallback(
              'wanderer://auth/sso-callback?error=sso_failed'),
          isNull,
        );
      });

      test('returns null when neither code nor error is present', () {
        expect(
          SsoService.codeFromCallback('wanderer://auth/sso-callback'),
          isNull,
        );
      });
    });
  });
}
