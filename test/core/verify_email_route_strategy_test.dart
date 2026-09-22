import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:wanderer_frontend/core/providers/app_providers.dart';
import 'package:wanderer_frontend/core/routing/strategies/verify_email_route_strategy.dart';
import 'package:wanderer_frontend/data/repositories/auth_repository.dart';
import 'package:wanderer_frontend/presentation/screens/verify_email_screen.dart';

import 'verify_email_route_strategy_test.mocks.dart';

@GenerateMocks([AuthRepository])
void main() {
  group('VerifyEmailRouteStrategy', () {
    late VerifyEmailRouteStrategy strategy;
    late MockAuthRepository mockRepository;

    setUp(() {
      strategy = VerifyEmailRouteStrategy();
      mockRepository = MockAuthRepository();
      when(mockRepository.verifyEmail(any)).thenAnswer((_) async {});
    });

    group('matches', () {
      test('matches /verify-email path', () {
        expect(strategy.matches(Uri.parse('/verify-email')), isTrue);
      });

      test('matches /verify-email with token query parameter', () {
        expect(
          strategy.matches(Uri.parse('/verify-email?token=abc123')),
          isTrue,
        );
      });

      test('does not match other paths', () {
        expect(strategy.matches(Uri.parse('/login')), isFalse);
      });
    });

    group('build', () {
      testWidgets('passes token query parameter to VerifyEmailScreen',
          (tester) async {
        final uri = Uri.parse('/verify-email?token=abc123');
        final settings =
            const RouteSettings(name: '/verify-email?token=abc123');
        final route = strategy.build(uri, settings);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authRepositoryProvider.overrideWithValue(mockRepository),
            ],
            child: MaterialApp(onGenerateRoute: (_) => route),
          ),
        );
        await tester.pump();

        final screen = tester.widget<VerifyEmailScreen>(
          find.byType(VerifyEmailScreen),
        );
        expect(screen.initialToken, 'abc123');

        // Drain the 2s post-verification navigation timer VerifyEmailScreen
        // schedules on successful verification, so the pending-timer check
        // in tearDown doesn't fail.
        await tester.pump(const Duration(seconds: 3));
      });

      testWidgets('builds VerifyEmailScreen without token when absent',
          (tester) async {
        final uri = Uri.parse('/verify-email');
        final settings = const RouteSettings(name: '/verify-email');
        final route = strategy.build(uri, settings);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authRepositoryProvider.overrideWithValue(mockRepository),
            ],
            child: MaterialApp(onGenerateRoute: (_) => route),
          ),
        );
        await tester.pump();

        final screen = tester.widget<VerifyEmailScreen>(
          find.byType(VerifyEmailScreen),
        );
        expect(screen.initialToken, isNull);
      });
    });
  });
}
