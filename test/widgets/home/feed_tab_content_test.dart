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
import 'package:wanderer_frontend/presentation/widgets/home/feed_tab_content.dart';
import 'package:wanderer_frontend/presentation/widgets/home/load_more_trips_button.dart';

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

Trip _trip(String id, String userId, TripStatus status) {
  final now = DateTime(2026, 1, 1);
  return Trip(
    id: id,
    userId: userId,
    username: userId,
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
  group('FeedTabContent Widget', () {
    testWidgets('shows the empty-state copy when the feed is empty',
        (WidgetTester tester) async {
      final l10n = AppLocalizations('en');
      await tester.pumpWidget(
        _wrap(
          FeedTabContent(
            onRefresh: () async {},
            onLoadMore: () {},
            onTripTap: (_) {},
            onDeleteTrip: (_) {},
          ),
          const HomeFeedState(),
        ),
      );

      expect(find.text(l10n.noTripsInYourFeed), findsOneWidget);
      expect(find.byType(EnhancedTripCard), findsNothing);
    });

    testWidgets(
        'renders live/friends/following groups and a load-more button when '
        'more trips are available', (WidgetTester tester) async {
      // Tall viewport so every relationship group's card renders (offscreen
      // sliver children otherwise stay unmounted).
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final trips = [
        _trip('live', 'friend1', TripStatus.inProgress),
        _trip('friend', 'friend1', TripStatus.paused),
        _trip('following', 'follow1', TripStatus.paused),
      ];

      await tester.pumpWidget(
        _wrap(
          FeedTabContent(
            onRefresh: () async {},
            onLoadMore: () {},
            onTripTap: (_) {},
            onDeleteTrip: (_) {},
          ),
          HomeFeedState(
            feedTrips: trips,
            friendIds: const {'friend1'},
            followingIds: const {'follow1'},
            hasMoreTrips: true,
          ),
        ),
      );

      expect(find.byType(EnhancedTripCard), findsNWidgets(3));
      expect(find.byType(LoadMoreTripsButton), findsOneWidget);
    });
  });
}
