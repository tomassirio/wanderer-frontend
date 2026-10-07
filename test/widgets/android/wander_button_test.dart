import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wanderer_frontend/core/constants/enums.dart';
import 'package:wanderer_frontend/core/providers/app_providers.dart';
import 'package:wanderer_frontend/data/client/api_client.dart';
import 'package:wanderer_frontend/data/models/responses/page_response.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/data/repositories/home_repository.dart';
import 'package:wanderer_frontend/data/services/trip_plan_service.dart';
import 'package:wanderer_frontend/presentation/screens/android/android_shell.dart';
import 'package:wanderer_frontend/presentation/screens/android/trips_plans_list.dart';
import 'package:wanderer_frontend/presentation/screens/android/ready_trip_screen.dart';
import 'package:wanderer_frontend/presentation/screens/create_trip_plan_screen.dart';

const _geolocator = MethodChannel('flutter.baseflow.com/geolocator');

void main() {
  late List<Trip> myTrips;
  late bool locationOn;
  late List<Route<dynamic>> pushed;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    myTrips = [];
    locationOn = true;
    pushed = [];
    AndroidShell.ongoingTrip.value = null;
    AndroidShell.debugLiveScreen = (t) => Text('TRIP ${t.id}');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_geolocator, (call) async {
      return switch (call.method) {
        'isLocationServiceEnabled' => locationOn,
        'checkPermission' => 2,
        _ => null,
      };
    });
  });

  tearDown(() {
    AndroidShell.debugLiveScreen = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_geolocator, null);
  });

  Future<void> pumpBar(WidgetTester tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = _OfflineApi();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        homeRepositoryProvider.overrideWithValue(_Home(() => myTrips)),
        apiClientQueryProvider.overrideWithValue(api),
        apiClientCommandProvider.overrideWithValue(api),
        apiClientAuthProvider.overrideWithValue(api),
      ],
      child: MaterialApp(
        navigatorObservers: [_Observer(pushed)],
        home: Builder(
          builder: (context) => Scaffold(
            bottomNavigationBar:
                AndroidShell.navigationBar(context, AndroidTab.home),
          ),
        ),
      ),
    ));
    await tester.pump();
  }

  Trip trip(TripStatus status) => Trip(
        id: 'live-1',
        userId: 'u',
        name: 'Morning walk',
        username: 'me',
        visibility: Visibility.public,
        status: status,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

  testWidgets('Wander sits in the middle as a real, labelled 48dp button',
      (tester) async {
    await pumpBar(tester);
    final wander = find.byKey(const Key('wander_button'));
    expect(wander, findsOneWidget);
    expect(find.bySemanticsLabel('Wander: start a trip'), findsOneWidget);
    final size = tester.getSize(wander);
    expect(size.height, greaterThanOrEqualTo(48));
    expect(size.width, greaterThanOrEqualTo(48));
    // Middle of five slots: Home, Trips, Wander, Explore, You.
    final x = tester.getCenter(wander).dx;
    expect(x, greaterThan(tester.getCenter(find.text('Trips')).dx));
    expect(x, lessThan(tester.getCenter(find.text('Explore')).dx));
  });

  testWidgets('Wander opens the ready-to-start screen', (tester) async {
    await pumpBar(tester);
    await tester.tap(find.byKey(const Key('wander_button')));
    await tester.pump();
    await tester.pump();
    expect(pushed.last, isA<PageRoute>());
    expect(find.byType(ReadyTripScreen), findsOneWidget);
    // Let the ready screen's location lookup time out.
    await tester.pump(const Duration(seconds: 20));
  });

  testWidgets('with location off it asks first; Not now stays put',
      (tester) async {
    locationOn = false;
    await pumpBar(tester);
    await tester.tap(find.byKey(const Key('wander_button')));
    await tester.pumpAndSettle();
    expect(find.text('Turn on location to wander'), findsOneWidget);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(find.byType(ReadyTripScreen), findsNothing);
  });

  testWidgets('with a trip running it shows Live and opens that trip',
      (tester) async {
    myTrips = [trip(TripStatus.inProgress)];
    await pumpBar(tester);
    await tester.tap(find.byKey(const Key('wander_button')));
    await tester.pump();
    await tester.pump();
    expect(
        find.descendant(
            of: find.byKey(const Key('wander_button')),
            matching: find.text('Live')),
        findsOneWidget);
    expect(find.bySemanticsLabel('Open your live trip'), findsOneWidget);
    expect(find.byType(ReadyTripScreen), findsNothing);
    expect(find.text('TRIP live-1'), findsOneWidget);
  });

  testWidgets('a paused trip counts as running too', (tester) async {
    myTrips = [trip(TripStatus.paused)];
    await pumpBar(tester);
    await tester.tap(find.byKey(const Key('wander_button')));
    await tester.pump();
    await tester.pump();
    expect(find.text('TRIP live-1'), findsOneWidget);
  });

  testWidgets('the create menu\'s plan item lives on in Plans as New plan',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [tripPlanServiceProvider.overrideWithValue(_NoPlans())],
      child: const MaterialApp(home: Scaffold(body: AndroidPlansList())),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('plans_new_plan')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(CreateTripPlanScreen), findsOneWidget);
  });
}

class _Observer extends NavigatorObserver {
  final List<Route<dynamic>> pushed;
  _Observer(this.pushed);
  @override
  void didPush(Route route, Route? previousRoute) => pushed.add(route);
}

class _Home extends HomeRepository {
  final List<Trip> Function() trips;
  _Home(this.trips);

  @override
  Future<PageResponse<Trip>> getMyTrips({int page = 0, int size = 20}) async =>
      PageResponse(
        content: trips(),
        totalElements: trips().length,
        totalPages: 1,
        number: 0,
        size: size,
        first: true,
        last: true,
      );
}

class _NoPlans extends TripPlanService {
  @override
  Future<List<TripPlan>> getUserTripPlans() async => const [];
}

class _OfflineApi extends ApiClient {
  _OfflineApi() : super(baseUrl: 'https://example.invalid');
  static final _offline = http.Response('{"message":"offline"}', 503);

  @override
  Future<http.Response> get(String endpoint,
          {bool requireAuth = false, Map<String, String>? headers}) async =>
      _offline;

  @override
  Future<http.Response> post(String endpoint,
          {required Map<String, dynamic> body,
          bool requireAuth = false,
          Map<String, String>? headers}) async =>
      _offline;
}
