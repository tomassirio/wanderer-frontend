import '../config/api_endpoints_stub.dart'
    if (dart.library.js_interop) '../config/api_endpoints_web.dart';

/// API endpoint constants
class ApiEndpoints {
  // Base URLs - read from window.appConfig (injected by Docker) or use defaults
  // Defaults use /api/1 for all services (query, command, auth)
  static String get commandBaseUrl =>
      getConfigValue('commandBaseUrl', 'http://localhost:8081/api/1');
  static String get queryBaseUrl =>
      getConfigValue('queryBaseUrl', 'http://localhost:8082/api/1');
  static String get authBaseUrl =>
      getConfigValue('authBaseUrl', 'http://localhost:8083/api/1/auth');

  /// Auth base for the SSO browser leg only (Google login in a Custom Tab).
  /// Unset everywhere except local Android dev runs, where the API is plain
  /// http but the SSO session cookie is Secure and needs https.
  static String get ssoAuthBaseUrl =>
      getConfigValue('ssoAuthBaseUrl', authBaseUrl);

  // Admin base URLs - admin operations now use command/query services (CQRS)
  // Write operations (promote, demote, delete) → command service
  // Read operations (get roles) → query service

  // WebSocket base URL - read from window.appConfig or use default
  static String get wsBaseUrl => getConfigValue('wsBaseUrl', '/ws');

  // Google Maps API key - read from window.appConfig
  static String get googleMapsApiKey => getConfigValue('googleMapsApiKey', '');

  // App base URL - used for deep links, QR codes, and sharing
  // Web: derived from window.location; Mobile: from APP_BASE_URL dart-define
  static String get appBaseUrl => getAppBaseUrl();

  // Trip deep link URL
  static String tripDeepLink(String tripId) => '$appBaseUrl/trip/$tripId';
  static String planDeepLink(String planId) => '$appBaseUrl/plan/$planId';

  // Android app listing on Google Play
  static const playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.tomassirio.wanderer.wanderer_frontend';

  // Resolve thumbnail URL (handles both relative and absolute URLs)
  static String resolveThumbnailUrl(String? thumbnailUrl) {
    if (thumbnailUrl == null || thumbnailUrl.isEmpty) {
      return '';
    }

    // If already absolute URL, return as-is
    if (thumbnailUrl.startsWith('http://') ||
        thumbnailUrl.startsWith('https://')) {
      return thumbnailUrl;
    }

    // Relative URL - prepend appBaseUrl
    return appBaseUrl + thumbnailUrl;
  }

  // Auth endpoints (use authBaseUrl)
  static const String authRegister = '/register';
  static const String authVerifyEmail = '/verify-email';
  static const String authLogin = '/login';
  static const String authLogout = '/logout';
  static const String authRefresh = '/refresh';
  static const String authPasswordReset = '/password/reset';
  static const String authPasswordChange = '/password/change';

  // SSO endpoints (use authBaseUrl)
  static const String authSsoExchange = '/sso/exchange';
  static String ssoAuthorizationPath(String providerId) =>
      '/oauth2/authorization/$providerId';
  static const String ssoWebCallbackPath = '/auth/sso-callback';
  static const String ssoMobileCallbackScheme = 'wanderer';
  static const String ssoMobileCallbackUrl = 'wanderer://auth/sso-callback';

  // User Query endpoints (use queryBaseUrl)
  static const String usersMe = '/users/me';
  static const String usersAll = '/users';
  static String userById(String userId) => '/users/$userId';
  static String userByUsername(String username) => '/users/username/$username';

  // Current user's friends, following, and followers (use /me/ endpoints)
  static const String usersMeFriends = '/users/me/friends';
  static const String usersMeFollowing = '/users/me/following';
  static const String usersMeFollowers = '/users/me/followers';
  static const String usersMeDiscover = '/users/me/discover';

  static const String usersFriendRequestsReceived =
      '/users/friends/requests/received';
  static const String usersFriendRequestsSent = '/users/friends/requests/sent';

  // Specific user's following, followers, and friends (for viewing other users' profiles)
  static String userFollowing(String userId) => '/users/$userId/following';
  static String userFollowers(String userId) => '/users/$userId/followers';
  static String userFriends(String userId) => '/users/$userId/friends';
  static String userAssociated(String userId) => '/users/$userId/associated';

  // User Command endpoints (use commandBaseUrl)
  static const String usersCreate = '/users';
  static const String usersUpdate = '/users/me';
  static const String usersAvatarUpload = '/users/me/avatar';
  static const String usersAvatarDelete = '/users/me/avatar';
  static const String usersFriendRequests = '/users/friends/requests';
  static String usersFriendRequestAccept(String requestId) =>
      '/users/friends/requests/$requestId/accept';

  /// Delete a friend request (works for both sender cancelling and receiver declining)
  static String usersFriendRequestDelete(String requestId) =>
      '/users/friends/requests/$requestId';
  static String usersRemoveFriend(String friendId) =>
      '/users/friends/$friendId';
  static const String usersFollows = '/users/follows';
  static String usersUnfollow(String followedId) =>
      '/users/follows/$followedId';

