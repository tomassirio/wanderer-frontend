import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:wanderer_frontend/presentation/widgets/profile/profile_avatar_image.dart';

/// A valid, decodable 1x1 transparent PNG (avoids async image-decode errors
/// that a widget test would otherwise surface for garbage bytes).
final _onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
);

void main() {
  group('ProfileAvatarImage Widget', () {
    testWidgets('shows initials fallback when there is no avatar URL',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProfileAvatarImage(
              optimisticAvatarBytes: null,
              avatarUrl: '',
              initials: 'JD',
              radius: 40,
            ),
          ),
        ),
      );

      expect(find.text('JD'), findsOneWidget);
      expect(find.byType(CachedNetworkImage), findsNothing);
    });

    testWidgets('shows a CachedNetworkImage when an avatar URL is provided',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProfileAvatarImage(
              optimisticAvatarBytes: null,
              avatarUrl: 'https://example.com/avatar.png',
              initials: 'JD',
              radius: 40,
            ),
          ),
        ),
      );

      expect(find.byType(CachedNetworkImage), findsOneWidget);
    });

    testWidgets(
        'shows the optimistic avatar bytes instead of the network image when present',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfileAvatarImage(
              optimisticAvatarBytes: _onePixelPng,
              avatarUrl: 'https://example.com/avatar.png',
              initials: 'JD',
              radius: 40,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('optimistic-avatar')), findsOneWidget);
      expect(find.byType(CachedNetworkImage), findsNothing);
    });
  });
}
