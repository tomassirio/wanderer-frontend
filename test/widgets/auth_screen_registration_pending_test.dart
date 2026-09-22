import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:wanderer_frontend/core/providers/app_providers.dart';
import 'package:wanderer_frontend/data/models/auth_models.dart';
import 'package:wanderer_frontend/data/repositories/auth_repository.dart';
import 'package:wanderer_frontend/presentation/screens/auth_screen.dart';
import 'package:wanderer_frontend/presentation/screens/verify_email_screen.dart';

import 'auth_screen_registration_pending_test.mocks.dart';

@GenerateMocks([AuthRepository])
void main() {
  late MockAuthRepository mockRepository;

  setUp(() {
    mockRepository = MockAuthRepository();
  });

  Future<void> fillAndSubmitRegistrationForm(WidgetTester tester) async {
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'newuser'); // username
    await tester.enterText(fields.at(1), 'newuser@example.com'); // email
    await tester.enterText(fields.at(2), 'Password1!'); // password
    await tester.enterText(fields.at(3), 'Password1!'); // confirm password
    await tester.tap(find.text('Sign Up'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'shows a manual verification entry point after registering, '
    'which navigates to VerifyEmailScreen',
    (tester) async {
      when(mockRepository.register(
              'newuser', 'newuser@example.com', 'Password1!'))
          .thenAnswer((_) async => RegisterPendingResponse(
                message: 'Registration pending.',
              ));

      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(mockRepository),
          ],
          child: const MaterialApp(
            home: AuthScreen(startInSignup: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await fillAndSubmitRegistrationForm(tester);

      expect(find.text('Enter verification token manually'), findsOneWidget);

      await tester.tap(find.text('Enter verification token manually'));
      await tester.pumpAndSettle();

      expect(find.byType(VerifyEmailScreen), findsOneWidget);
    },
  );
}
