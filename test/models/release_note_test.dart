import 'package:flutter_test/flutter_test.dart';
import 'package:wanderer_frontend/data/models/domain/release_note.dart';

void main() {
  test('parses the ReleaseDTO from the API contract', () {
    final r = ReleaseNote.fromJson({
      'id': '6f1c2a8e-1b0e-4a51-9a51-1d7c1f0e2b11',
      'version': '1.3.0',
      'status': 'PUBLISHED',
      'headline': 'Plan trips faster',
      'showPopup': true,
      'platforms': [
        {'platform': 'ANDROID', 'releaseDate': '2026-10-10T08:00:00Z'},
        {'platform': 'WEB', 'releaseDate': null},
      ],
      'items': [
        {
          'type': 'NEW',
          'title': 'One-step trip start',
          'text': 'x',
          'prNumber': 112
        },
        {
          'type': 'FIXED',
          'title': 'Single-day plans',
          'text': null,
          'prNumber': null
        },
      ],
    });
    expect(r.draft, isFalse);
    expect(r.releaseDateOn('ANDROID'), DateTime.utc(2026, 10, 10, 8));
    expect(r.releaseDateOn('WEB'), isNull);
    expect(r.items.map((i) => i.type),
        [ReleaseChangeType.newFeature, ReleaseChangeType.fixed]);
    expect(r.items.first.prNumber, 112);

    final body = r.toUpdateJson();
    expect(body.keys, ['headline', 'showPopup', 'platforms', 'items']);
    expect((body['items'] as List).first, {
      'type': 'NEW',
      'title': 'One-step trip start',
      'text': 'x',
      'prNumber': 112
    });
  });

  test('versions compare numerically and drop suffixes', () {
    expect(compareVersions('1.10.0', '1.9.0'), 1);
    expect(compareVersions('2.0.6-SNAPSHOT', '2.0.6'), 0);
    expect(compareVersions('1.6.11', '1.7.0'), -1);
    expect(semver('2.0.6-SNAPSHOT+3'), '2.0.6');
  });
}
