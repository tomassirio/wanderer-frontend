import 'package:flutter/widgets.dart';
import 'locale_controller.dart';

// ---------------------------------------------------------------------------
// InheritedNotifier — places LocaleController.locale in the widget tree so
// that any widget calling context.l10n automatically rebuilds on locale change.
// ---------------------------------------------------------------------------

/// Wraps a subtree with the [LocaleController.locale] notifier so that any
/// widget that reads [BuildContext.l10n] rebuilds whenever the locale changes.
///
/// Inject it inside [MaterialApp] via the `builder` callback.
class L10nScope extends InheritedNotifier<ValueNotifier<Locale>> {
  const L10nScope({
    super.key,
    required super.notifier,
    required super.child,
  });

  static Locale of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<L10nScope>();
    return scope?.notifier?.value ?? const Locale('en');
  }
}

/// Convenience extension: `context.l10n` returns a fresh [AppLocalizations]
/// for the current locale and registers the widget as a rebuild dependent.
extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n =>
      AppLocalizations(L10nScope.of(this).languageCode);
}

/// Provides translated strings for the app UI in English and Spanish.
///
/// Usage (preferred — reactive):
/// ```dart
/// final l10n = context.l10n;
/// Text(l10n.trips)
/// ```
class AppLocalizations {
  final String _lang;

  const AppLocalizations(this._lang);

  /// Creates an instance reflecting the current locale from [LocaleController].
  /// Prefer [BuildContext.l10n] in widget build methods for auto-rebuild.
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

  // --- App bar / navigation ---
  String get wanderer => 'Wanderer';
  String get login => _isEs ? 'Iniciar Sesión' : 'Login';
  String get notifications => _isEs ? 'Notificaciones' : 'Notifications';
  String get profile => _isEs ? 'Perfil' : 'Profile';
  String get search => _isEs ? 'Buscar' : 'Search';
  String get userProfile => _isEs ? 'Perfil de Usuario' : 'User Profile';
  String get switchToLightMode =>
      _isEs ? 'Cambiar a modo claro' : 'Switch to light mode';
  String get switchToDarkMode =>
      _isEs ? 'Cambiar a modo oscuro' : 'Switch to dark mode';

  // --- Common actions ---
  String get cancel => _isEs ? 'Cancelar' : 'Cancel';
  String get delete => _isEs ? 'Eliminar' : 'Delete';
  String get save => _isEs ? 'Guardar' : 'Save';
  String get retry => _isEs ? 'Reintentar' : 'Retry';
  String get confirm => _isEs ? 'Confirmar' : 'Confirm';
  String get edit => _isEs ? 'Editar' : 'Edit';
  String get close => _isEs ? 'Cerrar' : 'Close';
  String get create => _isEs ? 'Crear' : 'Create';
  String get minimize => _isEs ? 'Minimizar' : 'Minimize';
  String get refresh => _isEs ? 'Actualizar' : 'Refresh';
  String get done => _isEs ? 'Listo' : 'Done';
  String get send => _isEs ? 'Enviar' : 'Send';
  String get remove => _isEs ? 'Quitar' : 'Remove';
  String get promote => _isEs ? 'Promover' : 'Promote';
  String get unpromote => _isEs ? 'Despromover' : 'Unpromote';

  // --- Trip status ---
  String get allStatus => _isEs ? 'Todos los Estados' : 'All Status';
  String get live => _isEs ? 'En Vivo' : 'Live';
  String get paused => _isEs ? 'Pausado' : 'Paused';
  String get completed => _isEs ? 'Completado' : 'Completed';
  String get draft => _isEs ? 'Borrador' : 'Draft';
  String get resting => _isEs ? 'Descansando' : 'Resting';

  // --- Visibility ---
  String get allVisibility => _isEs ? 'Toda Visibilidad' : 'All Visibility';
  String get publicVisibility => _isEs ? 'Público' : 'Public';
  String get protectedVisibility => _isEs ? 'Protegido' : 'Protected';
  String get privateVisibility => _isEs ? 'Privado' : 'Private';
  String get visibility => _isEs ? 'Visibilidad' : 'Visibility';

  // --- Home screen ---
  String get newTrip => _isEs ? 'Nuevo Viaje' : 'New Trip';
  String get deleteTrip => _isEs ? 'Eliminar Viaje' : 'Delete Trip';
  String get deleteTripConfirm => _isEs
      ? '¿Estás seguro de que quieres eliminar '
      : 'Are you sure you want to delete ';
  String get welcomeToWanderer =>
      _isEs ? 'Bienvenido a Wanderer' : 'Welcome to Wanderer';
  String get trackAdventures => _isEs
      ? 'Rastrea tus aventuras, comparte tus viajes'
      : 'Track your adventures, share your journeys';
  String get discoverAdventures => _isEs
      ? 'Descubre aventuras de la comunidad'
      : 'Discover adventures from the community';
  String get explorePublicTrips =>
      _isEs ? 'Explorar Viajes Públicos' : 'Explore Public Trips';
  String get noTripsYet => _isEs ? 'Aún no hay viajes' : 'No trips yet';
  String get createFirstTrip => _isEs
      ? '¡Crea tu primer viaje para empezar!'
      : 'Create your first trip to get started!';
  String get noTripsInFeed =>
      _isEs ? 'No hay viajes en tu feed' : 'No trips in your feed';
  String get followToSeeTrips => _isEs
      ? '¡Sigue usuarios o agrega amigos para ver sus viajes!'
      : 'Follow users or add friends to see their trips!';
  String get noPublicTripsFound =>
      _isEs ? 'No se encontraron viajes públicos' : 'No public trips found';
  String get checkBackLater => _isEs
      ? '¡Vuelve más tarde para nuevas aventuras!'
      : 'Check back later for new adventures!';
  String get errorLoadingTrips =>
      _isEs ? 'Error al cargar viajes' : 'Error loading trips';
  String get loadMoreTrips => _isEs ? 'Cargar más viajes' : 'Load more trips';
  String get myTrips => _isEs ? 'Mis Viajes' : 'My Trips';
  String get friendsTrips => _isEs ? 'Viajes de Amigos' : 'Friends Trips';
  String get discover => _isEs ? 'Descubrir' : 'Discover';
  String get featuredTrips => _isEs ? 'Viajes Destacados' : 'Featured Trips';
  String get highlightedAdventures => _isEs
      ? 'Aventuras destacadas de la comunidad'
      : 'Highlighted adventures from the community';
  String get explorePublicTripsSubtitle => _isEs
      ? 'Explora viajes públicos de la comunidad'
      : 'Explore public trips from the community';
  String get feed => _isEs ? 'Feed' : 'Feed';
  String get minuteAgo => _isEs ? 'hace 1 minuto' : '1 minute ago';
  String minutesAgo(int n) =>
      _isEs ? 'hace $n minutos' : '$n minutes ago';
  String get hourAgo => _isEs ? 'hace 1 hora' : '1 hour ago';
  String hoursAgo(int n) => _isEs ? 'hace $n horas' : '$n hours ago';
  String get dayAgo => _isEs ? 'hace 1 día' : '1 day ago';
  String daysAgo(int n) => _isEs ? 'hace $n días' : '$n days ago';
  String get weekAgo => _isEs ? 'hace 1 semana' : '1 week ago';
  String weeksAgo(int n) => _isEs ? 'hace $n semanas' : '$n weeks ago';
  String get monthAgo => _isEs ? 'hace 1 mes' : '1 month ago';
  String monthsAgo(int n) => _isEs ? 'hace $n meses' : '$n months ago';
  String minutesAgoCompact(int n) => _isEs ? '${n}m' : '${n}m';
  String hoursAgoCompact(int n) => _isEs ? '${n}h' : '${n}h';
  String daysAgoCompact(int n) => _isEs ? '${n}d' : '${n}d';
  String get orExplorePublicTrips =>
      _isEs ? 'O explorar viajes públicos:' : 'Or explore public trips:';

