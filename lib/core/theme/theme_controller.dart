import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Global controller for the app's theme mode.
///
/// Persists the user's dark-mode preference via [SharedPreferences] and
/// exposes a [ValueNotifier] so that the root [MaterialApp] can rebuild
/// reactively when the user toggles the setting.
class ThemeController {
  static const String _darkModeKey = 'dark_mode_enabled';

  // Singleton
  static final ThemeController _instance = ThemeController._internal();
  factory ThemeController() => _instance;
  ThemeController._internal();

  /// Reactive holder for the current [ThemeMode].
  final ValueNotifier<ThemeMode> themeMode =
      ValueNotifier<ThemeMode>(ThemeMode.light);

  /// Whether dark mode is currently active.
  bool get isDarkMode => themeMode.value == ThemeMode.dark;

  /// Load the persisted preference from [SharedPreferences].
  ///
  /// Call once during app startup (before [runApp]).
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool(_darkModeKey) ?? false;
    themeMode.value = isDark ? ThemeMode.dark : ThemeMode.light;
  }

  /// Toggle or set dark mode and persist the preference.
  Future<void> setDarkMode(bool isDark) async {
    themeMode.value = isDark ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_darkModeKey, isDark);
  }
}
