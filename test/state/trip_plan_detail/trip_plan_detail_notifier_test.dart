import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:wanderer_frontend/core/constants/enums.dart';
import 'package:wanderer_frontend/core/providers/app_providers.dart';
import 'package:wanderer_frontend/data/client/google_directions_api_client.dart';
import 'package:wanderer_frontend/data/models/domain/trip.dart';
import 'package:wanderer_frontend/data/models/domain/trip_plan.dart';
import 'package:wanderer_frontend/data/models/requests/trip_from_plan_request.dart';
import 'package:wanderer_frontend/data/services/trip_plan_service.dart';
import 'package:wanderer_frontend/data/services/trip_service.dart';
import 'package:wanderer_frontend/presentation/state/trip_plan_detail/trip_plan_detail_notifier.dart';
import 'package:wanderer_frontend/presentation/state/trip_plan_detail/trip_plan_detail_state.dart';

import 'trip_plan_detail_notifier_test.mocks.dart';

@GenerateMocks([GoogleDirectionsApiClient, TripPlanService, TripService])
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
      container
          .read(tripPlanDetailNotifierProvider('plan-1'))
          .viewMap
          .isInfoCollapsed,
      isFalse,
    );
    notifier.setInfoCollapsed(true);
    expect(
      container
          .read(tripPlanDetailNotifierProvider('plan-1'))
          .viewMap
          .isInfoCollapsed,
      isTrue,
    );
  });

  group('edit-mode map/route/waypoint editing', () {
    late MockGoogleDirectionsApiClient mockDirectionsClient;

    setUp(() {
      mockDirectionsClient = MockGoogleDirectionsApiClient();
    });

    ProviderContainer buildEditContainer() {
      final container = ProviderContainer(overrides: [
        googleDirectionsApiClientProvider
            .overrideWithValue(mockDirectionsClient),
      ]);
      addTearDown(container.dispose);
      return container;
    }

    test('initEditLocations seeds edit-map fields from the trip plan', () {
      final container = buildEditContainer();
      final planWithRoute = TripPlan(
        id: 'plan-1',
        userId: 'owner-1',
        name: 'Hike',
        planType: 'SIMPLE',
        startLocation: PlanLocation(lat: 40.0, lon: -74.0),
        endLocation: PlanLocation(lat: 41.0, lon: -75.0),
        createdTimestamp: DateTime(2026, 1, 1),
      );
      final notifier =
          container.read(tripPlanDetailNotifierProvider('plan-1').notifier);
      notifier.seedInitialTripPlan(planWithRoute);
      notifier.initEditLocations();

      final editMap =
          container.read(tripPlanDetailNotifierProvider('plan-1')).editMap;
      expect(editMap.startLocation, const LatLng(40.0, -74.0));
      expect(editMap.endLocation, const LatLng(41.0, -75.0));
      expect(editMap.placementMode, EditPlacementMode.waypoint);
    });

    test(
        'removeWaypointAt removes the waypoint AND recomputes the route '
        '(this is the bug fix)', () async {
      final container = buildEditContainer();
      // Keep the autoDispose notifier alive across the `Future.delayed`
      // below — otherwise it gets torn down (zero listeners) before we
      // re-read it, per this codebase's established convention (see
      // trip_detail_notifier_test.dart).
      container.listen(tripPlanDetailNotifierProvider('plan-1'), (_, __) {});
      when(mockDirectionsClient.getRouteWithPoints(any))
          .thenAnswer((_) async => null);
      final notifier =
          container.read(tripPlanDetailNotifierProvider('plan-1').notifier);
      notifier.seedInitialTripPlan(TripPlan(
        id: 'plan-1',
        userId: 'owner-1',
        name: 'Hike',
        planType: 'SIMPLE',
        createdTimestamp: DateTime(2026, 1, 1),
      ));
      notifier.onEditMapTapped(const LatLng(40.0, -74.0));
      notifier.onEditMapTapped(const LatLng(41.0, -75.0));
      await Future<void>.delayed(Duration.zero);
      expect(
        container
            .read(tripPlanDetailNotifierProvider('plan-1'))
            .editMap
            .waypoints,
        hasLength(2),
      );
      // The 2-waypoint route was computed (1 call so far); its (dashed
      // placeholder) polyline is showing.
      expect(
        container
            .read(tripPlanDetailNotifierProvider('plan-1'))
            .editMap
            .polylines,
        isNotEmpty,
      );

      notifier.removeWaypointAt(0);
      await Future<void>.delayed(Duration.zero);

      final editMapAfterRemove =
          container.read(tripPlanDetailNotifierProvider('plan-1')).editMap;
      expect(editMapAfterRemove.waypoints, hasLength(1));
      // Proves the bug fix: with the pre-migration bug (no recompute after
      // "Remove"), the stale 2-point polyline from above would still be
      // showing even though only 1 waypoint remains. Recomputing with <2
      // points clears it instead.
      expect(
        editMapAfterRemove.polylines,
        isEmpty,
        reason: 'removeWaypointAt must recompute the route afterward — the '
            'stale polyline pointing at the removed waypoint must not '
            'linger (this is the bug fix)',
      );
      // Only 1 API call total: the 2-waypoint tap crossed the >=2-points
      // threshold once; removing back down to 1 point recomputes locally
      // (clearing the polyline above) without another network round trip.
      verify(mockDirectionsClient.getRouteWithPoints(any)).called(1);
    });

    test('reorderWaypoint reorders AND recomputes the route (bug fix)',
        () async {
      final container = buildEditContainer();
      container.listen(tripPlanDetailNotifierProvider('plan-1'), (_, __) {});
      when(mockDirectionsClient.getRouteWithPoints(any))
          .thenAnswer((_) async => null);
      final notifier =
          container.read(tripPlanDetailNotifierProvider('plan-1').notifier);
      notifier.seedInitialTripPlan(TripPlan(
        id: 'plan-1',
        userId: 'owner-1',
        name: 'Hike',
        planType: 'SIMPLE',
        createdTimestamp: DateTime(2026, 1, 1),
      ));
      notifier.onEditMapTapped(const LatLng(1.0, 1.0));
      notifier.onEditMapTapped(const LatLng(2.0, 2.0));
      await Future<void>.delayed(Duration.zero);
      clearInteractions(mockDirectionsClient);

      notifier.reorderWaypoint(0, 2); // ReorderableListView-style newIndex
      await Future<void>.delayed(Duration.zero);

      final waypoints = container
          .read(tripPlanDetailNotifierProvider('plan-1'))
          .editMap
          .waypoints;
      expect(waypoints[0], const LatLng(2.0, 2.0));
      expect(waypoints[1], const LatLng(1.0, 1.0));
      verify(mockDirectionsClient.getRouteWithPoints(any)).called(1);
    });

    // NOTE: adjusted from the plan's original version of this test, which
    // asserted that the very first tap (with no prior `initEditLocations()`
    // call) sets `startLocation` and cycles placementMode start -> end ->
    // waypoint. That is unreachable: `TripPlanDetailEditMapState`'s default
    // `placementMode` is `waypoint` (matching the pre-migration widget's
    // literal field default `_editPlacementMode = _EditPlacementMode.waypoint`,
    // which `_initEditLocations()` also unconditionally reset to on every
    // real entry into edit mode — so `.start`/`.end` were already dead code
    // pre-migration too). Changing the default to `.start` would be a real,
    // undocumented behavior change and directly contradicts the
    // removeWaypointAt/reorderWaypoint tests above (which rely on taps
    // landing in `.waypoints` from a fresh notifier). Verified against
    // trip_plan_detail_state.dart's existing default and cross-checked here.
    test(
        'onEditMapTapped places consecutive taps as waypoints, in order, '
        'from the default (waypoint) placement mode', () {
      final container = buildEditContainer();
      when(mockDirectionsClient.getRouteWithPoints(any))
          .thenAnswer((_) async => null);
      final notifier =
          container.read(tripPlanDetailNotifierProvider('plan-1').notifier);
      notifier.seedInitialTripPlan(TripPlan(
        id: 'plan-1',
        userId: 'owner-1',
        name: 'Hike',
        planType: 'SIMPLE',
        createdTimestamp: DateTime(2026, 1, 1),
      ));

      notifier.onEditMapTapped(const LatLng(1.0, 1.0));
      notifier.onEditMapTapped(const LatLng(2.0, 2.0));
      notifier.onEditMapTapped(const LatLng(3.0, 3.0));

      final editMap =
          container.read(tripPlanDetailNotifierProvider('plan-1')).editMap;
      expect(editMap.waypoints, [
        const LatLng(1.0, 1.0),
        const LatLng(2.0, 2.0),
        const LatLng(3.0, 3.0),
      ]);
      expect(editMap.startLocation, isNull);
      expect(editMap.endLocation, isNull);
      expect(editMap.placementMode, EditPlacementMode.waypoint);
    });

    test('onEditMapTapped ignores the tap once when ignoreNextMapTap is set',
        () {
      final container = buildEditContainer();
      final notifier =
          container.read(tripPlanDetailNotifierProvider('plan-1').notifier);
      notifier.seedInitialTripPlan(TripPlan(
        id: 'plan-1',
        userId: 'owner-1',
        name: 'Hike',
        planType: 'SIMPLE',
        createdTimestamp: DateTime(2026, 1, 1),
      ));
      notifier.setIgnoreNextMapTap(true);

      notifier.onEditMapTapped(const LatLng(1.0, 1.0));

      expect(
        container
            .read(tripPlanDetailNotifierProvider('plan-1'))
            .editMap
            .startLocation,
        isNull,
        reason: 'the ignored tap should not have placed a point',
      );
      expect(
        container
            .read(tripPlanDetailNotifierProvider('plan-1'))
            .editMap
            .ignoreNextMapTap,
        isFalse,
        reason: 'the flag should reset after absorbing one tap',
      );
    });

    test('resetEditMapToSavedPlan restores edit-map state to the trip plan',
        () async {
      final container = buildEditContainer();
      container.listen(tripPlanDetailNotifierProvider('plan-1'), (_, __) {});
      when(mockDirectionsClient.getRouteWithPoints(any))
          .thenAnswer((_) async => null);
      final notifier =
          container.read(tripPlanDetailNotifierProvider('plan-1').notifier);
      notifier.seedInitialTripPlan(TripPlan(
        id: 'plan-1',
        userId: 'owner-1',
        name: 'Hike',
        planType: 'SIMPLE',
        createdTimestamp: DateTime(2026, 1, 1),
      ));
      notifier.onEditMapTapped(const LatLng(1.0, 1.0));
      await Future<void>.delayed(Duration.zero);

      notifier.resetEditMapToSavedPlan();

      final editMap =
          container.read(tripPlanDetailNotifierProvider('plan-1')).editMap;
      expect(editMap.waypoints, isEmpty);
      expect(editMap.startLocation, isNull);
      expect(editMap.polylines, isEmpty);
      expect(editMap.isComputingRoute, isFalse);
    });
  });

  group('plan metadata + save/delete/create-from-plan lifecycle', () {
    late MockTripPlanService mockTripPlanService;
    late MockTripService mockTripService;
    late MockGoogleDirectionsApiClient mockDirectionsClient;
    late TripPlan plan;

    setUp(() {
      mockTripPlanService = MockTripPlanService();
      mockTripService = MockTripService();
      mockDirectionsClient = MockGoogleDirectionsApiClient();
      plan = TripPlan(
        id: 'plan-1',
        userId: 'owner-1',
        name: 'Hike',
        planType: 'SIMPLE',
        startDate: DateTime(2026, 6, 1),
        endDate: DateTime(2026, 6, 3),
        createdTimestamp: DateTime(2026, 1, 1),
      );
    });

    ProviderContainer buildLifecycleContainer() {
      final container = ProviderContainer(overrides: [
        tripPlanServiceProvider.overrideWithValue(mockTripPlanService),
        tripServiceProvider.overrideWithValue(mockTripService),
        googleDirectionsApiClientProvider
            .overrideWithValue(mockDirectionsClient),
      ]);
      addTearDown(container.dispose);
      return container;
    }

    test('seedMetadataFromPlan seeds planType/startDate/endDate', () {
      final container = buildLifecycleContainer();
      final notifier =
          container.read(tripPlanDetailNotifierProvider('plan-1').notifier);
      notifier.seedInitialTripPlan(plan);
      notifier.seedMetadataFromPlan(plan);

      final metadata =
          container.read(tripPlanDetailNotifierProvider('plan-1')).metadata;
      expect(metadata.selectedPlanType, 'SIMPLE');
      expect(metadata.startDate, DateTime(2026, 6, 1));
      expect(metadata.endDate, DateTime(2026, 6, 3));
    });

    test('enterEditMode seeds edit-map state and flips isEditing on',
        () async {
      final container = buildLifecycleContainer();
      when(mockDirectionsClient.getRouteWithPoints(any))
          .thenAnswer((_) async => null);
      final notifier =
          container.read(tripPlanDetailNotifierProvider('plan-1').notifier);
      notifier.seedInitialTripPlan(plan);

      await notifier.enterEditMode();

      final state = container.read(tripPlanDetailNotifierProvider('plan-1'));
      expect(state.metadata.isEditing, isTrue);
      expect(state.metadata.selectedPlanType, 'SIMPLE');
    });

    test('setDateRange updates metadata dates', () {
      final container = buildLifecycleContainer();
      final notifier =
          container.read(tripPlanDetailNotifierProvider('plan-1').notifier);
      notifier.seedInitialTripPlan(plan);

      notifier.setDateRange(DateTime(2026, 7, 1), DateTime(2026, 7, 5));

      final metadata =
          container.read(tripPlanDetailNotifierProvider('plan-1')).metadata;
      expect(metadata.startDate, DateTime(2026, 7, 1));
      expect(metadata.endDate, DateTime(2026, 7, 5));
    });

    test('saveChanges persists the plan and refetches it', () async {
      final updatedPlan = TripPlan(
        id: 'plan-1',
        userId: 'owner-1',
        name: 'Renamed Hike',
        planType: 'SIMPLE',
        createdTimestamp: DateTime(2026, 1, 1),
      );
      when(mockTripPlanService.updateTripPlan('plan-1', any))
          .thenAnswer((_) async => 'plan-1');
      when(mockTripPlanService.getTripPlanById('plan-1'))
          .thenAnswer((_) async => updatedPlan);

      final container = buildLifecycleContainer();
      final notifier =
          container.read(tripPlanDetailNotifierProvider('plan-1').notifier);
      notifier.seedInitialTripPlan(plan);

      await notifier.saveChanges(name: 'Renamed Hike');

      final state = container.read(tripPlanDetailNotifierProvider('plan-1'));
      expect(state.tripPlan.name, 'Renamed Hike');
      expect(state.metadata.isEditing, isFalse);
      expect(state.metadata.isLoading, isFalse);
    });

    test('saveChanges resets isLoading and rethrows on failure', () async {
      when(mockTripPlanService.updateTripPlan('plan-1', any))
          .thenThrow(Exception('network down'));

      final container = buildLifecycleContainer();
      final notifier =
          container.read(tripPlanDetailNotifierProvider('plan-1').notifier);
      notifier.seedInitialTripPlan(plan);

      await expectLater(
        notifier.saveChanges(name: 'Renamed Hike'),
        throwsException,
      );
      expect(
        container
            .read(tripPlanDetailNotifierProvider('plan-1'))
            .metadata
            .isLoading,
        isFalse,
      );
    });

    test('deleteTripPlan calls the service and resets isLoading on failure',
        () async {
      when(mockTripPlanService.deleteTripPlan('plan-1'))
          .thenThrow(Exception('network down'));

      final container = buildLifecycleContainer();
      final notifier =
          container.read(tripPlanDetailNotifierProvider('plan-1').notifier);
      notifier.seedInitialTripPlan(plan);

      await expectLater(notifier.deleteTripPlan(), throwsException);
      expect(
        container
            .read(tripPlanDetailNotifierProvider('plan-1'))
            .metadata
            .isLoading,
        isFalse,
      );
    });

    test('createTripFromPlan creates then fetches the new trip', () async {
      final newTrip = Trip(
        id: 'trip-9',
        userId: 'owner-1',
        username: 'owner',
        name: 'Hike Trip',
        status: TripStatus.created,
        visibility: Visibility.public,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
      when(mockTripService.createTripFromPlan('plan-1', any))
          .thenAnswer((_) async => 'trip-9');
      when(mockTripService.getTripById('trip-9'))
          .thenAnswer((_) async => newTrip);

      final container = buildLifecycleContainer();
      final notifier =
          container.read(tripPlanDetailNotifierProvider('plan-1').notifier);
      notifier.seedInitialTripPlan(plan);

      final trip = await notifier.createTripFromPlan(
        TripFromPlanRequest(
          visibility: Visibility.public,
          tripModality: TripModality.simple,
        ),
      );

      expect(trip.id, 'trip-9');
    });

    test(
        'exitEditModeWithoutSaving resets metadata to the trip plan\'s '
        'saved values', () {
      final container = buildLifecycleContainer();
      final notifier =
          container.read(tripPlanDetailNotifierProvider('plan-1').notifier);
      notifier.seedInitialTripPlan(plan);
      notifier.setSelectedPlanType('MULTI_DAY');
      notifier.setDateRange(DateTime(2030, 1, 1), DateTime(2030, 1, 2));

      notifier.exitEditModeWithoutSaving();

      final metadata =
          container.read(tripPlanDetailNotifierProvider('plan-1')).metadata;
      expect(metadata.isEditing, isFalse);
      expect(metadata.selectedPlanType, 'SIMPLE');
      expect(metadata.startDate, DateTime(2026, 6, 1));
      expect(metadata.endDate, DateTime(2026, 6, 3));
    });
  });
}