  // --- Search ---
  String get searchHint => _isEs ? 'Buscar…' : 'Search…';
  String get couldNotLoadResults => _isEs
      ? 'No se pudieron cargar resultados. Inténtalo de nuevo.'
      : 'Could not load results. Try again.';
  String get noTripsFound =>
      _isEs ? 'No se encontraron viajes' : 'No trips found';

  // --- Notifications ---
  String get noNotificationsYet =>
      _isEs ? 'Aún no hay notificaciones' : 'No notifications yet';
  String get notificationsWillAppear => _isEs
      ? 'Cuando recibas notificaciones, aparecerán aquí'
      : 'When you receive notifications, they appear here';
  String get readAll => _isEs ? 'Marcar todo como leído' : 'Read all';
  String get loadMoreNotifications =>
      _isEs ? 'Cargar más notificaciones' : 'Load more notifications';
  String get pleaseLogInForNotifications =>
      _isEs ? 'Por favor inicia sesión para ver notificaciones' : 'Please log in to view notifications';
  String get failedToLoadNotifications =>
      _isEs ? 'Error al cargar notificaciones' : 'Failed to load notifications';

  // --- Auth screen ---
  String get welcomeBack => _isEs ? '¡Bienvenido de nuevo!' : 'Welcome Back!';
  String get createAccount => _isEs ? 'Crear Cuenta' : 'Create Account';
  String get signInToContinue => _isEs
      ? 'Inicia sesión para continuar tu viaje'
      : 'Sign in to continue your journey';
  String get signUpToStart => _isEs
      ? 'Regístrate para empezar a rastrear tus aventuras'
      : 'Sign up to start tracking your adventures';
  String get signIn => _isEs ? 'Iniciar Sesión' : 'Sign In';
  String get signUp => _isEs ? 'Registrarse' : 'Sign Up';
  String get alreadyHaveAccount =>
      _isEs ? '¿Ya tienes una cuenta?' : 'Already have an account?';
  String get dontHaveAccount =>
      _isEs ? '¿No tienes una cuenta?' : "Don't have an account?";
  String get forgotPassword =>
      _isEs ? '¿Olvidaste tu contraseña?' : 'Forgot Password?';
  String get backToLogin =>
      _isEs ? 'Volver al inicio de sesión' : 'Back to Login';
  String get checkYourEmail =>
      _isEs ? 'Revisa tu correo electrónico' : 'Check your email';
  String get emailLabel => _isEs ? 'Correo Electrónico' : 'Email';
  String get usernameLabel => _isEs ? 'Nombre de usuario' : 'Username';
  String get passwordLabel => _isEs ? 'Contraseña' : 'Password';
  String get pleaseEnterPassword =>
      _isEs ? 'Por favor ingresa tu contraseña' : 'Please enter your password';
  String get passwordMinLength => _isEs
      ? 'La contraseña debe tener al menos 6 caracteres'
      : 'Password must be at least 6 characters';
  String get passwordsDoNotMatch =>
      _isEs ? 'Las contraseñas no coinciden' : 'Passwords do not match';
  String get resetPasswordTitle =>
      _isEs ? 'Restablecer Contraseña' : 'Reset Password';
  String get enterEmailForReset => _isEs
      ? "Ingresa tu dirección de correo electrónico y te enviaremos un enlace para restablecer tu contraseña."
      : "Enter your email address and we'll send you a link to reset your password.";
  String get sendResetLink => _isEs ? 'Enviar enlace' : 'Send Reset Link';
  String passwordResetEmailSent(String email) => _isEs
      ? 'Si existe una cuenta con $email, hemos enviado un enlace de restablecimiento. Revisa tu bandeja de entrada y sigue las instrucciones para restablecer tu contraseña.'
      : 'If an account with $email exists, we\'ve sent a password reset link. Check your inbox and follow the instructions to reset your password.';
  String get pleaseEnterEmail =>
      _isEs ? 'Por favor ingresa tu correo electrónico' : 'Please enter your email';
  String get pleaseEnterValidEmail =>
      _isEs ? 'Por favor ingresa un correo válido' : 'Please enter a valid email';
  String get pleaseEnterUsername =>
      _isEs ? 'Por favor ingresa tu nombre de usuario' : 'Please enter your username';
  String get usernameMinLength => _isEs
      ? 'El nombre de usuario debe tener al menos 3 caracteres'
      : 'Username must be at least 3 characters';
  String get confirmPassword =>
      _isEs ? 'Confirmar Contraseña' : 'Confirm Password';

