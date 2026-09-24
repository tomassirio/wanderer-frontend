import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wanderer_frontend/data/storage/token_refresh_manager.dart';
import 'package:wanderer_frontend/data/storage/token_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TokenStorage storage;
  late int expiredCalls;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = TokenStorage();
    await storage.saveTokens(
      accessToken: 'stale-access',
      refreshToken: 'stale-refresh',
      tokenType: 'Bearer',
      expiresIn: 900,
      userId: 'u1',
      username: 'tomas',
    );
    expiredCalls = 0;
    TokenRefreshManager.onSessionExpired = () => expiredCalls++;
  });

  tearDown(() => TokenRefreshManager.onSessionExpired = null);

  Future<bool> refreshWith(int status) =>
      TokenRefreshManager.instance.refreshIfNeeded(
        tokenStorage: storage,
        httpClient: MockClient((_) async => http.Response('nope', status)),
      );

  for (final status in [400, 401, 403]) {
    test('$status clears the whole session and signals expiry', () async {
      expect(await refreshWith(status), isFalse);
      expect(await storage.isLoggedIn(), isFalse);
      expect(await storage.getUsername(), isNull);
      expect(expiredCalls, 1);
    });
  }

  for (final status in [409, 500, 503]) {
    test('$status is transient and keeps the session', () async {
      expect(await refreshWith(status), isFalse);
      expect(await storage.isLoggedIn(), isTrue);
      expect(expiredCalls, 0);
    });
  }

  test('rejection after another tab rotated the token keeps the new one',
      () async {
    final result = await TokenRefreshManager.instance.refreshIfNeeded(
      tokenStorage: storage,
      httpClient: MockClient((_) async {
        // Simulates a concurrent refresh landing first.
        await storage.saveTokens(
          accessToken: 'fresh-access',
          refreshToken: 'fresh-refresh',
          tokenType: 'Bearer',
          expiresIn: 900,
        );
        return http.Response('Refresh token has been revoked', 400);
      }),
    );

    expect(result, isTrue);
    expect(await storage.getAccessToken(), 'fresh-access');
    expect(expiredCalls, 0);
  });
}
