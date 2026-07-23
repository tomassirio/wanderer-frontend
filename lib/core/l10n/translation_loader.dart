import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// Loads and caches the app's translation JSON assets
/// (`assets/translations/{code}.json`).
///
/// Call [load] once during app startup (see `main.dart`), before any
/// [AppLocalizations] is constructed. This is the single source of truth
/// for translated strings — widgets never touch it directly, they go
/// through `context.l10n` as before.
class TranslationLoader {
  TranslationLoader._internal();
  static final TranslationLoader instance = TranslationLoader._internal();

  static const List<String> supportedCodes = ['en', 'es', 'fr', 'nl'];
  static const String fallbackCode = 'en';

  final Map<String, Map<String, dynamic>> _cache = {};
  bool _loaded = false;

  bool get isLoaded => _loaded;

  /// Loads every supported locale's JSON asset into memory.
  /// Safe to call more than once — subsequent calls are no-ops.
  Future<void> load() async {
    if (_loaded) return;
    for (final code in supportedCodes) {
      final raw = await rootBundle.loadString('assets/translations/$code.json');
      _cache[code] = json.decode(raw) as Map<String, dynamic>;
    }
    _loaded = true;
  }

  Map<String, dynamic> _localeMap(String code) =>
      _cache[code] ?? _cache[fallbackCode] ?? const {};

  /// Flat string lookup: [code] -> falls back to [fallbackCode] -> falls
  /// back to [key] itself if nothing is found.
  String string(String code, String key) {
    final value = _localeMap(code)[key] ?? _cache[fallbackCode]?[key];
    return value is String ? value : key;
  }

  /// Nested map lookup (used for achievement names/descriptions), keyed by
  /// [mapKey] (e.g. `achievementNames`) then [entryKey] (e.g. `FIRST_TRIP`).
  String nested(String code, String mapKey, String entryKey) {
    final map = _localeMap(code)[mapKey];
    if (map is Map && map[entryKey] is String) return map[entryKey] as String;
    final fallbackMap = _cache[fallbackCode]?[mapKey];
    if (fallbackMap is Map && fallbackMap[entryKey] is String) {
      return fallbackMap[entryKey] as String;
    }
    return entryKey;
  }
}

/// Simple `{placeholder}` substitution for translation templates, plus a
/// singular/plural convention (`<key>_one` / `<key>_other`) for the handful
/// of count-sensitive strings the app uses.
class TranslationTemplate {
  const TranslationTemplate._();

  static String format(String template, Map<String, Object> params) {
    var result = template;
    params.forEach((key, value) {
      result = result.replaceAll('{$key}', value.toString());
    });
    return result;
  }

  /// Picks `<key>_one` when [count] == 1, else `<key>_other`, then applies
  /// [params] to the chosen template.
  static String plural(
    TranslationLoader loader,
    String code,
    String key,
    int count,
    Map<String, Object> params,
  ) {
    final suffix = count == 1 ? '_one' : '_other';
    final template = loader.string(code, '$key$suffix');
    return format(template, params);
  }
}