  // --- Verify email ---
  String get verifyYourEmail =>
      _isEs ? 'Verifica tu correo electrónico' : 'Verify your email';
  String get verifyEmail =>
      _isEs ? 'Verificar correo electrónico' : 'Verify Email';
  String get emailVerified =>
      _isEs ? '¡Correo electrónico verificado!' : 'Email verified!';
  String get verifyingEmail =>
      _isEs ? 'Verificando tu correo electrónico…' : 'Verifying your email…';
  String get verificationToken =>
      _isEs ? 'Token de verificación' : 'Verification token';
  String get enterVerificationToken => _isEs
      ? 'Ingresa el token de verificación del correo que te enviamos.'
      : 'Enter the verification token from the email we sent you.';
  String get accountNowActive => _isEs
      ? 'Tu cuenta está activa ahora. Redirigiendo a la app…'
      : 'Your account is now active. Redirecting you to the app…';

  // --- Settings screen ---
  String get appearance => _isEs ? 'Apariencia' : 'Appearance';
  String get darkMode => _isEs ? 'Modo Oscuro' : 'Dark Mode';
  String get darkModeSubtitle => _isEs
      ? 'Cambiar entre tema claro y oscuro'
      : 'Switch between light and dark theme';
  String get language => _isEs ? 'Idioma' : 'Language';
  String get account => _isEs ? 'Cuenta' : 'Account';
  String get changePassword => _isEs ? 'Cambiar Contraseña' : 'Change Password';
  String get changePasswordSubtitle =>
      _isEs ? 'Actualiza tu contraseña actual' : 'Update your current password';
  String get resetPassword =>
      _isEs ? 'Restablecer Contraseña' : 'Reset Password';
  String get resetPasswordSubtitle => _isEs
      ? 'Envía un enlace de restablecimiento a tu correo'
      : 'Send a password reset link to your email';
  String get support => _isEs ? 'Soporte' : 'Support';
  String get contactSupport => _isEs ? 'Contactar Soporte' : 'Contact Support';
  String get contactSupportSubtitle =>
      _isEs ? 'Obtén ayuda por correo electrónico' : 'Get help via email';
  String get termsOfService =>
      _isEs ? 'Términos de Servicio' : 'Terms of Service';
  String get privacyPolicy =>
      _isEs ? 'Política de Privacidad' : 'Privacy Policy';
  String get pushNotifications =>
      _isEs ? 'Notificaciones Push' : 'Push Notifications';
  String get pushNotificationsSubtitle => _isEs
      ? 'Recibe alertas de solicitudes de amistad, comentarios, logros y más'
      : 'Receive alerts for friend requests, comments, achievements, and other activity';
  String get closeAccount => _isEs ? 'Cerrar Cuenta' : 'Close Account';
  String get closeAccountSubtitle => _isEs
      ? 'Elimina permanentemente tu cuenta y todos los datos'
      : 'Permanently delete your account and all data';
  String get confirmAccountDeletion =>
      _isEs ? 'Confirmar eliminación de cuenta' : 'Confirm Account Deletion';
  String get deleteMyAccount =>
      _isEs ? 'Eliminar mi cuenta' : 'Delete My Account';
  String get typeDELETE => _isEs ? 'Escribe BORRAR' : 'Type DELETE';
  String get typeDELETEConfirm => _isEs
      ? 'Escribe BORRAR para confirmar que quieres cerrar tu cuenta definitivamente.'
      : 'Type DELETE to confirm you want to permanently close your account.';
  String get areYouSureDeleteAccount => _isEs
      ? '¿Estás seguro de que quieres eliminar permanentemente tu cuenta?'
      : 'Are you sure you want to permanently delete your account?';
  String get currentPassword =>
      _isEs ? 'Contraseña actual' : 'Current Password';
  String get newPassword => _isEs ? 'Nueva contraseña' : 'New Password';
  String get confirmNewPassword =>
      _isEs ? 'Confirmar nueva contraseña' : 'Confirm New Password';
  String get changePasswordTitle =>
      _isEs ? 'Cambiar Contraseña' : 'Change Password';
  String get continue_ => _isEs ? 'Continuar' : 'Continue';
  String get appVersion => _isEs ? 'Versión de la app' : 'App Version';
  String get notificationsSection => _isEs ? 'Notificaciones' : 'Notifications';

  // --- Profile screen ---
  String get editProfile => _isEs ? 'Editar Perfil' : 'Edit Profile';
  String get noProfileData => _isEs
      ? 'No hay datos de perfil disponibles'
      : 'No profile data available';
  String get noTripsMatchFilters => _isEs
      ? 'Ningún viaje coincide con los filtros seleccionados'
      : 'No trips match the selected filters';
  String get clearAllFilters =>
      _isEs ? 'Borrar todos los filtros' : 'Clear all filters';
  String get clearFilters => _isEs ? 'Borrar filtros' : 'Clear filters';
  String get sortTripsBy => _isEs ? 'Ordenar viajes por' : 'Sort trips by';
  String get displayName => _isEs ? 'Nombre para mostrar' : 'Display Name';
  String get yourDisplayName =>
      _isEs ? 'Tu nombre para mostrar' : 'Your display name';
  String get bio => _isEs ? 'Biografía' : 'Bio';
  String get tellUsAboutYourself =>
      _isEs ? 'Cuéntanos sobre ti' : 'Tell us about yourself';
  String get avatarUrl => _isEs ? 'URL del Avatar' : 'Avatar URL';

  // --- Friends & Followers screen ---
  String get followBack => _isEs ? 'Seguir de vuelta' : 'Follow Back';
  String get unfollow => _isEs ? 'Dejar de seguir' : 'Unfollow';
  String get noFollowersYet =>
      _isEs ? 'Aún no hay seguidores' : 'No followers yet';
  String get notFollowingAnyone =>
      _isEs ? 'Aún no sigues a nadie' : 'Not following anyone yet';
  String get noFriendRequests =>
      _isEs ? 'No hay solicitudes de amistad' : 'No friend requests';
  String get noFriendsYet => _isEs ? 'Aún no hay amigos' : 'No friends yet';
  String get noSentRequests =>
      _isEs ? 'No hay solicitudes enviadas' : 'No sent requests';
  String get sendFriendRequests => _isEs
      ? 'Envía solicitudes de amistad para conectar con otros'
      : 'Send friend requests to connect with others';

  // --- Achievements screen ---
  String get noAchievementsYet =>
      _isEs ? 'Aún no hay logros disponibles' : 'No achievements available yet';

