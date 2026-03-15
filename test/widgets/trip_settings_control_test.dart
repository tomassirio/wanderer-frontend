import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wanderer_frontend/core/constants/enums.dart';
import 'package:wanderer_frontend/presentation/widgets/trip_detail/trip_settings_control.dart';

void main() {
  group('TripSettingsControl Widget', () {
    testWidgets('does not show for non-owners', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TripSettingsControl(
              automaticUpdates: false,
              isOwner: false,
              isLoading: false,
              onSettingsChange: (_, __, ___) {},
              tripStatus: TripStatus.inProgress,
              isWeb: false,
            ),
          ),
        ),
      );

      expect(find.byType(Switch), findsNothing);
    });

    testWidgets('does not show on web platform', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TripSettingsControl(
              automaticUpdates: false,
              isOwner: true,
              isLoading: false,
              onSettingsChange: (_, __, ___) {},
              tripStatus: TripStatus.inProgress,
              isWeb: true,
            ),
          ),
        ),
      );

      expect(find.byType(Switch), findsNothing);
    });

    testWidgets('shows settings when trip is created (owner on mobile)',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TripSettingsControl(
              automaticUpdates: false,
              isOwner: true,
              isLoading: false,
              onSettingsChange: (_, __, ___) {},
              tripStatus: TripStatus.created,
              isWeb: false,
            ),
          ),
        ),
      );

      expect(find.byType(Switch), findsOneWidget);
      expect(find.text('Automatic Updates'), findsOneWidget);
    });

    testWidgets('switch is disabled when trip is in created status',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TripSettingsControl(
              automaticUpdates: true,
              isOwner: true,
              isLoading: false,
              onSettingsChange: (_, __, ___) {},
              tripStatus: TripStatus.created,
              isWeb: false,
            ),
          ),
        ),
      );

      final switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.value, true);
      expect(switchWidget.onChanged, isNull);
    });

    testWidgets(
        'shows hint message when automatic updates enabled but trip not started',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TripSettingsControl(
              automaticUpdates: true,
              isOwner: true,
              isLoading: false,
              onSettingsChange: (_, __, ___) {},
              tripStatus: TripStatus.created,
              isWeb: false,
            ),
          ),
        ),
      );

      expect(
        find.text('Will activate when the trip is started'),
        findsOneWidget,
      );
      // Interval field should not be shown when trip is not in progress
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets(
        'hides hint message when trip is in progress with automatic updates',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TripSettingsControl(
              automaticUpdates: true,
              updateRefresh: 1800,
              isOwner: true,
              isLoading: false,
              onSettingsChange: (_, __, ___) {},
              tripStatus: TripStatus.inProgress,
              isWeb: false,
            ),
          ),
        ),
      );

      expect(
        find.text('Will activate when the trip is started'),
        findsNothing,
      );
      // Interval field should be shown when trip is in progress
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('does not show when trip is finished',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TripSettingsControl(
              automaticUpdates: false,
              isOwner: true,
              isLoading: false,
              onSettingsChange: (_, __, ___) {},
              tripStatus: TripStatus.finished,
              isWeb: false,
            ),
          ),
        ),
      );

      expect(find.byType(Switch), findsNothing);
    });

    testWidgets('does not show when trip is paused',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TripSettingsControl(
              automaticUpdates: false,
              isOwner: true,
              isLoading: false,
              onSettingsChange: (_, __, ___) {},
              tripStatus: TripStatus.paused,
              isWeb: false,
            ),
          ),
        ),
      );

      expect(find.byType(Switch), findsNothing);
    });

    testWidgets('shows switch for owners on mobile when trip is in progress',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TripSettingsControl(
              automaticUpdates: false,
              isOwner: true,
              isLoading: false,
              onSettingsChange: (_, __, ___) {},
              tripStatus: TripStatus.inProgress,
              isWeb: false,
            ),
          ),
        ),
      );

      expect(find.byType(Switch), findsOneWidget);
      expect(find.text('Automatic Updates'), findsOneWidget);
    });

    testWidgets('shows trip type selector for simple trips (not yet multi-day)',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TripSettingsControl(
              automaticUpdates: false,
              tripModality: TripModality.simple,
              isOwner: true,
              isLoading: false,
              onSettingsChange: (_, __, ___) {},
              tripStatus: TripStatus.inProgress,
              isWeb: false,
            ),
          ),
        ),
      );

      expect(find.text('Trip Type'), findsOneWidget);
      expect(find.text('Simple'), findsOneWidget);
      expect(find.text('Multi-Day'), findsOneWidget);
    });

    testWidgets('hides trip type selector when trip is already multi-day',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TripSettingsControl(
              automaticUpdates: false,
              tripModality: TripModality.multiDay,
              isOwner: true,
              isLoading: false,
              onSettingsChange: (_, __, ___) {},
              tripStatus: TripStatus.inProgress,
              isWeb: false,
            ),
          ),
        ),
      );

      // Trip Type selector should be hidden (multi-day is irreversible)
      expect(find.text('Trip Type'), findsNothing);
      expect(find.text('Simple'), findsNothing);
      // Switch should still be visible
      expect(find.byType(Switch), findsOneWidget);
      expect(find.text('Automatic Updates'), findsOneWidget);
    });

    testWidgets('shows time interval field when automaticUpdates is true', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TripSettingsControl(
              automaticUpdates: true,
              updateRefresh: 1800,
              isOwner: true,
              isLoading: false,
              onSettingsChange: (_, __, ___) {},
              tripStatus: TripStatus.inProgress,
              isWeb: false,
            ),
          ),
        ),
      );

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Update Interval (min 15 min)'), findsOneWidget);
      expect(find.text('30'), findsOneWidget);
    });

    testWidgets(
        'does not show time interval field when automaticUpdates is false',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TripSettingsControl(
              automaticUpdates: false,
              isOwner: true,
              isLoading: false,
              onSettingsChange: (_, __, ___) {},
              tripStatus: TripStatus.inProgress,
              isWeb: false,
            ),
          ),
        ),
      );

      expect(find.byType(TextField), findsNothing);
      expect(find.text('Update Interval (min 15 min)'), findsNothing);
    });

    testWidgets(
        'calls onSettingsChange when Save is tapped with automaticUpdates enabled',
        (WidgetTester tester) async {
      bool? capturedAutomaticUpdates;
      int? capturedUpdateRefresh;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TripSettingsControl(
              automaticUpdates: true,
              updateRefresh: 1800,
              isOwner: true,
              isLoading: false,
              onSettingsChange:
                  (automaticUpdates, updateRefresh, tripModality) {
                capturedAutomaticUpdates = automaticUpdates;
                capturedUpdateRefresh = updateRefresh;
              },
              tripStatus: TripStatus.inProgress,
              isWeb: false,
            ),
          ),
        ),
      );

      // Save is grayed out until the interval changes — modify it first.
      await tester.enterText(find.byType(TextField), '45');
      await tester.pump();

      await tester.tap(find.text('Save'));
      await tester.pump();

      expect(capturedAutomaticUpdates, true);
      expect(capturedUpdateRefresh, 2700); // 45 * 60
    });

    testWidgets('Save button is grayed out when interval has not changed',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TripSettingsControl(
              automaticUpdates: true,
              updateRefresh: 1800,
              isOwner: true,
              isLoading: false,
              onSettingsChange: (_, __, ___) {},
              tripStatus: TripStatus.inProgress,
              isWeb: false,
            ),
          ),
        ),
      );

      // Save should be visible but disabled (interval unchanged)
      final saveButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Save'),
      );
      expect(saveButton.onPressed, isNull);
    });

    testWidgets('auto-saves when toggling automaticUpdates off',
        (WidgetTester tester) async {
      bool? capturedAutomaticUpdates;
      int? capturedUpdateRefresh;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TripSettingsControl(
              automaticUpdates: true,
              updateRefresh: 1800,
              isOwner: true,
              isLoading: false,
              onSettingsChange:
                  (automaticUpdates, updateRefresh, tripModality) {
                capturedAutomaticUpdates = automaticUpdates;
                capturedUpdateRefresh = updateRefresh;
              },
              tripStatus: TripStatus.inProgress,
              isWeb: false,
            ),
          ),
        ),
      );

      // Toggle automatic updates OFF — should auto-save immediately
      await tester.tap(find.byType(Switch));
      await tester.pump();

      expect(capturedAutomaticUpdates, false);
      expect(capturedUpdateRefresh, 1800);

      // Save button should no longer be visible
      expect(find.text('Save'), findsNothing);
    });

    testWidgets('does not show Save button when automaticUpdates is disabled',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TripSettingsControl(
              automaticUpdates: false,
              isOwner: true,
              isLoading: false,
              onSettingsChange: (_, __, ___) {},
              tripStatus: TripStatus.inProgress,
              isWeb: false,
            ),
          ),
        ),
      );

      expect(find.text('Save'), findsNothing);
    });

    testWidgets('toggles switch value when tapped',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TripSettingsControl(
              automaticUpdates: false,
              isOwner: true,
              isLoading: false,
              onSettingsChange: (_, __, ___) {},
              tripStatus: TripStatus.inProgress,
              isWeb: false,
            ),
          ),
        ),
      );

      expect(find.byType(TextField), findsNothing);

      await tester.tap(find.byType(Switch));
      await tester.pump();

      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('auto-saves when toggling automaticUpdates on',
        (WidgetTester tester) async {
      bool? capturedAutomaticUpdates;
      int? capturedUpdateRefresh;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TripSettingsControl(
              automaticUpdates: false,
              isOwner: true,
              isLoading: false,
              onSettingsChange:
                  (automaticUpdates, updateRefresh, tripModality) {
                capturedAutomaticUpdates = automaticUpdates;
                capturedUpdateRefresh = updateRefresh;
              },
              tripStatus: TripStatus.inProgress,
              isWeb: false,
            ),
          ),
        ),
      );

      // Toggle automatic updates ON — should auto-save immediately
      await tester.tap(find.byType(Switch));
      await tester.pump();

      expect(capturedAutomaticUpdates, true);
      // Default interval is 15 min = 900 seconds
      expect(capturedUpdateRefresh, 900);
    });

    testWidgets('shows error snackbar when saving with invalid interval',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TripSettingsControl(
              automaticUpdates: true,
              updateRefresh: 1800,
              isOwner: true,
              isLoading: false,
              onSettingsChange: (_, __, ___) {},
              tripStatus: TripStatus.inProgress,
              isWeb: false,
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), '');
      await tester.pump();

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle(); // Wait for notification to appear

      expect(find.text('Minimum interval is 15 minutes'), findsOneWidget);

      // Clean up - advance past auto-dismiss duration and exit animation
      await tester.pump(
          const Duration(seconds: 4)); // 3s auto-dismiss + 300ms exit animation
      await tester.pumpAndSettle();
    });

    testWidgets('disables controls when isLoading is true', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TripSettingsControl(
              automaticUpdates: true,
              updateRefresh: 1800,
              isOwner: true,
              isLoading: true,
              onSettingsChange: (_, __, ___) {},
              tripStatus: TripStatus.inProgress,
              isWeb: false,
            ),
          ),
        ),
      );

      final switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.onChanged, isNull);

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.enabled, false);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('updates text field value when updateRefresh prop changes',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TripSettingsControl(
              automaticUpdates: true,
              updateRefresh: 1800,
              isOwner: true,
              isLoading: false,
              onSettingsChange: (_, __, ___) {},
              tripStatus: TripStatus.inProgress,
              isWeb: false,
            ),
          ),
        ),
      );

      expect(find.text('30'), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TripSettingsControl(
              automaticUpdates: true,
              updateRefresh: 3600,
              isOwner: true,
              isLoading: false,
              onSettingsChange: (_, __, ___) {},
              tripStatus: TripStatus.inProgress,
              isWeb: false,
            ),
          ),
        ),
      );

      expect(find.text('60'), findsOneWidget);
      expect(find.text('30'), findsNothing);
    });
  });
}
