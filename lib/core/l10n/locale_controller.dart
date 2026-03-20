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

  /// Reactive holder for the current [Locale].
  final ValueNotifier<Locale> locale =
      ValueNotifier<Locale>(const Locale('en'));

  /// Whether Spanish is currently active.
  bool get isSpanish => locale.value.languageCode == 'es';

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

  /// Toggle between English and Spanish.
  Future<void> toggleLocale() async {
    final newLocale = isSpanish ? const Locale('en') : const Locale('es');
    await setLocale(newLocale);
  }
}