  // --- Trip detail screen ---
  String get loadingTrip => _isEs ? 'Cargando viaje...' : 'Loading trip...';
  String get supportTrip => _isEs ? 'Apoya este viaje' : 'Support this trip';
  String get startTrip => _isEs ? 'Iniciar Viaje' : 'Start Trip';
  String get finishTrip => _isEs ? 'Terminar Viaje' : 'Finish Trip';
  String get finishDay => _isEs ? 'Terminar Día' : 'Finish Day';
  String get pause => _isEs ? 'Pausar' : 'Pause';
  String get resume => _isEs ? 'Reanudar' : 'Resume';
  String get finish => _isEs ? 'Terminar' : 'Finish';
  String get finishTripConfirm => _isEs
      ? '¿Estás seguro de que quieres terminar este viaje? Esto marcará el viaje como completado.'
      : 'Are you sure you want to finish this trip? This will mark the trip as completed.';
  String get shareTrip => _isEs ? 'Compartir Viaje' : 'Share Trip';
  String get tripSettings =>
      _isEs ? 'Configuración del Viaje' : 'Trip Settings';
  String get showPlannedRoute =>
      _isEs ? 'Mostrar Ruta Planificada' : 'Show Planned Route';
  String get tripType => _isEs ? 'Tipo de Viaje' : 'Trip Type';
  String get automaticUpdates =>
      _isEs ? 'Actualizaciones Automáticas' : 'Automatic Updates';
  String get locationInterval => _isEs
      ? 'La ubicación se actualizará automáticamente a este intervalo cuando el viaje esté activo'
      : 'Location will be automatically updated at this interval when trip is active';
  String get willActivateWhenStarted => _isEs
      ? 'Se activará cuando el viaje sea iniciado'
      : 'Will activate when the trip is started';
  String get switchToMultiDay =>
      _isEs ? '¿Cambiar a Multi-Día?' : 'Switch to Multi-Day?';
  String get multiDayIrreversible => _isEs
      ? 'Esta acción es irreversible. Una vez que un viaje se convierte a'
      : 'This action is irreversible. Once a trip is converted to';
  String get testBackgroundUpdate => _isEs
      ? '🧪 Probar Actualización en Segundo Plano Ahora'
      : '🧪 Test Background Update Now';
  String get firesWorkManagerTask => _isEs
      ? 'Ejecuta una tarea WorkManager inmediatamente'
      : 'Fires a one-off WorkManager task immediately';
  String get loadingMap => _isEs ? 'Cargando mapa...' : 'Loading map...';
  String get mapLoadingError =>
      _isEs ? 'Error al cargar el mapa' : 'Map Loading Error';
  String get loadingTimeline =>
      _isEs ? 'Cargando línea de tiempo...' : 'Loading timeline...';
  String get noUpdatesYet =>
      _isEs ? 'Aún no hay actualizaciones' : 'No updates yet';
  String get tripUpdatesWillAppear => _isEs
      ? 'Las actualizaciones del viaje aparecerán aquí'
      : 'Trip updates will appear here';
  String get loadOlderUpdates =>
      _isEs ? 'Cargar actualizaciones anteriores' : 'Load older updates';
  String get timeline => _isEs ? 'Línea de Tiempo' : 'Timeline';
  String get noCommentsYet =>
      _isEs ? 'Aún no hay comentarios' : 'No comments yet';
  String get pleaseLogInToComment =>
      _isEs ? 'Inicia sesión para comentar' : 'Please log in to comment';
  String get loadMoreComments =>
      _isEs ? 'Cargar más comentarios' : 'Load more comments';
  String get latestFirst => _isEs ? 'Más reciente primero' : 'Latest first';
  String get oldestFirst => _isEs ? 'Más antiguo primero' : 'Oldest first';
  String get mostReactions => _isEs ? 'Más reacciones' : 'Most reactions';
  String get mostReplies => _isEs ? 'Más respuestas' : 'Most replies';
  String get chooseReaction =>
      _isEs ? 'Elige una reacción' : 'Choose a reaction';
  String get react => _isEs ? 'Reaccionar' : 'React';
  String get reply => _isEs ? 'Responder' : 'Reply';
  String get author => 'AUTHOR';
  String get replyingToComment =>
      _isEs ? 'Respondiendo al comentario' : 'Replying to comment';
  String get cancelReply => _isEs ? 'Cancelar respuesta' : 'Cancel reply';
  String get addMessageOptional =>
      _isEs ? 'Agregar un mensaje (opcional)' : 'Add a message (optional)';
  String get sendUpdate => _isEs ? 'Enviar Actualización' : 'Send Update';
  String get locationShared => _isEs
      ? 'Tu ubicación y nivel de batería serán compartidos'
      : 'Your location and battery level will be shared';
  String get achievementsEarned =>
      _isEs ? 'Logros Obtenidos' : 'Achievements Earned';
  String get changeVisibility =>
      _isEs ? 'Cambiar Visibilidad' : 'Change Visibility';
  String get onlyVisibleToYou =>
      _isEs ? 'Solo visible para ti' : 'Only visible to you';
  String get visibleToEveryone =>
      _isEs ? 'Visible para todos' : 'Visible to everyone';
  String get visibleToFriendsOnly =>
      _isEs ? 'Visible solo para amigos' : 'Visible to friends only';
  String get promoted => _isEs ? 'Promovido' : 'Promoted';
  String get justNow => _isEs ? 'Ahora mismo' : 'Just now';
  String get ok => 'OK';
  String get writeAReply => _isEs ? 'Escribe una respuesta...' : 'Write a reply...';
  String get writeAComment => _isEs ? 'Escribe un comentario...' : 'Write a comment...';
  String get comments => _isEs ? 'Comentarios' : 'Comments';
  String get resumeTrip => _isEs ? 'Reanudar Viaje' : 'Resume Trip';
  String get pauseTrip => _isEs ? 'Pausar Viaje' : 'Pause Trip';
  String get restForNight => _isEs ? 'Descansar por la noche' : 'Rest for Night';
  String get sending => _isEs ? 'Enviando...' : 'Sending...';
  String get startingToday => _isEs ? '¡Empieza hoy!' : 'Starting today!';
  String get startsTomorrow => _isEs ? 'Empieza mañana' : 'Starts tomorrow';
  String startsInDays(int days) =>
      _isEs ? 'Empieza en $days días' : 'Starts in $days days';
  String dayNumber(int day) => _isEs ? 'Día $day' : 'Day $day';
  String get multiDayConvertConfirm => _isEs
      ? 'Esta acción es irreversible. Una vez que un viaje se convierte a multi-día, no se puede cambiar de vuelta a simple.'
      : 'This action is irreversible. Once a trip is converted to multi-day, it cannot be changed back to simple.';

