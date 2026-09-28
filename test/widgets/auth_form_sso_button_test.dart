import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wanderer_frontend/presentation/widgets/auth/auth_form.dart';
import 'package:wanderer_frontend/presentation/widgets/auth/google_logo.dart';
import 'package:wanderer_frontend/presentation/widgets/auth/web_auth_layout.dart';

void main() {
  Widget buildMobile({required bool isLogin, required VoidCallback onSso}) {
    return AuthForm(
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
      onNeedVerificationToken: () {},
      onSsoPressed: onSso,
    );
  }

  Widget buildWeb({required bool isLogin, required VoidCallback onSso}) {
    return WebAuthForm(
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
      onNeedVerificationToken: () {},
      onSsoPressed: onSso,
    );
  }

  final cases = {
    'AuthForm': buildMobile,
    'WebAuthForm': buildWeb,
  };

  for (final MapEntry(key: name, value: build) in cases.entries) {
    for (final isLogin in [true, false]) {
      testWidgets(
          '$name shows Continue with Google in '
          '${isLogin ? 'login' : 'signup'} mode and invokes the callback',
          (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        var tapped = 0;
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: build(isLogin: isLogin, onSso: () => tapped++),
            ),
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('or'), findsOneWidget);
        final button = find.text('Continue with Google');
        expect(button, findsOneWidget);
        expect(find.byType(GoogleLogo), findsOneWidget);

        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pump();

        expect(tapped, 1);
      });
    }
  }
}
