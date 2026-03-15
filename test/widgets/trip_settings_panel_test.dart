import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wanderer_frontend/core/constants/enums.dart';
import 'package:wanderer_frontend/presentation/widgets/trip_detail/trip_settings_panel.dart';

void main() {
  group('TripSettingsPanel Widget', () {
    Widget buildPanel({
      bool isCollapsed = false,
      bool isOwner = true,
      bool tripHasPlannedRoute = false,
      bool showPlannedWaypoints = false,
      VoidCallback? onTogglePlannedWaypoints,
      bool automaticUpdates = false,
      int? updateRefresh,
      TripModality? tripModality = TripModality.simple,
      bool isLoading = false,
      TripStatus tripStatus = TripStatus.inProgress,
      bool isWeb = true, // default to web to hide mobile-only sections
      VoidCallback? onDeleteTrip,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: TripSettingsPanel(
            isCollapsed: isCollapsed,
            onToggleCollapse: () {},
            isOwner: isOwner,
            tripHasPlannedRoute: tripHasPlannedRoute,
            showPlannedWaypoints: showPlannedWaypoints,
            onTogglePlannedWaypoints: onTogglePlannedWaypoints,
            automaticUpdates: automaticUpdates,
            updateRefresh: updateRefresh,
            tripModality: tripModality,
            isLoading: isLoading,
            onSettingsChange: (_, __, ___) {},
            tripStatus: tripStatus,
            isWeb: isWeb,
            onDeleteTrip: onDeleteTrip,
          ),
        ),
      );
    }

    testWidgets('shows settings for owner when trip status is created',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildPanel(
        tripStatus: TripStatus.created,
        isOwner: true,
      ));

      expect(find.text('Trip Settings'), findsOneWidget);
      expect(find.text('Trip Type'), findsOneWidget);
    });

    testWidgets('shows settings for owner when trip status is inProgress',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildPanel(
        tripStatus: TripStatus.inProgress,
        isOwner: true,
      ));

      expect(find.text('Trip Settings'), findsOneWidget);
      expect(find.text('Trip Type'), findsOneWidget);
    });

    testWidgets('hides settings for owner when trip is finished',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildPanel(
        tripStatus: TripStatus.finished,
        isOwner: true,
      ));

      expect(find.text('Trip Settings'), findsNothing);
      expect(find.text('Trip Type'), findsNothing);
    });

    testWidgets('hides settings for owner when trip is paused',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildPanel(
        tripStatus: TripStatus.paused,
        isOwner: true,
      ));

      expect(find.text('Trip Settings'), findsNothing);
      expect(find.text('Trip Type'), findsNothing);
    });

    testWidgets('hides owner settings for non-owners',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildPanel(
        tripStatus: TripStatus.created,
        isOwner: false,
      ));

      // No planned route, not owner → entire panel hidden
      expect(find.text('Trip Settings'), findsNothing);
    });

    testWidgets(
        'shows planned route toggle for non-owner when trip has planned route',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildPanel(
        tripStatus: TripStatus.created,
        isOwner: false,
        tripHasPlannedRoute: true,
        onTogglePlannedWaypoints: () {},
      ));

      expect(find.text('Trip Settings'), findsOneWidget);
      expect(find.text('Show Planned Route'), findsOneWidget);
      // Non-owner should not see Trip Type
      expect(find.text('Trip Type'), findsNothing);
    });

    testWidgets('shows collapsed cog bubble when isCollapsed is true',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildPanel(
        isCollapsed: true,
        tripStatus: TripStatus.created,
        isOwner: true,
      ));

      // AnimatedCrossFade renders both children but cross-fades between them.
      // When collapsed, the cog bubble is the "first" child (visible).
      // The expanded card is the "second" child (not visible but still rendered).
      // We verify the panel exists (not SizedBox.shrink) by finding settings icons.
      expect(find.byIcon(Icons.settings), findsWidgets);
    });

    testWidgets(
        'shows trip type buttons (Simple/Multi-Day) for created trip owner',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildPanel(
        tripStatus: TripStatus.created,
        isOwner: true,
        tripModality: TripModality.simple,
      ));

      expect(find.text('Simple'), findsOneWidget);
      expect(find.text('Multi-Day'), findsOneWidget);
    });

    testWidgets(
        'shows automatic updates switch on mobile for created trip owner',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildPanel(
        tripStatus: TripStatus.created,
        isOwner: true,
        isWeb: false,
      ));

      expect(find.text('Automatic Updates'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
    });

    testWidgets(
        'automatic updates switch is disabled when trip is in created status',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildPanel(
        tripStatus: TripStatus.created,
        isOwner: true,
        isWeb: false,
        automaticUpdates: true,
      ));

      final switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.value, true);
      expect(switchWidget.onChanged, isNull);
    });

    testWidgets('automatic updates switch is enabled when trip is in progress',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildPanel(
        tripStatus: TripStatus.inProgress,
        isOwner: true,
        isWeb: false,
        automaticUpdates: true,
      ));

      final switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.value, true);
      expect(switchWidget.onChanged, isNotNull);
    });

    testWidgets(
        'shows hint message when automatic updates enabled but trip not started',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildPanel(
        tripStatus: TripStatus.created,
        isOwner: true,
        isWeb: false,
        automaticUpdates: true,
      ));

      expect(
        find.text('Will activate when the trip is started'),
        findsOneWidget,
      );
    });

    testWidgets('hides hint message when trip is in progress',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildPanel(
        tripStatus: TripStatus.inProgress,
        isOwner: true,
        isWeb: false,
        automaticUpdates: true,
      ));

      expect(
        find.text('Will activate when the trip is started'),
        findsNothing,
      );
    });

    testWidgets('hides automatic updates switch on web',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildPanel(
        tripStatus: TripStatus.created,
        isOwner: true,
        isWeb: true,
      ));

      expect(find.text('Automatic Updates'), findsNothing);
    });

    testWidgets('shows delete trip button for owner with editable trip status',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildPanel(
        tripStatus: TripStatus.created,
        isOwner: true,
        onDeleteTrip: () {},
      ));

      expect(find.text('Delete Trip'), findsOneWidget);
      expect(find.byIcon(Icons.delete_forever), findsOneWidget);
    });

    testWidgets('shows delete trip button for owner when trip is in progress',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildPanel(
        tripStatus: TripStatus.inProgress,
        isOwner: true,
        onDeleteTrip: () {},
      ));

      expect(find.text('Delete Trip'), findsOneWidget);
    });

    testWidgets('hides delete trip button for non-owner',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildPanel(
        tripStatus: TripStatus.created,
        isOwner: false,
        tripHasPlannedRoute: true,
        onTogglePlannedWaypoints: () {},
        onDeleteTrip: () {},
      ));

      expect(find.text('Delete Trip'), findsNothing);
    });

    testWidgets('hides delete trip button when trip is finished',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildPanel(
        tripStatus: TripStatus.finished,
        isOwner: true,
        onDeleteTrip: () {},
      ));

      // Entire panel is hidden for finished trips
      expect(find.text('Delete Trip'), findsNothing);
    });

    testWidgets('hides delete trip button when onDeleteTrip is null',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildPanel(
        tripStatus: TripStatus.created,
        isOwner: true,
        onDeleteTrip: null,
      ));

      expect(find.text('Delete Trip'), findsNothing);
    });

    testWidgets('delete trip button calls onDeleteTrip when tapped',
        (WidgetTester tester) async {
      bool deleteCalled = false;
      await tester.pumpWidget(buildPanel(
        tripStatus: TripStatus.created,
        isOwner: true,
        onDeleteTrip: () => deleteCalled = true,
      ));

      await tester.tap(find.text('Delete Trip'));
      await tester.pump();

      expect(deleteCalled, isTrue);
    });

    testWidgets('delete trip button is disabled when isLoading is true',
        (WidgetTester tester) async {
      bool deleteCalled = false;
      await tester.pumpWidget(buildPanel(
        tripStatus: TripStatus.created,
        isOwner: true,
        isLoading: true,
        onDeleteTrip: () => deleteCalled = true,
      ));

      await tester.tap(find.text('Delete Trip'));
      await tester.pump();

      expect(deleteCalled, isFalse);
    });
  });
}
