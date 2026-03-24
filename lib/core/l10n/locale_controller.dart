import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Global controller for the app's locale.
///
/// Persists the user's language preference via [SharedPreferences] and
/// exposes a [ValueNotifier] so that the root [MaterialApp] can rebuild
/// reactively when the user switches language.
class LocaleController {
  static const String _localeKey = 'app_locale';

  // Singleton
  static final LocaleController _instance = LocaleController._internal();
  factory LocaleController() => _instance;
  LocaleController._internal();

  /// All locales supported by the app.
  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('nl'),
  ];

  /// Flag emoji for each supported language code.
  static const Map<String, String> localeFlags = {
    'en': '🇬🇧',
    'es': '🇪🇸',
    'fr': '🇫🇷',
    'nl': '🇳🇱',
  };

  /// Short uppercase label for each supported language code.
  static const Map<String, String> localeLabels = {
    'en': 'EN',
    'es': 'ES',
    'fr': 'FR',
    'nl': 'NL',
  };

  /// Reactive holder for the current [Locale].
  final ValueNotifier<Locale> locale =
      ValueNotifier<Locale>(const Locale('en'));

  /// The current language code (e.g. 'en', 'es', 'fr', 'nl').
  String get languageCode => locale.value.languageCode;

  /// Load the persisted preference from [SharedPreferences].
  ///
  /// Call once during app startup (before [runApp]).
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final langCode = prefs.getString(_localeKey) ?? 'en';
    locale.value = Locale(langCode);
  }

  /// Set the locale and persist the preference.
  Future<void> setLocale(Locale newLocale) async {
    locale.value = newLocale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, newLocale.languageCode);
  }

  /// Cycle to the next supported locale (EN → ES → FR → NL → EN …).
  Future<void> nextLocale() async {
    final idx = supportedLocales.indexWhere(
      (l) => l.languageCode == locale.value.languageCode,
    );
    final next = (idx + 1) % supportedLocales.length;
    await setLocale(supportedLocales[next]);
  }
}
