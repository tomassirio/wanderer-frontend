import 'package:flutter_test/flutter_test.dart';
import 'package:wanderer_frontend/core/constants/enums.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/data/services/trip_update_service.dart';
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
}
