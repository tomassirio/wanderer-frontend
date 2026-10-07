import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter_test/flutter_test.dart';
import 'package:wanderer_frontend/core/constants/enums.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/presentation/screens/android/android_explore_tab.dart';
import 'package:wanderer_frontend/presentation/screens/android/android_home_tab.dart';
import 'package:wanderer_frontend/presentation/screens/android/android_search_screen.dart';
import 'package:wanderer_frontend/presentation/widgets/android/home_live_trip_card.dart';

Trip _trip(String id,
        {String user = 'u',
        TripStatus status = TripStatus.inProgress,
        Visibility vis = Visibility.public,
        bool promoted = false,
        DateTime? start}) =>
    Trip(
      id: id,
      userId: user,
      name: id,
      username: user,
      visibility: vis,
      status: status,
      isPromoted: promoted,
      startDate: start,
      createdAt: DateTime(2026, 1, int.parse(id.substring(1))),
      updatedAt: DateTime(2026, 1, int.parse(id.substring(1))),
    );

void main() {
  final l10n = AppLocalizations('en');

  test('greeting follows the hour', () {
    expect(homeGreeting(l10n, 8, 'Ana'), 'Morning, Ana');
    expect(homeGreeting(l10n, 13, 'Ana'), 'Afternoon, Ana');
    expect(homeGreeting(l10n, 20, 'Ana'), 'Evening, Ana');
  });

  test('friends on the road: friends only, visible, active, live first', () {
    final trips = [
      _trip('t1', user: 'f', status: TripStatus.paused),
      _trip('t2', user: 'f'),
      _trip('t3', user: 'f', vis: Visibility.private),
      _trip('t4', user: 'f', status: TripStatus.finished),
      _trip('t5', user: 'stranger'),
    ];
    expect(friendsOnTheRoad(trips, {'f'}).map((t) => t.id), ['t2', 't1']);
  });

  test('explore filters', () {
    final trips = [
      _trip('t1'),
      _trip('t2', status: TripStatus.finished),
      _trip('t3', status: TripStatus.finished, promoted: true),
      _trip('t4', user: 'f', vis: Visibility.protected),
      _trip('t5', status: TripStatus.created),
    ];
    ids(ExploreFilter f) => exploreTrips(trips, f, {'f'}).map((t) => t.id);
    // Public completed trips show even when not promoted (t2), like web.
    expect(ids(ExploreFilter.all), ['t3', 't2', 't1']);
    expect(ids(ExploreFilter.live), ['t1']);
    expect(ids(ExploreFilter.completed), ['t3', 't2']);
    expect(ids(ExploreFilter.friends), ['t4']);
  });

  test('live label', () {
    final now = DateTime(2026, 1, 1, 10, 0);
    expect(homeLiveLabel(l10n, _trip('t1'), now), 'Live');
    expect(
        homeLiveLabel(
            l10n, _trip('t1', start: DateTime(2026, 1, 1, 8, 48)), now),
        'Live · 1 h 12 min');
    expect(homeLiveLabel(l10n, _trip('t1', start: DateTime(2025, 12, 30)), now),
        'Live · Day 3');
  });

  test('search highlight splits every match, case-insensitive', () {
    final spans = searchHighlight('Jul and jules', 'jul', Colors.orange);
    expect(spans.map((s) => s.text), ['Jul', ' and ', 'jul', 'es']);
    expect(spans[0].style?.color, Colors.orange);
    expect(spans[1].style, isNull);
  });

  test('active travelers: public, not me or known, live first, one per user',
      () {
    final trips = [
      _trip('t1', user: 'ana', status: TripStatus.finished),
      _trip('t2', user: 'ana'),
      _trip('t3', user: 'me'),
      _trip('t4', user: 'friend'),
      _trip('t5', user: 'leo', vis: Visibility.private),
      _trip('t6', user: 'sam', status: TripStatus.finished),
      _trip('t7', user: 'kai', status: TripStatus.created),
    ];
    final r = activeTravelers(trips, me: 'me', known: {'friend'});
    expect(r.map((e) => e.$1.username), ['ana', 'sam']);
    expect(r.first.$2.id, 't2');
  });
}
