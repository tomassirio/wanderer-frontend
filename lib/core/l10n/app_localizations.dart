import 'package:flutter/widgets.dart';
import 'locale_controller.dart';
import 'translations/translations_en.dart';
import 'translations/translations_es.dart';
import 'translations/translations_fr.dart';
import 'translations/translations_nl.dart';

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

/// Provides translated strings for the app UI in English, Spanish, French
/// and Dutch.
///
/// Usage (preferred — reactive):
/// ```dart
/// final l10n = context.l10n;
/// Text(l10n.trips)
/// ```
class AppLocalizations {
  final String _lang;
  late final Map<String, String> _t;

  static const Map<String, Map<String, String>> _allTranslations = {
    'en': translationsEn,
    'es': translationsEs,
    'fr': translationsFr,
    'nl': translationsNl,
  };

  AppLocalizations(this._lang) {
    _t = _allTranslations[_lang] ?? translationsEn;
  }

  /// Creates an instance reflecting the current locale from [LocaleController].
  /// Prefer [BuildContext.l10n] in widget build methods for auto-rebuild.
  factory AppLocalizations.fromController() =>
      AppLocalizations(LocaleController().locale.value.languageCode);

  /// Look up a key, falling back to English if missing.
  String _tr(String key) => _t[key] ?? translationsEn[key] ?? key;

  // --- Sidebar navigation ---
  String get trips => _tr('trips');
  String get tripPlans => _tr('tripPlans');
  String get friends => _tr('friends');
  String get achievements => _tr('achievements');
  String get tripPromotion => _tr('tripPromotion');
  String get userManagement => _tr('userManagement');
  String get tripDataMaintenance => _tr('tripDataMaintenance');
  String get buyMeACoffee => _tr('buyMeACoffee');
  String get logout => _tr('logout');
  String get logIn => _tr('logIn');
  String get guest => _tr('guest');
  String get myProfile => _tr('myProfile');
  String get settings => _tr('settings');

  // --- App bar / navigation ---
  String get wanderer => _tr('wanderer');
  String get login => _tr('login');
  String get notifications => _tr('notifications');
  String get profile => _tr('profile');
  String get search => _tr('search');
  String get userProfile => _tr('userProfile');
  String get switchToLightMode => _tr('switchToLightMode');
  String get switchToDarkMode => _tr('switchToDarkMode');

  // --- Common actions ---
  String get cancel => _tr('cancel');
  String get delete => _tr('delete');
  String get save => _tr('save');
  String get retry => _tr('retry');
  String get confirm => _tr('confirm');
  String get edit => _tr('edit');
  String get close => _tr('close');
  String get create => _tr('create');
  String get minimize => _tr('minimize');
  String get refresh => _tr('refresh');
  String get done => _tr('done');
  String get send => _tr('send');
  String get remove => _tr('remove');
  String get promote => _tr('promote');
  String get unpromote => _tr('unpromote');

  // --- Trip status ---
  String get allStatus => _tr('allStatus');
  String get live => _tr('live');
  String get paused => _tr('paused');
  String get completed => _tr('completed');
  String get draft => _tr('draft');
  String get resting => _tr('resting');

  // --- Visibility ---
  String get allVisibility => _tr('allVisibility');
  String get publicVisibility => _tr('publicVisibility');
  String get protectedVisibility => _tr('protectedVisibility');
  String get privateVisibility => _tr('privateVisibility');
  String get visibility => _tr('visibility');

  // --- Home screen ---
  String get newTrip => _tr('newTrip');
  String get deleteTrip => _tr('deleteTrip');
  String get deleteTripConfirm => _tr('deleteTripConfirm');
  String get welcomeToWanderer => _tr('welcomeToWanderer');
  String get trackAdventures => _tr('trackAdventures');
  String get discoverAdventures => _tr('discoverAdventures');
  String get explorePublicTrips => _tr('explorePublicTrips');
  String get noTripsYet => _tr('noTripsYet');
  String get createFirstTrip => _tr('createFirstTrip');
  String get noTripsInFeed => _tr('noTripsInFeed');
  String get followToSeeTrips => _tr('followToSeeTrips');
  String get noPublicTripsFound => _tr('noPublicTripsFound');
  String get checkBackLater => _tr('checkBackLater');
  String get errorLoadingTrips => _tr('errorLoadingTrips');
  String get loadMoreTrips => _tr('loadMoreTrips');
  String get myTrips => _tr('myTrips');
  String get friendsTrips => _tr('friendsTrips');
  String get discover => _tr('discover');
  String get featuredTrips => _tr('featuredTrips');
  String get highlightedAdventures => _tr('highlightedAdventures');
  String get explorePublicTripsSubtitle => _tr('explorePublicTripsSubtitle');
  String get feed => _tr('feed');
  String get minuteAgo => _tr('minuteAgo');
  String minutesAgo(int n) {
    switch (_lang) {
      case 'es':
        return 'hace $n minutos';
      case 'fr':
        return 'il y a $n minutes';
      case 'nl':
        return '$n minuten geleden';
      default:
        return '$n minutes ago';
    }
  }

  String get hourAgo => _tr('hourAgo');
  String hoursAgo(int n) {
    switch (_lang) {
      case 'es':
        return 'hace $n horas';
      case 'fr':
        return 'il y a $n heures';
      case 'nl':
        return '$n uur geleden';
      default:
        return '$n hours ago';
    }
  }

