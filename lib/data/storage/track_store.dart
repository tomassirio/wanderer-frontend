import 'dart:async';
import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../models/trip_models.dart';

/// A check-in waiting in the outbox: the serialised [TripUpdateRequest]
/// (with its client `id` and `recordedAt`).
class PendingCheckIn {
  final String id;
  final String tripId;
  final Map<String, dynamic> json;
  final DateTime createdAt;

  const PendingCheckIn({
    required this.id,
    required this.tripId,
    required this.json,
    required this.createdAt,
  });
}

/// The phone's local track and check-in outbox, in SQLite
/// `wanderer_track.db` (Android only).
///
/// The native recorder (`TripTrackingService.kt`) inserts into
/// `track_points` on its own connection; this class reads and syncs them, and
/// owns `pending_checkins`. Both sides create their tables with
/// `IF NOT EXISTS` and leave `user_version` alone, so neither depends on who
/// opened the file first.
class TrackStore {
  static const String fileName = 'wanderer_track.db';

  static Future<Database>? _db;

  Future<Database> get _database => _db ??= _open();

  static Future<Database> _open() async {
    final db = await openDatabase('${await getDatabasesPath()}/$fileName');
    // Keep in sync with TripTrackingService.openTrackDb.
    await db.execute('CREATE TABLE IF NOT EXISTS track_points('
        'id TEXT PRIMARY KEY, trip_id TEXT NOT NULL, lat REAL NOT NULL, '
        'lon REAL NOT NULL, accuracy_m REAL, altitude_m REAL, '
        'recorded_at INTEGER NOT NULL, synced INTEGER NOT NULL DEFAULT 0)');
    await db.execute('CREATE INDEX IF NOT EXISTS track_points_trip '
        'ON track_points(trip_id, recorded_at)');
    await db.execute('CREATE TABLE IF NOT EXISTS pending_checkins('
        'id TEXT PRIMARY KEY, trip_id TEXT NOT NULL, json TEXT NOT NULL, '
        'created_at INTEGER NOT NULL)');
    return db;
  }

  // ---------------------------------------------------------------------------
  // Track points
  // ---------------------------------------------------------------------------

  /// All recorded points of [tripId] (synced or not), oldest first.
  /// [since] limits it to points recorded after that instant.
  Future<List<TrackPoint>> track(String tripId, {DateTime? since}) async {
    final rows = await (await _database).query(
      'track_points',
      where: since == null ? 'trip_id = ?' : 'trip_id = ? AND recorded_at > ?',
      whereArgs: [tripId, if (since != null) since.millisecondsSinceEpoch],
      orderBy: 'recorded_at',
    );
    return rows.map(TrackPoint.fromRow).toList();
  }

  /// [track] now and then every [interval], emitting only when it grew.
  /// The recorder writes from native code, so there is nothing to listen to.
  Stream<List<TrackPoint>> watchTrack(String tripId,
      {Duration interval = const Duration(seconds: 5)}) async* {
    var first = true;
    String? lastId;
    while (true) {
      final points = await track(tripId);
      final id = points.isEmpty ? null : points.last.id;
      if (first || id != lastId) yield points;
      first = false;
      lastId = id;
      await Future<void>.delayed(interval);
    }
  }

  /// The most recent point of [tripId], if any.
  Future<TrackPoint?> latestPoint(String tripId) async {
    final rows = await (await _database).query('track_points',
        where: 'trip_id = ?',
        whereArgs: [tripId],
        orderBy: 'recorded_at DESC',
        limit: 1);
    return rows.isEmpty ? null : TrackPoint.fromRow(rows.first);
  }

  /// Up to [limit] points of [tripId] the backend hasn't accepted yet.
  Future<List<TrackPoint>> unsyncedPoints(String tripId,
      {int limit = 500}) async {
    final rows = await (await _database).query('track_points',
        where: 'trip_id = ? AND synced = 0',
        whereArgs: [tripId],
        orderBy: 'recorded_at',
        limit: limit);
    return rows.map(TrackPoint.fromRow).toList();
  }

  Future<void> markSynced(List<String> ids) async {
    if (ids.isEmpty) return;
    await (await _database).update('track_points', {'synced': 1},
        where: 'id IN (${List.filled(ids.length, '?').join(',')})',
        whereArgs: ids);
  }

  // ---------------------------------------------------------------------------
  // Check-in outbox
  // ---------------------------------------------------------------------------

  Future<void> addPendingCheckIn(PendingCheckIn checkIn) async {
    await (await _database).insert(
      'pending_checkins',
      {
        'id': checkIn.id,
        'trip_id': checkIn.tripId,
        'json': jsonEncode(checkIn.json),
        'created_at': checkIn.createdAt.millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// Check-ins of [tripId] not sent yet, oldest first.
  Future<List<PendingCheckIn>> pendingCheckIns(String tripId) async {
    final rows = await (await _database).query('pending_checkins',
        where: 'trip_id = ?', whereArgs: [tripId], orderBy: 'created_at');
    return rows
        .map((r) => PendingCheckIn(
              id: r['id'] as String,
              tripId: r['trip_id'] as String,
              json: jsonDecode(r['json'] as String) as Map<String, dynamic>,
              createdAt:
                  DateTime.fromMillisecondsSinceEpoch(r['created_at'] as int),
            ))
        .toList();
  }

  Future<bool> isPending(String checkInId) async {
    final rows = await (await _database).query('pending_checkins',
        columns: ['id'], where: 'id = ?', whereArgs: [checkInId]);
    return rows.isNotEmpty;
  }

  Future<void> removePendingCheckIn(String checkInId) async {
    await (await _database)
        .delete('pending_checkins', where: 'id = ?', whereArgs: [checkInId]);
  }

  // ---------------------------------------------------------------------------
  // Housekeeping
  // ---------------------------------------------------------------------------

  /// Trips with unsynced points or pending check-ins.
  Future<List<String>> tripsWithPendingData() async {
    final rows = await (await _database).rawQuery(
        'SELECT trip_id FROM track_points WHERE synced = 0 '
        'UNION SELECT trip_id FROM pending_checkins');
    return rows.map((r) => r['trip_id'] as String).toList();
  }

  /// Forgets everything unsent for [tripId] (the backend will never take it).
  Future<void> dropTrip(String tripId) async {
    final db = await _database;
    await db.delete('track_points',
        where: 'trip_id = ? AND synced = 0', whereArgs: [tripId]);
    await db
        .delete('pending_checkins', where: 'trip_id = ?', whereArgs: [tripId]);
  }
}
