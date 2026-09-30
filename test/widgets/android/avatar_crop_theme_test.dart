import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/presentation/screens/android/android_avatar_crop_screen.dart';

// 1×1 transparent PNG.
final _png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=');

void main() {
  for (final dark in [false, true]) {
    testWidgets('adjust photo follows the ${dark ? 'dark' : 'light'} theme',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: dark ? WandererTheme.darkTheme() : WandererTheme.lightTheme(),
        home: AndroidAvatarCropScreen(initial: XFile.fromData(_png)),
      ));
      final colors = dark ? WandererColors.dark : WandererColors.light;
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, colors.ground);

      // "Choose another" text must not sit on a same-coloured fill.
      final button = tester.widget<OutlinedButton>(find.ancestor(
          of: find.text('Choose another'),
          matching: find.byType(OutlinedButton)));
      final bg = button.style?.backgroundColor?.resolve({});
      expect(bg, Colors.transparent);
      expect(button.style?.foregroundColor?.resolve({}), colors.text);
    });
  }
}
