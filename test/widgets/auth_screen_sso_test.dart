import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:wanderer_frontend/core/providers/app_providers.dart';
import 'package:wanderer_frontend/data/services/sso/pkce.dart';
import 'package:wanderer_frontend/presentation/screens/auth_screen.dart';
import 'package:wanderer_frontend/presentation/screens/initial_screen.dart';

// Reuses the generated MockAuthRepository (already includes completeSsoLogin).
import 'auth_screen_registration_pending_test.mocks.dart';

void main() {
  late MockAuthRepository repository;

  setUp(() => repository = MockAuthRepository());

  /// Pushes AuthScreen on top of a home route so `pop(true)` is observable.
  Future<List<Object?>> pumpScreen(
    WidgetTester tester,
    Future<String> Function(Uri url) authenticate,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final results = <Object?>[];
    await tester.pumpWidget(ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              results.add(await Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => AuthScreen(ssoAuthenticate: authenticate),
              )));
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return results;
  }

  Future<void> tapGoogle(WidgetTester tester) async {
    final button = find.text('Continue with Google');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets('exchanges the code with the in-memory verifier and lands home',
      (tester) async {
    Uri? launched;
    when(repository.completeSsoLogin(any, any)).thenAnswer((_) async {});

    final results = await pumpScreen(tester, (url) async {
      launched = url;
      return 'wanderer://auth/sso-callback?code=the-code';
    });
    await tapGoogle(tester);

    expect(
        launched!.queryParameters['return_to'], 'wanderer://auth/sso-callback');
    final challenge = launched!.queryParameters['code_challenge']!;
    final verifier = verify(repository.completeSsoLogin('the-code', captureAny))
        .captured
        .single as String;
    expect(PkcePair.challengeFor(verifier), challenge);
    // Android: a successful login replaces the stack with InitialScreen
    // (the shell), like a password login, instead of popping back.
    expect(results, isNot(contains(true)));
    expect(find.byType(AuthScreen), findsNothing);
    expect(find.byType(InitialScreen), findsOneWidget);
  });

  testWidgets('shows ssoFailed when the callback carries an error',
      (tester) async {
    await pumpScreen(
      tester,
      (_) async => 'wanderer://auth/sso-callback?error=sso_failed',
    );
    await tapGoogle(tester);

    expect(find.text("We couldn't sign you in with Google. Please try again."),
        findsOneWidget);
    verifyNever(repository.completeSsoLogin(any, any));
  });

  testWidgets('shows ssoFailed when the exchange fails', (tester) async {
    when(repository.completeSsoLogin(any, any))
        .thenThrow(Exception('400 invalid code'));
    await pumpScreen(
      tester,
      (_) async => 'wanderer://auth/sso-callback?code=the-code',
    );
    await tapGoogle(tester);

    expect(find.text("We couldn't sign you in with Google. Please try again."),
        findsOneWidget);
  });

  testWidgets('a second tap while a login is in flight is ignored',
      (tester) async {
    when(repository.completeSsoLogin(any, any)).thenAnswer((_) async {});
    final completer = Completer<String>();
    var authenticateCalls = 0;

    await pumpScreen(tester, (url) {
      authenticateCalls++;
      return completer.future;
    });

    final button = find.text('Continue with Google');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
    await tester.tap(button);
    await tester.pump();

    expect(authenticateCalls, 1);

    completer.complete('wanderer://auth/sso-callback?code=the-code');
    await tester.pumpAndSettle();

    verify(repository.completeSsoLogin(any, any)).called(1);
  });

  testWidgets('user cancel stops loading silently', (tester) async {
    await pumpScreen(
      tester,
      (_) async => throw PlatformException(code: 'CANCELED'),
    );
    await tapGoogle(tester);

    expect(find.text("We couldn't sign you in with Google. Please try again."),
        findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    final google = tester.widget<OutlinedButton>(find.ancestor(
        of: find.text('Continue with Google'),
        matching: find.byType(OutlinedButton)));
    expect(google.onPressed, isNotNull);
  });
}
