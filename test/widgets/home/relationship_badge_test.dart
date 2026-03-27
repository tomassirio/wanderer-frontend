import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wanderer_frontend/presentation/widgets/home/relationship_badge.dart';

void main() {
  group('RelationshipBadge Widget', () {
    testWidgets('displays friend badge correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RelationshipBadge(
              type: RelationshipType.friend,
            ),
          ),
        ),
      );

      expect(find.byType(RelationshipBadge), findsOneWidget);
      expect(find.text('Friend'), findsOneWidget);
      expect(find.byIcon(Icons.people), findsOneWidget);
    });

    testWidgets('displays following badge correctly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RelationshipBadge(
              type: RelationshipType.following,
            ),
          ),
        ),
      );

      expect(find.byType(RelationshipBadge), findsOneWidget);
      expect(find.text('Following'), findsOneWidget);
      expect(find.byIcon(Icons.person_add_alt_1), findsOneWidget);
    });

    testWidgets('displays follower badge correctly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RelationshipBadge(
              type: RelationshipType.follower,
            ),
          ),
        ),
      );

      expect(find.byType(RelationshipBadge), findsOneWidget);
      expect(find.text('Follower'), findsOneWidget);
      expect(find.byIcon(Icons.person_add), findsOneWidget);
    });

    testWidgets('displays compact badge without text',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RelationshipBadge(
              type: RelationshipType.friend,
              compact: true,
            ),
          ),
        ),
      );

      expect(find.byType(RelationshipBadge), findsOneWidget);
      expect(find.text('Friend'), findsNothing);
      expect(find.byIcon(Icons.people), findsOneWidget);
    });
  });
}
