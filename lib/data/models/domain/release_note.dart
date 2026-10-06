/// Release notes ("What's new"), backend `ReleaseDTO`
/// (wanderer-backend docs/release-changelog-api.md).
enum ReleaseChangeType {
  newFeature('NEW'),
  improved('IMPROVED'),
  fixed('FIXED');

  final String json;
  const ReleaseChangeType(this.json);

  static ReleaseChangeType fromJson(String? v) =>
      values.firstWhere((t) => t.json == v, orElse: () => improved);
}

/// `items[]`: one change.
class ReleaseChange {
  final ReleaseChangeType type;
  final String title;
  final String text;

  /// Pull request the change was drafted from.
  final int? prNumber;

  const ReleaseChange({
    required this.type,
    required this.title,
    this.text = '',
    this.prNumber,
  });

  factory ReleaseChange.fromJson(Map<String, dynamic> j) => ReleaseChange(
        type: ReleaseChangeType.fromJson(j['type'] as String?),
        title: j['title'] as String? ?? '',
        text: j['text'] as String? ?? '',
        prNumber: j['prNumber'] as int?,
      );

  Map<String, dynamic> toJson() => {
        'type': type.json,
        'title': title,
        'text': text.isEmpty ? null : text,
        'prNumber': prNumber,
      };

  ReleaseChange copyWith(
          {ReleaseChangeType? type, String? title, String? text}) =>
      ReleaseChange(
        type: type ?? this.type,
        title: title ?? this.title,
        text: text ?? this.text,
        prNumber: prNumber,
      );
}

/// `platforms[]`: where a release targets and when it goes live there
/// (`releaseDate` null = not released there yet).
class ReleasePlatform {
  final String platform;
  final DateTime? releaseDate;
  const ReleasePlatform(this.platform, [this.releaseDate]);

  factory ReleasePlatform.fromJson(Map<String, dynamic> j) => ReleasePlatform(
        j['platform'] as String? ?? '',
        DateTime.tryParse(j['releaseDate'] as String? ?? ''),
      );

  Map<String, dynamic> toJson() => {
        'platform': platform,
        'releaseDate': releaseDate?.toUtc().toIso8601String(),
      };
}

class ReleaseNote {
  final String id;
  final String version;
  final bool draft;
  final String headline;
  final bool showPopup;
  final List<ReleasePlatform> platforms;
  final List<ReleaseChange> items;

  const ReleaseNote({
    this.id = '',
    required this.version,
    this.draft = false,
    this.headline = '',
    this.showPopup = true,
    this.platforms = const [],
    this.items = const [],
  });

  factory ReleaseNote.fromJson(Map<String, dynamic> j) => ReleaseNote(
        id: j['id'] as String? ?? '',
        version: j['version'] as String? ?? '',
        draft: j['status'] == 'DRAFT',
        headline: j['headline'] as String? ?? '',
        showPopup: j['showPopup'] as bool? ?? true,
        platforms: [
          for (final p in j['platforms'] as List? ?? const [])
            ReleasePlatform.fromJson(p as Map<String, dynamic>)
        ],
        items: [
          for (final i in j['items'] as List? ?? const [])
            ReleaseChange.fromJson(i as Map<String, dynamic>)
        ],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'version': version,
        'status': draft ? 'DRAFT' : 'PUBLISHED',
        ...toUpdateJson(),
      };

  /// Body of `PUT /admin/releases/{version}`.
  Map<String, dynamic> toUpdateJson() => {
        'headline': headline,
        'showPopup': showPopup,
        'platforms': [for (final p in platforms) p.toJson()],
        'items': [for (final i in items) i.toJson()],
      };

  /// When this release went live on [platform].
  DateTime? releaseDateOn(String platform) => platforms
      .where((p) => p.platform == platform)
      .map((p) => p.releaseDate)
      .firstOrNull;
}

/// Compares dotted versions numerically ("1.10.0" > "1.9.2"); a suffix
/// like "-SNAPSHOT" or "+12" is ignored.
int compareVersions(String a, String b) {
  final x = semver(a).split('.'), y = semver(b).split('.');
  for (var i = 0; i < 3; i++) {
    final d = (int.tryParse(i < x.length ? x[i] : '') ?? 0) -
        (int.tryParse(i < y.length ? y[i] : '') ?? 0);
    if (d != 0) return d.sign;
  }
  return 0;
}

/// Plain `MAJOR.MINOR.PATCH` (the API rejects suffixes): "2.0.6-SNAPSHOT+3"
/// → "2.0.6".
String semver(String v) => v.split(RegExp(r'[-+]')).first;
