import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' show ImageFilter;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:wanderer_frontend/core/constants/enums.dart';
import 'package:wanderer_frontend/core/providers/app_providers.dart';
import 'package:wanderer_frontend/core/errors/error_utils.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/data/models/comment_models.dart';
import 'package:wanderer_frontend/data/models/achievement_models.dart';
import 'package:wanderer_frontend/data/models/websocket/websocket_event.dart';
import 'package:wanderer_frontend/data/repositories/trip_detail_repository.dart';
import 'package:wanderer_frontend/data/services/websocket_service.dart';
import 'package:wanderer_frontend/core/services/background_update_manager.dart';
import 'package:wanderer_frontend/presentation/helpers/trip_map_helper.dart';
import 'package:wanderer_frontend/presentation/helpers/ui_helpers.dart';
import 'package:wanderer_frontend/presentation/helpers/dialog_helper.dart';
import 'package:wanderer_frontend/presentation/helpers/background_location_disclosure.dart';
import 'package:wanderer_frontend/presentation/helpers/location_permission_disclosure.dart';
import 'package:wanderer_frontend/presentation/helpers/auth_navigation_helper.dart';
import 'package:wanderer_frontend/presentation/helpers/page_transitions.dart';
import 'package:wanderer_frontend/presentation/helpers/tutorial_helper.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wanderer_frontend/presentation/widgets/trip_detail/custom_planned_info_window.dart';
import 'package:wanderer_frontend/presentation/widgets/trip_detail/reaction_picker.dart';
import 'package:wanderer_frontend/presentation/widgets/trip_detail/trip_map_view.dart';
import 'package:wanderer_frontend/presentation/widgets/trip_detail/trip_lifecycle_buttons.dart';
import 'package:wanderer_frontend/presentation/widgets/common/wanderer_app_bar.dart';
import 'package:wanderer_frontend/presentation/widgets/common/app_sidebar.dart';
import 'package:wanderer_frontend/presentation/strategies/trip_detail_layout_strategy.dart';
import 'package:wanderer_frontend/presentation/state/trip_detail/trip_detail_notifier.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'auth_screen.dart';
import 'home_screen.dart';
import 'settings_screen.dart';

/// Trip detail screen showing trip info, map, and comments
class TripDetailScreen extends ConsumerStatefulWidget {
  final Trip trip;

  const TripDetailScreen({super.key, required this.trip});