  String get dayAgo => _tr('dayAgo');
  String daysAgo(int n) {
    switch (_lang) {
      case 'es':
        return 'hace $n días';
      case 'fr':
        return 'il y a $n jours';
      case 'nl':
        return '$n dagen geleden';
      default:
        return '$n days ago';
    }
  }

  String get weekAgo => _tr('weekAgo');
  String weeksAgo(int n) {
    switch (_lang) {
      case 'es':
        return 'hace $n semanas';
      case 'fr':
        return 'il y a $n semaines';
      case 'nl':
        return '$n weken geleden';
      default:
        return '$n weeks ago';
    }
  }

  String get monthAgo => _tr('monthAgo');
  String monthsAgo(int n) {
    switch (_lang) {
      case 'es':
        return 'hace $n meses';
      case 'fr':
        return 'il y a $n mois';
      case 'nl':
        return '$n maanden geleden';
      default:
        return '$n months ago';
    }
  }

  String minutesAgoCompact(int n) => '${n}m';
  String hoursAgoCompact(int n) => '${n}h';
  String daysAgoCompact(int n) => '${n}d';

  String get orExplorePublicTrips => _tr('orExplorePublicTrips');

  // --- Search ---
  String get searchHint => _tr('searchHint');
  String get couldNotLoadResults => _tr('couldNotLoadResults');
  String get noTripsFound => _tr('noTripsFound');

  // --- Notifications ---
  String get noNotificationsYet => _tr('noNotificationsYet');
  String get notificationsWillAppear => _tr('notificationsWillAppear');
  String get readAll => _tr('readAll');
  String get loadMoreNotifications => _tr('loadMoreNotifications');
  String get pleaseLogInForNotifications => _tr('pleaseLogInForNotifications');
  String get failedToLoadNotifications => _tr('failedToLoadNotifications');

  // --- Auth screen ---
  String get welcomeBack => _tr('welcomeBack');
  String get createAccount => _tr('createAccount');
  String get signInToContinue => _tr('signInToContinue');
  String get signUpToStart => _tr('signUpToStart');
  String get signIn => _tr('signIn');
  String get signUp => _tr('signUp');
  String get alreadyHaveAccount => _tr('alreadyHaveAccount');
  String get dontHaveAccount => _tr('dontHaveAccount');
  String get forgotPassword => _tr('forgotPassword');
  String get backToLogin => _tr('backToLogin');
  String get checkYourEmail => _tr('checkYourEmail');
  String get emailLabel => _tr('emailLabel');
  String get usernameLabel => _tr('usernameLabel');
  String get passwordLabel => _tr('passwordLabel');
  String get pleaseEnterPassword => _tr('pleaseEnterPassword');
  String get passwordMinLength => _tr('passwordMinLength');
  String get passwordsDoNotMatch => _tr('passwordsDoNotMatch');
  String get resetPasswordTitle => _tr('resetPasswordTitle');
  String get enterEmailForReset => _tr('enterEmailForReset');
  String get sendResetLink => _tr('sendResetLink');
  String passwordResetEmailSent(String email) {
    switch (_lang) {
      case 'es':
        return 'Si existe una cuenta con $email, hemos enviado un enlace de restablecimiento. Revisa tu bandeja de entrada y sigue las instrucciones para restablecer tu contraseña.';
      case 'fr':
        return 'Si un compte avec $email existe, nous avons envoyé un lien de réinitialisation. Vérifiez votre boîte de réception et suivez les instructions pour réinitialiser votre mot de passe.';
      case 'nl':
        return 'Als er een account met $email bestaat, hebben we een herstellink gestuurd. Controleer je inbox en volg de instructies om je wachtwoord te herstellen.';
      default:
        return 'If an account with $email exists, we\'ve sent a password reset link. Check your inbox and follow the instructions to reset your password.';
    }
  }

  String get pleaseEnterEmail => _tr('pleaseEnterEmail');
  String get pleaseEnterValidEmail => _tr('pleaseEnterValidEmail');
  String get pleaseEnterUsername => _tr('pleaseEnterUsername');
  String get usernameMinLength => _tr('usernameMinLength');
  String get confirmPassword => _tr('confirmPassword');

  // --- Verify email ---
  String get verifyYourEmail => _tr('verifyYourEmail');
  String get verifyEmail => _tr('verifyEmail');
  String get emailVerified => _tr('emailVerified');
  String get verifyingEmail => _tr('verifyingEmail');
  String get verificationToken => _tr('verificationToken');
  String get enterVerificationToken => _tr('enterVerificationToken');
  String get accountNowActive => _tr('accountNowActive');

