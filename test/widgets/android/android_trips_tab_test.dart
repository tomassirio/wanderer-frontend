import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wanderer_frontend/core/constants/enums.dart' as e;
import 'package:wanderer_frontend/core/providers/app_providers.dart';
import 'package:wanderer_frontend/data/models/responses/page_response.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/data/repositories/home_repository.dart';
import 'package:wanderer_frontend/presentation/screens/android/android_trips_tab.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AndroidTripsTab.resetPlansRequest();
  });

  testWidgets('showPlans switches to the Plans sub tab, every time',
      (tester) async {
    await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: AndroidTripsTab())));
    await tester.pump();
    final controller =
        DefaultTabController.of(tester.element(find.byType(TabBarView)));
    expect(controller.index, 0);

    AndroidTripsTab.showPlans();
    await tester.pump(const Duration(milliseconds: 400));
    expect(controller.index, 1);

    // Back to My trips, then ask again: must still switch.
    controller.index = 0;
    await tester.pump(const Duration(milliseconds: 400));
    AndroidTripsTab.showPlans();
    await tester.pump(const Duration(milliseconds: 400));
    expect(controller.index, 1);
  });

  testWidgets('a tab rebuilt right after showPlans still opens Plans',
      (tester) async {
    AndroidTripsTab.showPlans();
    // e.g. the shell rebuilding its tabs after "Save as a plan".
    await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: AndroidTripsTab())));
    await tester.pump(const Duration(milliseconds: 400));
    final controller =
        DefaultTabController.of(tester.element(find.byType(TabBarView)));
    expect(controller.index, 1);
  });

  testWidgets('no Drafts chip; one-time Plans notice links to Plans',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [homeRepositoryProvider.overrideWithValue(_Home())],
      child: const MaterialApp(home: AndroidTripsTab()),
    ));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('Drafts'), findsNothing);
    // The old Draft is still listed and openable under All.
    expect(find.text('Old draft'), findsOneWidget);
    expect(find.byKey(const Key('trips_plans_notice')), findsOneWidget);

    await tester.tap(find.text('See'));
    await tester.pump(const Duration(milliseconds: 400));
    final controller =
        DefaultTabController.of(tester.element(find.byType(TabBarView)));
    expect(controller.index, 1);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('trips_plans_notice_seen'), isTrue);
  });
}

class _Home extends HomeRepository {
  @override
  Future<PageResponse<Trip>> getMyTrips({int page = 0, int size = 20}) async =>
      PageResponse(
        content: [
          Trip(
            id: 'd',
            userId: 'u',
            name: 'Old draft',
            username: 'me',
            visibility: e.Visibility.private,
            status: e.TripStatus.created,
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          ),
        ],
        totalElements: 1,
        totalPages: 1,
        number: 0,
        size: 100,
        first: true,
        last: true,
      );
}
