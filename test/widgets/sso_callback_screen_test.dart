import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:wanderer_frontend/core/providers/app_providers.dart';
import 'package:wanderer_frontend/data/repositories/auth_repository.dart';
import 'package:wanderer_frontend/data/services/sso/sso_service.dart';
import 'package:wanderer_frontend/presentation/screens/sso_callback_screen.dart';

import 'sso_callback_screen_test.mocks.dart';

@GenerateMocks([AuthRepository, SsoService])
void main() {
  late MockAuthRepository mockRepository;
  late MockSsoService mockSsoService;

  setUp(() {
    mockRepository = MockAuthRepository();
    mockSsoService = MockSsoService();
  });

  Widget buildScreen({String? code, String? error}) {
    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(mockRepository),
        ssoServiceProvider.overrideWithValue(mockSsoService),
      ],
      child: MaterialApp(
        initialRoute: '/callback',
        routes: {
          '/callback': (context) => SsoCallbackScreen(code: code, error: error),
          '/': (context) => const Scaffold(body: Center(child: Text('Home'))),
          '/auth': (context) =>
              const Scaffold(body: Center(child: Text('Auth'))),
        },
      ),
    );
  }

  testWidgets(
    'shows error state, never exchanges, but clears the pending verifier '
    'when error param is present',
    (tester) async {
      when(mockSsoService.takePendingVerifier()).thenAnswer((_) async => null);

      await tester.pumpWidget(buildScreen(error: 'sso_failed'));
      await tester.pumpAndSettle();

      expect(
        find.text("We couldn't sign you in with Google. Please try again."),
        findsOneWidget,
      );
      verify(mockSsoService.takePendingVerifier()).called(1);
      verifyNever(mockRepository.completeSsoLogin(any, any));
    },
  );

  testWidgets(
    'shows error state, never exchanges, but clears the pending verifier '
    'when code is missing',
    (tester) async {
      when(mockSsoService.takePendingVerifier()).thenAnswer((_) async => null);

      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      expect(
        find.text("We couldn't sign you in with Google. Please try again."),
        findsOneWidget,
      );
      verify(mockSsoService.takePendingVerifier()).called(1);
      verifyNever(mockRepository.completeSsoLogin(any, any));
    },
  );

  testWidgets(
    'shows session-expired state when pending verifier is missing',
    (tester) async {
      when(mockSsoService.takePendingVerifier()).thenAnswer((_) async => null);

      await tester.pumpWidget(buildScreen(code: 'abc123'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Your sign-in link expired or was opened in a different '
          'browser. Please try again.',
        ),
        findsOneWidget,
      );
      verifyNever(mockRepository.completeSsoLogin(any, any));
    },
  );

  testWidgets(
    'exchanges code and verifier then navigates home on success',
    (tester) async {
      when(mockSsoService.takePendingVerifier())
          .thenAnswer((_) async => 'verifier-xyz');
      when(mockRepository.completeSsoLogin('abc123', 'verifier-xyz'))
          .thenAnswer((_) async {});

      await tester.pumpWidget(buildScreen(code: 'abc123'));
      await tester.pumpAndSettle();

      verify(mockRepository.completeSsoLogin('abc123', 'verifier-xyz'))
          .called(1);
      expect(find.text('Home'), findsOneWidget);
    },
  );

  testWidgets(
    'shows error state when the exchange fails',
    (tester) async {
      when(mockSsoService.takePendingVerifier())
          .thenAnswer((_) async => 'verifier-xyz');
      when(mockRepository.completeSsoLogin('abc123', 'verifier-xyz'))
          .thenThrow(Exception('Exchange failed'));

      await tester.pumpWidget(buildScreen(code: 'abc123'));
      await tester.pumpAndSettle();

      expect(
        find.text("We couldn't sign you in with Google. Please try again."),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'back to login button navigates to /auth',
    (tester) async {
      when(mockSsoService.takePendingVerifier()).thenAnswer((_) async => null);

      await tester.pumpWidget(buildScreen(error: 'sso_failed'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Back to Login'));
      await tester.pumpAndSettle();

      expect(find.text('Auth'), findsOneWidget);
    },
  );
}