  // --- Settings screen ---
  String get appearance => _tr('appearance');
  String get darkMode => _tr('darkMode');
  String get darkModeSubtitle => _tr('darkModeSubtitle');
  String get language => _tr('language');
  String get account => _tr('account');
  String get changePassword => _tr('changePassword');
  String get changePasswordSubtitle => _tr('changePasswordSubtitle');
  String get resetPassword => _tr('resetPassword');
  String get resetPasswordSubtitle => _tr('resetPasswordSubtitle');
  String get support => _tr('support');
  String get contactSupport => _tr('contactSupport');
  String get contactSupportSubtitle => _tr('contactSupportSubtitle');
  String get termsOfService => _tr('termsOfService');
  String get privacyPolicy => _tr('privacyPolicy');
  String get pushNotifications => _tr('pushNotifications');
  String get pushNotificationsSubtitle => _tr('pushNotificationsSubtitle');
  String get closeAccount => _tr('closeAccount');
  String get closeAccountSubtitle => _tr('closeAccountSubtitle');
  String get confirmAccountDeletion => _tr('confirmAccountDeletion');
  String get deleteMyAccount => _tr('deleteMyAccount');
  String get typeDELETE => _tr('typeDELETE');
  String get typeDELETEConfirm => _tr('typeDELETEConfirm');
  String get areYouSureDeleteAccount => _tr('areYouSureDeleteAccount');
  String get currentPassword => _tr('currentPassword');
  String get newPassword => _tr('newPassword');
  String get confirmNewPassword => _tr('confirmNewPassword');
  String get changePasswordTitle => _tr('changePasswordTitle');
  String get continue_ => _tr('continue_');
  String get appVersion => _tr('appVersion');
  String get notificationsSection => _tr('notificationsSection');

  // --- Profile screen ---
  String get editProfile => _tr('editProfile');
  String get noProfileData => _tr('noProfileData');
  String get noTripsMatchFilters => _tr('noTripsMatchFilters');
  String get clearAllFilters => _tr('clearAllFilters');
  String get clearFilters => _tr('clearFilters');
  String get sortTripsBy => _tr('sortTripsBy');
  String get displayName => _tr('displayName');
  String get yourDisplayName => _tr('yourDisplayName');
  String get bio => _tr('bio');
  String get tellUsAboutYourself => _tr('tellUsAboutYourself');
  String get avatarUrl => _tr('avatarUrl');

  // --- Friends & Followers screen ---
  String get followBack => _tr('followBack');
  String get unfollow => _tr('unfollow');
  String get noFollowersYet => _tr('noFollowersYet');
  String get notFollowingAnyone => _tr('notFollowingAnyone');
  String get noFriendRequests => _tr('noFriendRequests');
  String get noFriendsYet => _tr('noFriendsYet');
  String get noSentRequests => _tr('noSentRequests');
  String get sendFriendRequests => _tr('sendFriendRequests');

  // --- Achievements screen ---
  String get noAchievementsYet => _tr('noAchievementsYet');

  // --- Trip detail screen ---
  String get loadingTrip => _tr('loadingTrip');
  String get supportTrip => _tr('supportTrip');
  String get startTrip => _tr('startTrip');
  String get finishTrip => _tr('finishTrip');
  String get finishDay => _tr('finishDay');
  String get pause => _tr('pause');
  String get resume => _tr('resume');
  String get finish => _tr('finish');
  String get finishTripConfirm => _tr('finishTripConfirm');
  String get shareTrip => _tr('shareTrip');
  String get tripSettings => _tr('tripSettings');
  String get showPlannedRoute => _tr('showPlannedRoute');
  String get tripType => _tr('tripType');
  String get automaticUpdates => _tr('automaticUpdates');
  String get locationInterval => _tr('locationInterval');
  String get willActivateWhenStarted => _tr('willActivateWhenStarted');
  String get switchToMultiDay => _tr('switchToMultiDay');
  String get multiDayIrreversible => _tr('multiDayIrreversible');
  String get testBackgroundUpdate => _tr('testBackgroundUpdate');
  String get firesWorkManagerTask => _tr('firesWorkManagerTask');
  String get loadingMap => _tr('loadingMap');
  String get mapLoadingError => _tr('mapLoadingError');
  String get loadingTimeline => _tr('loadingTimeline');
  String get noUpdatesYet => _tr('noUpdatesYet');
  String get tripUpdatesWillAppear => _tr('tripUpdatesWillAppear');
  String get loadOlderUpdates => _tr('loadOlderUpdates');
  String get timeline => _tr('timeline');
  String get noCommentsYet => _tr('noCommentsYet');
  String get pleaseLogInToComment => _tr('pleaseLogInToComment');
  String get loadMoreComments => _tr('loadMoreComments');
  String get latestFirst => _tr('latestFirst');
  String get oldestFirst => _tr('oldestFirst');
  String get mostReactions => _tr('mostReactions');
  String get mostReplies => _tr('mostReplies');
  String get chooseReaction => _tr('chooseReaction');
  String get react => _tr('react');
  String get reply => _tr('reply');
  String get author => _tr('author');
  String get replyingToComment => _tr('replyingToComment');
  String get cancelReply => _tr('cancelReply');
  String get addMessageOptional => _tr('addMessageOptional');
  String get sendUpdate => _tr('sendUpdate');
  String get locationShared => _tr('locationShared');
  String get achievementsEarned => _tr('achievementsEarned');
  String get changeVisibility => _tr('changeVisibility');
  String get onlyVisibleToYou => _tr('onlyVisibleToYou');
  String get visibleToEveryone => _tr('visibleToEveryone');
  String get visibleToFriendsOnly => _tr('visibleToFriendsOnly');
  String get promoted => _tr('promoted');
  String get justNow => _tr('justNow');
  String get ok => _tr('ok');
  String get writeAReply => _tr('writeAReply');
  String get writeAComment => _tr('writeAComment');
  String get comments => _tr('comments');
  String get resumeTrip => _tr('resumeTrip');
  String get pauseTrip => _tr('pauseTrip');
  String get restForNight => _tr('restForNight');
  String get sending => _tr('sending');
  String get startingToday => _tr('startingToday');
  String get startsTomorrow => _tr('startsTomorrow');
  String startsInDays(int days) {
    switch (_lang) {
      case 'es':
        return 'Empieza en $days días';
      case 'fr':
        return 'Commence dans $days jours';
      case 'nl':
        return 'Begint over $days dagen';
      default:
        return 'Starts in $days days';
    }
  }

