import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wanderer_frontend/core/constants/api_endpoints.dart';
import 'package:wanderer_frontend/core/providers/app_providers.dart';
import 'package:wanderer_frontend/data/storage/token_storage.dart';

void main() {
  group('Base providers', () {
    test('tokenStorageProvider returns a TokenStorage', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(tokenStorageProvider), isA<TokenStorage>());
    });

    test('tokenStorageProvider returns the same instance on repeated reads',
        () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final a = container.read(tokenStorageProvider);
      final b = container.read(tokenStorageProvider);
      expect(identical(a, b), isTrue);
    });

    test('apiClientQueryProvider uses ApiEndpoints.queryBaseUrl', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(apiClientQueryProvider).baseUrl,
          ApiEndpoints.queryBaseUrl);
    });

    test('apiClientCommandProvider uses ApiEndpoints.commandBaseUrl', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(apiClientCommandProvider).baseUrl,
          ApiEndpoints.commandBaseUrl);
    });

    test('apiClientAuthProvider uses ApiEndpoints.authBaseUrl', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(apiClientAuthProvider).baseUrl,
          ApiEndpoints.authBaseUrl);
    });

    test('the 3 ApiClient providers are distinct instances', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final query = container.read(apiClientQueryProvider);
      final command = container.read(apiClientCommandProvider);
      final auth = container.read(apiClientAuthProvider);
      expect(identical(query, command), isFalse);
      expect(identical(query, auth), isFalse);
      expect(identical(command, auth), isFalse);
    });
  });
}
