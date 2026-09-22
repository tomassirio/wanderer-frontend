import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wanderer_frontend/presentation/widgets/auth/auth_form.dart';

void main() {
  Widget buildForm({required bool isLogin, required VoidCallback onNeedCode}) {
    return MaterialApp(
      home: Scaffold(
        body: AuthForm(
          formKey: GlobalKey<FormState>(),
          isLogin: isLogin,
          isLoading: false,
          usernameController: TextEditingController(),
          emailController: TextEditingController(),
          passwordController: TextEditingController(),
          confirmPasswordController: TextEditingController(),
          onSubmit: () {},
          onToggleMode: () {},
          onForgotPassword: () {},
          onNeedVerificationToken: onNeedCode,
        ),
      ),
    );
  }

  testWidgets('shows "Have a verification token?" in login mode and taps through',
      (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      buildForm(isLogin: true, onNeedCode: () => tapped = true),
    );
    await tester.pumpAndSettle();

    expect(find.text('Have a verification token?'), findsOneWidget);

    await tester.tap(find.text('Have a verification token?'));
    await tester.pump();

    expect(tapped, isTrue);
  });

  testWidgets('does not show the link in signup mode', (tester) async {
    // Signup mode renders more fields than fit the default test surface;
    // match the viewport size already used by other AuthForm/AuthScreen
    // signup-mode tests (see auth_screen_registration_pending_test.dart)
    // to avoid an unrelated layout overflow.
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      buildForm(isLogin: false, onNeedCode: () {}),
    );
    await tester.pumpAndSettle();

    expect(find.text('Have a verification token?'), findsNothing);
  });
}
