import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wanderer_frontend/core/l10n/locale_controller.dart';
import 'package:wanderer_frontend/core/l10n/translation_loader.dart';

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

  test('TranslationLoader and asset files agree with LocaleController', () {
    final localeCodes =
        LocaleController.supportedLocales.map((l) => l.languageCode).toSet();

    expect(TranslationLoader.supportedCodes.toSet(), localeCodes,
        reason:
            'TranslationLoader.supportedCodes must match LocaleController.supportedLocales');

    for (final code in localeCodes) {
      expect(File('assets/translations/$code.json').existsSync(), isTrue,
          reason: 'Missing assets/translations/$code.json for locale $code');
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