  String dayNumber(int day) {
    switch (_lang) {
      case 'es':
        return 'Día $day';
      case 'fr':
        return 'Jour $day';
      case 'nl':
        return 'Dag $day';
      default:
        return 'Day $day';
    }
  }

  String get multiDayConvertConfirm => _tr('multiDayConvertConfirm');
  String get notSet => _tr('notSet');

  // --- Create trip screen ---
  String get newTripTitle => _tr('newTripTitle');
  String get tripTitleLabel => _tr('tripTitleLabel');
  String get tripTitleHint => _tr('tripTitleHint');
  String get tripDescriptionLabel => _tr('tripDescriptionLabel');
  String get tripDescriptionHint => _tr('tripDescriptionHint');
  String get automaticUpdatesIntervalHint =>
      _tr('automaticUpdatesIntervalHint');
  String get planDetails => _tr('planDetails');
  String get multiDayTrip => _tr('multiDayTrip');
  String get datesOptional => _tr('datesOptional');
  String get creating => _tr('creating');
  String get createTrip => _tr('createTrip');
  String get simple => _tr('simple');
  String get singleDayTrip => _tr('singleDayTrip');
  String get multiDay => _tr('multiDay');
  String get multiDayJourney => _tr('multiDayJourney');
  String get startDate => _tr('startDate');
  String get endDate => _tr('endDate');
  String get pleaseEnterTitle => _tr('pleaseEnterTitle');

  // --- Trip plans screen ---
  String get deleteTripPlan => _tr('deleteTripPlan');
  String get deleteTripPlanConfirm => _tr('deleteTripPlanConfirm');
  String get editTripPlan => _tr('editTripPlan');
  String get createTripFromPlan => _tr('createTripFromPlan');
  String get noTripPlansYet => _tr('noTripPlansYet');
  String get startPlanningAdventure => _tr('startPlanningAdventure');
  String get createTripPlan => _tr('createTripPlan');
  String get loginRequired => _tr('loginRequired');
  String get pleaseLogInForPlans => _tr('pleaseLogInForPlans');
  String get errorLoadingTripPlans => _tr('errorLoadingTripPlans');
  String get noDateSet => _tr('noDateSet');
  String get noRouteSet => _tr('noRouteSet');
  String get route => _tr('route');
  String get createTripFromPlanTitle => _tr('createTripFromPlanTitle');
  String get saveChanges => _tr('saveChanges');

  // --- Create trip plan screen ---
  String get newTripPlan => _tr('newTripPlan');
  String get computingRoute => _tr('computingRoute');
  String get tapMapToSetPosition => _tr('tapMapToSetPosition');
  String get dragToReorder => _tr('dragToReorder');
  String get rePlaceOnMap => _tr('rePlaceOnMap');
  String get removeLastMarker => _tr('removeLastMarker');
  String get clearAllMarkers => _tr('clearAllMarkers');
  String get gettingLocation => _tr('gettingLocation');
  String get dragMarkerOnMap => _tr('dragMarkerOnMap');
  String get longPressToDrag => _tr('longPressToDrag');
  String get tapEditToModify => _tr('tapEditToModify');
  String get noLocationData => _tr('noLocationData');

  // --- Trip promotion screen ---
  String get tripPromotion2 => _tr('tripPromotion2');
  String get currentlyPromotedTrips => _tr('currentlyPromotedTrips');
  String get promotableTrips => _tr('promotableTrips');
  String get noPromotedTrips => _tr('noPromotedTrips');
  String get noPromotableTripsFound => _tr('noPromotableTripsFound');
  String get publicTripsNote => _tr('publicTripsNote');
  String get promoteTripTitle => _tr('promoteTripTitle');
  String get unpromoteTripTitle => _tr('unpromoteTripTitle');
  String get unpromoteConfirm => _tr('unpromoteConfirm');
  String get donationLink => _tr('donationLink');
  String get preAnnounce => _tr('preAnnounce');
  String get showCountdown => _tr('showCountdown');
  String get startDateRequired => _tr('startDateRequired');
  String get searchTripsByNameOrUser => _tr('searchTripsByNameOrUser');
  String get searchTrips => _tr('searchTrips');
  String get loadMoreTrips2 => _tr('loadMoreTrips2');
  String get preAnnounced => _tr('preAnnounced');
  String get comingSoon => _tr('comingSoon');

