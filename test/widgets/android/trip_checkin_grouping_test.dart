import 'package:flutter_test/flutter_test.dart';
import 'package:wanderer_frontend/core/constants/enums.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/data/services/trip_update_service.dart';
import 'package:wanderer_frontend/data/storage/track_store.dart';
import 'package:wanderer_frontend/presentation/widgets/android/trip_checkin_sheet.dart';

void main() {
  final t0 = DateTime(2026, 9, 29, 22, 45);
  TripLocation u(String id, int minutesAgo,
          {String? city = 'Nieuwegein',
          String? message = TripUpdateService.automaticUpdateMessage,
          TripUpdateType type = TripUpdateType.regular}) =>
      TripLocation(
        id: id,
        latitude: 0,
        longitude: 0,
        city: city,
        country: 'Netherlands',
        message: message,
        updateType: type,
        timestamp: t0.subtract(Duration(minutes: minutesAgo)),
      );

  List<List<String>> ids(List<List<TripLocation>> g) =>
      [for (final x in g) x.map((e) => e.id).toList()];

  test('folds consecutive check-ins at one place within the window', () {
    final groups = groupCheckIns([
      u('a', 0),
      u('b', 2),
      u('c', 10),
      u('d', 40), // 30 min gap: new group
      u('e', 42, city: 'Utrecht'), // other place
      u('f', 44, message: 'Coffee stop'), // user message stands alone
      u('g', 45, type: TripUpdateType.tripStarted),
    ]);
    expect(ids(groups), [
      ['a', 'b', 'c'],
      ['d'],
      ['e'],
      ['f'],
      ['g'],
    ]);
  });

  test('auto placeholder is not shown as a message', () {
    expect(isAutoCheckIn(u('a', 0)), isTrue);
    expect(tripCheckInMessage(u('a', 0)), isNull);
    expect(tripCheckInMessage(u('b', 0, message: ' Hi ')), 'Hi');
  });

  group('pending check-ins', () {
    PendingCheckIn pending(String id, {String? recordedAt}) => PendingCheckIn(
          id: id,
          tripId: 'trip-1',
          json: TripUpdateRequest(
            latitude: 52.09,
            longitude: 5.12,
            message: 'Coffee stop',
            battery: 80,
            id: id,
            recordedAt: recordedAt == null ? null : DateTime.parse(recordedAt),
          ).toJson(),
          createdAt: t0,
        );

    test('a queued check-in maps to a pending timeline item', () {
      final u =
          pending('p-1', recordedAt: '2026-09-29T20:00:00Z').toTripLocation();
      expect(u.id, 'p-1');
      expect(u.pending, isTrue);
      expect(u.latitude, 52.09);
      expect(u.longitude, 5.12);
      expect(u.message, 'Coffee stop');
      expect(u.battery, 80);
      expect(u.timestamp, DateTime.utc(2026, 9, 29, 20));
    });

    test('without recordedAt it is dated when it was queued', () {
      expect(pending('p-1').toTripLocation().timestamp, t0);
    });

    test('pending check-ins go on top, newest first', () {
      final p1 = u('p1', 5).copyWith(pending: true);
      final p2 = u('p2', 1).copyWith(pending: true);
      final merged = withPendingCheckIns([u('a', 10), u('b', 20)], [p1, p2]);
      expect(merged.map((e) => e.id), ['p2', 'p1', 'a', 'b']);
    });

    test('a sent check-in shows once, as a normal one', () {
      final merged = withPendingCheckIns(
          [u('p1', 5), u('a', 10)], [u('p1', 5).copyWith(pending: true)]);
      expect(merged.map((e) => e.id), ['p1', 'a']);
      expect(merged.first.pending, isFalse);
    });

    test('pending check-ins never fold into a group', () {
      final groups = groupCheckIns(
          [u('p1', 0).copyWith(pending: true), u('a', 1), u('b', 2)]);
      expect(ids(groups), [
        ['p1'],
        ['a', 'b'],
      ]);
    });
  });
}
