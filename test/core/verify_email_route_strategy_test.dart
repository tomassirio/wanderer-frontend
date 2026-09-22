// wanderer-frontend/test/core/verify_email_route_strategy_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wanderer_frontend/core/routing/strategies/verify_email_route_strategy.dart';
import 'package:wanderer_frontend/presentation/screens/verify_email_screen.dart';

void main() {
  group('VerifyEmailRouteStrategy', () {
    late VerifyEmailRouteStrategy strategy;

    setUp(() {
      strategy = VerifyEmailRouteStrategy();
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
            child: MaterialApp(onGenerateRoute: (_) => route),
          ),
        );
        await tester.pump();

        final screen = tester.widget<VerifyEmailScreen>(
          find.byType(VerifyEmailScreen),
        );
        expect(screen.initialToken, 'abc123');
      });

      testWidgets('builds VerifyEmailScreen without token when absent',
          (tester) async {
        final uri = Uri.parse('/verify-email');
        final settings = const RouteSettings(name: '/verify-email');
        final route = strategy.build(uri, settings);

        await tester.pumpWidget(
          ProviderScope(
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
