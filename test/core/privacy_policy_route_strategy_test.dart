import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wanderer_frontend/core/routing/strategies/privacy_policy_route_strategy.dart';

void main() {
  group('PrivacyPolicyRouteStrategy', () {
    late PrivacyPolicyRouteStrategy strategy;

    setUp(() {
      strategy = PrivacyPolicyRouteStrategy();
    });

    group('matches', () {
      test('matches /privacy-policy path', () {
        expect(strategy.matches(Uri.parse('/privacy-policy')), isTrue);
      });

      test('does not match other paths', () {
        expect(strategy.matches(Uri.parse('/home')), isFalse);
        expect(strategy.matches(Uri.parse('/login')), isFalse);
        expect(strategy.matches(Uri.parse('/privacy')), isFalse);
        expect(strategy.matches(Uri.parse('/policy')), isFalse);
        expect(strategy.matches(Uri.parse('/')), isFalse);
      });
    });

    group('build', () {
      test('builds route as PageRouteBuilder', () {
        final uri = Uri.parse('/privacy-policy');
        final settings = const RouteSettings(name: '/privacy-policy');
        final route = strategy.build(uri, settings);

        expect(route, isA<PageRouteBuilder>());
      });

      test('returns a valid PageRoute', () {
        final uri = Uri.parse('/privacy-policy');
        final settings = const RouteSettings(name: '/privacy-policy');
        final route = strategy.build(uri, settings);

        expect(route, isA<PageRoute>());
      });
    });
  });
}
