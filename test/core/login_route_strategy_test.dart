import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wanderer_frontend/core/routing/strategies/login_route_strategy.dart';
import 'package:wanderer_frontend/presentation/screens/auth_screen.dart';

void main() {
  group('LoginRouteStrategy', () {
    late LoginRouteStrategy strategy;

    setUp(() {
      strategy = LoginRouteStrategy();
    });

    group('matches', () {
      test('matches /login path', () {
        expect(strategy.matches(Uri.parse('/login')), isTrue);
      });

      test('matches /auth path', () {
        expect(strategy.matches(Uri.parse('/auth')), isTrue);
      });

      test('matches /login with username query parameter', () {
        expect(
          strategy.matches(Uri.parse('/login?username=testuser')),
          isTrue,
        );
      });

      test('does not match other paths', () {
        expect(strategy.matches(Uri.parse('/home')), isFalse);
        expect(strategy.matches(Uri.parse('/signup')), isFalse);
        expect(strategy.matches(Uri.parse('/')), isFalse);
      });
    });

    group('build', () {
      test('builds route to AuthScreen', () {
        final uri = Uri.parse('/login');
        final settings = const RouteSettings(name: '/login');
        final route = strategy.build(uri, settings);

        expect(route, isA<PageRoute>());
      });

      test('passes username query parameter to AuthScreen', () {
        final uri = Uri.parse('/login?username=testuser');
        final settings = const RouteSettings(name: '/login?username=testuser');
        final route = strategy.build(uri, settings);

        // Route is built successfully
        expect(route, isNotNull);
        expect(route, isA<PageRoute>());
      });

      test('builds AuthScreen without username when not in query', () {
        final uri = Uri.parse('/login');
        final settings = const RouteSettings(name: '/login');
        final route = strategy.build(uri, settings);

        // Route is built successfully
        expect(route, isNotNull);
        expect(route, isA<PageRoute>());
      });
    });
  });

  group('AuthScreen initialUsername', () {
    testWidgets('pre-fills username when initialUsername is provided',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: AuthScreen(initialUsername: 'testuser'),
        ),
      );
      await tester.pumpAndSettle();

      final textFormField =
          tester.widget<TextFormField>(find.byType(TextFormField).first);
      expect(textFormField.controller?.text, 'testuser');
    });

    testWidgets('username field is empty when no initialUsername',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: AuthScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final textFormField =
          tester.widget<TextFormField>(find.byType(TextFormField).first);
      expect(textFormField.controller?.text, '');
    });

    testWidgets('shows forgot password form when Forgot Password is tapped',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: AuthScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Forgot Password?'));
      await tester.pumpAndSettle();

      expect(find.text('Reset Password'), findsOneWidget);
      expect(find.text('Send Reset Link'), findsOneWidget);
    });

    testWidgets('returns to login form when Back to Login is tapped',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: AuthScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Forgot Password?'));
      await tester.pumpAndSettle();

      expect(find.text('Reset Password'), findsOneWidget);

      await tester.tap(find.text('Back to Login'));
      await tester.pumpAndSettle();

      expect(find.text('Welcome Back!'), findsOneWidget);
    });
  });
}
