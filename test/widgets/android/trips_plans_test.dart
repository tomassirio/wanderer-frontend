import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:wanderer_frontend/core/constants/enums.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/presentation/screens/android/android_trips_tab.dart';
import 'package:wanderer_frontend/presentation/screens/android/plan_detail_view.dart';
import 'package:wanderer_frontend/presentation/widgets/android/plan_map_style.dart';
import 'package:wanderer_frontend/presentation/widgets/trip_plans/trip_from_plan_dialog.dart';

void main() {
  test('Live filter covers every started, unfinished state', () {
    expect(TripsFilter.live.matches(TripStatus.inProgress), isTrue);
    expect(TripsFilter.live.matches(TripStatus.paused), isTrue);
    expect(TripsFilter.live.matches(TripStatus.resting), isTrue);
    expect(TripsFilter.live.matches(TripStatus.created), isFalse);
    expect(TripsFilter.drafts.matches(TripStatus.created), isTrue);
    expect(TripsFilter.finished.matches(TripStatus.finished), isTrue);
  });

  test('distanceKm sums the route', () {
    final km = PlanMapStyle.distanceKm(
        const [LatLng(0, 0), LatLng(0, 1), LatLng(0, 2)]);
    expect(km, closeTo(222.4, 1));
  });

  testWidgets('Start sheet returns visibility and auto check-in interval',
      (tester) async {
    TripFromPlanRequest? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => result = await TripFromPlanDialog.show(context,
              planName: 'Camino', planType: 'MULTI_DAY'),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Friends'));
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.tap(find.text('30 min'));
    await tester.tap(find.text('Start trip now'));
    await tester.pumpAndSettle();

    expect(result!.visibility, Visibility.protected);
    expect(result!.tripModality, TripModality.multiDay);
    expect(result!.automaticUpdates, isTrue);
    expect(result!.updateRefresh, 30);
  });

  testWidgets('Plan detail sheet lays out on a phone', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final plan = TripPlan(
      id: 'p',
      userId: 'u',
      name: 'Santiago de Compostela 2026',
      planType: 'MULTI_DAY',
      startDate: DateTime(2026, 4, 3),
      endDate: DateTime(2026, 5, 21),
      startLocation: PlanLocation(lat: 52.09, lon: 5.12),
      endLocation: PlanLocation(lat: 42.88, lon: -8.54),
      waypoints: [PlanLocation(lat: 48.8, lon: 2.3)],
      createdTimestamp: DateTime(2026),
    );
    await tester.pumpWidget(MaterialApp(
      home: AndroidPlanDetailView(
        plan: plan,
        map: const Placeholder(),
        route: const [LatLng(52.09, 5.12), LatLng(42.88, -8.54)],
        onBack: () {},
        onDelete: () {},
        onEdit: () {},
        onStart: () {},
        onFocusStop: (_) {},
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Start this trip'), findsOneWidget);
    expect(find.text('Per day'), findsOneWidget);
  });
}
