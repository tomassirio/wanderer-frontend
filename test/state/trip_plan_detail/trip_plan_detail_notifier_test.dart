import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wanderer_frontend/data/models/domain/trip_plan.dart';
import 'package:wanderer_frontend/presentation/state/trip_plan_detail/trip_plan_detail_notifier.dart';

void main() {
  late TripPlan plan;

  setUp(() {
    plan = TripPlan(
      id: 'plan-1',
      userId: 'owner-1',
      name: 'Weekend Hike',
      planType: 'SIMPLE',
      startLocation: PlanLocation(lat: 40.0, lon: -74.0),
      endLocation: PlanLocation(lat: 41.0, lon: -75.0),
      createdTimestamp: DateTime(2026, 1, 1),
    );
  });

  ProviderContainer buildContainer() {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    return container;
  }

  test('build() seeds an empty placeholder for the given id', () {
    final container = buildContainer();
    final state = container.read(tripPlanDetailNotifierProvider('plan-1'));
    expect(state.tripPlan.id, 'plan-1');
    expect(state.tripPlan.name, isEmpty);
  });

  test('seedInitialTripPlan always applies its argument (unconditional)', () {
    final container = buildContainer();
    final notifier =
        container.read(tripPlanDetailNotifierProvider('plan-1').notifier);
    notifier.seedInitialTripPlan(plan);
    expect(
      container.read(tripPlanDetailNotifierProvider('plan-1')).tripPlan.name,
      'Weekend Hike',
    );

    final revisedPlan = TripPlan(
      id: 'plan-1',
      userId: 'owner-1',
      name: 'Renamed Hike',
      planType: 'SIMPLE',
      createdTimestamp: DateTime(2026, 1, 1),
    );
    notifier.seedInitialTripPlan(revisedPlan);
    expect(
      container.read(tripPlanDetailNotifierProvider('plan-1')).tripPlan.name,
      'Renamed Hike',
      reason: 'seedInitialTripPlan must apply the latest call unconditionally',
    );
  });

  test('updateViewMapData populates markers/polylines from the seeded plan',
      () {
    final container = buildContainer();
    final notifier =
        container.read(tripPlanDetailNotifierProvider('plan-1').notifier);
    notifier.seedInitialTripPlan(plan);
    notifier.updateViewMapData();

    final state = container.read(tripPlanDetailNotifierProvider('plan-1'));
    expect(state.viewMap.markers, isNotEmpty);
  });

  test('setInfoCollapsed toggles the collapse flag', () {
    final container = buildContainer();
    final notifier =
        container.read(tripPlanDetailNotifierProvider('plan-1').notifier);
    expect(
      container.read(tripPlanDetailNotifierProvider('plan-1')).viewMap
          .isInfoCollapsed,
      isFalse,
    );
    notifier.setInfoCollapsed(true);
    expect(
      container.read(tripPlanDetailNotifierProvider('plan-1')).viewMap
          .isInfoCollapsed,
      isTrue,
    );
  });
}
