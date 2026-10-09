import '../../../core/constants/enums.dart';

/// How densely the phone records the track and how often it uploads.
///
/// The sync knobs live here; the recorder knobs (fix interval, min distance,
/// batch delivery) live in `TripTrackingService.locationRequest` on the
/// native side, keyed by [wireName].
enum RecordingProfile {
  /// Single-day trips: a fix every 10 s / 10 m, uploaded every 2 min,
  /// no automatic check-ins.
  live('LIVE', uploadInterval: Duration(minutes: 2), autoCheckIn: false),

  /// Multi-day trips: a fix every 120 s / 25 m, uploaded and checked in
  /// every `updateRefresh` (today's behaviour).
  saver('SAVER', uploadInterval: null, autoCheckIn: true);

  const RecordingProfile(this.wireName,
      {required this.uploadInterval, required this.autoCheckIn});

  /// Name sent over the method channel and stored in preferences.
  final String wireName;

  /// How often the sync chain runs; `null` means the trip's `updateRefresh`.
  final Duration? uploadInterval;

  /// Whether each sync tick also posts an "Automatic Update" check-in.
  final bool autoCheckIn;

  /// Seconds between sync ticks for a trip whose `updateRefresh` is
  /// [updateRefreshSeconds].
  int uploadSeconds(int updateRefreshSeconds) =>
      uploadInterval?.inSeconds ?? updateRefreshSeconds;

  /// Default profile for a trip of [modality]: Live for single-day trips,
  /// Battery saver otherwise.
  static RecordingProfile defaultFor(TripModality? modality) =>
      modality == TripModality.simple ? live : saver;

  static RecordingProfile? fromWireName(String? name) {
    for (final p in values) {
      if (p.wireName == name) return p;
    }
    return null;
  }
}
