import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wanderer_frontend/presentation/helpers/location_permission_disclosure.dart';

void main() {
  group('LocationPermissionDisclosure', () {
    testWidgets('displays dialog with correct title', (tester) async {
      late BuildContext savedContext;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) {
            savedContext = context;
            return const Scaffold();
          },
        ),
      ));

      LocationPermissionDisclosure.show(savedContext);
      await tester.pumpAndSettle();

      expect(find.text('Location Access'), findsOneWidget);
    });

    testWidgets('displays location usage explanation', (tester) async {
      late BuildContext savedContext;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) {
            savedContext = context;
            return const Scaffold();
          },
        ),
      ));

      LocationPermissionDisclosure.show(savedContext);
      await tester.pumpAndSettle();

      expect(find.text('How your location is used:'), findsOneWidget);
      expect(
        find.textContaining('trip tracking and mapping features'),
        findsOneWidget,
      );
    });

    testWidgets('displays all three bullet points', (tester) async {
      late BuildContext savedContext;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) {
            savedContext = context;
            return const Scaffold();
          },
        ),
      ));

      LocationPermissionDisclosure.show(savedContext);
      await tester.pumpAndSettle();

      expect(
          find.textContaining('current position on the map'), findsOneWidget);
      expect(find.textContaining('GPS coordinates'), findsOneWidget);
      expect(find.textContaining('Center the map'), findsOneWidget);
    });

    testWidgets('displays decline note text', (tester) async {
      late BuildContext savedContext;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) {
            savedContext = context;
            return const Scaffold();
          },
        ),
      ));

      LocationPermissionDisclosure.show(savedContext);
      await tester.pumpAndSettle();

      expect(
        find.textContaining('You can decline'),
        findsOneWidget,
      );
    });

    testWidgets('returns true when user taps Continue', (tester) async {
      late BuildContext savedContext;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) {
            savedContext = context;
            return const Scaffold();
          },
        ),
      ));

      final future = LocationPermissionDisclosure.show(savedContext);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(await future, isTrue);
    });

    testWidgets('returns false when user taps No thanks', (tester) async {
      late BuildContext savedContext;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) {
            savedContext = context;
            return const Scaffold();
          },
        ),
      ));

      final future = LocationPermissionDisclosure.show(savedContext);
      await tester.pumpAndSettle();

      await tester.tap(find.text('No thanks'));
      await tester.pumpAndSettle();

      expect(await future, isFalse);
    });

    testWidgets('dialog is not dismissible by tapping outside', (tester) async {
      late BuildContext savedContext;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) {
            savedContext = context;
            return const Scaffold();
          },
        ),
      ));

      LocationPermissionDisclosure.show(savedContext);
      await tester.pumpAndSettle();

      // Tap outside the dialog (on the barrier)
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      // Dialog should still be visible
      expect(find.text('Location Access'), findsOneWidget);
    });

    testWidgets('displays location_on icon', (tester) async {
      late BuildContext savedContext;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) {
            savedContext = context;
            return const Scaffold();
          },
        ),
      ));

      LocationPermissionDisclosure.show(savedContext);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.location_on), findsOneWidget);
      expect(find.byIcon(Icons.map), findsOneWidget);
      expect(find.byIcon(Icons.route), findsOneWidget);
      expect(find.byIcon(Icons.center_focus_strong), findsOneWidget);
    });
  });
}
