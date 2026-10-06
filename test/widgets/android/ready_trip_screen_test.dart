import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:wanderer_frontend/core/constants/enums.dart';
import 'package:wanderer_frontend/core/errors/app_exception.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/providers/app_providers.dart';
import 'package:wanderer_frontend/data/client/google_geocoding_api_client.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/data/services/trip_plan_service.dart';
import 'package:wanderer_frontend/data/services/trip_service.dart';
import 'package:wanderer_frontend/presentation/screens/android/ready_trip_screen.dart';
import 'package:wanderer_frontend/presentation/widgets/common/toasts.dart';

const _geolocator = MethodChannel('flutter.baseflow.com/geolocator');

void main() {
  late _FakeTrips trips;
  late _FakePlans plans;
  String? place;

  setUp(() {
    trips = _FakeTrips();
    plans = _FakePlans();
    place = 'Amsterdam';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_geolocator, (call) async {
      return switch (call.method) {
        'isLocationServiceEnabled' => true,
        'checkPermission' => 2, // whileInUse
        'getCurrentPosition' => {
            'latitude': 52.37,
            'longitude': 4.89,
            'timestamp': DateTime(2026, 10, 6).millisecondsSinceEpoch,
            'accuracy': 5.0,
          },
        _ => null,
      };
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_geolocator, null);
    Toasts.clear();
  });

  /// Opens the ready screen from a button so closing it can be checked.
  Future<void> open(WidgetTester tester, {TripPlan? plan}) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        tripServiceProvider.overrideWithValue(trips),
        tripPlanServiceProvider.overrideWithValue(plans),
        googleGeocodingApiClientProvider
            .overrideWithValue(_FakeGeocoder(() => place)),
      ],
      child: MaterialApp(
        builder: (_, child) => ToastHost(child: child!),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => ReadyTripScreen(
                          plan: plan,
                          testMap: const SizedBox.expand(),
                          testLive: (t) => Text('LIVE ${t.name}'),
                        ))),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  /// Success toasts count down, so pumpAndSettle never settles.
  Future<void> settle(WidgetTester tester) async {
    // Includes the 2 s battery read timeout.
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  String nameField(WidgetTester tester) => tester
      .widget<TextField>(find.byKey(const Key('ready_name')))
      .controller!
      .text;

  testWidgets('A: name from place and date, tiles from the last trip',
      (tester) async {
    await open(tester);
    expect(find.text('Ready to start'), findsOneWidget);
    expect(nameField(tester), startsWith('Amsterdam · '));
    expect(find.text('Friends'), findsOneWidget);
    expect(find.text('30 min'), findsOneWidget);
    expect(trips.events, [('READY_SCREEN_VIEWED', 'SCRATCH')]);
  });

  testWidgets('A: reverse geocoding failing falls back to a date-only name',
      (tester) async {
    place = null;
    await open(tester);
    expect(nameField(tester), isNot(contains('·')));
    expect(nameField(tester), isNotEmpty);
  });

  testWidgets('B: tapping a tile opens one settings sheet', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('ready_tile_visibility')));
    await tester.pumpAndSettle();
    expect(find.text('Who can see it?'), findsOneWidget);
    expect(find.text('Auto check-in'), findsWidgets);
    expect(find.text('How long?'), findsOneWidget);
    await tester.tap(find.text('Only me'));
    await tester.tap(find.byKey(const Key('ready_settings_done')));
    await tester.pumpAndSettle();
    expect(find.text('Only me'), findsOneWidget);
  });

  testWidgets('C: Start creates and starts in one call, then turns Live',
      (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('ready_start')));
    await settle(tester);

    expect(trips.starts, hasLength(1));
    final (request, key) = trips.starts.single;
    expect(key, isNotEmpty);
    expect(request.name, startsWith('Amsterdam · '));
    expect(request.visibility, Visibility.protected);
    expect(request.automaticUpdates, isTrue);
    expect(request.updateRefresh, 1800);
    expect(request.lat, 52.37);
    expect(request.tripPlanId, isNull);
    // Same screen, now live: no route was pushed on top.
    expect(find.textContaining('LIVE Amsterdam'), findsOneWidget);
    expect(find.text('Trip started'), findsOneWidget);
  });

  testWidgets('C: a retry after no connection reuses the idempotency key',
      (tester) async {
    trips.failNext = http.ClientException('offline');
    await open(tester);
    await tester.tap(find.byKey(const Key('ready_start')));
    await settle(tester);
    expect(find.text(AppLocalizations('en').readyOffline), findsOneWidget);
    expect(find.text('Ready to start'), findsOneWidget);

    await tester.tap(find.byKey(const Key('ready_start')));
    await settle(tester);
    expect(trips.starts, hasLength(2));
    expect(trips.starts[0].$2, trips.starts[1].$2);
    expect(find.textContaining('LIVE'), findsOneWidget);
  });

  testWidgets('C: no location means no start, in plain words', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_geolocator, (call) async {
      return call.method == 'isLocationServiceEnabled' ? false : 0;
    });
    await open(tester);
    expect(find.text(AppLocalizations('en').readyLocationOff), findsOneWidget);
    await tester.tap(find.byKey(const Key('ready_start')));
    await settle(tester);
    expect(trips.starts, isEmpty);
    expect(
        find.text(AppLocalizations('en').readyLocationNeeded), findsOneWidget);
  });

  group('D: closing without starting', () {
    testWidgets('asks "Not leaving yet?"; Discard creates nothing',
        (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const Key('ready_close')));
      await tester.pumpAndSettle();
      expect(find.text('Not leaving yet?'), findsOneWidget);
      expect(find.text('Save as a plan'), findsOneWidget);
      expect(find.text('Actually, start it now'), findsOneWidget);

      await tester.tap(find.byKey(const Key('ready_discard')));
      await tester.pumpAndSettle();
      expect(find.byType(ReadyTripScreen), findsNothing);
      expect(trips.starts, isEmpty);
      expect(plans.created, isEmpty);
      expect(trips.events.last, ('CLOSED_WITHOUT_STARTING', 'SCRATCH'));
    });

    testWidgets('dismissing the sheet stays on the ready screen',
        (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const Key('ready_close')));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(200, 40));
      await tester.pumpAndSettle();
      expect(find.text('Ready to start'), findsOneWidget);
    });

    testWidgets('Save as a plan saves a plan here, today', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const Key('ready_close')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ready_save_plan')));
      await settle(tester);
      final plan = plans.created.single;
      expect(plan.name, startsWith('Amsterdam · '));
      expect(plan.startLocation.lat, 52.37);
      expect(plan.metadata, {'visibility': 'PROTECTED'});
      expect(trips.starts, isEmpty);
      expect(trips.events.last, ('SAVED_AS_PLAN', 'SCRATCH'));
      expect(find.text('Saved to your plans'), findsOneWidget);
    });

    testWidgets('Actually, start it now starts the trip', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const Key('ready_close')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ready_start_now')));
      await settle(tester);
      expect(trips.starts, hasLength(1));
      expect(find.textContaining('LIVE'), findsOneWidget);
    });
  });

  testWidgets('E: starting a plan uses the same screen with the plan',
      (tester) async {
    final plan = TripPlan(
      id: 'plan-1',
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
    await open(tester, plan: plan);
    expect(find.text('Santiago de Compostela 2026'), findsOneWidget);
    expect(find.text('Multi-day plan'), findsOneWidget);
    expect(find.text('49 days'), findsOneWidget);
    expect(trips.events.first, ('READY_SCREEN_VIEWED', 'PLAN'));

    await tester.tap(find.byKey(const Key('ready_start')));
    await settle(tester);
    final (request, _) = trips.starts.single;
    expect(request.tripPlanId, 'plan-1');
    expect(request.tripModality, TripModality.multiDay);
    expect(find.textContaining('LIVE'), findsOneWidget);
  });

  testWidgets('"Or start one of your plans" switches to that plan',
      (tester) async {
    plans.list = [
      TripPlan(
        id: 'p2',
        userId: 'u',
        name: 'Coastal walk',
        planType: 'SIMPLE',
        createdTimestamp: DateTime(2026),
      ),
    ];
    await open(tester);
    await tester.tap(find.byKey(const Key('ready_pick_plan')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Coastal walk'));
    await tester.pumpAndSettle();
    expect(find.text('Simple plan'), findsOneWidget);
    await tester.tap(find.byKey(const Key('ready_start')));
    await settle(tester);
    expect(trips.starts.single.$1.tripPlanId, 'p2');
  });

  test('Start errors are plain words without codes', () {
    final l10n = AppLocalizations('en');
    expect(
        readyStartError(
            l10n, const ApiException(statusCode: 409, apiMessage: 'x')),
        l10n.readyAlreadyLive);
    expect(
        readyStartError(
            l10n, const ApiException(statusCode: 500, apiMessage: 'x')),
        l10n.readyStartFailed);
    expect(readyStartError(l10n, http.ClientException('x')), l10n.readyOffline);
  });

  test('idempotency keys are UUID shaped and unique', () {
    final a = newIdempotencyKey();
    expect(
        a,
        matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-'
            r'[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
    expect(newIdempotencyKey(), isNot(a));
  });

  test('trip name falls back to the date', () {
    final d = DateTime(2026, 10, 6);
    expect(readyTripName('Amsterdam', d, 'en_US'), 'Amsterdam · Tue 6 Oct');
    expect(readyTripName(null, d, 'en_US'), 'Tue 6 Oct');
  });

  test('start defaults parse seconds to minutes', () {
    final s = TripStartSettings.fromJson({
      'visibility': 'PRIVATE',
      'automaticUpdates': false,
      'updateRefresh': 1200,
      'tripModality': 'MULTI_DAY',
    });
    expect(s.visibility, Visibility.private);
    expect(s.automaticUpdates, isFalse);
    expect(s.intervalMinutes, 20);
    expect(s.modality, TripModality.multiDay);
  });
}

class _FakeTrips extends TripService {
  final starts = <(StartTripRequest, String)>[];
  final events = <(String, String?)>[];
  Object? failNext;

  @override
  Future<(TripStartSettings, bool)> getStartDefaults() async => (
        const TripStartSettings(
            visibility: Visibility.protected, intervalMinutes: 30),
        true
      );

  @override
  Future<StartTripResult> startTrip(StartTripRequest request,
      {required String idempotencyKey}) async {
    starts.add((request, idempotencyKey));
    if (failNext case final e?) {
      failNext = null;
      throw e;
    }
    return const StartTripResult(tripId: 't1', status: TripStatus.inProgress);
  }

  @override
  Future<Trip> getTripById(String tripId) async {
    final r = starts.last.$1;
    return Trip(
      id: tripId,
      userId: 'u',
      name: r.tripPlanId != null ? 'From plan' : r.name,
      username: 'me',
      visibility: r.visibility,
      status: TripStatus.inProgress,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
  }

  @override
  Future<void> trackStartFunnel(String event, {String? source}) async =>
      events.add((event, source));
}

class _FakePlans extends TripPlanService {
  List<TripPlan> list = const [];
  final created = <CreateTripPlanBackendRequest>[];

  @override
  Future<List<TripPlan>> getUserTripPlans() async => list;

  @override
  Future<String> createTripPlanBackend(
      CreateTripPlanBackendRequest request) async {
    created.add(request);
    return 'new-plan';
  }
}

class _FakeGeocoder extends GoogleGeocodingApiClient {
  final String? Function() place;
  _FakeGeocoder(this.place) : super('');

  @override
  Future<String?> placeName(double lat, double lon, {String? language}) async =>
      place();
}
