import 'package:flutter_test/flutter_test.dart';
import 'package:wanderer_frontend/core/constants/enums.dart';
import 'package:wanderer_frontend/core/services/background_update_manager.dart';
import 'package:wanderer_frontend/data/models/domain/trip.dart';

void main() {
  group('BackgroundUpdateManager Constants', () {
    test('Trip minUpdateRefresh is 1 minute (60 seconds)', () {
      // Minimum is 1 minute since we use chained one-off tasks
      // instead of periodic tasks (no 15 min WorkManager constraint)
      expect(Trip.minUpdateRefresh, 60);
    });

    test('Trip defaultUpdateRefresh is 30 minutes (1800 seconds)', () {
      expect(Trip.defaultUpdateRefresh, 1800);
    });

    test('defaultUpdateRefresh is greater than minUpdateRefresh', () {
      expect(Trip.defaultUpdateRefresh, greaterThan(Trip.minUpdateRefresh));
    });
  });

  group('Update Interval Clamping Logic', () {
    test('interval below minimum is clamped to minimum', () {
      const intervalSeconds = 30; // 30 seconds - below minimum
      final clampedInterval = intervalSeconds < Trip.minUpdateRefresh
          ? Trip.minUpdateRefresh
          : intervalSeconds;

      expect(clampedInterval, Trip.minUpdateRefresh);
    });

    test('interval at minimum is not changed', () {
      final intervalSeconds = Trip.minUpdateRefresh;
      final clampedInterval = intervalSeconds < Trip.minUpdateRefresh
          ? Trip.minUpdateRefresh
          : intervalSeconds;

      expect(clampedInterval, Trip.minUpdateRefresh);
    });

    test('interval above minimum is not changed', () {
      const intervalSeconds = 3600; // 1 hour
      final clampedInterval = intervalSeconds < Trip.minUpdateRefresh
          ? Trip.minUpdateRefresh
          : intervalSeconds;

      expect(clampedInterval, 3600);
    });

    test('zero interval is clamped to minimum', () {
      const intervalSeconds = 0;
      final clampedInterval = intervalSeconds < Trip.minUpdateRefresh
          ? Trip.minUpdateRefresh
          : intervalSeconds;

      expect(clampedInterval, Trip.minUpdateRefresh);
    });

    test('negative interval is clamped to minimum', () {
      const intervalSeconds = -100;
      final clampedInterval = intervalSeconds < Trip.minUpdateRefresh
          ? Trip.minUpdateRefresh
          : intervalSeconds;

      expect(clampedInterval, Trip.minUpdateRefresh);
    });
  });

  group('BackgroundUpdateManager.recordsTrack', () {
    Trip trip(TripModality modality, {required bool auto}) => Trip(
          id: 't',
          userId: 'u',
          name: 'Trip',
          username: 'user',
          visibility: Visibility.public,
          status: TripStatus.inProgress,
          tripModality: modality,
          automaticUpdates: auto,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        );

    test('single-day trips always record', () {
      expect(
          BackgroundUpdateManager.recordsTrack(
              trip(TripModality.simple, auto: false)),
          isTrue);
    });

    test('multi-day trips record only with automatic updates', () {
      expect(
          BackgroundUpdateManager.recordsTrack(
              trip(TripModality.multiDay, auto: true)),
          isTrue);
      expect(
          BackgroundUpdateManager.recordsTrack(
              trip(TripModality.multiDay, auto: false)),
          isFalse);
    });
  });
}