  String get notSet => _isEs ? 'No establecido' : 'Not set';

  // --- Create trip screen ---
  String get newTripTitle => _isEs ? 'Nuevo Viaje' : 'New Trip';
  String get tripTitleLabel => _isEs ? 'Título del Viaje *' : 'Trip Title *';
  String get tripTitleHint => _isEs
      ? 'ej., Aventura Europea de Verano'
      : 'e.g., European Summer Adventure';
  String get tripDescriptionLabel =>
      _isEs ? 'Descripción (Opcional)' : 'Description (Optional)';
  String get tripDescriptionHint => _isEs
      ? 'Cuéntanos sobre tu viaje... (opcional)'
      : 'Tell us about your trip... (optional)';
  String get automaticUpdatesIntervalHint => 'e.g., 15';
  String get planDetails => _isEs ? 'Detalles del Plan' : 'Plan Details';
  String get multiDayTrip => _isEs ? '· Viaje Multi-Día' : '· Multi-day trip';
  String get datesOptional => _isEs ? 'Fechas (Opcional)' : 'Dates (Optional)';
  String get creating => _isEs ? 'Creando...' : 'Creating...';
  String get createTrip => _isEs ? 'Crear Viaje' : 'Create Trip';
  String get simple => _isEs ? 'Simple' : 'Simple';
  String get singleDayTrip => _isEs ? 'Viaje de un día' : 'Single-day trip';
  String get multiDay => _isEs ? 'Multi-Día' : 'Multi-Day';
  String get multiDayJourney => _isEs ? 'Viaje de varios días' : 'Multi-day journey';
  String get startDate => _isEs ? 'Fecha de Inicio' : 'Start Date';
  String get endDate => _isEs ? 'Fecha de Fin' : 'End Date';
  String get pleaseEnterTitle =>
      _isEs ? 'Por favor ingresa un título' : 'Please enter a title';

  // --- Trip plans screen ---
  String get deleteTripPlan =>
      _isEs ? 'Eliminar Plan de Viaje' : 'Delete Trip Plan';
  String get deleteTripPlanConfirm => _isEs
      ? '¿Estás seguro de que quieres eliminar '
      : 'Are you sure you want to delete ';
  String get editTripPlan => _isEs ? 'Editar Plan de Viaje' : 'Edit Trip Plan';
  String get createTripFromPlan =>
      _isEs ? 'Crear Viaje desde Plan' : 'Create Trip';
  String get noTripPlansYet =>
      _isEs ? 'Aún no hay Planes de Viaje' : 'No Trip Plans Yet';
  String get startPlanningAdventure => _isEs
      ? '¡Empieza a planificar tu próxima aventura!'
      : 'Start planning your next adventure!';
  String get createTripPlan =>
      _isEs ? 'Crear Plan de Viaje' : 'Create Trip Plan';
  String get loginRequired =>
      _isEs ? 'Inicio de Sesión Requerido' : 'Login Required';
  String get pleaseLogInForPlans => _isEs
      ? 'Por favor inicia sesión para ver tus planes de viaje'
      : 'Please log in to view your trip plans';
  String get errorLoadingTripPlans =>
      _isEs ? 'Error al cargar planes de viaje' : 'Error loading trip plans';
  String get noDateSet => _isEs ? 'Sin fechas establecidas' : 'No dates set';
  String get noRouteSet => _isEs ? 'Sin ruta establecida' : 'No route set';
  String get route => _isEs ? 'Ruta' : 'Route';
  String get createTripFromPlanTitle =>
      _isEs ? 'Crear viaje desde ' : 'Create a trip from ';
  String get saveChanges => _isEs ? 'Guardar Cambios' : 'Save Changes';

  // --- Create trip plan screen ---
  String get newTripPlan => _isEs ? 'Nuevo Plan de Viaje' : 'New Trip Plan';
  String get computingRoute =>
      _isEs ? 'Calculando ruta...' : 'Computing route...';
  String get tapMapToSetPosition => _isEs
      ? 'Toca el mapa para establecer una nueva posición'
      : 'Tap the map to set a new position';
  String get dragToReorder =>
      _isEs ? 'Arrastra para reordenar' : 'Drag to reorder';
  String get rePlaceOnMap =>
      _isEs ? 'Volver a colocar en el mapa' : 'Re-place on map';
  String get removeLastMarker =>
      _isEs ? 'Quitar último marcador' : 'Remove last marker';
  String get clearAllMarkers =>
      _isEs ? 'Borrar todos los marcadores' : 'Clear all markers';
  String get gettingLocation =>
      _isEs ? 'Obteniendo ubicación...' : 'Getting location...';
  String get dragMarkerOnMap => _isEs
      ? 'Arrastra el marcador en el mapa para moverlo'
      : 'Drag marker on map to move';
  String get longPressToDrag => _isEs
      ? 'Mantén presionado y arrastra para reposicionar'
      : 'Long press and drag to reposition';
  String get tapEditToModify => _isEs
      ? 'Toca Editar en la barra para modificar'
      : 'Tap Edit in the toolbar to modify';
  String get noLocationData => _isEs
      ? 'No hay datos de ubicación disponibles'
      : 'No location data available';