  // --- Admin users screen ---
  String get userManagementTitle => _tr('userManagementTitle');
  String get filterResults => _tr('filterResults');
  String get noUsersFound => _tr('noUsersFound');
  String get viewProfile => _tr('viewProfile');
  String get promoteToAdmin => _tr('promoteToAdmin');
  String get demoteFromAdmin => _tr('demoteFromAdmin');
  String get deleteUser => _tr('deleteUser');
  String get deleteUserConfirm => _tr('deleteUserConfirm');
  String get deleteUserNote => _tr('deleteUserNote');
  String get promoteUserConfirm => _tr('promoteUserConfirm');
  String get demoteUserConfirm => _tr('demoteUserConfirm');
  String get sortBy => _tr('sortBy');
  String get firstPage => _tr('firstPage');
  String get previousPage => _tr('previousPage');
  String get nextPage => _tr('nextPage');
  String get lastPage => _tr('lastPage');
  String get adminBadge => _tr('adminBadge');

  // --- Trip maintenance screen ---
  String get tripDataOverview => _tr('tripDataOverview');
  String get allTrips => _tr('allTrips');
  String get polylineStats => _tr('polylineStats');
  String get geocodingStats => _tr('geocodingStats');
  String get polyline => _tr('polyline');
  String get geocoding => _tr('geocoding');
  String get needs1Location => _tr('needs1Location');
  String get needs2Locations => _tr('needs2Locations');
  String get recomputePolyline => _tr('recomputePolyline');
  String get recomputeGeocoding => _tr('recomputeGeocoding');
  String get recomputeAllPolylines => _tr('recomputeAllPolylines');
  String get recomputeAll => _tr('recomputeAll');
  String get recompute => _tr('recompute');
  String get searchByNameUsernameId => _tr('searchByNameUsernameId');
  String get noTripsFoundMaintenance => _tr('noTripsFoundMaintenance');
  String get tapTripToView => _tr('tapTripToView');
  String get recomputePolylineConfirm => _tr('recomputePolylineConfirm');
  String get recomputeGeocodingConfirm => _tr('recomputeGeocodingConfirm');
  String get loadMoreTrips3 => _tr('loadMoreTrips3');
  String get searchTrips2 => _tr('searchTrips2');

  // --- Deep link screens ---
  String get loadingTripDeepLink => _tr('loadingTripDeepLink');
  String get loadingProfileDeepLink => _tr('loadingProfileDeepLink');
  String get goHome => _tr('goHome');

  // --- Home widgets ---
  String get seeAll => _tr('seeAll');
  String get tapPlusToCreate => _tr('tapPlusToCreate');
  String get loginOrRegister => _tr('loginOrRegister');
  String get following => _tr('following');
  String get friend => _tr('friend');

  // --- Trip info card ---
  String get privateVisibilityHint => _tr('privateVisibilityHint');
  String get publicVisibilityHint => _tr('publicVisibilityHint');
  String get protectedVisibilityHint => _tr('protectedVisibilityHint');

  // --- Home screen sections / filter chips ---
  String get activeTripsSection => _tr('activeTripsSection');
  String get currentlyInProgress => _tr('currentlyInProgress');
  String get pausedTripsSection => _tr('pausedTripsSection');
  String get temporarilyStopped => _tr('temporarilyStopped');
  String get draftTripsSection => _tr('draftTripsSection');
  String get notYetStarted => _tr('notYetStarted');
  String get completedTripsSection => _tr('completedTripsSection');
  String get finishedAdventures => _tr('finishedAdventures');
  String get liveNow => _tr('liveNow');
  String get happeningRightNow => _tr('happeningRightNow');
  String get friendsTripsSection => _tr('friendsTripsSection');
  String get fromYourFriends => _tr('fromYourFriends');
  String get fromUsersYouFollow => _tr('fromUsersYouFollow');
  String get createYourFirstTrip => _tr('createYourFirstTrip');
  String get noTripsInYourFeed => _tr('noTripsInYourFeed');
  String get followUsersToSeeFeed => _tr('followUsersToSeeFeed');
  String get deleteTripWarning => _tr('deleteTripWarning');

  // Timeline day/trip markers
  String dayNStarted(int day) {
    switch (_lang) {
      case 'es':
        return 'Día $day Iniciado';
      case 'fr':
        return 'Jour $day Commencé';
      case 'nl':
        return 'Dag $day Gestart';
      default:
        return 'Day $day Started';
    }
  }

  String dayNEnded(int day) {
    switch (_lang) {
      case 'es':
        return 'Día $day Finalizado';
      case 'fr':
        return 'Jour $day Terminé';
      case 'nl':
        return 'Dag $day Beëindigd';
      default:
        return 'Day $day Ended';
    }
  }

  String get tripStartedLabel => _tr('tripStartedLabel');
  String get tripEndedLabel => _tr('tripEndedLabel');
  String get updateLabel => _tr('updateLabel');

  // Comments section
  String get beFirstToComment => _tr('beFirstToComment');
  String get loginToAddComment => _tr('loginToAddComment');

  // Achievements screen
  String achievementsProgress(int unlocked, int total) {
    switch (_lang) {
      case 'es':
        return 'Logros ($unlocked/$total)';
      case 'fr':
        return 'Réalisations ($unlocked/$total)';
      case 'nl':
        return 'Prestaties ($unlocked/$total)';
      default:
        return 'Achievements ($unlocked/$total)';
    }
  }

  String achievedValue(String value) {
    switch (_lang) {
      case 'es':
        return 'Logrado: $value';
      case 'fr':
        return 'Atteint : $value';
      case 'nl':
        return 'Behaald: $value';
      default:
        return 'Achieved: $value';
    }
  }

