import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wanderer_frontend/core/constants/enums.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/presentation/state/home_feed/home_feed_notifier.dart';
import 'package:wanderer_frontend/presentation/state/home_feed/home_feed_state.dart';
import 'package:wanderer_frontend/presentation/widgets/home/filter_chip_button.dart';
import 'package:wanderer_frontend/presentation/widgets/home/home_filter_chips.dart';

class _FakeHomeFeedNotifier extends HomeFeedNotifier {
  _FakeHomeFeedNotifier(this._initial);
  final HomeFeedState _initial;

  @override
  HomeFeedState build() => _initial;
}

Widget _wrap(Widget child, HomeFeedState state) {
  return ProviderScope(
    overrides: [
      homeFeedNotifierProvider.overrideWith(
        () => _FakeHomeFeedNotifier(state),
      ),
    ],
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  group('HomeFilterChips Widget', () {
    testWidgets('shows only the status chip outside the My Trips tab',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          const HomeFilterChips(isMyTripsTab: false),
          const HomeFeedState(),
        ),
      );

      expect(find.byType(FilterChipButton<TripStatus?>), findsOneWidget);
      expect(find.byType(FilterChipButton<Visibility?>), findsNothing);
    });

    testWidgets('shows both chips on the My Trips tab',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          const HomeFilterChips(isMyTripsTab: true),
          const HomeFeedState(),
        ),
      );

      expect(find.byType(FilterChipButton<TripStatus?>), findsOneWidget);
      expect(find.byType(FilterChipButton<Visibility?>), findsOneWidget);
    });

    testWidgets('selecting a status option updates the notifier state',
        (WidgetTester tester) async {
      final container = ProviderContainer(
        overrides: [
          homeFeedNotifierProvider.overrideWith(
            () => _FakeHomeFeedNotifier(const HomeFeedState()),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: HomeFilterChips(isMyTripsTab: false)),
          ),
        ),
      );

      final l10n = AppLocalizations('en');
      await tester.tap(find.byType(FilterChipButton<TripStatus?>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.live).last);
      await tester.pumpAndSettle();

      expect(
        container.read(homeFeedNotifierProvider).statusFilter,
        TripStatus.inProgress,
      );
    });
  });
}