  // --- Trip promotion screen ---
  String get tripPromotion2 => _isEs ? 'Promoción de Viajes' : 'Trip Promotion';
  String get currentlyPromotedTrips =>
      _isEs ? 'Viajes Actualmente Promovidos' : 'Currently Promoted Trips';
  String get promotableTrips =>
      _isEs ? 'Viajes Promovibles' : 'Promotable Trips';
  String get noPromotedTrips =>
      _isEs ? 'No hay viajes promovidos' : 'No promoted trips';
  String get noPromotableTripsFound => _isEs
      ? 'No se encontraron viajes promovibles'
      : 'No promotable trips found';
  String get publicTripsNote => _isEs
      ? 'Viajes públicos que están creados, en progreso o pausados'
      : 'Public trips that are created, in progress, or paused';
  String get promoteTripTitle => _isEs ? 'Promover Viaje' : 'Promote Trip';
  String get unpromoteTripTitle =>
      _isEs ? 'Despromover Viaje' : 'Unpromote Trip';
  String get unpromoteConfirm => _isEs
      ? '¿Estás seguro de que quieres despromover este viaje?'
      : 'Are you sure you want to unpromote this trip?';
  String get donationLink =>
      _isEs ? 'Enlace de donación (opcional)' : 'Donation Link (optional)';
  String get preAnnounce => _isEs ? 'Pre-Anuncio' : 'Pre-Announce';
  String get showCountdown => _isEs
      ? 'Mostrar cuenta regresiva antes de que el viaje comience'
      : 'Show countdown before trip starts';
  String get startDateRequired => _isEs
      ? 'Se requiere fecha de inicio para pre-anuncios'
      : 'Start date is required for pre-announcements';
  String get searchTripsByNameOrUser => _isEs
      ? 'Buscar por nombre de viaje o usuario'
      : 'Search by trip name or username';
  String get searchTrips => _isEs ? 'Buscar viajes' : 'Search trips';
  String get loadMoreTrips2 => _isEs ? 'Cargar más viajes' : 'Load more trips';
  String get preAnnounced => _isEs ? 'Pre Anunciado' : 'Pre Announced';
  String get comingSoon => _isEs ? 'Próximamente' : 'Coming Soon';

  // --- Admin users screen ---
  String get userManagementTitle =>
      _isEs ? 'Gestión de Usuarios' : 'User Management';
  String get filterResults =>
      _isEs ? 'Filtrar resultados...' : 'Filter results...';
  String get noUsersFound =>
      _isEs ? 'No se encontraron usuarios' : 'No users found';
  String get viewProfile => _isEs ? 'Ver Perfil' : 'View Profile';
  String get promoteToAdmin => _isEs ? 'Promover a Admin' : 'Promote to Admin';
  String get demoteFromAdmin =>
      _isEs ? 'Quitar rol de Admin' : 'Demote from Admin';
  String get deleteUser => _isEs ? 'Eliminar Usuario' : 'Delete User';
  String get deleteUserConfirm => _isEs
      ? '¿Estás seguro de que quieres eliminar permanentemente a '
      : 'Are you sure you want to permanently delete ';
  String get deleteUserNote => _isEs
      ? 'Esta acción no se puede deshacer. Todos los datos del usuario serán eliminados.'
      : 'This action cannot be undone. All user data will be removed.';
  String get promoteUserConfirm => _isEs
      ? '¿Estás seguro de que quieres promover a '
      : 'Are you sure you want to promote ';
  String get demoteUserConfirm => _isEs
      ? '¿Estás seguro de que quieres quitar el rol de admin a '
      : 'Are you sure you want to remove admin role from ';
  String get sortBy => _isEs ? 'Ordenar por: ' : 'Sort by: ';
  String get firstPage => _isEs ? 'Primera página' : 'First page';
  String get previousPage => _isEs ? 'Página anterior' : 'Previous page';
  String get nextPage => _isEs ? 'Siguiente página' : 'Next page';
  String get lastPage => _isEs ? 'Última página' : 'Last page';
  String get adminBadge => 'ADMIN';

  // --- Trip maintenance screen ---
  String get tripDataOverview =>
      _isEs ? 'Resumen de Datos de Viajes' : 'Trip Data Overview';
  String get allTrips => _isEs ? 'Todos los Viajes' : 'All Trips';
  String get polylineStats =>
      _isEs ? 'Estadísticas de Polilínea' : 'Polyline Statistics';
  String get geocodingStats =>
      _isEs ? 'Estadísticas de Geocodificación' : 'Geocoding Statistics';
  String get polyline => 'Polyline';
  String get geocoding => 'Geocoding';
  String get needs1Location =>
      _isEs ? 'Necesita 1+ ubicación' : 'Needs 1+ location';
  String get needs2Locations =>
      _isEs ? 'Necesita 2+ ubicaciones' : 'Needs 2+ locations';
  String get recomputePolyline =>
      _isEs ? 'Recalcular Polilínea' : 'Recompute Polyline';
  String get recomputeGeocoding =>
      _isEs ? 'Recalcular Geocodificación' : 'Recompute Geocoding';
  String get recomputeAllPolylines =>
      _isEs ? 'Recalcular Todas las Polilíneas' : 'Recompute All Polylines';
  String get recomputeAll => _isEs ? 'Recalcular Todo' : 'Recompute All';
  String get recompute => _isEs ? 'Recalcular' : 'Recompute';
  String get searchByNameUsernameId => _isEs
      ? 'Buscar por nombre, usuario o ID de viaje'
      : 'Search by name, username, or trip ID';
  String get noTripsFoundMaintenance =>
      _isEs ? 'No se encontraron viajes' : 'No trips found';
  String get tapTripToView => _isEs
      ? 'Toca un viaje para ver detalles, o recalcular su polilínea/geocodificación'
      : 'Tap a trip to view details, or recompute its polyline/geocoding';
  String get recomputePolylineConfirm => _isEs
      ? 'Esto recalculará completamente la polilínea codificada de todas las'
      : 'This will fully recompute the encoded polyline from all ';
  String get recomputeGeocodingConfirm => _isEs
      ? 'Esto recalculará la ciudad y el país de todas las'
      : 'This will recompute city and country for all ';
  String get loadMoreTrips3 => _isEs ? 'Cargar más viajes' : 'Load more trips';
  String get searchTrips2 => _isEs ? 'Buscar viajes' : 'Search trips';

  // --- Deep link screens ---
  String get loadingTripDeepLink => _isEs ? 'Cargando viaje…' : 'Loading trip…';
  String get loadingProfileDeepLink =>
      _isEs ? 'Cargando perfil…' : 'Loading profile…';
  String get goHome => _isEs ? 'Ir al inicio' : 'Go Home';

  // --- Home widgets ---
  String get seeAll => _isEs ? 'Ver todo' : 'See All';
  String get tapPlusToCreate => _isEs
      ? 'Toca el botón + para crear un viaje'
      : 'Tap the + button to create a trip';
  String get loginOrRegister =>
      _isEs ? 'Iniciar sesión / Registrarse' : 'Login / Register';
  String get following => _isEs ? 'Siguiendo' : 'Following';
  String get friend => _isEs ? 'Amigo' : 'Friend';

