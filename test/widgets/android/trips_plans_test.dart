import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:wanderer_frontend/core/constants/enums.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/presentation/screens/android/android_trips_tab.dart';
import 'package:wanderer_frontend/presentation/screens/android/plan_detail_view.dart';
import 'package:wanderer_frontend/presentation/widgets/android/plan_map_style.dart';

void main() {
  test('Live filter covers every started, unfinished state', () {
    expect(TripsFilter.live.matches(TripStatus.inProgress), isTrue);
    expect(TripsFilter.live.matches(TripStatus.paused), isTrue);
    expect(TripsFilter.live.matches(TripStatus.resting), isTrue);
    expect(TripsFilter.live.matches(TripStatus.created), isFalse);
    // Drafts have no chip any more; they still show under All.
    expect(TripsFilter.all.matches(TripStatus.created), isTrue);
    expect(TripsFilter.values.length, 3);
    expect(TripsFilter.finished.matches(TripStatus.finished), isTrue);
  });

  test('distanceKm sums the route', () {
    final km = PlanMapStyle.distanceKm(
        const [LatLng(0, 0), LatLng(0, 1), LatLng(0, 2)]);
    expect(km, closeTo(222.4, 1));
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

  testWidgets('Plan detail without start, finish or route shows an empty state',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final plan = TripPlan(
      id: 'p',
      userId: 'u',
      name: 'Someday walk',
      planType: 'SIMPLE',
      createdTimestamp: DateTime(2026),
    );
    await tester.pumpWidget(MaterialApp(
      home: AndroidPlanDetailView(
        plan: plan,
        map: const Placeholder(),
        route: const [],
        onBack: () {},
        onDelete: () {},
        onEdit: () {},
        onStart: () {},
        onFocusStop: (_) {},
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('plan_no_route')), findsOneWidget);
    expect(find.text('Not set'), findsNWidgets(2));
    expect(find.text('Start this trip'), findsOneWidget);
  });
}
