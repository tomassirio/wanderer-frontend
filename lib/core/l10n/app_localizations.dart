import 'package:flutter/widgets.dart';
import 'locale_controller.dart';
import 'translation_loader.dart';

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
  final TranslationLoader _loader;

  AppLocalizations(this._lang, {TranslationLoader? loader})
      : _loader = loader ?? TranslationLoader.instance;

  /// Creates an instance reflecting the current locale from [LocaleController].
  /// Prefer [BuildContext.l10n] in widget build methods for auto-rebuild.
  factory AppLocalizations.fromController() =>
      AppLocalizations(LocaleController().locale.value.languageCode);

  /// Look up a key, falling back to English if missing.
  String _tr(String key) => _loader.string(_lang, key);

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
  String get getStarted => _tr('getStarted');
  String get landingHeadline => _tr('landingHeadline');
  String get landingSubheadline => _tr('landingSubheadline');
  String get landingInstallCta => _tr('landingInstallCta');
  String get landingFeatureTrackingTitle => _tr('landingFeatureTrackingTitle');
  String get landingFeatureTrackingDesc => _tr('landingFeatureTrackingDesc');
  String get landingFeatureSocialTitle => _tr('landingFeatureSocialTitle');
  String get landingFeatureSocialDesc => _tr('landingFeatureSocialDesc');
  String get landingFeaturePlanningTitle => _tr('landingFeaturePlanningTitle');
  String get landingFeaturePlanningDesc => _tr('landingFeaturePlanningDesc');
  String get landingFeatureAchievementsTitle =>
      _tr('landingFeatureAchievementsTitle');
  String get landingFeatureAchievementsDesc =>
      _tr('landingFeatureAchievementsDesc');
  String get tutorialSkip => _tr('tutorialSkip');
  String get tutorialNext => _tr('tutorialNext');
  String get tutorialMenuTitle => _tr('tutorialMenuTitle');
  String get tutorialMenuDescription => _tr('tutorialMenuDescription');
  String get tutorialSearchTitle => _tr('tutorialSearchTitle');
  String get tutorialSearchDescription => _tr('tutorialSearchDescription');
  String get tutorialNotificationsTitle => _tr('tutorialNotificationsTitle');
  String get tutorialNotificationsDescription =>
      _tr('tutorialNotificationsDescription');
  String get tutorialNewTripTitle => _tr('tutorialNewTripTitle');
  String get tutorialNewTripDescription => _tr('tutorialNewTripDescription');
  String get tutorialBottomNavTitle => _tr('tutorialBottomNavTitle');
  String get tutorialBottomNavDescription =>
      _tr('tutorialBottomNavDescription');
  String get tutorialTripNameTitle => _tr('tutorialTripNameTitle');
  String get tutorialTripNameDescription => _tr('tutorialTripNameDescription');
  String get tutorialTripTypeTitle => _tr('tutorialTripTypeTitle');
  String get tutorialTripTypeDescription => _tr('tutorialTripTypeDescription');
  String get tutorialVisibilityTitle => _tr('tutorialVisibilityTitle');
  String get tutorialVisibilityDescription =>
      _tr('tutorialVisibilityDescription');
  String get tutorialAutoUpdatesTitle => _tr('tutorialAutoUpdatesTitle');
  String get tutorialAutoUpdatesDescription =>
      _tr('tutorialAutoUpdatesDescription');
  String get tutorialCreateButtonTitle => _tr('tutorialCreateButtonTitle');
  String get tutorialCreateButtonDescription =>
      _tr('tutorialCreateButtonDescription');
  String get tutorialSendUpdateTitle => _tr('tutorialSendUpdateTitle');
  String get tutorialSendUpdateDescription =>
      _tr('tutorialSendUpdateDescription');
  String get tutorialTripStatusTitle => _tr('tutorialTripStatusTitle');
  String get tutorialTripStatusDescription =>
      _tr('tutorialTripStatusDescription');
  String get tutorialShareTripTitle => _tr('tutorialShareTripTitle');
  String get tutorialShareTripDescription =>
      _tr('tutorialShareTripDescription');
  String get tutorialInfoBubbleTitle => _tr('tutorialInfoBubbleTitle');
  String get tutorialInfoBubbleDescription =>
      _tr('tutorialInfoBubbleDescription');
  String get tutorialCommentsBubbleTitle => _tr('tutorialCommentsBubbleTitle');
  String get tutorialCommentsBubbleDescription =>
      _tr('tutorialCommentsBubbleDescription');
  String get tutorialTimelineBubbleTitle => _tr('tutorialTimelineBubbleTitle');
  String get tutorialTimelineBubbleDescription =>
      _tr('tutorialTimelineBubbleDescription');
  String get tutorialSettingsBubbleTitle => _tr('tutorialSettingsBubbleTitle');
  String get tutorialSettingsBubbleDescription =>
      _tr('tutorialSettingsBubbleDescription');
  String get discoverAdventures => _tr('discoverAdventures');
  String get explorePublicTrips => _tr('explorePublicTrips');
  String get noTripsYet => _tr('noTripsYet');
  String get trackFirstAdventure => _tr('trackFirstAdventure');
  String get createFirstTrip => _tr('createFirstTrip');
  String get noTripsInFeed => _tr('noTripsInFeed');
  String get followToSeeTrips => _tr('followToSeeTrips');
  String get noPublicTripsFound => _tr('noPublicTripsFound');
  String get checkBackLater => _tr('checkBackLater');
  String get errorLoadingTrips => _tr('errorLoadingTrips');
  String get loadMoreTrips => _tr('loadMoreTrips');
  String get loadMore => _tr('loadMore');
  String get myTrips => _tr('myTrips');
  String get friendsTrips => _tr('friendsTrips');
  String get discover => _tr('discover');
  String get featuredTrips => _tr('featuredTrips');
  String get highlightedAdventures => _tr('highlightedAdventures');
  String get explorePublicTripsSubtitle => _tr('explorePublicTripsSubtitle');
  String get feed => _tr('feed');
  String get minuteAgo => _tr('minuteAgo');
  String minutesAgo(int n) =>
      TranslationTemplate.format(_tr('minutesAgo'), {'n': n});

  String get hourAgo => _tr('hourAgo');
  String hoursAgo(int n) =>
      TranslationTemplate.format(_tr('hoursAgo'), {'n': n});

  String get dayAgo => _tr('dayAgo');
  String daysAgo(int n) =>
      TranslationTemplate.format(_tr('daysAgo'), {'n': n});

  String get weekAgo => _tr('weekAgo');
  String weeksAgo(int n) =>
      TranslationTemplate.format(_tr('weeksAgo'), {'n': n});

  String get monthAgo => _tr('monthAgo');
  String monthsAgo(int n) =>
      TranslationTemplate.format(_tr('monthsAgo'), {'n': n});

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
  String get usernameOrEmailLabel => _tr('usernameOrEmailLabel');
  String get usernameOrEmailHint => _tr('usernameOrEmailHint');
  String get passwordLabel => _tr('passwordLabel');
  String get pleaseEnterPassword => _tr('pleaseEnterPassword');
  String get passwordMinLength => _tr('passwordMinLength');
  String get passwordMinLength8 => _tr('passwordMinLength8');
  String get passwordRequiresLowercase => _tr('passwordRequiresLowercase');
  String get passwordRequiresUppercase => _tr('passwordRequiresUppercase');
  String get passwordRequiresNumber => _tr('passwordRequiresNumber');
  String get passwordRequiresSpecial => _tr('passwordRequiresSpecial');
  String get passwordRequirements => _tr('passwordRequirements');
  String get passwordRequirement8Chars => _tr('passwordRequirement8Chars');
  String get passwordRequirementUppercase =>
      _tr('passwordRequirementUppercase');
  String get passwordRequirementLowercase =>
      _tr('passwordRequirementLowercase');
  String get passwordRequirementNumber => _tr('passwordRequirementNumber');
  String get passwordRequirementSpecial => _tr('passwordRequirementSpecial');
  String get passwordsDoNotMatch => _tr('passwordsDoNotMatch');
  String get resetPasswordTitle => _tr('resetPasswordTitle');
  String get enterEmailForReset => _tr('enterEmailForReset');
  String get sendResetLink => _tr('sendResetLink');
  String passwordResetEmailSent(String email) => TranslationTemplate.format(
      _tr('passwordResetEmailSent'), {'email': email});

  String get pleaseEnterEmail => _tr('pleaseEnterEmail');
  String get pleaseEnterValidEmail => _tr('pleaseEnterValidEmail');
  String get pleaseEnterUsername => _tr('pleaseEnterUsername');
  String get pleaseEnterUsernameOrEmail => _tr('pleaseEnterUsernameOrEmail');
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
  String get resetTutorials => _tr('resetTutorials');
  String get resetTutorialsSubtitle => _tr('resetTutorialsSubtitle');
  String get resetTutorialsSuccess => _tr('resetTutorialsSuccess');
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
  String startsInDays(int days) =>
      TranslationTemplate.format(_tr('startsInDays'), {'days': days});

  String dayNumber(int day) =>
      TranslationTemplate.format(_tr('dayNumber'), {'day': day});

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
  String dayNStarted(int day) =>
      TranslationTemplate.format(_tr('dayNStarted'), {'day': day});

  String dayNEnded(int day) =>
      TranslationTemplate.format(_tr('dayNEnded'), {'day': day});

  String get tripStartedLabel => _tr('tripStartedLabel');
  String get tripEndedLabel => _tr('tripEndedLabel');
  String get updateLabel => _tr('updateLabel');

  // Comments section
  String get beFirstToComment => _tr('beFirstToComment');
  String get loginToAddComment => _tr('loginToAddComment');

  // Achievements screen
  String achievementsProgress(int unlocked, int total) =>
      TranslationTemplate.format(
          _tr('achievementsProgress'), {'unlocked': unlocked, 'total': total});

  String achievedValue(String value) =>
      TranslationTemplate.format(_tr('achievedValue'), {'value': value});

  String unlockedOn(String date) =>
      TranslationTemplate.format(_tr('unlockedOn'), {'date': date});

  String goalValue(String value) =>
      TranslationTemplate.format(_tr('goalValue'), {'value': value});

  // Achievement categories
  String get categoryDistance => _tr('categoryDistance');
  String get categoryUpdates => _tr('categoryUpdates');
  String get categoryDuration => _tr('categoryDuration');
  String get categorySocial => _tr('categorySocial');
  String get categoryOther => _tr('categoryOther');
  String get categoryGettingStarted => _tr('categoryGettingStarted');

  // Achievement units
  String achievementKm(double v) => '${v.toStringAsFixed(1)} km';
  String achievementDays(int v) =>
      TranslationTemplate.format(_tr('achievementDays'), {'v': v});

  String achievementUpdatesCount(int v) => TranslationTemplate.plural(
      _loader, _lang, 'achievementUpdatesCount', v, {'v': v});

  String achievementFollowers(int v) => TranslationTemplate.plural(
      _loader, _lang, 'achievementFollowers', v, {'v': v});

  String achievementFriends(int v) => TranslationTemplate.plural(
      _loader, _lang, 'achievementFriends', v, {'v': v});

  // Achievement localized names (keyed by backend type string)
  String achievementNameFor(String typeKey) =>
      _loader.nested(_lang, 'achievementNames', typeKey);

  // Achievement localized descriptions (keyed by backend type string)
  String achievementDescriptionFor(String typeKey) =>
      _loader.nested(_lang, 'achievementDescriptions', typeKey);

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
  String get follower => _tr('follower');
  String get followers => _tr('followers');
  String get noUsersToDiscover => _tr('noUsersToDiscover');
  String get addFriendsToDiscoverMore => _tr('addFriendsToDiscoverMore');
  String myTripsLabel(bool isViewingOwnProfile) =>
      isViewingOwnProfile ? myTrips : trips;
  String tripCountLabel(int count) => TranslationTemplate.plural(
      _loader, _lang, 'tripCountLabel', count, {'count': count});

  String get sortOptionStatus => _tr('sortOptionStatus');
  String get sortOptionNameAZ => _tr('sortOptionNameAZ');
  String get sortOptionNameZA => _tr('sortOptionNameZA');
  String get sortOptionNewest => _tr('sortOptionNewest');
  String get sortOptionOldest => _tr('sortOptionOldest');
  String unfollowedUser(String username) => TranslationTemplate.format(
      _tr('unfollowedUser'), {'username': username});

  String nowFollowingUser(String username) => TranslationTemplate.format(
      _tr('nowFollowingUser'), {'username': username});

  String noLongerFriendsWith(String username) => TranslationTemplate.format(
      _tr('noLongerFriendsWith'), {'username': username});

  String get friendRequestCancelled => _tr('friendRequestCancelled');
  String friendRequestSentTo(String username) => TranslationTemplate.format(
      _tr('friendRequestSentTo'), {'username': username});

  // --- Friends/Followers screen ---
  String get newFollowerMsg => _tr('newFollowerMsg');
  String get friendRequestReceivedMsg => _tr('friendRequestReceivedMsg');
  String get friendRequestAcceptedMsg => _tr('friendRequestAcceptedMsg');
  String get followRequestSentMsg => _tr('followRequestSentMsg');
  String failedToFollowUser(String e) =>
      TranslationTemplate.format(_tr('failedToFollowUser'), {'error': e});

  String get unfollowedUserMsg => _tr('unfollowedUserMsg');
  String failedToUnfollowUser(String e) =>
      TranslationTemplate.format(_tr('failedToUnfollowUser'), {'error': e});

  String failedToAcceptFriendRequest(String e) => TranslationTemplate.format(
      _tr('failedToAcceptFriendRequest'), {'error': e});

  String get friendRequestDeclinedMsg => _tr('friendRequestDeclinedMsg');
  String failedToDeclineFriendRequest(String e) => TranslationTemplate.format(
      _tr('failedToDeclineFriendRequest'), {'error': e});

  String get requestsTab => _tr('requestsTab');
  String get unknownUser => _tr('unknownUser');
  String get messagingComingSoon => _tr('messagingComingSoon');
  String get receivedTab => _tr('receivedTab');
  String get sentTab => _tr('sentTab');
  String sentDateLabel(String date) =>
      TranslationTemplate.format(_tr('sentDateLabel'), {'date': date});

  String daysAgoShort(int days) =>
      TranslationTemplate.format(_tr('daysAgoShort'), {'days': days});

  String hoursAgoShort(int hours) =>
      TranslationTemplate.format(_tr('hoursAgoShort'), {'hours': hours});

  String minutesAgoShort(int minutes) =>
      TranslationTemplate.format(_tr('minutesAgoShort'), {'minutes': minutes});

  // --- Easter egg ---
  String easterEggTapsRemaining(int remaining) => TranslationTemplate.format(
      _tr('easterEggTapsRemaining'), {'remaining': remaining});

  String get easterEggFound => _tr('easterEggFound');
  String get easterEggThanks => _tr('easterEggThanks');
  String get easterEggDismiss => _tr('easterEggDismiss');

  // --- Language names (for the language picker) ---
  String get languageNameEn => _tr('languageName_en');
  String get languageNameEs => _tr('languageName_es');
  String get languageNameFr => _tr('languageName_fr');
  String get languageNameNl => _tr('languageName_nl');

  /// Returns the native name for a given language code.
  String languageNameFor(String code) => _tr('languageName_$code');
}
