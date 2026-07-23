import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _codes = ['en', 'es', 'fr', 'nl'];

Map<String, dynamic> _load(String code) => json.decode(
    File('assets/translations/$code.json').readAsStringSync())
    as Map<String, dynamic>;

void main() {
  test('every locale JSON file has the same top-level flat keys', () {
    final maps = {for (final c in _codes) c: _load(c)};
    final flatKeySets = maps.map((code, m) => MapEntry(
        code,
        m.keys
            .where((k) => m[k] is! Map)
            .toSet()));

    final reference = flatKeySets['en']!;
    for (final code in _codes.skip(1)) {
      final missing = reference.difference(flatKeySets[code]!);
      final extra = flatKeySets[code]!.difference(reference);
      expect(missing, isEmpty,
          reason: '$code is missing keys present in en: $missing');
      expect(extra, isEmpty,
          reason: '$code has extra keys not present in en: $extra');
    }
  });

  test('every locale has the same achievementNames keys', () {
    final maps = {for (final c in _codes) c: _load(c)};
    final reference =
        (maps['en']!['achievementNames'] as Map).keys.toSet();
    for (final code in _codes.skip(1)) {
      final keys = (maps[code]!['achievementNames'] as Map).keys.toSet();
      expect(keys, reference, reason: '$code achievementNames key mismatch');
    }
  });

  test('every locale has the same achievementDescriptions keys', () {
    final maps = {for (final c in _codes) c: _load(c)};
    final reference =
        (maps['en']!['achievementDescriptions'] as Map).keys.toSet();
    for (final code in _codes.skip(1)) {
      final keys =
          (maps[code]!['achievementDescriptions'] as Map).keys.toSet();
      expect(keys, reference,
          reason: '$code achievementDescriptions key mismatch');
    }
  });
}
