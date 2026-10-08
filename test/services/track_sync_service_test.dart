import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wanderer_frontend/core/errors/app_exception.dart';
import 'package:wanderer_frontend/data/client/command/track_point_command_client.dart';
import 'package:wanderer_frontend/data/client/command/trip_update_command_client.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/data/services/track_sync_service.dart';
import 'package:wanderer_frontend/data/storage/track_store.dart';

void main() {
  late MockTrackStore store;
  late MockTrackPointCommandClient points;
  late MockTripUpdateCommandClient updates;
  late TrackSyncService sync;

  setUp(() {
    store = MockTrackStore();
    points = MockTrackPointCommandClient();
    updates = MockTripUpdateCommandClient();
    sync = TrackSyncService(
      store: store,
      trackPointCommandClient: points,
      tripUpdateCommandClient: updates,
    );
  });

  group('TrackSyncService.flush', () {
    test('uploads points in batches of 500 and marks them synced', () async {
      store.addPoints('trip-1', 1201);

      final result = await sync.flush('trip-1');

      expect(points.batchSizes, [500, 500, 201]);
      expect(store.unsynced('trip-1'), isEmpty);
      expect(result.rejectedStatus, isNull);
      expect(result.hasPending, isFalse);
    });

    test('sends pending check-ins after the points, oldest first', () async {
      store.addPoints('trip-1', 3);
      store.addCheckIn('trip-1', 'c1');
      store.addCheckIn('trip-1', 'c2');

      await sync.flush('trip-1');

      expect(updates.sentIds, ['c1', 'c2']);
      expect(store.checkIns, isEmpty);
      expect(points.calls, 1);
    });

    for (final status in [403, 404, 409]) {
      test('drops the trip queue on $status', () async {
        store.addPoints('trip-1', 10);
        store.addPoints('trip-2', 2);
        store.addCheckIn('trip-1', 'c1');
        points.error = ApiException(statusCode: status, apiMessage: 'no');

        final result = await sync.flush('trip-1');

        expect(result.rejectedStatus, status);
        expect(result.hasPending, isFalse);
        expect(store.unsynced('trip-1'), isEmpty);
        expect(store.checkIns, isEmpty);
        expect(store.unsynced('trip-2'), hasLength(2));
      });

      test('drops the trip queue when a check-in gets $status', () async {
        store.addCheckIn('trip-1', 'c1');
        updates.error = ApiException(statusCode: status, apiMessage: 'no');

        final result = await sync.flush('trip-1');

        expect(result.rejectedStatus, status);
        expect(store.checkIns, isEmpty);
      });
    }

    test('keeps everything on a server error and retries next time', () async {
      store.addPoints('trip-1', 5);
      store.addCheckIn('trip-1', 'c1');
      points.error = const ApiException(statusCode: 500, apiMessage: 'boom');

      final first = await sync.flush('trip-1');

      expect(first.rejectedStatus, isNull);
      expect(first.hasPending, isTrue);
      expect(store.unsynced('trip-1'), hasLength(5));
      expect(store.checkIns, hasLength(1));
      expect(updates.sentIds, isEmpty);

      points.error = null;
      final second = await sync.flush('trip-1');

      expect(second.hasPending, isFalse);
      expect(store.unsynced('trip-1'), isEmpty);
      expect(updates.sentIds, ['c1']);
    });

    test('keeps everything when offline', () async {
      store.addPoints('trip-1', 5);
      points.error = const SocketException('offline');

      final result = await sync.flush('trip-1');

      expect(result.hasPending, isTrue);
      expect(store.unsynced('trip-1'), hasLength(5));
    });

    test('keeps a check-in that fails with a network error', () async {
      store.addCheckIn('trip-1', 'c1');
      updates.error = const SocketException('offline');

      final result = await sync.flush('trip-1');

      expect(result.hasPending, isTrue);
      expect(store.checkIns, hasLength(1));
    });

    test('drops a check-in the backend rejects as malformed (400)', () async {
      store.addCheckIn('trip-1', 'bad');
      store.addCheckIn('trip-1', 'good');
      updates.failIds['bad'] =
          const ApiException(statusCode: 400, apiMessage: 'bad');

      final result = await sync.flush('trip-1');

      expect(result.hasPending, isFalse);
      expect(updates.sentIds, ['good']);
      expect(store.checkIns, isEmpty);
    });

    test('does nothing when the queue is empty', () async {
      final result = await sync.flush('trip-1');

      expect(points.calls, 0);
      expect(updates.sentIds, isEmpty);
      expect(result.hasPending, isFalse);
    });
  });

  test('flushAll flushes every trip with queued data', () async {
    store.addPoints('trip-1', 2);
    store.addCheckIn('trip-2', 'c1');

    await sync.flushAll();

    expect(store.unsynced('trip-1'), isEmpty);
    expect(updates.sentIds, ['c1']);
  });
}

class MockTrackStore extends TrackStore {
  final List<TrackPoint> points = [];
  final List<PendingCheckIn> checkIns = [];

  void addPoints(String tripId, int count) {
    final start = DateTime.utc(2026, 10, 8);
    for (var i = 0; i < count; i++) {
      points.add(TrackPoint(
        id: '$tripId-p${points.length}',
        tripId: tripId,
        lat: 52,
        lon: 5,
        recordedAt: start.add(Duration(seconds: points.length)),
      ));
    }
  }

  void addCheckIn(String tripId, String id) => checkIns.add(PendingCheckIn(
      id: id, tripId: tripId, json: {'id': id}, createdAt: DateTime.now()));

  List<TrackPoint> unsynced(String tripId) =>
      points.where((p) => p.tripId == tripId && !p.synced).toList();

  @override
  Future<List<TrackPoint>> unsyncedPoints(String tripId,
          {int limit = 500}) async =>
      unsynced(tripId).take(limit).toList();

  @override
  Future<void> markSynced(List<String> ids) async {
    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      if (ids.contains(p.id)) {
        points[i] = TrackPoint(
            id: p.id,
            tripId: p.tripId,
            lat: p.lat,
            lon: p.lon,
            recordedAt: p.recordedAt,
            synced: true);
      }
    }
  }

  @override
  Future<List<PendingCheckIn>> pendingCheckIns(String tripId) async =>
      checkIns.where((c) => c.tripId == tripId).toList();

  @override
  Future<void> removePendingCheckIn(String checkInId) async =>
      checkIns.removeWhere((c) => c.id == checkInId);

  @override
  Future<List<String>> tripsWithPendingData() async => {
        for (final p in points)
          if (!p.synced) p.tripId,
        for (final c in checkIns) c.tripId,
      }.toList();

  @override
  Future<void> dropTrip(String tripId) async {
    points.removeWhere((p) => p.tripId == tripId && !p.synced);
    checkIns.removeWhere((c) => c.tripId == tripId);
  }
}

class MockTrackPointCommandClient extends TrackPointCommandClient {
  int calls = 0;
  final List<int> batchSizes = [];
  Object? error;

  @override
  Future<int> uploadTrackPoints(String tripId, List<TrackPoint> points) async {
    calls++;
    if (error != null) throw error!;
    batchSizes.add(points.length);
    return points.length;
  }
}

class MockTripUpdateCommandClient extends TripUpdateCommandClient {
  final List<String> sentIds = [];
  final Map<String, Object> failIds = {};
  Object? error;

  @override
  Future<String> postTripUpdateJson(
      String tripId, Map<String, dynamic> body) async {
    final id = body['id'] as String;
    if (error != null) throw error!;
    if (failIds[id] != null) throw failIds[id]!;
    sentIds.add(id);
    return id;
  }
}
