import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wanderer_frontend/presentation/screens/android/android_welcome_screen.dart';
import 'package:wanderer_frontend/presentation/screens/auth_screen.dart';

void main() {
  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: AndroidWelcomeScreen())));
    await tester.pumpAndSettle();
  }

  testWidgets('Create free account opens sign-up', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Create free account'));
    await tester.pumpAndSettle();
    expect(find.byType(AuthScreen), findsOneWidget);
    expect(find.text('Create your account'), findsOneWidget);
  });

  testWidgets('I already have an account opens sign-in', (tester) async {
    await pump(tester);
    await tester.tap(find.text('I already have an account'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
  });
}
