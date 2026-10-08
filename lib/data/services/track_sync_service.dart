import 'package:flutter/foundation.dart';

import '../../core/errors/app_exception.dart';
import '../client/command/track_point_command_client.dart';
import '../client/command/trip_update_command_client.dart';
import '../storage/track_store.dart';

/// Outcome of [TrackSyncService.flush].
typedef FlushResult = ({
  /// The backend refused the trip (403/404/409) and its queue was dropped.
  int? rejectedStatus,

  /// Whether anything is still waiting (to retry on the next trigger).
  bool hasPending,
});

/// Uploads what the phone recorded offline: track points in batches, then
/// the check-in outbox. Safe to call often and from anywhere — every upload
/// is idempotent server-side.
class TrackSyncService {
  /// Max points per request (backend limit).
  static const int batchSize = 500;

  /// Statuses meaning the backend will never take this trip's data.
  static const Set<int> _tripGone = {403, 404, 409};

  final TrackStore _store;
  final TrackPointCommandClient _trackPointClient;
  final TripUpdateCommandClient _tripUpdateClient;

  TrackSyncService({
    TrackStore? store,
    TrackPointCommandClient? trackPointCommandClient,
    TripUpdateCommandClient? tripUpdateCommandClient,
  })  : _store = store ?? TrackStore(),
        _trackPointClient =
            trackPointCommandClient ?? TrackPointCommandClient(),
        _tripUpdateClient =
            tripUpdateCommandClient ?? TripUpdateCommandClient();

  /// Uploads [tripId]'s unsynced points, then its pending check-ins.
  /// Network and server failures stay queued for the next trigger.
  // ponytail: concurrent flushes of one trip may upload twice; harmless as
  // both endpoints are idempotent. Add a per-trip lock if bandwidth matters.
  Future<FlushResult> flush(String tripId) async {
    try {
      while (true) {
        final batch = await _store.unsyncedPoints(tripId, limit: batchSize);
        if (batch.isEmpty) break;
        await _trackPointClient.uploadTrackPoints(tripId, batch);
        await _store.markSynced([for (final p in batch) p.id]);
        if (batch.length < batchSize) break;
      }

      for (final checkIn in await _store.pendingCheckIns(tripId)) {
        try {
          await _tripUpdateClient.postTripUpdateJson(tripId, checkIn.json);
        } on ApiException catch (e) {
          // A malformed check-in can never succeed; don't let it block the
          // ones behind it.
          if (e.statusCode != 400) rethrow;
          debugPrint('TrackSync: dropping rejected check-in ${checkIn.id}: $e');
        }
        await _store.removePendingCheckIn(checkIn.id);
      }
      return (rejectedStatus: null, hasPending: false);
    } on ApiException catch (e) {
      if (_tripGone.contains(e.statusCode)) {
        debugPrint('TrackSync: trip $tripId refused (${e.statusCode}), '
            'dropping its queue');
        await _store.dropTrip(tripId);
        return (rejectedStatus: e.statusCode, hasPending: false);
      }
      debugPrint('TrackSync: $tripId will retry: $e');
      return (rejectedStatus: null, hasPending: true);
    } catch (e) {
      debugPrint('TrackSync: $tripId will retry: $e');
      return (rejectedStatus: null, hasPending: true);
    }
  }

  /// [flush] for every trip with something queued (e.g. on app resume).
  Future<void> flushAll() async {
    try {
      for (final tripId in await _store.tripsWithPendingData()) {
        await flush(tripId);
      }
    } catch (e) {
      debugPrint('TrackSync: flushAll failed: $e');
    }
  }
}
