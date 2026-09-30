import 'package:flutter_test/flutter_test.dart';
import 'package:wanderer_frontend/core/constants/enums.dart';
import 'package:wanderer_frontend/core/services/background_update_manager.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';

void main() {
  Trip trip(TripStatus status) => Trip(
        id: 't1',
        userId: 'u1',
        name: 'Trip',
        username: 'me',
        visibility: Visibility.public,
        status: status,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

  test('auto check-ins continue only while the trip is live', () async {
    for (final s in TripStatus.values) {
      expect(await shouldKeepAutoUpdating(() async => trip(s)),
          s == TripStatus.inProgress,
          reason: '$s');
    }
  });

  test('a failed status lookup keeps the chain going', () async {
    expect(await shouldKeepAutoUpdating(() async => throw Exception('offline')),
        isTrue);
  });
}