  String unlockedOn(String date) {
    switch (_lang) {
      case 'es':
        return 'Desbloqueado el $date';
      case 'fr':
        return 'Débloqué le $date';
      case 'nl':
        return 'Ontgrendeld op $date';
      default:
        return 'Unlocked on $date';
    }
  }

  String goalValue(String value) {
    switch (_lang) {
      case 'es':
        return 'Meta: $value';
      case 'fr':
        return 'Objectif : $value';
      case 'nl':
        return 'Doel: $value';
      default:
        return 'Goal: $value';
    }
  }

  // Achievement categories
  String get categoryDistance => _tr('categoryDistance');
  String get categoryUpdates => _tr('categoryUpdates');
  String get categoryDuration => _tr('categoryDuration');
  String get categorySocial => _tr('categorySocial');
  String get categoryOther => _tr('categoryOther');

  // Achievement units
  String achievementKm(double v) => '${v.toStringAsFixed(1)} km';
  String achievementDays(int v) {
    switch (_lang) {
      case 'es':
        return '$v días';
      case 'fr':
        return '$v jours';
      case 'nl':
        return '$v dagen';
      default:
        return '$v days';
    }
  }

  String achievementUpdatesCount(int v) {
    switch (_lang) {
      case 'es':
        return '$v actualizaciones';
      case 'fr':
        return '$v mises à jour';
      case 'nl':
        return '$v updates';
      default:
        return '$v updates';
    }
  }

  String achievementFollowers(int v) {
    switch (_lang) {
      case 'es':
        return '$v seguidores';
      case 'fr':
        return '$v abonnés';
      case 'nl':
        return '$v volgers';
      default:
        return '$v followers';
    }
  }