  // --- Trip info card ---
  String get privateVisibilityHint =>
      _isEs ? 'Solo visible para ti' : 'Only visible to you';
  String get publicVisibilityHint =>
      _isEs ? 'Visible para todos' : 'Visible to everyone';
  String get protectedVisibilityHint =>
      _isEs ? 'Visible solo para amigos' : 'Visible to friends only';

  // --- Home screen sections / filter chips ---
  String get activeTripsSection =>
      _isEs ? 'Viajes Activos' : 'Active Trips';
  String get currentlyInProgress =>
      _isEs ? 'Actualmente en curso' : 'Currently in progress';
  String get pausedTripsSection =>
      _isEs ? 'Viajes Pausados' : 'Paused Trips';
  String get temporarilyStopped =>
      _isEs ? 'Temporalmente detenido' : 'Temporarily stopped';
  String get draftTripsSection =>
      _isEs ? 'Viajes Borrador' : 'Draft Trips';
  String get notYetStarted =>
      _isEs ? 'Aún no comenzado' : 'Not yet started';
  String get completedTripsSection =>
      _isEs ? 'Viajes Completados' : 'Completed Trips';
  String get finishedAdventures =>
      _isEs ? 'Aventuras terminadas' : 'Finished adventures';
  String get liveNow => _isEs ? 'En Vivo Ahora' : 'Live Now';
  String get happeningRightNow =>
      _isEs ? 'Ocurriendo ahora mismo' : 'Happening right now';
  String get friendsTripsSection =>
      _isEs ? 'Viajes de Amigos' : "Friends' Trips";
  String get fromYourFriends =>
      _isEs ? 'De tus amigos' : 'From your friends';
  String get fromUsersYouFollow =>
      _isEs ? 'De usuarios que sigues' : 'From users you follow';
  String get createYourFirstTrip =>
      _isEs ? '¡Crea tu primer viaje para comenzar!' : 'Create your first trip to get started!';
  String get noTripsInYourFeed =>
      _isEs ? 'No hay viajes en tu feed' : 'No trips in your feed';
  String get followUsersToSeeFeed =>
      _isEs ? '¡Sigue usuarios o añade amigos para ver sus viajes!' : 'Follow users or add friends to see their trips!';
  String get deleteTripWarning =>
      _isEs ? 'Esta acción no se puede deshacer.' : 'This action cannot be undone.';

  // Timeline day/trip markers
  String dayNStarted(int day) =>
      _isEs ? 'Día $day Iniciado' : 'Day $day Started';
  String dayNEnded(int day) =>
      _isEs ? 'Día $day Finalizado' : 'Day $day Ended';
  String get tripStartedLabel =>
      _isEs ? 'Viaje Iniciado' : 'Trip Started';
  String get tripEndedLabel =>
      _isEs ? 'Viaje Finalizado' : 'Trip Ended';
  String get updateLabel => _isEs ? 'Actualización' : 'Update';

  // Comments section
  String get beFirstToComment =>
      _isEs ? '¡Sé el primero en comentar!' : 'Be the first to comment!';
  String get loginToAddComment =>
      _isEs ? 'Inicia sesión para añadir un comentario' : 'Log in to add a comment';

  // Achievements screen
  String achievementsProgress(int unlocked, int total) =>
      _isEs ? 'Logros ($unlocked/$total)' : 'Achievements ($unlocked/$total)';
  String achievedValue(String value) =>
      _isEs ? 'Logrado: $value' : 'Achieved: $value';
  String unlockedOn(String date) =>
      _isEs ? 'Desbloqueado el $date' : 'Unlocked on $date';
  String goalValue(String value) =>
      _isEs ? 'Meta: $value' : 'Goal: $value';

  // Achievement categories
  String get categoryDistance => _isEs ? 'Distancia' : 'Distance';
  String get categoryUpdates => _isEs ? 'Actualizaciones' : 'Updates';
  String get categoryDuration => _isEs ? 'Duración' : 'Duration';
  String get categorySocial => _isEs ? 'Social' : 'Social';
  String get categoryOther => _isEs ? 'Otro' : 'Other';

  // Achievement units
  String achievementKm(double v) =>
      _isEs ? '${v.toStringAsFixed(1)} km' : '${v.toStringAsFixed(1)} km';
  String achievementDays(int v) => _isEs ? '$v días' : '$v days';
  String achievementUpdatesCount(int v) =>
      _isEs ? '$v actualizaciones' : '$v updates';
  String achievementFollowers(int v) =>
      _isEs ? '$v seguidores' : '$v followers';
  String achievementFriends(int v) => _isEs ? '$v amigos' : '$v friends';

  // Achievement localized names (keyed by backend type string)
  String achievementNameFor(String typeKey) {
    switch (typeKey) {
      case 'DISTANCE_100KM':
        return '100 km';
      case 'DISTANCE_200KM':
        return '200 km';
      case 'DISTANCE_500KM':
        return '500 km';
      case 'DISTANCE_800KM':
        return '800 km';
      case 'DISTANCE_1000KM':
        return _isEs ? '1.000 km' : '1,000 km';
      case 'DISTANCE_1600KM':
        return _isEs ? '1.600 km' : '1,600 km';
      case 'DISTANCE_2200KM':
        return _isEs ? '2.200 km' : '2,200 km';
      case 'UPDATES_10':
        return _isEs ? '10 Actualizaciones' : '10 Updates';
      case 'UPDATES_50':
        return _isEs ? '50 Actualizaciones' : '50 Updates';
      case 'UPDATES_100':
        return _isEs ? '100 Actualizaciones' : '100 Updates';
      case 'DURATION_7_DAYS':
        return _isEs ? '7 Días' : '7 Days';
      case 'DURATION_30_DAYS':
        return _isEs ? '30 Días' : '30 Days';
      case 'DURATION_45_DAYS':
        return _isEs ? '45 Días' : '45 Days';
      case 'DURATION_60_DAYS':
        return _isEs ? '60 Días' : '60 Days';
      case 'FOLLOWERS_10':
        return _isEs ? '10 Seguidores' : '10 Followers';
      case 'FOLLOWERS_50':
        return _isEs ? '50 Seguidores' : '50 Followers';
      case 'FOLLOWERS_100':
        return _isEs ? '100 Seguidores' : '100 Followers';
      case 'FRIENDS_5':
        return _isEs ? '5 Amigos' : '5 Friends';
      case 'FRIENDS_20':
        return _isEs ? '20 Amigos' : '20 Friends';
      case 'FRIENDS_50':
        return _isEs ? '50 Amigos' : '50 Friends';
      default:
        return typeKey;
    }
  }

