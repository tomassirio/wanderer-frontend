import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wanderer_frontend/presentation/screens/android/android_trips_tab.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

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
}
