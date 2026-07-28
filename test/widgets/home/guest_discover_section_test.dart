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
import 'package:wanderer_frontend/presentation/widgets/home/guest_discover_section.dart';

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

Trip _trip(String id) {
  final now = DateTime(2026, 1, 1);
  return Trip(
    id: id,
    userId: 'other',
    username: 'other',
    name: 'Trip $id',
    visibility: Visibility.public,
    status: TripStatus.inProgress,
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
      userChromeNotifierProvider
          .overrideWith(() => _FakeUserChromeNotifier(const UserChromeState())),
    ],
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  group('GuestDiscoverSection Widget', () {
    testWidgets('shows the empty-state copy when there are no public trips',
        (WidgetTester tester) async {
      final l10n = AppLocalizations('en');
      await tester.pumpWidget(
        _wrap(
          GuestDiscoverSection(onTripTap: (_) {}, onDeleteTrip: (_) {}),
          const HomeFeedState(),
        ),
      );

      expect(find.text(l10n.noPublicTripsFound), findsOneWidget);
      expect(find.byType(EnhancedTripCard), findsNothing);
    });

    testWidgets('renders public trips without a ListView/Refresh wrapper',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          GuestDiscoverSection(onTripTap: (_) {}, onDeleteTrip: (_) {}),
          HomeFeedState(discoverTrips: [_trip('t1'), _trip('t2')]),
        ),
      );

      expect(find.byType(EnhancedTripCard), findsNWidgets(2));
      expect(find.byType(RefreshIndicator), findsNothing);
      expect(find.byType(ListView), findsNothing);
    });
  });
}
