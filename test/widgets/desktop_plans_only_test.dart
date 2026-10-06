import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wanderer_frontend/core/constants/api_endpoints.dart';
import 'package:wanderer_frontend/core/providers/app_providers.dart';
import 'package:wanderer_frontend/data/client/api_client.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/presentation/helpers/adaptive_layout.dart';
import 'package:wanderer_frontend/presentation/screens/android/ready_trip_screen.dart';
import 'package:wanderer_frontend/presentation/screens/create_trip_plan_screen.dart';
import 'package:wanderer_frontend/presentation/screens/create_trip_screen.dart';
import 'package:wanderer_frontend/presentation/widgets/trip_detail/web_draft_trip_view.dart';

/// Desktop web is plans-only: new trips are plans and plans start on the
/// phone, so the browser never creates or starts a trip.
void main() {
  late _RecordingApi api;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AdaptiveLayout.debugIsWeb = true;
    api = _RecordingApi();
  });
  tearDown(() => AdaptiveLayout.debugIsWeb = null);

  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        apiClientQueryProvider.overrideWithValue(api),
        apiClientCommandProvider.overrideWithValue(api),
        apiClientAuthProvider.overrideWithValue(api),
      ],
      child: MaterialApp(home: home),
    ));
    await tester.pump();
  }

  testWidgets('desktop "+ → Trip" opens plan creation, never POST /trips',
      (tester) async {
    await pump(tester, const CreateTripScreen());
    expect(find.byType(CreateTripPlanScreen), findsOneWidget);
    expect(find.byType(ReadyTripScreen), findsNothing);
    expect(api.writes, isEmpty);
  });

  testWidgets('desktop "Start this trip" shows the phone handoff, no API call',
      (tester) async {
    final plan = TripPlan(
      id: 'plan-9',
      userId: 'u',
      name: 'Camino',
      planType: 'MULTI_DAY',
      createdTimestamp: DateTime(2026),
    );
    await pump(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                StartOnPhoneCard.showForPlan(context, plan, username: 'me'),
            child: const Text('Start this trip'),
          ),
        ));
    await tester.tap(find.text('Start this trip'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('start_on_phone_card')), findsOneWidget);
    expect(find.textContaining('Open this plan', findRichText: true),
        findsOneWidget);
    // Play Store badge for Android, the plan's web link for other phones.
    expect(find.byType(Image), findsOneWidget);
    expect(find.text(ApiEndpoints.planDeepLink('plan-9')), findsOneWidget);
    expect(api.writes, isEmpty);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('start_on_phone_card')), findsNothing);
  });
}

/// Offline API that records every write (POST/PUT/PATCH/DELETE).
class _RecordingApi extends ApiClient {
  _RecordingApi() : super(baseUrl: 'https://example.invalid');
  final writes = <String>[];
  static final _offline = http.Response('{"message":"offline"}', 503);

  @override
  Future<http.Response> get(String endpoint,
          {bool requireAuth = false, Map<String, String>? headers}) async =>
      _offline;

  @override
  Future<http.Response> post(String endpoint,
      {required Map<String, dynamic> body,
      bool requireAuth = false,
      Map<String, String>? headers}) async {
    writes.add('POST $endpoint');
    return _offline;
  }

  @override
  Future<http.Response> put(String endpoint,
      {required Map<String, dynamic> body,
      bool requireAuth = false,
      Map<String, String>? headers}) async {
    writes.add('PUT $endpoint');
    return _offline;
  }

  @override
  Future<http.Response> patch(String endpoint,
      {required Map<String, dynamic> body,
      bool requireAuth = false,
      Map<String, String>? headers}) async {
    writes.add('PATCH $endpoint');
    return _offline;
  }

  @override
  Future<http.Response> delete(String endpoint,
      {Map<String, dynamic>? body,
      bool requireAuth = false,
      Map<String, String>? headers}) async {
    writes.add('DELETE $endpoint');
    return _offline;
  }
}
