import '../../../core/constants/enums.dart';
import 'recording_profile.dart';

/// The choices a trip starts with: who sees it, auto check-in and length.
/// Prefilled from the user's last trip (see `TripService.getStartDefaults`).
class TripStartSettings {
  final Visibility visibility;
  final bool automaticUpdates;

  /// Auto check-in interval in minutes (minimum 15).
  final int intervalMinutes;
  final TripModality modality;

  /// Route recording the user picked (Android, local only); null means the
  /// default for [modality].
  final RecordingProfile? recordingProfile;

  const TripStartSettings({
    this.visibility = Visibility.public,
    this.automaticUpdates = true,
    this.intervalMinutes = 15,
    this.modality = TripModality.simple,
    this.recordingProfile,
  });

  /// `GET /trips/me/start-defaults` (interval comes in seconds).
  factory TripStartSettings.fromJson(Map<String, dynamic> json) =>
      TripStartSettings(
        visibility:
            Visibility.fromJson(json['visibility'] as String? ?? 'PUBLIC'),
        automaticUpdates: json['automaticUpdates'] as bool? ?? true,
        intervalMinutes:
            (((json['updateRefresh'] as num?) ?? 900) / 60).round().clamp(
                  15,
                  24 * 60,
                ),
        modality:
            TripModality.fromJson(json['tripModality'] as String? ?? 'SIMPLE'),
      );

  TripStartSettings copyWith({
    Visibility? visibility,
    bool? automaticUpdates,
    int? intervalMinutes,
    TripModality? modality,
    RecordingProfile? recordingProfile,
  }) =>
      TripStartSettings(
        visibility: visibility ?? this.visibility,
        automaticUpdates: automaticUpdates ?? this.automaticUpdates,
        intervalMinutes: intervalMinutes ?? this.intervalMinutes,
        modality: modality ?? this.modality,
        recordingProfile: recordingProfile ?? this.recordingProfile,
      );

  @override
  bool operator ==(Object other) =>
      other is TripStartSettings &&
      other.visibility == visibility &&
      other.automaticUpdates == automaticUpdates &&
      other.intervalMinutes == intervalMinutes &&
      other.modality == modality &&
      other.recordingProfile == recordingProfile;

  @override
  int get hashCode => Object.hash(visibility, automaticUpdates, intervalMinutes,
      modality, recordingProfile);
}
