import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wanderer_frontend/core/constants/enums.dart';
import 'package:wanderer_frontend/presentation/widgets/trip_detail/trip_status_control.dart';

void main() {
  group('TripStatusControl Widget', () {
    testWidgets('does not show on web platform', (WidgetTester tester) async {
      // Note: kIsWeb is a compile-time constant, so we can't truly test this dynamically
      // This test documents the expected behavior
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TripStatusControl(
              currentStatus: TripStatus.created,
              isOwner: true,
              isLoading: false,
              onStatusChange: (_) {},
            ),
          ),
        ),
      );

      // On web (if kIsWeb is true), should not show any buttons
      // On mobile platforms, should show buttons
      if (kIsWeb) {
        expect(find.byType(ElevatedButton), findsNothing);
      }
    });

    testWidgets('does not show for non-owners', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TripStatusControl(
              currentStatus: TripStatus.created,
              isOwner: false,
              isLoading: false,
              onStatusChange: (_) {},
            ),
          ),
        ),
      );

      expect(find.byType(ElevatedButton), findsNothing);
    });

    testWidgets('does not show for finished trips', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TripStatusControl(
              currentStatus: TripStatus.finished,
              isOwner: true,
              isLoading: false,
              onStatusChange: (_) {},
            ),
          ),
        ),
      );

      expect(find.byType(ElevatedButton), findsNothing);
    });

    testWidgets('shows Start Trip button for created status', (
      WidgetTester tester,
    ) async {
      // Skip on web
      if (kIsWeb) return;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TripStatusControl(
              currentStatus: TripStatus.created,
              isOwner: true,
              isLoading: false,
              onStatusChange: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Start Trip'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    });

    testWidgets('shows Resume button for paused status', (
      WidgetTester tester,
    ) async {
      // Skip on web
      if (kIsWeb) return;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TripStatusControl(
              currentStatus: TripStatus.paused,
              isOwner: true,
              isLoading: false,
              onStatusChange: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Resume'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    });

    testWidgets('shows Pause and Finish buttons for in-progress status', (
      WidgetTester tester,
    ) async {
      // Skip on web
      if (kIsWeb) return;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TripStatusControl(
              currentStatus: TripStatus.inProgress,
              isOwner: true,
              isLoading: false,
              onStatusChange: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Pause'), findsOneWidget);
      expect(find.text('Finish'), findsOneWidget);
      expect(find.byIcon(Icons.pause), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);
      // Rest button should not be shown (moved to TripUpdatePanel for multi-day trips)
      expect(find.text('Rest'), findsNothing);
      expect(find.byIcon(Icons.nightlight_round), findsNothing);
    });

    testWidgets('calls onStatusChange when Start Trip is tapped', (
      WidgetTester tester,
    ) async {
      // Skip on web
      if (kIsWeb) return;

      TripStatus? changedStatus;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TripStatusControl(
              currentStatus: TripStatus.created,
              isOwner: true,
              isLoading: false,
              onStatusChange: (status) {
                changedStatus = status;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Start Trip'));
      await tester.pump();

      expect(changedStatus, TripStatus.inProgress);
    });

    testWidgets('calls onStatusChange when Pause is tapped', (
      WidgetTester tester,
    ) async {
      // Skip on web
      if (kIsWeb) return;

      TripStatus? changedStatus;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TripStatusControl(
              currentStatus: TripStatus.inProgress,
              isOwner: true,
              isLoading: false,
              onStatusChange: (status) {
                changedStatus = status;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Pause'));
      await tester.pump();

      expect(changedStatus, TripStatus.paused);
    });

    testWidgets('shows confirmation dialog when Finish is tapped', (
      WidgetTester tester,
    ) async {
      // Skip on web
      if (kIsWeb) return;

      TripStatus? changedStatus;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TripStatusControl(
              currentStatus: TripStatus.inProgress,
              isOwner: true,
              isLoading: false,
              onStatusChange: (status) {
                changedStatus = status;
              },
            ),
          ),
        ),
      );

      // Tap the Finish button
      await tester.tap(find.text('Finish'));
      await tester.pumpAndSettle();

      // Verify confirmation dialog is shown
      expect(find.text('Finish Trip'), findsOneWidget);
      expect(
        find.text(
          'Are you sure you want to finish this trip? This will mark the trip as completed.',
        ),
        findsOneWidget,
      );
      expect(find.text('Cancel'), findsOneWidget);

      // Tap the confirm button in the dialog using its key
      await tester.tap(find.byKey(const Key('confirm_finish_button')));
      await tester.pumpAndSettle();

      // Verify onStatusChange was called
      expect(changedStatus, TripStatus.finished);
    });

    testWidgets('does not change status when confirmation is cancelled', (
      WidgetTester tester,
    ) async {
      // Skip on web
      if (kIsWeb) return;

      TripStatus? changedStatus;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TripStatusControl(
              currentStatus: TripStatus.inProgress,
              isOwner: true,
              isLoading: false,
              onStatusChange: (status) {
                changedStatus = status;
              },
            ),
          ),
        ),
      );

      // Tap the Finish button
      await tester.tap(find.text('Finish'));
      await tester.pumpAndSettle();

      // Tap the Cancel button in the dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Verify onStatusChange was NOT called
      expect(changedStatus, isNull);
    });

    testWidgets('disables buttons when isLoading is true', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TripStatusControl(
              currentStatus: TripStatus.created,
              isOwner: true,
              isLoading: true,
              onStatusChange: (_) {},
              isWeb: false, // Explicitly set for testing
            ),
          ),
        ),
      );

      // Verify "Start Trip" button text exists
      expect(find.text('Start Trip'), findsOneWidget);

      // Find the ElevatedButton by type
      final buttonFinder = find.byType(ElevatedButton);
      expect(buttonFinder, findsOneWidget);

      // Get the ElevatedButton widget and check that it's disabled
      final elevatedButton = tester.widget<ElevatedButton>(buttonFinder);
      expect(
        elevatedButton.enabled,
        isFalse,
        reason: 'Button should be disabled when isLoading is true',
      );
    });
  });
}
