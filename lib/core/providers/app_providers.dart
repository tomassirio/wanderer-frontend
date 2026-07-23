import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/api_endpoints.dart';
import '../../data/client/api_client.dart';
import '../../data/storage/token_storage.dart';

// ---------------------------------------------------------------------------
// Base infrastructure
// ---------------------------------------------------------------------------

/// Shared token storage, injected into every ApiClient below so all of them
/// read/write the same underlying SharedPreferences-backed tokens.
final tokenStorageProvider = Provider<TokenStorage>((ref) {
  return TokenStorage();
});

/// ApiClient for read (query) endpoints — port 8082 by default.
final apiClientQueryProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    baseUrl: ApiEndpoints.queryBaseUrl,
    tokenStorage: ref.watch(tokenStorageProvider),
  );
});

/// ApiClient for write (command) endpoints — port 8081 by default.
final apiClientCommandProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    baseUrl: ApiEndpoints.commandBaseUrl,
    tokenStorage: ref.watch(tokenStorageProvider),
  );
});

/// ApiClient for auth endpoints — port 8083 by default.
final apiClientAuthProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    baseUrl: ApiEndpoints.authBaseUrl,
    tokenStorage: ref.watch(tokenStorageProvider),
  );
});
