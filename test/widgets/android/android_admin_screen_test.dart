import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/presentation/screens/android/android_admin_screen.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets('admin tools lay out on a phone (dark: $dark)', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.6;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var tapped = false;
      await tester.pumpWidget(ProviderScope(
          child: MaterialApp(
        theme: dark ? WandererTheme.darkTheme() : WandererTheme.lightTheme(),
        home: Scaffold(
          body: Column(children: [
            AdminToolsButton(onTap: () => tapped = true),
            const Expanded(child: AndroidAdminScreen()),
          ]),
        ),
      )));
      expect(find.text('Release notes'), findsOneWidget);
      expect(find.text('Only admins see this. Changes here affect every user.'),
          findsOneWidget);
      expect(find.text('Trips Management'), findsOneWidget);
      expect(find.text('User Management'), findsOneWidget);
      expect(find.text('Trip Data Maintenance'), findsOneWidget);
      await tester.tap(find.text('Admin tools').first);
      expect(tapped, isTrue);
    });
  }
}