  @override
  ConsumerState<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends ConsumerState<TripDetailScreen> {
  late final TripDetailRepository _repository;
  late final WebSocketService _webSocketService;
  GoogleMapController? _mapController;
  final Completer<GoogleMapController> _mapControllerCompleter = Completer();
  StreamSubscription<WebSocketEvent>? _wsSubscription;
  StreamSubscription<WebSocketEvent>? _globalWsSubscription;
  Trip get _trip => ref.watch(tripDetailNotifierProvider(widget.trip.id)).trip;
  // Map/geolocation state below lives in TripDetailNotifier's `map` sub-state
  // (Task 8); these getters keep the rest of the widget's code unchanged.
  // `_mapController`/`_mapControllerCompleter` above stay as plain widget
  // fields — they hold a platform GoogleMapController tied to the GoogleMap
  // widget's lifecycle (received via its onMapCreated callback), which isn't
  // meaningfully comparable/immutable data and so is not a good fit for
  // Riverpod state.
  Set<Marker> get _markers =>
      ref.watch(tripDetailNotifierProvider(widget.trip.id)).map.markers;
  Set<Polyline> get _polylines =>
      ref.watch(tripDetailNotifierProvider(widget.trip.id)).map.polylines;
  bool get _hasInitialMapPosition =>
      ref.watch(tripDetailNotifierProvider(widget.trip.id)).map.hasInitialMapPosition;
  bool get _isMapLoading =>
      ref.watch(tripDetailNotifierProvider(widget.trip.id)).map.isMapLoading;
  bool get _showPlannedWaypoints => ref
      .watch(tripDetailNotifierProvider(widget.trip.id))
      .map
      .showPlannedWaypoints;
  TripLocation? get _selectedMapLocation => ref
      .watch(tripDetailNotifierProvider(widget.trip.id))
      .map
      .selectedMapLocation;
  PlannedWaypointInfo? get _selectedPlannedWaypoint => ref
      .watch(tripDetailNotifierProvider(widget.trip.id))
      .map
      .selectedPlannedWaypoint;
  LatLng? get _userLocation =>
      ref.watch(tripDetailNotifierProvider(widget.trip.id)).map.userLocation;
  bool get _isWsCameraGuardActive => ref
      .read(tripDetailNotifierProvider(widget.trip.id).notifier)
      .isWsCameraGuardActive;

  List<Comment> get _comments =>
      ref.watch(tripDetailNotifierProvider(widget.trip.id)).comments.comments;
  Map<String, List<Comment>> get _replies =>
      ref.watch(tripDetailNotifierProvider(widget.trip.id)).comments.replies;
  Map<String, bool> get _expandedComments =>
      ref.watch(tripDetailNotifierProvider(widget.trip.id)).comments.expandedComments;
  bool get _hasMoreComments =>
      ref.watch(tripDetailNotifierProvider(widget.trip.id)).comments.hasMoreComments;
  bool get _isLoadingMoreComments => ref
      .watch(tripDetailNotifierProvider(widget.trip.id))
      .comments
      .isLoadingMoreComments;

  List<TripLocation> get _tripUpdates =>
      ref.watch(tripDetailNotifierProvider(widget.trip.id)).timeline.tripUpdates;
  bool get _isLoadingUpdates => ref
      .watch(tripDetailNotifierProvider(widget.trip.id))
      .timeline
      .isLoadingUpdates;
  bool get _hasMoreUpdates =>
      ref.watch(tripDetailNotifierProvider(widget.trip.id)).timeline.hasMoreUpdates;
  bool get _isLoadingMoreUpdates => ref
      .watch(tripDetailNotifierProvider(widget.trip.id))
      .timeline
      .isLoadingMoreUpdates;

  bool get _isLoadingComments =>
      ref.watch(tripDetailNotifierProvider(widget.trip.id)).comments.isLoadingComments;
  bool get _isAddingComment =>
      ref.watch(tripDetailNotifierProvider(widget.trip.id)).comments.isAddingComment;
  bool get _isChangingStatus =>
      ref.watch(tripDetailNotifierProvider(widget.trip.id)).lifecycle.isChangingStatus;
  bool get _isChangingSettings => ref
      .watch(tripDetailNotifierProvider(widget.trip.id))
      .lifecycle
      .isChangingSettings;
  String? get _replyingToCommentId => ref
      .watch(tripDetailNotifierProvider(widget.trip.id))
      .comments
      .replyingToCommentId;
  CommentSortOption get _sortOption =>
      ref.watch(tripDetailNotifierProvider(widget.trip.id)).comments.sortOption;
  final int _selectedSidebarIndex = -1; // Trip detail is not a main nav item
  String? get _username =>
      ref.watch(tripDetailNotifierProvider(widget.trip.id)).identity.username;
  String? get _userId =>
      ref.watch(tripDetailNotifierProvider(widget.trip.id)).identity.userId;
  String? get _displayName => ref
      .watch(tripDetailNotifierProvider(widget.trip.id))
      .identity
      .displayName;
  String? get _avatarUrl =>
      ref.watch(tripDetailNotifierProvider(widget.trip.id)).identity.avatarUrl;
  bool get _isAdmin =>
      ref.watch(tripDetailNotifierProvider(widget.trip.id)).identity.isAdmin;
  bool get _isLoggedIn =>
      ref.watch(tripDetailNotifierProvider(widget.trip.id)).identity.isLoggedIn;

  // Track social interactions
  bool get _isFollowingTripOwner => ref
      .watch(tripDetailNotifierProvider(widget.trip.id))
      .social
      .isFollowingTripOwner;
  bool get _hasSentFriendRequest => ref
      .watch(tripDetailNotifierProvider(widget.trip.id))
      .social
      .hasSentFriendRequest;
  bool get _isAlreadyFriends =>
      ref.watch(tripDetailNotifierProvider(widget.trip.id)).social.isAlreadyFriends;
  String? get _sentFriendRequestId => ref
      .watch(tripDetailNotifierProvider(widget.trip.id))
      .social
      .sentFriendRequestId;

  // Promotion state
  bool get _isPromoted =>
      ref.watch(tripDetailNotifierProvider(widget.trip.id)).promotion.isPromoted;
  String? get _donationLink => ref
      .watch(tripDetailNotifierProvider(widget.trip.id))
      .promotion
      .donationLink;

  // Trip achievements
  List<UserAchievement> get _tripAchievements =>
      ref.watch(tripDetailNotifierProvider(widget.trip.id)).tripAchievements;

  // Collapsible panel states
  // Collapsible panel states
  bool _isTimelineCollapsed = false;
  bool _isCommentsCollapsed = false;
  bool _isTripInfoCollapsed = false;
  bool _isTripUpdateCollapsed = true;
  bool _isTripSettingsCollapsed = true;
  bool get _isSendingUpdate =>
      ref.watch(tripDetailNotifierProvider(widget.trip.id)).lifecycle.isSendingUpdate;
  bool _hasInitializedPanelStates = false;

  // Multi-day trip: current day derived from backend's currentDay field
  int get _currentDay => _trip.currentDay ?? 1;

  // Desktop web: track whether the mouse is hovering over a panel
  // so we can disable map gestures only when hovering.
  bool _isHoveringOverPanel = false;

  // First-time trip detail tutorial (coach marks)
  final GlobalKey _tutorialUpdatePanelKey = GlobalKey();
  final GlobalKey _tutorialLifecycleKey = GlobalKey();
  final GlobalKey _tutorialShareKey = GlobalKey();
  final GlobalKey _tutorialInfoBubbleKey = GlobalKey();
  final GlobalKey _tutorialCommentsBubbleKey = GlobalKey();
  final GlobalKey _tutorialTimelineBubbleKey = GlobalKey();
  final GlobalKey _tutorialSettingsBubbleKey = GlobalKey();
  bool _tutorialCheckDone = false;

  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  /// Check if we're on Android (the only platform supporting background updates)
  bool get _isAndroid => !kIsWeb && Platform.isAndroid;

  /// Check if trip update panel should be shown
  /// Only on Android, for trip owner, when trip is in progress
  bool get _showTripUpdatePanel =>
      _isAndroid &&
      _userId != null &&
      _trip.userId == _userId &&
      _trip.status == TripStatus.inProgress;

  /// Check if the "Finish Day / Begin Day N" button should be shown
  /// Only for MULTI_DAY trips, for the trip owner, when IN_PROGRESS or RESTING
  bool get _showDayButton =>
      _userId != null &&
      _trip.userId == _userId &&
      _trip.tripModality == TripModality.multiDay &&
      (_trip.status == TripStatus.inProgress ||
          _trip.status == TripStatus.resting);

  @override
  void initState() {
    super.initState();

    // Initialize repository and services
    _repository = ref.read(tripDetailRepositoryProvider);
    _webSocketService = ref.read(websocketServiceProvider);

    ref
        .read(tripDetailNotifierProvider(widget.trip.id).notifier)
        .seedInitialTrip(widget.trip);
    // Default to showing the planned route when the trip has one
    ref
        .read(tripDetailNotifierProvider(widget.trip.id).notifier)
        .setShowPlannedWaypoints(widget.trip.hasPlannedRoute);
    // Don't call _updateMapData() here — it would use stale trip data.
    // Let _initializeMapPosition() handle everything after loading fresh data.
    _checkLoginStatus();
    _loadUserInfo();
    _loadComments();
    _loadPromotionInfo();
    _loadTripAchievements();
    _initWebSocket();
    // Load trip updates, full trip data and user location together, then set
    // the initial camera position exactly once (instant jump, no animation).
    // _fetchUserLocation is included so that trips with no locations/route can
    // centre on the user's real position instead of the hardcoded NYC default.
    _initializeMapPosition();
  }

  /// Fetches the user's current device location so that freshly-created trips
  /// (with no locations or planned route) centre on the user's real position
  /// instead of the hardcoded NYC default.
  Future<void> _fetchUserLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 10),
      );

      if (mounted) {
        ref
            .read(tripDetailNotifierProvider(widget.trip.id).notifier)
            .setUserLocation(LatLng(position.latitude, position.longitude));
      }
    } catch (e) {
      debugPrint('TripDetailScreen: Could not get user location: $e');
    }
  }

  /// Loads trip updates and refreshes trip data in parallel, then positions
  /// the map camera instantly at the latest location. This avoids the jarring
  /// "zoom to stale position → animate to real position" sequence.
  Future<void> _initializeMapPosition() async {
    // Fire data requests, user location fetch, and wait for the map controller
    // in parallel. Including _fetchUserLocation ensures _userLocation is set
    // before we position the camera — critical for trips with no locations.
    await Future.wait([
      _loadTripUpdates(),
      _refreshTripData(),
      _fetchUserLocation(),
      _mapControllerCompleter.future,
    ]);
    // Now both the data and the map are ready — jump to latest location.
    // Always call _updateMapData() as a safety net: if _refreshTripData()
    // failed (e.g. backend 500), the map would otherwise stay empty because
    // _updateMapData() is only called inside _refreshTripData's success path.
    // This ensures whatever data _trip holds (from widget.trip or a previous
    // successful load) is still rendered on the map.
    if (mounted) {
      _updateMapData();
      _animateMapToLatestLocation(animate: false);
      ref
          .read(tripDetailNotifierProvider(widget.trip.id).notifier)
          .setMapLoading(false);
      ref
          .read(tripDetailNotifierProvider(widget.trip.id).notifier)
          .markInitialMapPositionSet();
    }
  }

  Future<void> _initWebSocket() async {
    debugPrint('TripDetailScreen: Initializing WebSocket for trip ${_trip.id}');
    // Connect to WebSocket server first
    await _webSocketService.connect();
    if (!mounted) return;
    // Subscribe to events for this specific trip
    final tripStream = _webSocketService.subscribeToTrip(_trip.id);
    _wsSubscription = tripStream.listen(_handleWebSocketEvent);

    // Listen to the global events stream for notification events
    // (e.g. ACHIEVEMENT_UNLOCKED) that arrive on the user topic, not
    // the trip topic.
    _globalWsSubscription =
        _webSocketService.events.listen(_handleGlobalWebSocketEvent);

    // Subscribe to the user topic so NOTIFICATION_CREATED events
    // (including ACHIEVEMENT_UNLOCKED) are received. The userId may
    // not be available yet (loaded async in _loadUserInfo), so we
    // try now and also retry in _loadUserInfo via _subscribeUserTopic.
    _subscribeUserTopic();

    debugPrint(
        'TripDetailScreen: WebSocket initialized and listening for trip ${_trip.id}');
  }

  /// Subscribe to the current user's WebSocket topic if userId is known.
  /// Safe to call multiple times — no-ops when already subscribed.
  void _subscribeUserTopic() {
    final userId = _userId;
    if (userId == null) return;
    _webSocketService.subscribeToUser(userId);
    debugPrint('TripDetailScreen: Subscribed to user topic for user $userId');
  }

  /// Handle events from the global WebSocket stream that are relevant
  /// to the trip detail screen but may arrive on non-trip topics (e.g.
  /// user topic) or fail to route to the trip-specific stream (e.g.
  /// because the backend didn't include tripId at the expected JSON level).
  ///
  /// This acts as a reliable fallback: if an event was already handled by
  /// the trip-specific listener it will be a no-op because the state is
  /// already up-to-date.
  void _handleGlobalWebSocketEvent(WebSocketEvent event) {
    if (!mounted) return;

    if (event is NotificationCreatedEvent) {
      final notifType = event.notificationType.toUpperCase();
      if (notifType == 'ACHIEVEMENT_UNLOCKED') {
        debugPrint(
            'TripDetailScreen: Received ACHIEVEMENT_UNLOCKED notification');
        _loadTripAchievements();
      }
      return;
    }

    // For trip-scoped events, only process if they belong to this trip.
    // Extract tripId from the event itself or from the raw payload.
    final eventTripId =
        event.tripId ?? (event.payload['tripId'] as String?) ?? '';
    if (eventTripId.isEmpty || eventTripId != _trip.id) return;

    switch (event.type) {
      case WebSocketEventType.tripUpdateCreated:
        _handleTripUpdateCreatedEvent(event as TripUpdateCreatedEvent);
        _debouncedAchievementRefresh();
        break;
      case WebSocketEventType.tripUpdated:
        _handleTripUpdatedEvent(event as TripUpdatedEvent);
        break;
      case WebSocketEventType.tripStatusChanged:
        _handleTripStatusChanged(event as TripStatusChangedEvent);
        break;
      case WebSocketEventType.polylineUpdated:
        _handlePolylineUpdatedEvent(event as PolylineUpdatedEvent);
        break;
      case WebSocketEventType.commentAdded:
        _handleCommentAdded(event as CommentAddedEvent);
        break;
      case WebSocketEventType.commentReactionAdded:
      case WebSocketEventType.commentReactionRemoved:
      case WebSocketEventType.commentReactionReplaced:
        _handleCommentReaction(event as CommentReactionEvent);
        break;
      case WebSocketEventType.tripSettingsUpdated:
        _handleTripSettingsUpdated(event as TripSettingsUpdatedEvent);
        break;
      default:
        break;
    }
  }

  void _handleWebSocketEvent(WebSocketEvent event) {
    if (!mounted) return;

    switch (event.type) {
      case WebSocketEventType.tripStatusChanged:
        _handleTripStatusChanged(event as TripStatusChangedEvent);
        break;
      case WebSocketEventType.tripUpdated:
        _handleTripUpdatedEvent(event as TripUpdatedEvent);
        break;
      case WebSocketEventType.tripUpdateCreated:
        _handleTripUpdateCreatedEvent(event as TripUpdateCreatedEvent);
        // Achievements are evaluated server-side after trip updates
        // (distance milestones, time-based, etc.). Debounce a refresh
        // so rapid-fire updates don't hammer the API.
        _debouncedAchievementRefresh();
        break;
      case WebSocketEventType.polylineUpdated:
        _handlePolylineUpdatedEvent(event as PolylineUpdatedEvent);
        break;
      case WebSocketEventType.commentAdded:
        _handleCommentAdded(event as CommentAddedEvent);
        break;
      case WebSocketEventType.commentReactionAdded:
      case WebSocketEventType.commentReactionRemoved:
      case WebSocketEventType.commentReactionReplaced:
        _handleCommentReaction(event as CommentReactionEvent);
        break;
      case WebSocketEventType.tripSettingsUpdated:
        _handleTripSettingsUpdated(event as TripSettingsUpdatedEvent);
        break;
      default:
        break;
    }
  }

  void _handleTripStatusChanged(TripStatusChangedEvent event) {
    final notifier = ref.read(tripDetailNotifierProvider(widget.trip.id).notifier);
    notifier.applyTripStatusChanged(event);
    setState(() {});

    // Reload timeline to pick up any lifecycle markers
    // (TRIP_STARTED, TRIP_ENDED, DAY_START, DAY_END)
    _loadTripUpdates();

    // Reload full trip data to pick up updated currentDay / tripDays
    // after toggle-day transitions
    if (_trip.tripModality == TripModality.multiDay) {
      _refreshTripData();
    }
  }

  /// Refreshes full trip data from the backend via [TripDetailNotifier].
  ///
  /// The notifier's `refreshTripData()` already handles retry-with-backoff
  /// internally (see Task 8), so this widget wrapper no longer needs a
  /// `retryCount` parameter — all call sites (`_handleTripStatusChanged` and
  /// others) already invoke `_refreshTripData()` with no arguments, matching
  /// how Task 5's `_loadTripUpdates` wrapper dropped its own `retryCount`.
  Future<void> _refreshTripData() async {
    try {
      await ref
          .read(tripDetailNotifierProvider(widget.trip.id).notifier)
          .refreshTripData();
      if (mounted) {
        _updateMapData();
        // Only animate the camera on subsequent refreshes (e.g. after a
        // WebSocket status change). The very first positioning is handled by
        // _initializeMapPosition with an instant jump.
        // Skip the animation when a WebSocket event recently positioned the
        // camera — the WS event has the most up-to-date coordinates,
        // whereas the API response may still carry stale CQRS data.
        if (_hasInitialMapPosition && !_isWsCameraGuardActive) {
          _animateMapToLatestLocation(animate: true);
        }
      }
    } catch (e) {
      // Render whatever data we already have so the map isn't blank.
      if (mounted) {
        _updateMapData();
      }
    } finally {
      if (mounted) setState(() {});
    }
  }

  void _handleTripUpdatedEvent(TripUpdatedEvent event) {
    final parsedUpdateType = event.updateType != null
        ? TripUpdateType.fromJson(event.updateType!)
        : TripUpdateType.regular;
    final updateId = 'ws_${event.timestamp.millisecondsSinceEpoch}';

    final notifier = ref.read(tripDetailNotifierProvider(widget.trip.id).notifier);
    final applied = notifier.applyTripUpdateEvent(
      updateId: updateId,
      latitude: event.latitude,
      longitude: event.longitude,
      timestamp: event.timestamp,
      batteryLevel: event.batteryLevel,
      message: event.message,
      city: event.city,
      country: event.country,
      temperatureCelsius: event.temperatureCelsius,
      weatherCondition: event.weatherCondition != null
          ? WeatherCondition.fromJson(event.weatherCondition!)
          : null,
      updateType: parsedUpdateType,
      distanceSoFarKm: event.distanceSoFarKm,
    );
    setState(() {});

    if (applied) {
      _updateMapData();
      notifier.markWsCameraUpdate();
      _animateMapToLocation(LatLng(event.latitude!, event.longitude!));
    }
  }

  void _handleTripUpdateCreatedEvent(TripUpdateCreatedEvent event) {
    final parsedUpdateType = event.updateType != null
        ? TripUpdateType.fromJson(event.updateType!)
        : TripUpdateType.regular;
    final updateId = event.tripUpdateId.isNotEmpty
        ? event.tripUpdateId
        : 'ws_${event.timestamp.millisecondsSinceEpoch}';

    final notifier = ref.read(tripDetailNotifierProvider(widget.trip.id).notifier);
    final applied = notifier.applyTripUpdateEvent(
      updateId: updateId,
      latitude: event.latitude,
      longitude: event.longitude,
      timestamp: event.timestamp,
      batteryLevel: event.batteryLevel,
      message: event.message,
      city: event.city,
      country: event.country,
      temperatureCelsius: event.temperatureCelsius,
      weatherCondition: event.weatherCondition != null
          ? WeatherCondition.fromJson(event.weatherCondition!)
          : null,
      updateType: parsedUpdateType,
      distanceSoFarKm: event.distanceSoFarKm,
    );
    setState(() {});

    if (applied) {
      _updateMapData();
      notifier.markWsCameraUpdate();
      _animateMapToLocation(LatLng(event.latitude!, event.longitude!));
    }
  }

  void _handlePolylineUpdatedEvent(PolylineUpdatedEvent event) {
    // Validate that we have the required data
    if (event.tripId == null || event.tripId!.isEmpty) {
      debugPrint(
          'TripDetailScreen: PolylineUpdatedEvent missing tripId, ignoring');
      return;
    }

    if (event.encodedPolyline.isEmpty) {
      debugPrint(
          'TripDetailScreen: PolylineUpdatedEvent has empty encodedPolyline for trip ${event.tripId}, ignoring');
      return;
    }

    // Only update if this event is for the current trip
    if (event.tripId != _trip.id) {
      debugPrint(
          'TripDetailScreen: PolylineUpdatedEvent for different trip (${event.tripId}), ignoring');
      return;
    }

    debugPrint(
        'TripDetailScreen: Processing POLYLINE_UPDATED - updating encoded polyline');

    // Update the trip's encoded polyline and refresh the map
    ref
        .read(tripDetailNotifierProvider(widget.trip.id).notifier)
        .applyPolylineUpdated(event);
    setState(() {});

    // Redraw the polyline on the map
    _updateMapData();
    debugPrint('TripDetailScreen: Polyline updated on map');

    // Animate to the latest location on the polyline (only after the initial
    // camera position has been set — during startup, _initializeMapPosition
    // handles the first jump).
    // Skip when a WebSocket event recently positioned the camera to avoid
    // jumping back to a stale CQRS-derived position.
    if (_hasInitialMapPosition && !_isWsCameraGuardActive) {
      _animateMapToLatestLocation(animate: true);
    }
  }

  /// Move the Google Maps camera to the given [target].
  /// When [animate] is true, uses a smooth animation; otherwise jumps instantly.
  Future<void> _animateMapToLocation(LatLng target,
      {double zoom = 15.0, bool animate = true}) async {
    if (_mapController == null) return;
    final update = CameraUpdate.newLatLngZoom(target, zoom);
    if (animate) {
      await _mapController!.animateCamera(update);
    } else {
      await _mapController!.moveCamera(update);
    }
  }

  /// Move the map camera to the latest real location in the trip.
  /// When [animate] is true, uses a smooth animation; otherwise jumps instantly.
  void _animateMapToLatestLocation({bool animate = true}) {
    if (_mapController == null) return;

    // Find the latest update with a real location
    final latestWithLocation = _tripUpdates
        .where((u) => !u.isLifecycleMarker || u.hasLocation)
        .toList();
    if (latestWithLocation.isNotEmpty) {
      final latest = latestWithLocation.first;
      _animateMapToLocation(LatLng(latest.latitude, latest.longitude),
          animate: animate);
    } else {
      // Fall back to trip's initial location
      final initialLoc =
          TripMapHelper.getInitialLocation(_trip, userLocation: _userLocation);
      _animateMapToLocation(initialLoc, animate: animate);
    }
  }

  /// Fetches the user's current device location and centres the map on it.
  /// Called when a trip is started so that the map immediately shows where
  /// the user is. Falls back to [_animateMapToLatestLocation] when the
  /// device location cannot be determined.
  Future<void> _centerMapOnCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _animateMapToLatestLocation(animate: true);
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _animateMapToLatestLocation(animate: true);
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        _animateMapToLatestLocation(animate: true);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      final target = LatLng(position.latitude, position.longitude);

      if (mounted) {
        ref
            .read(tripDetailNotifierProvider(widget.trip.id).notifier)
            .setUserLocation(target);
        await _animateMapToLocation(target);
      }
    } catch (e) {
      debugPrint('TripDetailScreen: Could not center on current location: $e');
      // Gracefully fall back to existing behaviour
      _animateMapToLatestLocation(animate: true);
    }
  }

  void _handleTripSettingsUpdated(TripSettingsUpdatedEvent event) {
    // Only update UI state from the server confirmation.
    // Background update management is already handled optimistically
    // in _handleSettingsChange to avoid duplicate stop/start cycles.
    ref
        .read(tripDetailNotifierProvider(widget.trip.id).notifier)
        .applyTripSettingsUpdated(event);
    setState(() {});
  }

  void _handleCommentAdded(CommentAddedEvent event) {
    ref
        .read(tripDetailNotifierProvider(widget.trip.id).notifier)
        .applyCommentAdded(event);
    setState(() {});
  }

  void _handleCommentReaction(CommentReactionEvent event) {
    final normalizedReactionType = ReactionType.fromJson(event.reactionType);
    final normalizedPreviousReactionType = event.previousReactionType != null
        ? ReactionType.fromJson(event.previousReactionType!)
        : null;

    final ReactionType? oldReaction;
    final ReactionType? newReaction;
    if (normalizedPreviousReactionType != null) {
      // REPLACED: remove the old reaction, add the new one.
      oldReaction = normalizedPreviousReactionType;
      newReaction = normalizedReactionType;
    } else if (event.isRemoval) {
      // REMOVED: only the old reaction goes away.
      oldReaction = normalizedReactionType;
      newReaction = null;
    } else {
      // ADDED: only the new reaction appears.
      oldReaction = null;
      newReaction = normalizedReactionType;
    }

    ref.read(tripDetailNotifierProvider(widget.trip.id).notifier).applyCommentReaction(
          event.commentId,
          currentUserId: event.userId,
          oldReaction: oldReaction,
          newReaction: newReaction,
        );
    setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Initialize panel states based on screen size (only once)
    if (!_hasInitializedPanelStates) {
      _hasInitializedPanelStates = true;
      final screenWidth = MediaQuery.of(context).size.width;
      final isMobile = screenWidth < 600;

      if (isMobile) {
        // On mobile, collapse all panels by default so map is visible.
        // Set directly (no post-frame callback) so the first build already
        // uses collapsed state — avoids an AnimatedSwitcher transition that
        // overflows the 160 px collapsed-width constraint.
        _isTimelineCollapsed = true;
        _isCommentsCollapsed = true;
        _isTripInfoCollapsed = true;
      }
    }
  }

  @override
  void dispose() {
    // `ref` is not safely usable this late in teardown, so use
    // widget.trip.id — identical to _trip.id for the lifetime of this
    // screen instance, since no call site ever changes a Trip's id.
    // (tripDetailNotifierProvider is autoDispose — Riverpod tears down
    // this trip id's notifier on its own once nothing watches it anymore;
    // seedInitialTrip's unconditional overwrite means a reused, not-yet-
    // disposed instance is harmless too, so no explicit invalidate is
    // needed here.)
    debugPrint('TripDetailScreen: Disposing for trip ${widget.trip.id}');
    _wsSubscription?.cancel();
    _globalWsSubscription?.cancel();
    debugPrint('TripDetailScreen: Cancelled WebSocket subscriptions');
    _webSocketService.unsubscribeFromTrip(widget.trip.id);
    debugPrint('TripDetailScreen: Unsubscribed from trip');
    _commentController.dispose();
    _scrollController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadUserInfo() async {
    await ref
        .read(tripDetailNotifierProvider(widget.trip.id).notifier)
        .loadUserInfo();
    if (!mounted) return;

    _maybeShowTripDetailTutorial();

    // Now that userId is available, ensure we're subscribed to the
    // user topic for NOTIFICATION_CREATED events (achievements, etc.)
    _subscribeUserTopic();

    // If logged in and viewing another user's trip, check social status
    final userId = _userId;
    if (userId != null && _trip.userId != userId) {
      await _loadSocialStatus();
    }
  }

  /// Shows the first-time trip detail tutorial (coach marks) once per
  /// device, the first time this screen is ever opened. The target list is
  /// built dynamically:
  /// - The four collapsible bubbles (Info, Comments, Timeline, Settings)
  ///   only collapse to bubble form on mobile — on desktop they're already
  ///   expanded side-by-side, so those steps are mobile-only. Settings is
  ///   further gated on it actually having content (mirrors
  ///   `TripSettingsPanel._hasContent`), otherwise it renders a zero-size
  ///   box and there'd be nothing to spotlight.
  /// - Send Update and Trip Status controls only appear for the trip owner
  ///   under the same conditions that already gate their visibility
  ///   elsewhere in this screen.
  /// - Share is only a standalone step on desktop, where the info card is
  ///   never collapsed so the share button is always reachable. On mobile
  ///   it's reachable only after expanding the Info bubble, so it's
  ///   explained as part of that step's copy instead of a separate target.
  Future<void> _maybeShowTripDetailTutorial() async {
    if (_tutorialCheckDone || !mounted) return;
    _tutorialCheckDone = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final l10n = context.l10n;
      final isMobile = TripDetailLayoutStrategyFactory.isMobile(
        MediaQuery.sizeOf(context).width,
      );
      final isOwner = _userId != null && _trip.userId == _userId;
      final isEditableStatus = _trip.status == TripStatus.created ||
          _trip.status == TripStatus.inProgress;
      final settingsPanelHasContent =
          _trip.hasPlannedRoute || (isOwner && isEditableStatus);

      showFirstTimeTutorial(
        context: context,
        tutorialKey: TutorialKeys.tripDetail,
        steps: [
          if (isMobile)
            TutorialStep(
              key: _tutorialInfoBubbleKey,
              title: l10n.tutorialInfoBubbleTitle,
              description: l10n.tutorialInfoBubbleDescription,
            ),
          if (isMobile)
            TutorialStep(
              key: _tutorialCommentsBubbleKey,
              title: l10n.tutorialCommentsBubbleTitle,
              description: l10n.tutorialCommentsBubbleDescription,
            ),
          if (isMobile)
            TutorialStep(
              key: _tutorialTimelineBubbleKey,
              title: l10n.tutorialTimelineBubbleTitle,
              description: l10n.tutorialTimelineBubbleDescription,
              align: ContentAlign.left,
            ),
          if (isMobile && settingsPanelHasContent)
            TutorialStep(
              key: _tutorialSettingsBubbleKey,
              title: l10n.tutorialSettingsBubbleTitle,
              description: l10n.tutorialSettingsBubbleDescription,
            ),
          if (_showTripUpdatePanel)
            TutorialStep(
              key: _tutorialUpdatePanelKey,
              title: l10n.tutorialSendUpdateTitle,
              description: l10n.tutorialSendUpdateDescription,
              shape: ShapeLightFocus.RRect,
              radius: 16,
            ),
          if (isMobile && isOwner && _trip.status != TripStatus.finished)
            TutorialStep(
              key: _tutorialLifecycleKey,
              title: l10n.tutorialTripStatusTitle,
              description: l10n.tutorialTripStatusDescription,
              align: ContentAlign.left,
            ),
          if (!isMobile)
            TutorialStep(
              key: _tutorialShareKey,
              title: l10n.tutorialShareTripTitle,
              description: l10n.tutorialShareTripDescription,
              align: ContentAlign.bottom,
            ),
        ],
      );
    });
  }

  /// Load the current user's social relationship with the trip owner
  Future<void> _loadSocialStatus() async {
    await ref
        .read(tripDetailNotifierProvider(widget.trip.id).notifier)
        .loadSocialStatus();
    if (mounted) setState(() {});
  }

  Future<void> _checkLoginStatus() async {
    await ref
        .read(tripDetailNotifierProvider(widget.trip.id).notifier)
        .checkLoginStatus();
    if (mounted) setState(() {});
  }

  Future<void> _loadTripUpdates() async {
    try {
      await ref
          .read(tripDetailNotifierProvider(widget.trip.id).notifier)
          .loadTripUpdates();
    } catch (e) {
      if (mounted) {
        UiHelpers.showErrorMessage(context, 'Error loading updates: $e');
      }
    } finally {
      if (mounted) setState(() {});
    }
  }

  Future<void> _loadMoreTripUpdates() async {
    try {
      await ref
          .read(tripDetailNotifierProvider(widget.trip.id).notifier)
          .loadMoreTripUpdates();
      _updateMapData();
    } catch (e) {
      if (mounted) {
        UiHelpers.showErrorMessage(context, 'Error loading more updates: $e');
      }
    } finally {
      if (mounted) setState(() {});
    }
  }

  Future<void> _loadPromotionInfo() async {
    await ref
        .read(tripDetailNotifierProvider(widget.trip.id).notifier)
        .loadPromotionInfo();
    if (mounted) setState(() {});
  }

  void _debouncedAchievementRefresh() {
    ref
        .read(tripDetailNotifierProvider(widget.trip.id).notifier)
        .debouncedAchievementRefresh();
  }

  Future<void> _loadTripAchievements() async {
    await ref
        .read(tripDetailNotifierProvider(widget.trip.id).notifier)
        .loadTripAchievements();
    if (mounted) setState(() {});
  }

  void _updateMapData() {
    debugPrint(
        'TripDetailScreen: Updating map data - locations: ${_trip.locations?.length}, encodedPolyline length: ${_trip.encodedPolyline?.length}');
    final notifier =
        ref.read(tripDetailNotifierProvider(widget.trip.id).notifier);
    try {
      final mapData = TripMapHelper.createMapDataWithDirections(
        _trip,
        onMarkerTap: _onMapMarkerTapped,
        onPlannedMarkerTap: _onPlannedMarkerTapped,
        showPlannedWaypoints: _showPlannedWaypoints,
      );
      notifier.setMapMarkersAndPolylines(mapData.markers, mapData.polylines);
    } catch (e) {
      debugPrint(
          'TripDetailScreen: Error in createMapDataWithDirections, falling back to straight lines: $e');
      // Fallback to straight lines if decoding fails
      final mapData = TripMapHelper.createMapData(
        _trip,
        onMarkerTap: _onMapMarkerTapped,
        onPlannedMarkerTap: _onPlannedMarkerTapped,
        showPlannedWaypoints: _showPlannedWaypoints,
      );
      notifier.setMapMarkersAndPolylines(mapData.markers, mapData.polylines);
    }
  }

  void _onMapMarkerTapped(TripLocation location) {
    ref
        .read(tripDetailNotifierProvider(widget.trip.id).notifier)
        .selectMapLocation(location);
  }

  void _onPlannedMarkerTapped(PlannedWaypointInfo waypoint) {
    ref
        .read(tripDetailNotifierProvider(widget.trip.id).notifier)
        .selectPlannedWaypoint(waypoint);
  }

  void _onInfoWindowClosed() {
    ref
        .read(tripDetailNotifierProvider(widget.trip.id).notifier)
        .clearMapSelection();
  }

  Future<void> _loadComments() async {
    try {
      await ref
          .read(tripDetailNotifierProvider(widget.trip.id).notifier)
          .loadComments();
    } catch (e) {
      if (mounted) {
        UiHelpers.showErrorMessage(context, 'Error loading comments: $e');
      }
    } finally {
      if (mounted) setState(() {});
    }
  }

  Future<void> _loadMoreComments() async {
    try {
      await ref
          .read(tripDetailNotifierProvider(widget.trip.id).notifier)
          .loadMoreComments();
    } catch (e) {
      if (mounted) {
        UiHelpers.showErrorMessage(context, 'Error loading more comments: $e');
      }
    } finally {
      if (mounted) setState(() {});
    }
  }

  void _changeSortOption(CommentSortOption option) {
    ref
        .read(tripDetailNotifierProvider(widget.trip.id).notifier)
        .changeSortOption(option);
  }

  Future<void> _addComment() async {
    final message = _commentController.text.trim();
    if (message.isEmpty) return;

    try {
      await ref.read(tripDetailNotifierProvider(widget.trip.id).notifier).addComment(
            message,
            currentUserId: _userId,
            currentUsername: _username,
            currentAvatarUrl: _avatarUrl,
          );
      _commentController.clear();
      if (mounted) {
        setState(() {});
        UiHelpers.showSuccessMessage(context, 'Comment added!');
      }
    } catch (e) {
      if (mounted) {
        UiHelpers.showErrorMessage(context, 'Error adding comment: $e');
      }
    }
  }

  Future<void> _handleReactionClick(String commentId, ReactionType type) async {
    final currentReaction = ref
        .read(tripDetailNotifierProvider(widget.trip.id).notifier)
        .getUserReaction(commentId, _userId);
    final isRemoving = currentReaction == type;
    final isReplacing = !isRemoving && currentReaction != null;

    try {
      await ref
          .read(tripDetailNotifierProvider(widget.trip.id).notifier)
          .handleReactionClick(
            commentId,
            type,
            currentUserId: _userId,
            currentUsername: _username,
          );
      if (!mounted) return;
      setState(() {});
      if (isRemoving) {
        UiHelpers.showSuccessMessage(context, 'Reaction removed!');
      } else if (isReplacing) {
        UiHelpers.showSuccessMessage(context, 'Reaction changed!');
      } else {
        UiHelpers.showSuccessMessage(context, 'Reaction added!');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {});
      final errorMessage = e.toString();
      if (errorMessage.contains('409') || errorMessage.contains('Conflict')) {
        UiHelpers.showInfoMessage(
            context, 'You already have this reaction on the comment');
      } else if (errorMessage.contains('500')) {
        UiHelpers.showErrorMessage(context,
            'Server error while changing reaction. This may be a backend issue.');
      } else {
        UiHelpers.showErrorMessage(context, 'Error with reaction: $e');
      }
    }
  }

  Future<void> _addReaction(String commentId, ReactionType type) async {
    // Delegate to the new handler
    await _handleReactionClick(commentId, type);
  }

  Future<void> _changeTripStatus(TripStatus newStatus) async {
    if (_userId == null || _trip.userId != _userId) {
      if (mounted) {
        UiHelpers.showErrorMessage(
            context, 'Only trip owner can change status');
      }
      return;
    }

    if (newStatus == TripStatus.inProgress &&
        _trip.automaticUpdates &&
        _isAndroid) {
      final hasPermission =
          await _ensureLocationPermission(requireBackground: true);
      if (!hasPermission) return;
    }

    try {
      await ref
          .read(tripDetailNotifierProvider(widget.trip.id).notifier)
          .changeTripStatus(newStatus, isMultiDay: _trip.tripModality == TripModality.multiDay);
      if (!mounted) return;

      if (_isAndroid) {
        final backgroundManager = BackgroundUpdateManager();
        if (newStatus == TripStatus.inProgress && _trip.automaticUpdates) {
          await backgroundManager.startAutoUpdates(
            _trip.id,
            _trip.name,
            _trip.effectiveUpdateRefresh,
          );
        } else {
          await backgroundManager.stopAutoUpdates(_trip.id);
        }
      }

      if (newStatus == TripStatus.inProgress) {
        await _centerMapOnCurrentLocation();
      }

      if (mounted) {
        setState(() {});
        String message;
        switch (newStatus) {
          case TripStatus.inProgress:
            message = 'Trip started!';
            break;
          case TripStatus.paused:
            message = 'Trip paused';
            break;
          case TripStatus.finished:
            message = 'Trip finished!';
            break;
          case TripStatus.resting:
            message = 'Resting for the night';
            break;
          case TripStatus.created:
            message = 'Trip status updated';
            break;
        }
        UiHelpers.showSuccessMessage(context, message);
      }
    } catch (e) {
      if (mounted) {
        setState(() {});
        UiHelpers.showErrorMessage(context, friendlyMessage(e));
      }
    }
  }

  Future<void> _changeTripVisibility(Visibility newVisibility) async {
    if (_userId == null || _trip.userId != _userId) {
      if (mounted) {
        UiHelpers.showErrorMessage(
            context, 'Only trip owner can change visibility');
      }
      return;
    }

    try {
      await ref
          .read(tripDetailNotifierProvider(widget.trip.id).notifier)
          .changeTripVisibility(newVisibility);
      if (mounted) {
        setState(() {});
        UiHelpers.showSuccessMessage(
          context,
          'Visibility changed to ${newVisibility.toJson()}',
        );
      }
    } catch (e) {
      if (mounted) {
        UiHelpers.showErrorMessage(context, 'Error changing visibility: $e');
      }
    }
  }

  /// Handles trip deletion with confirmation dialog.
  /// On success, navigates to the home screen and clears the navigation stack.
  Future<void> _handleDeleteTrip() async {
    final l10n = context.l10n;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteTrip),
        content: Text(
          'Are you sure you want to delete "${_trip.name}"? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      await ref
          .read(tripDetailNotifierProvider(widget.trip.id).notifier)
          .deleteTrip();
      if (mounted) {
        UiHelpers.showSuccessMessage(context, 'Trip deleted');
        Navigator.of(context).pushAndRemoveUntil(
          PageTransitions.fade(const HomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        UiHelpers.showErrorMessage(context, 'Error deleting trip: $e');
      }
    }
  }

  /// Handle "Finish Day N" / "Begin Day N+1" button tap for MULTI_DAY trips.
  /// Calls the backend toggle-day endpoint which handles the status transition.
  /// When finishing a day, shows a confirmation dialog first.
  /// Returns `true` when the action was completed (message field can be cleared).
  Future<bool> _handleDayButtonTap(String? message) async {
    final l10n = context.l10n;
    if (_trip.status == TripStatus.inProgress) {
      // --- Finish Day: confirmation → toggle day ---
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('Finish Day $_currentDay'),
          content: Text(
            'Are you sure you want to finish Day $_currentDay? '
            'Your trip status will change to resting.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              key: const Key('confirm_finish_day_button'),
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: WandererTheme.dayEndColor,
                foregroundColor: Colors.white,
              ),
              child: Text(l10n.finishDay),
            ),
          ],
        ),
      );

      if (confirmed != true || !mounted) return false;

      try {
        await ref
            .read(tripDetailNotifierProvider(widget.trip.id).notifier)
            .toggleDay(isFinishingDay: true);
        if (!mounted) return false;

        if (_isAndroid) {
          final backgroundManager = BackgroundUpdateManager();
          await backgroundManager.stopAutoUpdates(_trip.id);
        }

        if (mounted) {
          setState(() {});
          UiHelpers.showSuccessMessage(context, 'Resting for the night');
          await _loadTripUpdates();
        }
        return true;
      } catch (e) {
        if (mounted) {
          setState(() {});
          UiHelpers.showErrorMessage(context, 'Error ending day: $e');
        }
        return false;
      }
    } else if (_trip.status == TripStatus.resting) {
      try {
        await ref
            .read(tripDetailNotifierProvider(widget.trip.id).notifier)
            .toggleDay(isFinishingDay: false);
        if (!mounted) return false;

        if (_isAndroid && _trip.automaticUpdates) {
          final hasPermission =
              await _ensureLocationPermission(requireBackground: true);
          if (!mounted) return false;
          if (hasPermission) {
            final backgroundManager = BackgroundUpdateManager();
            await backgroundManager.startAutoUpdates(
              _trip.id,
              _trip.name,
              _trip.effectiveUpdateRefresh,
            );
          }
        }

        if (mounted) {
          setState(() {});
          UiHelpers.showSuccessMessage(context, 'Day $_currentDay started!');
          await _loadTripUpdates();
        }
        return true;
      } catch (e) {
        if (mounted) {
          setState(() {});
          UiHelpers.showErrorMessage(context, 'Error starting day: $e');
        }
        return false;
      }
    }
    return false;
  }

  Future<void> _handleSettingsChange(bool automaticUpdates, int? updateRefresh,
      TripModality? tripModality) async {
    if (_userId == null || _trip.userId != _userId) {
      if (mounted) {
        UiHelpers.showErrorMessage(
            context, 'Only trip owner can change settings');
      }
      return;
    }

    if (automaticUpdates && _isAndroid) {
      final hasPermission =
          await _ensureLocationPermission(requireBackground: true);
      if (!hasPermission) return;
    }

    try {
      await ref
          .read(tripDetailNotifierProvider(widget.trip.id).notifier)
          .changeTripSettings(automaticUpdates, updateRefresh, tripModality);
      if (!mounted) return;

      if (_isAndroid && _trip.status == TripStatus.inProgress) {
        final backgroundManager = BackgroundUpdateManager();
        if (automaticUpdates && updateRefresh != null) {
          await backgroundManager.startAutoUpdates(
              _trip.id, _trip.name, updateRefresh);
        } else {
          await backgroundManager.stopAutoUpdates(_trip.id);
        }
      }

      if (mounted) {
        setState(() {});
        UiHelpers.showSuccessMessage(
            context, 'Trip settings updated successfully');
      }
    } catch (e) {
      if (mounted) {
        setState(() {});
        UiHelpers.showErrorMessage(context, 'Error updating settings: $e');
      }
    }
  }

  /// Trigger a one-off background update for testing (bypasses 15-min minimum)
  Future<void> _triggerTestBackgroundUpdate() async {
    final backgroundManager = BackgroundUpdateManager();
    await backgroundManager.triggerTestUpdate(_trip.id, tripName: _trip.name);
    if (mounted) {
      UiHelpers.showSuccessMessage(
        context,
        '🧪 Test background update triggered — check notifications',
      );
    }
  }

  void _showReactionPicker(String commentId) {
    showModalBottomSheet(
      context: context,
      builder: (context) => ReactionPicker(
        onReactionSelected: (type) => _addReaction(commentId, type),
      ),
    );
  }

  void _handleReply(String commentId) {
    ref
        .read(tripDetailNotifierProvider(widget.trip.id).notifier)
        .setReplyingTo(commentId);
    FocusScope.of(context).requestFocus(FocusNode());
  }

  Future<void> _handleToggleReplies(String commentId, bool isExpanded) async {
    try {
      await ref
          .read(tripDetailNotifierProvider(widget.trip.id).notifier)
          .toggleRepliesExpanded(commentId, isExpanded);
    } catch (e) {
      if (mounted) {
        UiHelpers.showErrorMessage(context, 'Error loading replies: $e');
      }
    } finally {
      if (mounted) setState(() {});
    }
  }

  /// Handle trip update panel toggle with mobile-specific behavior
  void _handleToggleTripUpdate(bool isMobile) {
    setState(() {
      if (_isTripUpdateCollapsed) {
        // Opening
        _isTripUpdateCollapsed = false;
        if (isMobile) {
          // Close other panels on mobile
          _isTripInfoCollapsed = true;
          _isCommentsCollapsed = true;
          _isTimelineCollapsed = true;
          _isTripSettingsCollapsed = true;
        }
      } else {
        // Closing
        _isTripUpdateCollapsed = true;
      }
    });
  }

  Future<void> _sendManualUpdate(String? message) async {
    try {
      final permissionReady = await _ensureLocationPermission();
      if (!permissionReady) return;

      final result = await ref
          .read(tripDetailNotifierProvider(widget.trip.id).notifier)
          .sendManualUpdate(message);

      if (mounted) {
        setState(() {});
        if (result.isSuccess) {
          UiHelpers.showSuccessMessage(context, 'Update sent successfully!');
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) _loadTripUpdates();
          });

          if (_isAndroid &&
              _trip.status == TripStatus.inProgress &&
              _trip.automaticUpdates) {
            final backgroundManager = BackgroundUpdateManager();
            await backgroundManager.startAutoUpdates(
              _trip.id,
              _trip.name,
              _trip.effectiveUpdateRefresh,
            );
          }
        } else {
          UiHelpers.showErrorMessage(context, result.userMessage);
        }
      }
    } catch (e) {
      if (mounted) {
        UiHelpers.showErrorMessage(context, 'Error sending update: $e');
      }
    } finally {
      if (mounted) setState(() {});
    }
  }

  /// Ensures location permission is granted, requesting it from the user
  /// if necessary.  Returns `true` when permission is sufficient to proceed.
  ///
  /// On Android, when background location is needed (automatic trip updates),
  /// this also shows a prominent in-app disclosure as required by Google Play
  /// and requests ACCESS_BACKGROUND_LOCATION (i.e. "Allow all the time").
  Future<bool> _ensureLocationPermission(
      {bool requireBackground = false}) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      if (mounted) {
        UiHelpers.showErrorMessage(
          context,
          'Location services are disabled. '
          'Please enable GPS in your device settings.',
        );
      }
      return false;
    }

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      if (!mounted) return false;
      final consented = await LocationPermissionDisclosure.show(context);
      if (!consented) return false;
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      if (mounted) {
        UiHelpers.showErrorMessage(
          context,
          'Location permission is required to send updates.',
        );
      }
      return false;
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        UiHelpers.showErrorMessage(
          context,
          'Location permission is permanently denied. '
          'Please enable it in your device settings.',
        );
        // Try to open app settings so the user can grant permission.
        await Geolocator.openAppSettings();
      }
      return false;
    }

    // On Android, if background location is needed (for automatic updates),
    // show the prominent disclosure and request "Allow all the time".
    if (requireBackground &&
        !kIsWeb &&
        Platform.isAndroid &&
        permission == LocationPermission.whileInUse) {
      if (!mounted) return false;
      final userConsented = await BackgroundLocationDisclosure.show(context);
      if (!userConsented) {
        if (mounted) {
          UiHelpers.showErrorMessage(
            context,
            'Background location is required for automatic trip updates. '
            'You can still send manual updates.',
          );
        }
        return false;
      }

      // After consent, trigger the system prompt for background location
      permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.always) {
        if (mounted) {
          UiHelpers.showErrorMessage(
            context,
            'Please select "Allow all the time" in your device settings '
            'to enable automatic trip updates.',
          );
          await Geolocator.openAppSettings();
        }
        return false;
      }
    }

    return true;
  }

  /// Handle tap on a timeline update - animate map to that location
  /// Ignores lifecycle markers (Day Started/Ended, Trip Started/Ended) since
  /// they have no real location.
  void _handleTimelineUpdateTap(TripLocation update) {
    // Zoom to the update location on the map (for all update types)
    // For lifecycle markers without real location, use fallback coordinates
    if (update.hasLocation) {
      _animateMapToLocation(LatLng(update.latitude, update.longitude));
    }
  }

  Future<void> _logout() async {
    final confirm = await DialogHelper.showLogoutConfirmation(context);

    if (confirm) {
      await _repository.logout();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          PageTransitions.fade(const HomeScreen()),
          (route) => false,
        );
      }
    }
  }

  void _handleSettings() {
    Navigator.push(
      context,
      PageTransitions.slideFromBottom(const SettingsScreen()),
    );
  }

  void _handleProfile() {
    AuthNavigationHelper.navigateToOwnProfile(context);
  }

  Future<void> _launchDonationLink() async {
    if (_donationLink == null) return;
    final uri = Uri.parse(_donationLink!);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      UiHelpers.showErrorMessage(context, 'Could not open donation link');
    }
  }

  Future<void> _navigateToAuth() async {
    final result = await Navigator.push(
      context,
      PageTransitions.fade(const AuthScreen()),
    );

    // Refresh screen data after login
    if (result == true && mounted) {
      await _loadUserInfo();
      await _checkLoginStatus();
      await _loadComments(); // Reload comments in case user can now see more
      await _loadTripUpdates(); // Reload timeline
      setState(() {}); // Force rebuild to update UI
    }
  }

  Future<void> _handleFollowTripOwner() async {
    if (!_isLoggedIn || _trip.userId == _userId) return;

    final wasFollowing = _isFollowingTripOwner;
    try {
      await ref
          .read(tripDetailNotifierProvider(widget.trip.id).notifier)
          .followTripOwner();
      if (mounted) {
        setState(() {});
        UiHelpers.showSuccessMessage(
          context,
          wasFollowing
              ? 'Unfollowed @${_trip.username}'
              : 'You are now following @${_trip.username}',
        );
      }
    } catch (e) {
      if (mounted) {
        UiHelpers.showErrorMessage(
          context,
          wasFollowing
              ? 'Failed to unfollow user: $e'
              : 'Failed to follow user: $e',
        );
      }
    }
  }

  Future<void> _handleSendFriendRequestToTripOwner() async {
    if (!_isLoggedIn || _trip.userId == _userId) return;

    final wasAlreadyFriends = _isAlreadyFriends;
    final wasCancelling = _hasSentFriendRequest && _sentFriendRequestId != null;

    try {
      await ref
          .read(tripDetailNotifierProvider(widget.trip.id).notifier)
          .sendFriendRequestToTripOwner();
      if (!mounted) return;
      setState(() {});
      if (wasAlreadyFriends) {
        UiHelpers.showSuccessMessage(
            context, 'You are no longer friends with @${_trip.username}');
      } else if (wasCancelling) {
        UiHelpers.showSuccessMessage(context, 'Friend request cancelled');
      } else {
        UiHelpers.showSuccessMessage(
            context, 'Friend request sent to @${_trip.username}');
      }
    } catch (e) {
      if (!mounted) return;
      if (wasAlreadyFriends) {
        UiHelpers.showErrorMessage(context, 'Failed to remove friend: $e');
      } else if (wasCancelling) {
        UiHelpers.showErrorMessage(
            context, 'Failed to cancel friend request: $e');
      } else {
        UiHelpers.showErrorMessage(
            context, 'Failed to send friend request: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: WandererAppBar(
        isLoggedIn: _isLoggedIn,
        onLoginPressed: _navigateToAuth,
        username: _username,
        userId: _userId,
        displayName: _displayName,
        avatarUrl: _avatarUrl,
        onProfile: _handleProfile,
        onSettings: _handleSettings,
        onLogout: _logout,
      ),
      drawer: AppSidebar(
        username: _username,
        userId: _userId,
        displayName: _displayName,
        avatarUrl: _avatarUrl,
        selectedIndex: _selectedSidebarIndex,
        onLogout: _logout,
        onSettings: _handleSettings,
        isAdmin: _isAdmin,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Get the appropriate layout strategy based on screen size
          final isMobile =
              TripDetailLayoutStrategyFactory.isMobile(constraints.maxWidth);
          final strategy =
              TripDetailLayoutStrategyFactory.getStrategy(constraints.maxWidth);

          // Create layout data with all state and callbacks
          final layoutData = _createLayoutData(isMobile);

          // Calculate dimensions using strategy
          final leftPanelWidth =
              strategy.calculateLeftPanelWidth(constraints, layoutData);

          return Stack(
            children: [
              // Full-screen Map (background)
              Positioned.fill(
                child: TripMapView(
                  initialLocation: TripMapHelper.getInitialLocation(_trip,
                      userLocation: _userLocation),
                  initialZoom: TripMapHelper.getInitialZoom(_trip,
                      userLocation: _userLocation),
                  markers: _markers,
                  polylines: _polylines,
                  onMapCreated: (controller) {
                    _mapController = controller;
                    if (!_mapControllerCompleter.isCompleted) {
                      _mapControllerCompleter.complete(controller);
                    }
                  },
                  isOwner: _userId != null && _trip.userId == _userId,
                  // On mobile: disable map gestures when any panel is expanded
                  // to prevent scroll-through on touch devices.
                  // On desktop: disable map gestures only when the mouse is
                  // hovering over a panel, so scroll/drag on panels doesn't
                  // move the map, but the map is freely navigable otherwise.
                  gesturesEnabled: isMobile
                      ? (_isTripInfoCollapsed &&
                          _isCommentsCollapsed &&
                          _isTimelineCollapsed &&
                          _isTripUpdateCollapsed &&
                          _isTripSettingsCollapsed)
                      : !_isHoveringOverPanel,
                  selectedLocation: _selectedMapLocation,
                  onInfoWindowClosed: _onInfoWindowClosed,
                  selectedPlannedWaypoint: _selectedPlannedWaypoint,
                  onPlannedInfoWindowClosed: _onInfoWindowClosed,
                  onMapTap: _onInfoWindowClosed,
                ),
              ),

              // Map loading overlay with blur and spinner
              if (_isMapLoading)
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                    child: Container(
                      color: Colors.black.withOpacity(0.1),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                WandererTheme.primaryOrange,
                              ),
                              strokeWidth: 3,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              l10n.loadingTrip,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.5),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // Left side: Trip Info and Comments (floating glass panels)
              Positioned(
                left: 0,
                top: 0,
                bottom: strategy.shouldLeftPanelStretchToBottom(layoutData)
                    ? 0
                    : null,
                child: SizedBox(
                  width: leftPanelWidth,
                  child: MouseRegion(
                    onEnter: (_) {
                      if (!isMobile) {
                        setState(() => _isHoveringOverPanel = true);
                      }
                    },
                    onExit: (_) {
                      if (!isMobile) {
                        setState(() => _isHoveringOverPanel = false);
                      }
                    },
                    child: strategy.buildLeftPanel(constraints, layoutData),
                  ),
                ),
              ),

              // Right side: Timeline panel (floating glass card)
              Positioned(
                right: 0,
                top: 0,
                bottom: strategy.shouldTimelinePanelStretchToBottom(layoutData)
                    ? 0
                    : null,
                child: MouseRegion(
                  onEnter: (_) {
                    if (!isMobile) {
                      setState(() => _isHoveringOverPanel = true);
                    }
                  },
                  onExit: (_) {
                    if (!isMobile) {
                      setState(() => _isHoveringOverPanel = false);
                    }
                  },
                  child: strategy.buildTimelinePanel(constraints, layoutData),
                ),
              ),

              // Lifecycle circle buttons (mobile only, owner only)
              // Positioned on right side above native Google Maps zoom controls
              if (isMobile &&
                  _userId != null &&
                  _trip.userId == _userId &&
                  _trip.status != TripStatus.finished)
                Positioned(
                  right: 8,
                  bottom: 120,
                  child: TripLifecycleButtons(
                    key: _tutorialLifecycleKey,
                    currentStatus: _trip.status,
                    tripModality: _trip.tripModality,
                    isOwner: true,
                    isLoading: _isChangingStatus,
                    onStatusChange: _changeTripStatus,
                    showDayButton: _showDayButton,
                    currentDay: _currentDay,
                    isResting: _trip.status == TripStatus.resting,
                    onDayButtonTap:
                        _showDayButton ? () => _handleDayButtonTap(null) : null,
                  ),
                ),

              // Floating donation button for promoted trips
              if (_isPromoted && _donationLink != null)
                isMobile
                    ? Positioned(
                        left: 16,
                        bottom: 16,
                        child: _buildDonationButton(),
                      )
                    : AnimatedPositioned(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        left: _isCommentsCollapsed
                            ? 16.0
                            : strategy.calculateInfoColumnWidth(
                                    constraints, layoutData) -
                                16,
                        bottom: 16,
                        child: _buildDonationButton(),
                      ),
            ],
          );
        },
      ),
    );
  }

  /// Builds a donation button styled based on the donation link provider
  Widget _buildDonationButton() {
    final l10n = context.l10n;
    final isBuyMeACoffee =
        _donationLink != null && _donationLink!.contains('buymeacoffee.com');

    if (isBuyMeACoffee) {
      return GestureDetector(
        onTap: _launchDonationLink,
        child: Image.asset(
          'assets/third_app_logos/buymeacoffee.png',
          height: 48,
        ),
      );
    }

    // Generic donation button for other providers
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(12),
      color: Colors.amber.shade700,
      child: InkWell(
        onTap: _launchDonationLink,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.favorite, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                l10n.supportTrip,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Creates the layout data object with all state and callbacks
  TripDetailLayoutData _createLayoutData(bool isMobile) {
    return TripDetailLayoutData(
      trip: _trip,
      comments: _comments,
      replies: _replies,
      expandedComments: _expandedComments,
      tripUpdates: _tripUpdates,
      isLoadingComments: _isLoadingComments,
      isLoadingMoreComments: _isLoadingMoreComments,
      hasMoreComments: _hasMoreComments,
      isLoadingUpdates: _isLoadingUpdates,
      isLoadingMoreUpdates: _isLoadingMoreUpdates,
      hasMoreUpdates: _hasMoreUpdates,
      isLoggedIn: _isLoggedIn,
      isAddingComment: _isAddingComment,
      isTimelineCollapsed: _isTimelineCollapsed,
      isCommentsCollapsed: _isCommentsCollapsed,
      isTripInfoCollapsed: _isTripInfoCollapsed,
      isTripUpdateCollapsed: _isTripUpdateCollapsed,
      isTripSettingsCollapsed: _isTripSettingsCollapsed,
      isSendingUpdate: _isSendingUpdate,
      sortOption: _sortOption,
      commentController: _commentController,
      scrollController: _scrollController,
      replyingToCommentId: _replyingToCommentId,
      currentUserId: _userId,
      isChangingStatus: _isChangingStatus,
      isChangingSettings: _isChangingSettings,
      showTripUpdatePanel: _showTripUpdatePanel,
      isFollowingTripOwner: _isFollowingTripOwner,
      hasSentFriendRequest: _hasSentFriendRequest,
      isAlreadyFriends: _isAlreadyFriends,
      isPromoted: _isPromoted,
      donationLink: _donationLink,
      tripAchievements: _tripAchievements,
      showPlannedWaypoints: _showPlannedWaypoints,
      shareButtonKey: _tutorialShareKey,
      updatePanelKey: _tutorialUpdatePanelKey,
      infoCardKey: _tutorialInfoBubbleKey,
      commentsSectionKey: _tutorialCommentsBubbleKey,
      timelinePanelKey: _tutorialTimelineBubbleKey,
      settingsPanelKey: _tutorialSettingsBubbleKey,
      onToggleTripInfo: () => _handleToggleTripInfo(isMobile),
      onToggleComments: () => _handleToggleComments(isMobile),
      onToggleTimeline: () => _handleToggleTimeline(isMobile),
      onToggleTripUpdate: () => _handleToggleTripUpdate(isMobile),
      onToggleTripSettings: () => _handleToggleTripSettings(isMobile),
      onRefreshTimeline: _loadTripUpdates,
      onLoadMoreUpdates: _hasMoreUpdates ? _loadMoreTripUpdates : null,
      onTimelineUpdateTap: _handleTimelineUpdateTap,
      onSortChanged: _changeSortOption,
      onReact: _showReactionPicker,
      onReactionChipTap: (commentId, type) =>
          _handleReactionClick(commentId, type),
      onReply: _handleReply,
      onToggleReplies: _handleToggleReplies,
      onSendComment: _addComment,
      onCancelReply: () => ref
          .read(tripDetailNotifierProvider(widget.trip.id).notifier)
          .setReplyingTo(null),
      onLoadMoreComments: _hasMoreComments ? _loadMoreComments : null,
      onStatusChange: _changeTripStatus,
      onSettingsChange: _handleSettingsChange,
      onSendTripUpdate: _sendManualUpdate,
      onFollowTripOwner: _isLoggedIn && _trip.userId != _userId
          ? _handleFollowTripOwner
          : null,
      onSendFriendRequestToTripOwner: _isLoggedIn && _trip.userId != _userId
          ? _handleSendFriendRequestToTripOwner
          : null,
      onTestBackgroundUpdate:
          _isAndroid ? () => _triggerTestBackgroundUpdate() : null,
      onVisibilityChange:
          _isLoggedIn && _trip.userId == _userId ? _changeTripVisibility : null,
      onDeleteTrip:
          _isLoggedIn && _trip.userId == _userId ? _handleDeleteTrip : null,
      onTogglePlannedWaypoints: _trip.hasPlannedRoute
          ? () {
              ref
                  .read(tripDetailNotifierProvider(widget.trip.id).notifier)
                  .setShowPlannedWaypoints(!_showPlannedWaypoints);
              _updateMapData();
            }
          : null,
    );
  }

  /// Handle trip info panel toggle with mobile-specific behavior
  void _handleToggleTripInfo(bool isMobile) {
    setState(() {
      if (_isTripInfoCollapsed) {
        // Opening
        _isTripInfoCollapsed = false;
        if (isMobile) {
          // Close other panels on mobile
          _isCommentsCollapsed = true;
          _isTimelineCollapsed = true;
          _isTripUpdateCollapsed = true;
          _isTripSettingsCollapsed = true;
        }
      } else {
        // Closing
        _isTripInfoCollapsed = true;
      }
    });
  }

  /// Handle comments panel toggle with mobile-specific behavior
  void _handleToggleComments(bool isMobile) {
    setState(() {
      if (_isCommentsCollapsed) {
        // Opening
        _isCommentsCollapsed = false;
        if (isMobile) {
          // Close other panels on mobile
          _isTripInfoCollapsed = true;
          _isTimelineCollapsed = true;
          _isTripUpdateCollapsed = true;
          _isTripSettingsCollapsed = true;
        }
      } else {
        // Closing
        _isCommentsCollapsed = true;
      }
    });
  }

  /// Handle timeline panel toggle with mobile-specific behavior
  void _handleToggleTimeline(bool isMobile) {
    setState(() {
      if (_isTimelineCollapsed) {
        // Opening
        _isTimelineCollapsed = false;
        if (isMobile) {
          // Close other panels on mobile
          _isTripInfoCollapsed = true;
          _isCommentsCollapsed = true;
          _isTripUpdateCollapsed = true;
          _isTripSettingsCollapsed = true;
        }
      } else {
        // Closing
        _isTimelineCollapsed = true;
      }
    });
  }

  /// Handle trip settings panel toggle with mobile-specific behavior
  void _handleToggleTripSettings(bool isMobile) {
    setState(() {
      if (_isTripSettingsCollapsed) {
        // Opening
        _isTripSettingsCollapsed = false;
        if (isMobile) {
          // Close other panels on mobile
          _isTripInfoCollapsed = true;
          _isCommentsCollapsed = true;
          _isTimelineCollapsed = true;
          _isTripUpdateCollapsed = true;
        }
      } else {
        // Closing
        _isTripSettingsCollapsed = true;
      }
    });
  }
}