  // Achievement localized descriptions (keyed by backend type string)
  String achievementDescriptionFor(String typeKey) {
    switch (typeKey) {
      case 'DISTANCE_100KM':
        return _isEs
            ? 'Camina 100 km en un solo viaje'
            : 'Walk 100 km in a single trip';
      case 'DISTANCE_200KM':
        return _isEs
            ? 'Camina 200 km en un solo viaje'
            : 'Walk 200 km in a single trip';
      case 'DISTANCE_500KM':
        return _isEs
            ? 'Camina 500 km en un solo viaje'
            : 'Walk 500 km in a single trip';
      case 'DISTANCE_800KM':
        return _isEs
            ? 'Camina 800 km en un solo viaje'
            : 'Walk 800 km in a single trip';
      case 'DISTANCE_1000KM':
        return _isEs
            ? 'Camina 1.000 km en un solo viaje'
            : 'Walk 1,000 km in a single trip';
      case 'DISTANCE_1600KM':
        return _isEs
            ? 'Camina 1.600 km en un solo viaje'
            : 'Walk 1,600 km in a single trip';
      case 'DISTANCE_2200KM':
        return _isEs
            ? 'Camina 2.200 km en un solo viaje'
            : 'Walk 2,200 km in a single trip';
      case 'UPDATES_10':
        return _isEs
            ? 'Publica 10 actualizaciones en un viaje'
            : 'Post 10 updates in a trip';
      case 'UPDATES_50':
        return _isEs
            ? 'Publica 50 actualizaciones en un viaje'
            : 'Post 50 updates in a trip';
      case 'UPDATES_100':
        return _isEs
            ? 'Publica 100 actualizaciones en un viaje'
            : 'Post 100 updates in a trip';
      case 'DURATION_7_DAYS':
        return _isEs
            ? 'Completa un viaje de 7 días'
            : 'Complete a trip lasting 7 days';
      case 'DURATION_30_DAYS':
        return _isEs
            ? 'Completa un viaje de 30 días'
            : 'Complete a trip lasting 30 days';
      case 'DURATION_45_DAYS':
        return _isEs
            ? 'Completa un viaje de 45 días'
            : 'Complete a trip lasting 45 days';
      case 'DURATION_60_DAYS':
        return _isEs
            ? 'Completa un viaje de 60 días'
            : 'Complete a trip lasting 60 days';
      case 'FOLLOWERS_10':
        return _isEs ? 'Consigue 10 seguidores' : 'Reach 10 followers';
      case 'FOLLOWERS_50':
        return _isEs ? 'Consigue 50 seguidores' : 'Reach 50 followers';
      case 'FOLLOWERS_100':
        return _isEs ? 'Consigue 100 seguidores' : 'Reach 100 followers';
      case 'FRIENDS_5':
        return _isEs ? 'Haz 5 amigos' : 'Make 5 friends';
      case 'FRIENDS_20':
        return _isEs ? 'Haz 20 amigos' : 'Make 20 friends';
      case 'FRIENDS_50':
        return _isEs ? 'Haz 50 amigos' : 'Make 50 friends';
      default:
        return typeKey;
    }
  }

  // --- Profile screen ---
  String get mustBeLoggedInToViewProfile =>
      _isEs ? 'Debes iniciar sesión para ver tu perfil' : 'You must be logged in to view your profile';
  String get profileUpdatedSuccessfully =>
      _isEs ? '¡Perfil actualizado con éxito!' : 'Profile updated successfully!';
  String get failedToUpdateProfile =>
      _isEs ? 'No se pudo actualizar el perfil' : 'Failed to update profile';
  String get tapPencilToAddBio =>
      _isEs ? 'Toca el lápiz para añadir una bio...' : 'Tap the pencil to add a bio...';
  String get noBioYet => _isEs ? 'Aún sin bio.' : 'No bio yet.';
  String get follow => _isEs ? 'Seguir' : 'Follow';
  String get unfriend => _isEs ? 'Eliminar amigo' : 'Unfriend';
  String get cancelFriendRequest =>
      _isEs ? 'Cancelar solicitud de amistad' : 'Cancel Friend Request';
  String get sendFriendRequest =>
      _isEs ? 'Enviar solicitud de amistad' : 'Send Friend Request';
  String get followers => _isEs ? 'Seguidores' : 'Followers';
  String myTripsLabel(bool isOwn) =>
      isOwn ? (_isEs ? 'Mis Viajes' : 'My Trips') : (_isEs ? 'Viajes' : 'Trips');
  String tripCountLabel(int count) =>
      count == 1 ? (_isEs ? '1 viaje' : '1 trip') : (_isEs ? '$count viajes' : '$count trips');
  String get sortOptionStatus => _isEs ? 'Estado' : 'Status';
  String get sortOptionNameAZ => _isEs ? 'Nombre (A-Z)' : 'Name (A-Z)';
  String get sortOptionNameZA => _isEs ? 'Nombre (Z-A)' : 'Name (Z-A)';
  String get sortOptionNewest => _isEs ? 'Más reciente' : 'Newest';
  String get sortOptionOldest => _isEs ? 'Más antiguo' : 'Oldest';
  String unfollowedUser(String username) =>
      _isEs ? 'Dejaste de seguir a $username' : 'Unfollowed $username';
  String nowFollowingUser(String username) =>
      _isEs ? 'Ahora sigues a $username' : 'You are now following $username';
  String noLongerFriendsWith(String username) =>
      _isEs ? 'Ya no eres amigo de $username' : 'You are no longer friends with $username';
  String get friendRequestCancelled =>
      _isEs ? 'Solicitud de amistad cancelada' : 'Friend request cancelled';
  String friendRequestSentTo(String username) =>
      _isEs ? 'Solicitud de amistad enviada a $username' : 'Friend request sent to $username';
}
