import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../client/command/release_command_client.dart';
import '../client/query/release_query_client.dart';
import '../models/domain/release_note.dart';

/// What the Settings "What's new" row shows: the newest release up to the
/// installed version and whether the user has read it.
typedef WhatsNewStatus = ({ReleaseNote release, bool unread});

/// Release notes for travellers (What's new, changelog) and admins (edit,
/// publish). Read state lives on the server (`lastSeenVersion` per user);
/// the history is cached locally so it still shows offline.
class ReleaseNotesService {
  final ReleaseQueryClient _query;
  final ReleaseCommandClient _command;

  ReleaseNotesService({
    ReleaseQueryClient? queryClient,
    ReleaseCommandClient? commandClient,
  })  : _query = queryClient ?? ReleaseQueryClient(),
        _command = commandClient ?? ReleaseCommandClient();

  static const _cacheKey = 'release_notes_cache';

  String get platform => kIsWeb ? 'WEB' : 'ANDROID';

  /// Installed version as plain semver.
  Future<String> appVersion() async =>
      semver((await PackageInfo.fromPlatform()).version);

  /// Visible releases for this platform, newest first. Refreshes the cache.
  Future<List<ReleaseNote>> getReleases() async {
    final releases = await _query.getReleases(platform);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _cacheKey, jsonEncode([for (final r in releases) r.toJson()]));
    } catch (e) {
      debugPrint('ReleaseNotesService: cache write failed: $e');
    }
    return releases;
  }

  /// Releases from the last successful [getReleases], or null.
  Future<List<ReleaseNote>?> cachedReleases() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_cacheKey);
      if (raw == null) return null;
      return [
        for (final r in jsonDecode(raw) as List)
          ReleaseNote.fromJson(r as Map<String, dynamic>)
      ];
    } catch (e) {
      debugPrint('ReleaseNotesService: cache read failed: $e');
      return null;
    }
  }

  Future<({String? lastSeenVersion, List<ReleaseNote> releases})> getUnread(
          String currentVersion) =>
      _query.getUnread(platform, currentVersion);

  Future<void> markSeen(String version) => _command.markSeen(version);

  /// Release to pop up now, or null. New users (no last-seen yet) are
  /// silently baselined at the installed version, so they start there and
  /// the next release does show. Everyone else keeps their last-seen: notes
  /// are usually published after the update ships, and marking seen here
  /// would hide them.
  Future<ReleaseNote?> popupRelease() async {
    final version = await appVersion();
    final unread = await getUnread(version);
    if (unread.releases.isNotEmpty) return unread.releases.first;
    if (unread.lastSeenVersion == null) await markSeen(version);
    return null;
  }

  /// Settings row state. Offline: cached notes, never a dot. Null when there
  /// are no notes at all.
  Future<WhatsNewStatus?> status() async {
    final version = await appVersion();
    List<ReleaseNote>? releases;
    String? lastSeen;
    var online = true;
    try {
      final results = await Future.wait(
          [getReleases(), getUnread(version).then((u) => u.lastSeenVersion)]);
      releases = results[0] as List<ReleaseNote>;
      lastSeen = results[1] as String?;
    } catch (e) {
      debugPrint('ReleaseNotesService: status offline: $e');
      online = false;
      releases = await cachedReleases();
    }
    final release = releases
        ?.where((r) => compareVersions(r.version, version) <= 0)
        .firstOrNull;
    if (release == null) return null;
    return (
      release: release,
      unread: online &&
          lastSeen != null &&
          compareVersions(lastSeen, release.version) < 0,
    );
  }

  // --- Admin ---

  Future<List<ReleaseNote>> getAdminReleases() => _query.getAdminReleases();

  /// Saves the edits, then publishes.
  Future<ReleaseNote> publish(ReleaseNote note) async {
    await _command.update(note);
    return _command.publish(note.version);
  }
}
