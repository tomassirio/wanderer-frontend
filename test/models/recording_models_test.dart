import 'package:flutter_test/flutter_test.dart';
import 'package:wanderer_frontend/core/constants/enums.dart';
import 'package:wanderer_frontend/data/models/domain/location_update_result.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';

void main() {
  group('RecordingProfile', () {
    test('single-day trips default to Live, everything else to Saver', () {
      expect(RecordingProfile.defaultFor(TripModality.simple),
          RecordingProfile.live);
      expect(RecordingProfile.defaultFor(TripModality.multiDay),
          RecordingProfile.saver);
      expect(RecordingProfile.defaultFor(null), RecordingProfile.saver);
    });

    test('Live uploads every 2 min without automatic check-ins', () {
      expect(RecordingProfile.live.uploadSeconds(900), 120);
      expect(RecordingProfile.live.autoCheckIn, isFalse);
    });

    test('Saver keeps the trip interval and automatic check-ins', () {
      expect(RecordingProfile.saver.uploadSeconds(900), 900);
      expect(RecordingProfile.saver.uploadSeconds(1800), 1800);
      expect(RecordingProfile.saver.autoCheckIn, isTrue);
    });

    test('wire names round-trip', () {
      for (final p in RecordingProfile.values) {
        expect(RecordingProfile.fromWireName(p.wireName), p);
      }
      expect(RecordingProfile.live.wireName, 'LIVE');
      expect(RecordingProfile.saver.wireName, 'SAVER');
      expect(RecordingProfile.fromWireName('nope'), isNull);
      expect(RecordingProfile.fromWireName(null), isNull);
    });
  });

  group('TrackPoint', () {
    test('toJson matches the upload contract', () {
      final p = TrackPoint(
        id: 'p1',
        tripId: 't1',
        lat: 52.09,
        lon: 5.12,
        accuracyM: 8,
        altitudeM: 3.1,
        recordedAt: DateTime.utc(2026, 10, 8, 9, 15, 2),
      );
      expect(p.toJson(), {
        'id': 'p1',
        'lat': 52.09,
        'lon': 5.12,
        'accuracyM': 8.0,
        'altitudeM': 3.1,
        'recordedAt': '2026-10-08T09:15:02.000Z',
      });
    });

    test('fromRow reads a track_points row', () {
      final p = TrackPoint.fromRow({
        'id': 'p1',
        'trip_id': 't1',
        'lat': 52.09,
        'lon': 5,
        'accuracy_m': null,
        'altitude_m': 3,
        'recorded_at': DateTime.utc(2026, 10, 8).millisecondsSinceEpoch,
        'synced': 1,
      });
      expect(p.lon, 5.0);
      expect(p.accuracyM, isNull);
      expect(p.altitudeM, 3.0);
      expect(p.recordedAt, DateTime.utc(2026, 10, 8));
      expect(p.synced, isTrue);
      expect(p.toJson().containsKey('accuracyM'), isFalse);
    });
  });

  group('TripUpdateRequest outbox fields', () {
    test('carries id and recordedAt', () {
      final json = TripUpdateRequest(
        latitude: 1,
        longitude: 2,
        id: 'c1',
        recordedAt: DateTime.utc(2026, 10, 8, 9),
      ).toJson();
      expect(json['id'], 'c1');
      expect(json['recordedAt'], '2026-10-08T09:00:00.000Z');
    });

    test('omits location for a marker without a fix', () {
      final json = TripUpdateRequest(
        latitude: null,
        longitude: null,
        updateType: TripUpdateType.dayEnd,
      ).toJson();
      expect(json.containsKey('location'), isFalse);
    });
  });

  test('a queued check-in is not a failure', () {
    const result = LocationUpdateResult.queued(latitude: 1, longitude: 2);
    expect(result.isSuccess, isTrue);
    expect(result.isQueued, isTrue);
    expect(result.failureReason, isNull);
    expect(const LocationUpdateResult.success().isQueued, isFalse);
  });
}
