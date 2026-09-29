import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:wanderer_frontend/core/providers/app_providers.dart';
import 'package:wanderer_frontend/core/routing/strategies/sso_callback_route_strategy.dart';
import 'package:wanderer_frontend/data/repositories/auth_repository.dart';
import 'package:wanderer_frontend/data/services/sso/sso_service.dart';
import 'package:wanderer_frontend/presentation/screens/sso_callback_screen.dart';

import 'sso_callback_route_strategy_test.mocks.dart';

@GenerateMocks([AuthRepository, SsoService])
void main() {
  group('SsoCallbackRouteStrategy', () {
    late SsoCallbackRouteStrategy strategy;
    late MockAuthRepository mockRepository;
    late MockSsoService mockSsoService;

    setUp(() {
      strategy = SsoCallbackRouteStrategy();
      mockRepository = MockAuthRepository();
      mockSsoService = MockSsoService();
      when(mockSsoService.takePendingVerifier()).thenAnswer((_) async => null);
    });

    group('matches', () {
      test('matches /auth/sso-callback path', () {
        expect(strategy.matches(Uri.parse('/auth/sso-callback')), isTrue);
      });

      test('matches /auth/sso-callback with query parameters', () {
        expect(
          strategy.matches(Uri.parse('/auth/sso-callback?code=abc123')),
          isTrue,
        );
      });

      test('does not match other paths', () {
        expect(strategy.matches(Uri.parse('/auth')), isFalse);
        expect(strategy.matches(Uri.parse('/login')), isFalse);
      });
    });

    group('build', () {
      testWidgets('passes code query parameter to SsoCallbackScreen',
          (tester) async {
        final uri = Uri.parse('/auth/sso-callback?code=abc123');
        final settings =
            const RouteSettings(name: '/auth/sso-callback?code=abc123');
        final route = strategy.build(uri, settings);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authRepositoryProvider.overrideWithValue(mockRepository),
              ssoServiceProvider.overrideWithValue(mockSsoService),
            ],
            child: MaterialApp(onGenerateRoute: (_) => route),
          ),
        );
        await tester.pump();

        final screen = tester.widget<SsoCallbackScreen>(
          find.byType(SsoCallbackScreen),
        );
        expect(screen.code, 'abc123');
        expect(screen.error, isNull);
      });

      testWidgets('passes error query parameter to SsoCallbackScreen',
          (tester) async {
        final uri = Uri.parse('/auth/sso-callback?error=sso_failed');
        final settings =
            const RouteSettings(name: '/auth/sso-callback?error=sso_failed');
        final route = strategy.build(uri, settings);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authRepositoryProvider.overrideWithValue(mockRepository),
              ssoServiceProvider.overrideWithValue(mockSsoService),
            ],
            child: MaterialApp(onGenerateRoute: (_) => route),
          ),
        );
        await tester.pump();

        final screen = tester.widget<SsoCallbackScreen>(
          find.byType(SsoCallbackScreen),
        );
        expect(screen.code, isNull);
        expect(screen.error, 'sso_failed');
      });
    });
  });
}