  String achievementFriends(int v) {
    switch (_lang) {
      case 'es':
        return '$v amigos';
      case 'fr':
        return '$v amis';
      case 'nl':
        return '$v vrienden';
      default:
        return '$v friends';
    }
  }

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
        return _lang == 'en' || _lang == 'nl' ? '1,000 km' : '1.000 km';
      case 'DISTANCE_1600KM':
        return _lang == 'en' || _lang == 'nl' ? '1,600 km' : '1.600 km';
      case 'DISTANCE_2200KM':
        return _lang == 'en' || _lang == 'nl' ? '2,200 km' : '2.200 km';
      case 'UPDATES_10':
        switch (_lang) {
          case 'es':
            return '10 Actualizaciones';
          case 'fr':
            return '10 Mises à jour';
          case 'nl':
            return '10 Updates';
          default:
            return '10 Updates';
        }
      case 'UPDATES_50':
        switch (_lang) {
          case 'es':
            return '50 Actualizaciones';
          case 'fr':
            return '50 Mises à jour';
          case 'nl':
            return '50 Updates';
          default:
            return '50 Updates';
        }
      case 'UPDATES_100':
        switch (_lang) {
          case 'es':
            return '100 Actualizaciones';
          case 'fr':
            return '100 Mises à jour';
          case 'nl':
            return '100 Updates';
          default:
            return '100 Updates';
        }
      case 'DURATION_7_DAYS':
        return achievementDays(7);
      case 'DURATION_30_DAYS':
        return achievementDays(30);
      case 'DURATION_45_DAYS':
        return achievementDays(45);
      case 'DURATION_60_DAYS':
        return achievementDays(60);
      case 'FOLLOWERS_10':
        return achievementFollowers(10);
      case 'FOLLOWERS_50':
        return achievementFollowers(50);
      case 'FOLLOWERS_100':
        return achievementFollowers(100);
      case 'FRIENDS_5':
        return achievementFriends(5);
      case 'FRIENDS_20':
        return achievementFriends(20);
      case 'FRIENDS_50':
        return achievementFriends(50);
      default:
        return typeKey;
    }
  }

  // Achievement localized descriptions (keyed by backend type string)
  String achievementDescriptionFor(String typeKey) {
    final Map<String, Map<String, String>> descs = {
      'DISTANCE_100KM': {
        'en': 'Walk 100 km in a single trip',
        'es': 'Camina 100 km en un solo viaje',
        'fr': 'Parcourez 100 km en un seul voyage',
        'nl': 'Loop 100 km in een enkele reis',
      },
      'DISTANCE_200KM': {
        'en': 'Walk 200 km in a single trip',
        'es': 'Camina 200 km en un solo viaje',
        'fr': 'Parcourez 200 km en un seul voyage',
        'nl': 'Loop 200 km in een enkele reis',
      },
      'DISTANCE_500KM': {
        'en': 'Walk 500 km in a single trip',
        'es': 'Camina 500 km en un solo viaje',
        'fr': 'Parcourez 500 km en un seul voyage',
        'nl': 'Loop 500 km in een enkele reis',
      },
      'DISTANCE_800KM': {
        'en': 'Walk 800 km in a single trip',
        'es': 'Camina 800 km en un solo viaje',
        'fr': 'Parcourez 800 km en un seul voyage',
        'nl': 'Loop 800 km in een enkele reis',
      },
      'DISTANCE_1000KM': {
        'en': 'Walk 1,000 km in a single trip',
        'es': 'Camina 1.000 km en un solo viaje',
        'fr': 'Parcourez 1 000 km en un seul voyage',
        'nl': 'Loop 1.000 km in een enkele reis',
      },
      'DISTANCE_1600KM': {
        'en': 'Walk 1,600 km in a single trip',
        'es': 'Camina 1.600 km en un solo viaje',
        'fr': 'Parcourez 1 600 km en un seul voyage',
        'nl': 'Loop 1.600 km in een enkele reis',
      },
      'DISTANCE_2200KM': {
        'en': 'Walk 2,200 km in a single trip',
        'es': 'Camina 2.200 km en un solo viaje',
        'fr': 'Parcourez 2 200 km en un seul voyage',
        'nl': 'Loop 2.200 km in een enkele reis',
      },
      'UPDATES_10': {
        'en': 'Post 10 updates in a trip',
        'es': 'Publica 10 actualizaciones en un viaje',
        'fr': 'Publiez 10 mises à jour dans un voyage',
        'nl': 'Plaats 10 updates in een reis',
      },
      'UPDATES_50': {
        'en': 'Post 50 updates in a trip',
        'es': 'Publica 50 actualizaciones en un viaje',
        'fr': 'Publiez 50 mises à jour dans un voyage',
        'nl': 'Plaats 50 updates in een reis',
      },
      'UPDATES_100': {
        'en': 'Post 100 updates in a trip',
        'es': 'Publica 100 actualizaciones en un viaje',
        'fr': 'Publiez 100 mises à jour dans un voyage',
        'nl': 'Plaats 100 updates in een reis',
      },
      'DURATION_7_DAYS': {
        'en': 'Complete a trip lasting 7 days',
        'es': 'Completa un viaje de 7 días',
        'fr': 'Terminez un voyage de 7 jours',
        'nl': 'Voltooi een reis van 7 dagen',
      },
      'DURATION_30_DAYS': {
        'en': 'Complete a trip lasting 30 days',
        'es': 'Completa un viaje de 30 días',
        'fr': 'Terminez un voyage de 30 jours',
        'nl': 'Voltooi een reis van 30 dagen',
      },
      'DURATION_45_DAYS': {
        'en': 'Complete a trip lasting 45 days',
        'es': 'Completa un viaje de 45 días',
        'fr': 'Terminez un voyage de 45 jours',
        'nl': 'Voltooi een reis van 45 dagen',
      },
      'DURATION_60_DAYS': {
        'en': 'Complete a trip lasting 60 days',
        'es': 'Completa un viaje de 60 días',
        'fr': 'Terminez un voyage de 60 jours',
        'nl': 'Voltooi een reis van 60 dagen',
      },
      'FOLLOWERS_10': {
        'en': 'Reach 10 followers',
        'es': 'Consigue 10 seguidores',
        'fr': 'Atteignez 10 abonnés',
        'nl': 'Bereik 10 volgers',
      },
      'FOLLOWERS_50': {
        'en': 'Reach 50 followers',
        'es': 'Consigue 50 seguidores',
        'fr': 'Atteignez 50 abonnés',
        'nl': 'Bereik 50 volgers',
      },
      'FOLLOWERS_100': {
        'en': 'Reach 100 followers',
        'es': 'Consigue 100 seguidores',
        'fr': 'Atteignez 100 abonnés',
        'nl': 'Bereik 100 volgers',
      },
      'FRIENDS_5': {
        'en': 'Make 5 friends',
        'es': 'Haz 5 amigos',
        'fr': 'Faites-vous 5 amis',
        'nl': 'Maak 5 vrienden',
      },
      'FRIENDS_20': {
        'en': 'Make 20 friends',
        'es': 'Haz 20 amigos',
        'fr': 'Faites-vous 20 amis',
        'nl': 'Maak 20 vrienden',
      },
      'FRIENDS_50': {
        'en': 'Make 50 friends',
        'es': 'Haz 50 amigos',
        'fr': 'Faites-vous 50 amis',
        'nl': 'Maak 50 vrienden',
      },
    };
    final desc = descs[typeKey];
    if (desc == null) return typeKey;
    return desc[_lang] ?? desc['en'] ?? typeKey;
  }

  // --- Profile screen (extra) ---
  String get mustBeLoggedInToViewProfile => _tr('mustBeLoggedInToViewProfile');
  String get profileUpdatedSuccessfully => _tr('profileUpdatedSuccessfully');
  String get failedToUpdateProfile => _tr('failedToUpdateProfile');
  String get tapPencilToAddBio => _tr('tapPencilToAddBio');
  String get noBioYet => _tr('noBioYet');
  String get follow => _tr('follow');
  String get unfriend => _tr('unfriend');
  String get cancelFriendRequest => _tr('cancelFriendRequest');
  String get sendFriendRequest => _tr('sendFriendRequest');
  String get followers => _tr('followers');
  String myTripsLabel(bool isViewingOwnProfile) =>
      isViewingOwnProfile ? myTrips : trips;
  String tripCountLabel(int count) {
    switch (_lang) {
      case 'es':
        return count == 1 ? '1 viaje' : '$count viajes';
      case 'fr':
        return count == 1 ? '1 voyage' : '$count voyages';
      case 'nl':
        return count == 1 ? '1 reis' : '$count reizen';
      default:
        return count == 1 ? '1 trip' : '$count trips';
    }
  }

  String get sortOptionStatus => _tr('sortOptionStatus');
  String get sortOptionNameAZ => _tr('sortOptionNameAZ');
  String get sortOptionNameZA => _tr('sortOptionNameZA');
  String get sortOptionNewest => _tr('sortOptionNewest');
  String get sortOptionOldest => _tr('sortOptionOldest');
  String unfollowedUser(String username) {
    switch (_lang) {
      case 'es':
        return 'Dejaste de seguir a $username';
      case 'fr':
        return 'Vous ne suivez plus $username';
      case 'nl':
        return '$username ontvolgd';
      default:
        return 'Unfollowed $username';
    }
  }

  String nowFollowingUser(String username) {
    switch (_lang) {
      case 'es':
        return 'Ahora sigues a $username';
      case 'fr':
        return 'Vous suivez maintenant $username';
      case 'nl':
        return 'Je volgt nu $username';
      default:
        return 'You are now following $username';
    }
  }

  String noLongerFriendsWith(String username) {
    switch (_lang) {
      case 'es':
        return 'Ya no eres amigo de $username';
      case 'fr':
        return 'Vous n\'êtes plus ami avec $username';
      case 'nl':
        return 'Je bent niet langer bevriend met $username';
      default:
        return 'You are no longer friends with $username';
    }
  }

  String get friendRequestCancelled => _tr('friendRequestCancelled');
  String friendRequestSentTo(String username) {
    switch (_lang) {
      case 'es':
        return 'Solicitud de amistad enviada a $username';
      case 'fr':
        return 'Demande d\'ami envoyée à $username';
      case 'nl':
        return 'Vriendschapsverzoek gestuurd naar $username';
      default:
        return 'Friend request sent to $username';
    }
  }

  // --- Friends/Followers screen ---
  String get newFollowerMsg => _tr('newFollowerMsg');
  String get friendRequestReceivedMsg => _tr('friendRequestReceivedMsg');
  String get friendRequestAcceptedMsg => _tr('friendRequestAcceptedMsg');
  String get followRequestSentMsg => _tr('followRequestSentMsg');
  String failedToFollowUser(String e) {
    switch (_lang) {
      case 'es':
        return 'No se pudo seguir al usuario: $e';
      case 'fr':
        return 'Impossible de suivre l\'utilisateur : $e';
      case 'nl':
        return 'Kan gebruiker niet volgen: $e';
      default:
        return 'Failed to follow user: $e';
    }
  }

  String get unfollowedUserMsg => _tr('unfollowedUserMsg');
  String failedToUnfollowUser(String e) {
    switch (_lang) {
      case 'es':
        return 'No se pudo dejar de seguir al usuario: $e';
      case 'fr':
        return 'Impossible de ne plus suivre l\'utilisateur : $e';
      case 'nl':
        return 'Kan gebruiker niet ontvolgen: $e';
      default:
        return 'Failed to unfollow user: $e';
    }
  }

  String failedToAcceptFriendRequest(String e) {
    switch (_lang) {
      case 'es':
        return 'No se pudo aceptar la solicitud de amistad: $e';
      case 'fr':
        return 'Impossible d\'accepter la demande d\'ami : $e';
      case 'nl':
        return 'Kan vriendschapsverzoek niet accepteren: $e';
      default:
        return 'Failed to accept friend request: $e';
    }
  }

  String get friendRequestDeclinedMsg => _tr('friendRequestDeclinedMsg');
  String failedToDeclineFriendRequest(String e) {
    switch (_lang) {
      case 'es':
        return 'No se pudo rechazar la solicitud de amistad: $e';
      case 'fr':
        return 'Impossible de refuser la demande d\'ami : $e';
      case 'nl':
        return 'Kan vriendschapsverzoek niet weigeren: $e';
      default:
        return 'Failed to decline friend request: $e';
    }
  }

  String get requestsTab => _tr('requestsTab');
  String get unknownUser => _tr('unknownUser');
  String get messagingComingSoon => _tr('messagingComingSoon');
  String get receivedTab => _tr('receivedTab');
  String get sentTab => _tr('sentTab');
  String sentDateLabel(String date) {
    switch (_lang) {
      case 'es':
        return 'Enviado $date';
      case 'fr':
        return 'Envoyé $date';
      case 'nl':
        return 'Verzonden $date';
      default:
        return 'Sent $date';
    }
  }

  String daysAgoShort(int days) {
    switch (_lang) {
      case 'es':
        return 'hace ${days}d';
      case 'fr':
        return 'il y a ${days}j';
      case 'nl':
        return '${days}d geleden';
      default:
        return '${days}d ago';
    }
  }

  String hoursAgoShort(int hours) {
    switch (_lang) {
      case 'es':
        return 'hace ${hours}h';
      case 'fr':
        return 'il y a ${hours}h';
      case 'nl':
        return '${hours}u geleden';
      default:
        return '${hours}h ago';
    }
  }

  String minutesAgoShort(int minutes) {
    switch (_lang) {
      case 'es':
        return 'hace ${minutes}m';
      case 'fr':
        return 'il y a ${minutes}m';
      case 'nl':
        return '${minutes}m geleden';
      default:
        return '${minutes}m ago';
    }
  }

  // --- Language names (for the language picker) ---
  String get languageNameEn => _tr('languageName_en');
  String get languageNameEs => _tr('languageName_es');
  String get languageNameFr => _tr('languageName_fr');
  String get languageNameNl => _tr('languageName_nl');

  /// Returns the native name for a given language code.
  String languageNameFor(String code) => _tr('languageName_$code');
}
