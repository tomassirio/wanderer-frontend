import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wanderer_frontend/core/constants/enums.dart';
import 'package:wanderer_frontend/core/providers/app_providers.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/data/services/url_shortener_service.dart';
import 'package:wanderer_frontend/presentation/helpers/dialog_helper.dart';
import 'package:wanderer_frontend/presentation/widgets/common/wanderer_dialog.dart';
import 'package:wanderer_frontend/presentation/widgets/trip_detail/trip_settings_panel.dart';
import 'package:wanderer_frontend/presentation/widgets/trip_detail/trip_share_dialog.dart';
import 'package:wanderer_frontend/presentation/widgets/trip_plans/trip_from_plan_dialog.dart';

class _FakeShortener implements UrlShortenerService {
  @override
  Future<String?> shorten(String url) async => 'https://wndr.io/abc';
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

void main() {
  final sizes = {'desktop': const Size(1440, 900), 'phone': const Size(390, 844)};
  final cases = <String, void Function(BuildContext)>{
    'share': (c) => TripShareDialog.show(c, tripId: 't1', tripName: 'Camino'),
    'fromPlan': (c) =>
        TripFromPlanDialog.show(c, planName: 'Europe', planType: 'SIMPLE'),
    'picker': (c) => DialogHelper.showWebOptions<int>(c,
        title: 'Change visibility',
        selected: 1,
        options: const [
          DialogOption(icon: Icons.public, label: 'Public', subtitle: 'Everyone', value: 0),
          DialogOption(icon: Icons.lock, label: 'Private', value: 1),
        ]),
    'confirm': (c) => WandererDialog.confirm(c,
        title: 'Delete this user?',
        message: 'x will be removed',
        confirmLabel: 'Delete user',
        destructive: true),
    'settings': (c) => WandererDialog.show<void>(c,
        builder: (_) => WandererFormDialog(
              title: 'Trip settings',
              body: TripSettingsPanel(
                isCollapsed: false,
                onToggleCollapse: () {},
                isOwner: true,
                tripHasPlannedRoute: true,
                showPlannedWaypoints: true,
                onTogglePlannedWaypoints: () {},
                automaticUpdates: false,
                isLoading: false,
                tripStatus: TripStatus.inProgress,
                onDeleteTrip: () {},
                embedded: true,
              ),
              actions: [ElevatedButton(onPressed: () {}, child: const Text('Done'))],
            )),
  };
  for (final dark in [false, true]) {
    for (final s in sizes.entries) {
      for (final e in cases.entries) {
        testWidgets('${e.key} ${s.key} dark=$dark', (tester) async {
          expect(kIsWeb, isTrue);
          tester.view.physicalSize = s.value;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(ProviderScope(
            overrides: [urlShortenerServiceProvider.overrideWithValue(_FakeShortener())],
            child: MaterialApp(
              theme: dark ? WandererTheme.darkTheme() : WandererTheme.lightTheme(),
              home: Builder(
                  builder: (c) => Scaffold(
                      body: Center(
                          child: TextButton(
                              onPressed: () => e.value(c), child: const Text('open'))))),
            ),
          ));
          await tester.tap(find.text('open'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          if (s.key == 'desktop' && !dark) {
            await expectLater(find.byType(MaterialApp),
                matchesGoldenFile('/tmp/dialogs_${e.key}.png'));
          }
        });
      }
    }
  }
}