  // Trip Query endpoints (use queryBaseUrl)
  static String tripById(String tripId) => '/trips/$tripId';
  static const String trips = '/trips';
  static const String tripsMe = '/trips/me';
  static const String tripsPublic = '/trips/public';
  static const String tripsAvailable = '/trips/me/available';
  static String tripsByUser(String userId) => '/trips/users/$userId';

  // Trip Command endpoints (use commandBaseUrl)
  static const String tripsCreate = '/trips';
  static String tripUpdate(String tripId) => '/trips/$tripId';
  static String tripDelete(String tripId) => '/trips/$tripId';
  static String tripVisibility(String tripId) => '/trips/$tripId/visibility';
  static String tripStatus(String tripId) => '/trips/$tripId/status';
  static String tripSettings(String tripId) => '/trips/$tripId/settings';
  static String tripToggleDay(String tripId) => '/trips/$tripId/toggle-day';
  static String tripFromPlan(String tripPlanId) =>
      '/trips/from-plan/$tripPlanId';

  /// One-step create + start (live trip and first check-in in one call).
  static const String tripsStart = '/trips/start';

  /// Ready screen prefill from the last trip (queryBaseUrl).
  static const String tripsStartDefaults = '/trips/me/start-defaults';

  /// Trip start funnel counters (commandBaseUrl).
  static const String analyticsEvents = '/analytics/events';

  // Trip Plan endpoints (use commandBaseUrl for commands, queryBaseUrl for queries)
  static const String tripPlans = '/trips/plans';
  static String tripPlanById(String planId) => '/trips/plans/$planId';
  static const String tripPlansMe = '/trips/plans/me';

  // Trip Update Command endpoints (use commandBaseUrl)
  static String tripUpdates(String tripId) => '/trips/$tripId/updates';
  static String tripTrackPoints(String tripId) =>
      '/trips/$tripId/track-points';

  // Comment Command endpoints (use commandBaseUrl)
  static String tripComments(String tripId) => '/trips/$tripId/comments';
  static String commentReactions(String commentId) =>
      '/comments/$commentId/reactions';

  // Trip Promotion Command endpoints (use commandBaseUrl, ADMIN only)
  static String tripPromote(String tripId) => '/admin/trips/$tripId/promote';

  // Trip Promotion Query endpoints (use queryBaseUrl, PUBLIC)
  static const String promotedTrips = '/promoted-trips';
  static String tripPromotion(String tripId) => '/trips/$tripId/promotion';

  // Admin User Management endpoints (ADMIN only)
  // Write operations: use commandBaseUrl
  static String adminPromoteUser(String userId) =>
      '/admin/users/$userId/promote';
  static String adminDeleteUser(String userId) => '/admin/users/$userId';
  // Read operations: use queryBaseUrl
  static String adminUserRoles(String userId) => '/admin/users/$userId/roles';

  // Admin Trip Management endpoints (ADMIN only, commandBaseUrl)
  static String adminTripById(String tripId) => '/admin/trips/$tripId';
  static String adminRecomputePolyline(String tripId) =>
      '/admin/trips/$tripId/recompute-polyline';
  static String adminRecomputeGeocoding(String tripId) =>
      '/admin/trips/$tripId/recompute-geocoding';
  static const String adminTripStats = '/admin/trips/stats';
  static const String adminRegenerateMissingThumbnails =
      '/admin/trips/thumbnails/regenerate-missing';

  // Release notes / What's new (reads: queryBaseUrl, writes: commandBaseUrl)
  static const String releases = '/releases';
  static const String releasesUnread = '/releases/me/unread';
  static const String releasesSeen = '/releases/me/seen';
  static const String adminReleases = '/admin/releases';
  static String adminRelease(String version) => '/admin/releases/$version';
  static String adminReleasePublish(String version) =>
      '/admin/releases/$version/publish';

  // Self-deletion endpoint (use commandBaseUrl, any authenticated user)
  static const String usersDeleteMe = '/users/me';

  // WebSocket topics
  static String wsTripTopic(String tripId) => '/topic/trips/$tripId';
  static String wsUserTopic(String userId) => '/topic/users/$userId';

  // Notification Query endpoints (use queryBaseUrl)
  static const String notificationsMe = '/notifications/me';
  static const String notificationsUnreadCount =
      '/notifications/me/unread-count';

  // Notification Command endpoints (use commandBaseUrl)
  static String notificationMarkRead(String notificationId) =>
      '/notifications/$notificationId/read';
  static const String notificationsMarkAllRead = '/notifications/me/read-all';

  // Achievement Query endpoints (use queryBaseUrl)
  static const String achievements = '/achievements';
  static const String achievementsMe = '/users/me/achievements';
  static String userAchievements(String userId) =>
      '/users/$userId/achievements';
  static String tripAchievements(String tripId) =>
      '/trips/$tripId/achievements';

  // Search Query endpoint (use queryBaseUrl)
  static const String search = '/search';
}
