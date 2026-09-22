import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:wanderer_frontend/core/providers/app_providers.dart';
import 'package:wanderer_frontend/data/repositories/auth_repository.dart';
import 'package:wanderer_frontend/presentation/screens/verify_email_screen.dart';

import 'verify_email_screen_test.mocks.dart';

@GenerateMocks([AuthRepository])
void main() {
  late MockAuthRepository mockRepository;

  setUp(() {
    mockRepository = MockAuthRepository();
  });

  Widget buildScreen({String? initialToken}) {
    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(mockRepository),
      ],
      child: MaterialApp(
        initialRoute: '/verify',
        routes: {
          '/verify': (context) => VerifyEmailScreen(initialToken: initialToken),
          '/': (context) => const Scaffold(body: Center(child: Text('Home'))),
        },
      ),
    );
  }

  testWidgets(
    'auto-verifies with initialToken without requiring kIsWeb',
    (tester) async {
      when(mockRepository.verifyEmail('token-abc')).thenAnswer((_) async {});

      await tester.pumpWidget(buildScreen(initialToken: 'token-abc'));
      // Let the postFrameCallback execute
      await tester.pump();

      // Verify it was called once at this point
      verify(mockRepository.verifyEmail('token-abc')).called(1);

      // Check that the success widget is showing
      expect(find.text('Email verified!'), findsOneWidget);

      // Pump to allow the 2-second navigation delay to complete
      await tester.pump(const Duration(seconds: 3));
    },
  );

  testWidgets(
    'shows manual entry form when no initialToken is provided',
    (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      verifyNever(mockRepository.verifyEmail(any));
      expect(find.byType(TextField), findsOneWidget);
    },
  );
}
