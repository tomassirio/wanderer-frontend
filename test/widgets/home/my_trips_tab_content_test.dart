import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wanderer_frontend/core/constants/enums.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/presentation/state/home_feed/home_feed_notifier.dart';
import 'package:wanderer_frontend/presentation/state/home_feed/home_feed_state.dart';
import 'package:wanderer_frontend/presentation/state/user_chrome/user_chrome_notifier.dart';
import 'package:wanderer_frontend/presentation/state/user_chrome/user_chrome_state.dart';
import 'package:wanderer_frontend/presentation/widgets/home/enhanced_trip_card.dart';
import 'package:wanderer_frontend/presentation/widgets/home/my_trips_tab_content.dart';

class _FakeHomeFeedNotifier extends HomeFeedNotifier {
  _FakeHomeFeedNotifier(this._initial);
  final HomeFeedState _initial;

  @override
  HomeFeedState build() => _initial;
}

class _FakeUserChromeNotifier extends UserChromeNotifier {
  _FakeUserChromeNotifier(this._initial);
  final UserChromeState _initial;

  @override
  UserChromeState build() => _initial;
}

Trip _trip(String id, TripStatus status) {
  final now = DateTime(2026, 1, 1);
  return Trip(
    id: id,
    userId: 'me',
    username: 'me',
    name: 'Trip $id',
    visibility: Visibility.public,
    status: status,
    createdAt: now,
    updatedAt: now,
  );
}

Widget _wrap(Widget child, HomeFeedState feedState) {
  return ProviderScope(
    overrides: [
      homeFeedNotifierProvider.overrideWith(
        () => _FakeHomeFeedNotifier(feedState),
      ),
      userChromeNotifierProvider.overrideWith(
        () => _FakeUserChromeNotifier(const UserChromeState(userId: 'me')),
      ),
    ],
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  group('MyTripsTabContent Widget', () {
    testWidgets('shows the empty-state copy when there are no trips',
        (WidgetTester tester) async {
      final l10n = AppLocalizations('en');
      await tester.pumpWidget(
        _wrap(
          MyTripsTabContent(
            onRefresh: () async {},
            onTripTap: (_) {},
            onDeleteTrip: (_) {},
          ),
          const HomeFeedState(),
        ),
      );

      expect(find.text(l10n.noTripsYet), findsOneWidget);
      expect(find.byType(EnhancedTripCard), findsNothing);
    });

    testWidgets('groups trips by status and forwards taps',
        (WidgetTester tester) async {
      // Tall viewport so every status group's card renders (offscreen
      // sliver children otherwise stay unmounted).
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      Trip? tapped;
      final trips = [
        _trip('active', TripStatus.inProgress),
        _trip('paused', TripStatus.paused),
        _trip('draft', TripStatus.created),
        _trip('done', TripStatus.finished),
      ];

      await tester.pumpWidget(
        _wrap(
          MyTripsTabContent(
            onRefresh: () async {},
            onTripTap: (trip) => tapped = trip,
            onDeleteTrip: (_) {},
          ),
          HomeFeedState(myTrips: trips),
        ),
      );

      expect(find.byType(EnhancedTripCard), findsNWidgets(4));

      await tester.tap(find.byKey(const ValueKey('active')));
      await tester.pump();

      expect(tapped?.id, 'active');
    });
  });
}
