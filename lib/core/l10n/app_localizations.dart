import 'locale_controller.dart';

/// Provides translated strings for the app UI in English and Spanish.
///
/// Usage:
/// ```dart
/// final l10n = AppLocalizations.fromController();
/// Text(l10n.trips)
/// ```
class AppLocalizations {
  final String _lang;

  const AppLocalizations(this._lang);

  /// Creates an instance reflecting the current locale from [LocaleController].
  factory AppLocalizations.fromController() =>
      AppLocalizations(LocaleController().locale.value.languageCode);

  bool get _isEs => _lang == 'es';

  // --- Sidebar navigation ---
  String get trips => _isEs ? 'Viajes' : 'Trips';
  String get tripPlans => _isEs ? 'Planes de Viaje' : 'Trip Plans';
  String get friends => _isEs ? 'Amigos' : 'Friends';
  String get achievements => _isEs ? 'Logros' : 'Achievements';
  String get tripPromotion => _isEs ? 'Promoción de Viajes' : 'Trip Promotion';
  String get userManagement =>
      _isEs ? 'Gestión de Usuarios' : 'User Management';
  String get tripDataMaintenance =>
      _isEs ? 'Mantenimiento de Datos' : 'Trip Data Maintenance';
  String get buyMeACoffee => _isEs ? 'Cómprame un Café' : 'Buy Me a Coffee';
  String get logout => _isEs ? 'Cerrar Sesión' : 'Logout';
  String get logIn => _isEs ? 'Iniciar Sesión' : 'Log In';
  String get guest => _isEs ? 'Invitado' : 'Guest';
  String get myProfile => _isEs ? 'Mi Perfil' : 'My Profile';
  String get settings => _isEs ? 'Configuración' : 'Settings';

  // --- Common actions ---
  String get cancel => _isEs ? 'Cancelar' : 'Cancel';
  String get delete => _isEs ? 'Eliminar' : 'Delete';
  String get save => _isEs ? 'Guardar' : 'Save';
  String get retry => _isEs ? 'Reintentar' : 'Retry';
  String get confirm => _isEs ? 'Confirmar' : 'Confirm';

  // --- Trip status ---
  String get allStatus => _isEs ? 'Todos los Estados' : 'All Status';
  String get live => _isEs ? 'En Vivo' : 'Live';
  String get paused => _isEs ? 'Pausado' : 'Paused';
  String get completed => _isEs ? 'Completado' : 'Completed';
  String get draft => _isEs ? 'Borrador' : 'Draft';

  // --- Visibility ---
  String get allVisibility => _isEs ? 'Toda Visibilidad' : 'All Visibility';
  String get publicVisibility => _isEs ? 'Público' : 'Public';
  String get protectedVisibility => _isEs ? 'Protegido' : 'Protected';
  String get privateVisibility => _isEs ? 'Privado' : 'Private';

  // --- Home screen ---
  String get newTrip => _isEs ? 'Nuevo Viaje' : 'New Trip';
  String get deleteTrip => _isEs ? 'Eliminar Viaje' : 'Delete Trip';

  // --- Settings screen ---
  String get appearance => _isEs ? 'Apariencia' : 'Appearance';
  String get darkMode => _isEs ? 'Modo Oscuro' : 'Dark Mode';
  String get darkModeSubtitle => _isEs
      ? 'Cambiar entre tema claro y oscuro'
      : 'Switch between light and dark theme';
  String get language => _isEs ? 'Idioma' : 'Language';
}
