import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' show ImageFilter;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' hide Visibility;
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:wanderer_frontend/core/constants/enums.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/data/models/user_models.dart';
import 'package:wanderer_frontend/data/models/comment_models.dart';
import 'package:wanderer_frontend/data/models/achievement_models.dart';
import 'package:wanderer_frontend/data/models/websocket/websocket_event.dart';
import 'package:wanderer_frontend/data/repositories/trip_detail_repository.dart';
import 'package:wanderer_frontend/data/client/query/promotion_query_client.dart';
import 'package:wanderer_frontend/data/services/websocket_service.dart';
import 'package:wanderer_frontend/data/services/user_service.dart';
import 'package:wanderer_frontend/data/services/achievement_service.dart';
import 'package:wanderer_frontend/core/services/background_update_manager.dart';
import 'package:wanderer_frontend/presentation/helpers/trip_map_helper.dart';
import 'package:wanderer_frontend/presentation/helpers/ui_helpers.dart';
import 'package:wanderer_frontend/presentation/helpers/dialog_helper.dart';
import 'package:wanderer_frontend/presentation/helpers/background_location_disclosure.dart';
import 'package:wanderer_frontend/presentation/helpers/auth_navigation_helper.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wanderer_frontend/presentation/widgets/trip_detail/reaction_picker.dart';
import 'package:wanderer_frontend/presentation/widgets/trip_detail/trip_map_view.dart';
import 'package:wanderer_frontend/presentation/widgets/trip_detail/comments_section.dart';
import 'package:wanderer_frontend/presentation/widgets/trip_detail/trip_lifecycle_buttons.dart';
import 'package:wanderer_frontend/presentation/widgets/common/wanderer_app_bar.dart';
import 'package:wanderer_frontend/presentation/widgets/common/app_sidebar.dart';
import 'package:wanderer_frontend/presentation/strategies/trip_detail_layout_strategy.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'auth_screen.dart';
import 'home_screen.dart';
import 'settings_screen.dart';

/// Trip detail screen showing trip info, map, and comments
class TripDetailScreen extends StatefulWidget {
  final Trip trip;

  const TripDetailScreen({super.key, required this.trip});

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  late final TripDetailRepository _repository;
  final UserService _userService = UserService();
  final PromotionQueryClient _promotionQueryClient = PromotionQueryClient();
  final AchievementService _achievementService = AchievementService();
  final WebSocketService _webSocketService = WebSocketService();
  GoogleMapController? _mapController;
  final Completer<GoogleMapController> _mapControllerCompleter = Completer();
  StreamSubscription<WebSocketEvent>? _wsSubscription;
  late Trip _trip;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  List<Comment> _comments = [];
  final Map<String, List<Comment>> _replies = {};
  final Map<String, bool> _expandedComments = {};

  int _currentCommentPage = 0;
  bool _hasMoreComments = false;
  bool _isLoadingMoreComments = false;
  static const int _commentPageSize = 20;

  List<TripLocation> _tripUpdates = [];
  bool _isLoadingUpdates = false;
  int _currentUpdatesPage = 0;
  bool _hasMoreUpdates = false;
  bool _isLoadingMoreUpdates = false;
  static const int _updatesPageSize = 50;

  bool _isLoadingComments = false;
  bool _isAddingComment = false;
  bool _isLoggedIn = false;
  bool _isAdmin = false;
  bool _isChangingStatus = false;
  bool _isChangingSettings = false;
  String? _replyingToCommentId;
  CommentSortOption _sortOption = CommentSortOption.latest;
  final int _selectedSidebarIndex = -1; // Trip detail is not a main nav item
  String? _username;
  String? _userId;
  String? _displayName;
  String? _avatarUrl;

  // Track social interactions
  bool _isFollowingTripOwner = false;
  bool _hasSentFriendRequest = false;
  bool _isAlreadyFriends = false;
  String? _sentFriendRequestId; // Store the request ID for cancellation

  // Promotion state
  bool _isPromoted = false;
  String? _donationLink;

  // Trip achievements
  List<UserAchievement> _tripAchievements = [];

  // Collapsible panel states
  bool _isTimelineCollapsed = false;
  bool _isCommentsCollapsed = false;
  bool _isTripInfoCollapsed = false;
  bool _isTripUpdateCollapsed = true;
  bool _isTripSettingsCollapsed = true;
  bool _isSendingUpdate = false;
  bool _hasInitializedPanelStates = false;
  bool _hasInitialMapPosition = false;
  bool _isMapLoading = true;

  // Planned waypoints overlay toggle (for trips created from a plan)
  bool _showPlannedWaypoints = false;

  // Multi-day trip: current day derived from backend's currentDay field
  int get _currentDay => _trip.currentDay ?? 1;

  // Desktop web: track whether the mouse is hovering over a panel
  // so we can disable map gestures only when hovering.
  bool _isHoveringOverPanel = false;

  // Custom info window: currently selected map marker location
  TripLocation? _selectedMapLocation;

  // User's current device location (used as fallback for empty maps)
  LatLng? _userLocation;

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

    // Initialize repository
    _repository = TripDetailRepository();

    _trip = widget.trip;
    // Default to showing the planned route when the trip has one
    _showPlannedWaypoints = _trip.hasPlannedRoute;
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
        setState(() {
          _userLocation = LatLng(position.latitude, position.longitude);
        });
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
    // Now both the data and the map are ready — jump to latest location
    // (map data was already updated by _refreshTripData)
    if (mounted) {
      _animateMapToLatestLocation(animate: false);
      setState(() {
        _isMapLoading = false;
      });
    }
    _hasInitialMapPosition = true;
  }

  Future<void> _initWebSocket() async {
    debugPrint('TripDetailScreen: Initializing WebSocket for trip ${_trip.id}');
    // Connect to WebSocket server first
    await _webSocketService.connect();
    // Subscribe to events for this specific trip
    final tripStream = _webSocketService.subscribeToTrip(_trip.id);
    _wsSubscription = tripStream.listen(_handleWebSocketEvent);
    debugPrint(
        'TripDetailScreen: WebSocket initialized and listening for trip ${_trip.id}');
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
    setState(() {
      _trip = _trip.copyWith(
        status: event.newStatus,
        // Use currentDay from the event if available; when a multi-day trip
        // is first started and the backend hasn't set currentDay yet, default
        // to 1 so the "Day 1" badge shows right away.
        currentDay: event.currentDay ??
            ((event.newStatus == TripStatus.inProgress &&
                    event.previousStatus == TripStatus.created &&
                    _trip.tripModality == TripModality.multiDay &&
                    _trip.currentDay == null)
                ? 1
                : null),
      );
    });

    // Reload timeline to pick up any lifecycle markers
    // (TRIP_STARTED, TRIP_ENDED, DAY_START, DAY_END)
    _loadTripUpdates();

    // Reload full trip data to pick up updated currentDay / tripDays
    // after toggle-day transitions
    if (_trip.tripModality == TripModality.multiDay) {
      _refreshTripData();
    }
  }

  /// Refreshes full trip data from the backend
  Future<void> _refreshTripData() async {
    try {
      final updatedTrip = await _repository.getTripById(_trip.id);
      if (mounted) {
        setState(() {
          // Preserve automaticUpdates / updateRefresh when the backend query
          // model hasn't propagated them yet (CQRS eventual consistency).
          // If the backend returns false/null but we already know the user
          // enabled automatic updates, keep the local value.
          _trip = updatedTrip.copyWith(
            automaticUpdates:
                updatedTrip.automaticUpdates || _trip.automaticUpdates,
            updateRefresh: updatedTrip.updateRefresh ?? _trip.updateRefresh,
          );
        });
        _updateMapData();
        // Only animate the camera on subsequent refreshes (e.g. after a
        // WebSocket status change). The very first positioning is handled by
        // _initializeMapPosition with an instant jump.
        if (_hasInitialMapPosition) {
          _animateMapToLatestLocation(animate: true);
        }
      }
    } catch (e) {
      debugPrint('TripDetailScreen: Error refreshing trip data: $e');
    }
  }

  void _handleTripUpdatedEvent(TripUpdatedEvent event) {
    // Parse the update type from the event
    final parsedUpdateType = event.updateType != null
        ? TripUpdateType.fromJson(event.updateType!)
        : TripUpdateType.regular;

    // Lifecycle markers (DAY_START, DAY_END, TRIP_STARTED, TRIP_ENDED) may
    // have location: null. Add them to the timeline but don't create map pins.
    final hasLocation = event.latitude != null && event.longitude != null;

    final newUpdate = TripLocation(
      id: 'ws_${event.timestamp.millisecondsSinceEpoch}',
      latitude: event.latitude ?? 0.0,
      longitude: event.longitude ?? 0.0,
      timestamp: event.timestamp,
      battery: hasLocation ? event.batteryLevel : null,
      message: event.message,
      city: hasLocation ? event.city : null,
      country: hasLocation ? event.country : null,
      temperatureCelsius: hasLocation ? event.temperatureCelsius : null,
      weatherCondition: hasLocation && event.weatherCondition != null
          ? WeatherCondition.fromJson(event.weatherCondition!)
          : null,
      updateType: parsedUpdateType,
    );

    setState(() {
      _tripUpdates = [newUpdate, ..._tripUpdates];
    });

    // Only update the map for updates with real locations
    if (hasLocation) {
      // Add the new location to _trip.locations so the map helper
      // rebuilds markers correctly (previous green → orange, new → green)
      final updatedLocations = <TripLocation>[
        ...(_trip.locations ?? []),
        newUpdate,
      ];
      setState(() {
        _trip = _trip.copyWith(locations: updatedLocations);
      });
      _updateMapData();
      // Animate the camera to the new location
      _animateMapToLocation(LatLng(event.latitude!, event.longitude!));
    }
  }

  void _handlePolylineUpdatedEvent(PolylineUpdatedEvent event) {
    // Validate that we have the required data
    if (event.tripId == null || event.tripId!.isEmpty) {
      debugPrint('PolylineUpdatedEvent: Missing tripId, ignoring event');
      return;
    }

    if (event.encodedPolyline.isEmpty) {
      debugPrint(
          'PolylineUpdatedEvent: Empty encodedPolyline for trip ${event.tripId}, ignoring event');
      return;
    }

    // Only update if this event is for the current trip
    if (event.tripId != _trip.id) {
      return;
    }

    // Update the trip's encoded polyline and refresh the map
    setState(() {
      _trip = _trip.copyWith(encodedPolyline: event.encodedPolyline);
    });

    // Redraw the polyline on the map
    _updateMapData();

    // Animate to the latest location on the polyline (only after the initial
    // camera position has been set — during startup, _initializeMapPosition
    // handles the first jump).
    if (_hasInitialMapPosition) {
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
        setState(() {
          _userLocation = target;
        });
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
    setState(() {
      _trip = _trip.copyWith(
        automaticUpdates: event.automaticUpdates ?? _trip.automaticUpdates,
        updateRefresh: event.updateRefresh ?? _trip.updateRefresh,
      );
    });
  }

  void _handleCommentAdded(CommentAddedEvent event) {
    // Create a new comment from the event
    final newComment = Comment(
      id: event.commentId,
      tripId: _trip.id,
      userId: event.userId,
      username: event.username,
      message: event.message,
      parentCommentId: event.parentCommentId,
      individualReactions: const [],
      createdAt: event.timestamp,
      updatedAt: event.timestamp,
    );

    setState(() {
      if (event.parentCommentId != null) {
        // It's a reply
        final parentId = event.parentCommentId!;
        bool isNewReply = false;

        if (_replies.containsKey(parentId)) {
          // Check if reply already exists (avoid duplicates from optimistic updates)
          final existingIndex =
              _replies[parentId]!.indexWhere((c) => c.id == event.commentId);
          if (existingIndex != -1) {
            // Replace optimistic reply with server version (has correct timestamp, etc.)
            _replies[parentId]![existingIndex] = newComment;
          } else {
            // New reply from another user or WebSocket arrived before optimistic update
            _replies[parentId] = [..._replies[parentId]!, newComment];
            isNewReply = true;
          }
        } else {
          // First reply to this comment
          _replies[parentId] = [newComment];
          isNewReply = true;
        }

        // Update the parent comment's responsesCount if this is a new reply
        // (not an optimistic update replacement)
        if (isNewReply) {
          final parentIndex = _comments.indexWhere((c) => c.id == parentId);
          if (parentIndex != -1) {
            final parentComment = _comments[parentIndex];
            _comments[parentIndex] = Comment(
              id: parentComment.id,
              tripId: parentComment.tripId,
              userId: parentComment.userId,
              username: parentComment.username,
              userAvatarUrl: parentComment.userAvatarUrl,
              message: parentComment.message,
              parentCommentId: parentComment.parentCommentId,
              reactions: parentComment.reactions,
              individualReactions: parentComment.individualReactions,
              replies: parentComment.replies,
              reactionsCount: parentComment.reactionsCount,
              responsesCount: parentComment.responsesCount + 1,
              createdAt: parentComment.createdAt,
              updatedAt: parentComment.updatedAt,
            );
          }
        }
      } else {
        // It's a top-level comment
        // Check if comment already exists (avoid duplicates from optimistic updates)
        final existingIndex =
            _comments.indexWhere((c) => c.id == event.commentId);
        if (existingIndex != -1) {
          // Replace optimistic comment with server version (has correct timestamp, etc.)
          _comments[existingIndex] = newComment;
          _sortComments();
        } else {
          // New comment from another user or WebSocket arrived before optimistic update
          _comments.insert(0, newComment);
          _sortComments();
        }
      }
    });
  }

  void _handleCommentReaction(CommentReactionEvent event) {
    debugPrint(
        'TripDetailScreen: Handling comment reaction event for comment ${event.commentId}');
    debugPrint(
        'TripDetailScreen: Event type=${event.type}, reactionType=${event.reactionType}, userId=${event.userId}, isRemoval=${event.isRemoval}');

    // Normalize reaction type strings to ensure consistent map keys
    // Backend might send "SMILEY" or "smiley", but we need consistency with ReactionType.toJson()
    final normalizedReactionType =
        ReactionType.fromJson(event.reactionType).toJson();
    final normalizedPreviousReactionType = event.previousReactionType != null
        ? ReactionType.fromJson(event.previousReactionType!).toJson()
        : null;

    // Update local state directly from WebSocket event instead of making a GET request
    setState(() {
      // Find and update the comment in top-level comments
      final commentIndex = _comments.indexWhere((c) => c.id == event.commentId);
      if (commentIndex != -1) {
        final comment = _comments[commentIndex];
        final updatedReactions = Map<String, int>.from(comment.reactions ?? {});
        final updatedIndividualReactions =
            List<Reaction>.from(comment.individualReactions ?? []);

        if (normalizedPreviousReactionType != null) {
          // REPLACED event: remove old reaction and add new reaction
          // Check if user already has the new reaction (duplicate event detection)
          final hasNewReaction = updatedIndividualReactions.any((r) =>
              r.userId == event.userId &&
              r.reactionType.toJson() == normalizedReactionType);
          if (hasNewReaction) {
            debugPrint(
                'TripDetailScreen: Ignoring duplicate REPLACED event for comment ${event.commentId}');
            return; // Skip duplicate event
          }

          // Remove user's old reaction from individualReactions
          updatedIndividualReactions
              .removeWhere((r) => r.userId == event.userId);
          // Decrement old reaction count
          final oldCount =
              updatedReactions[normalizedPreviousReactionType] ?? 0;
          if (oldCount > 1) {
            updatedReactions[normalizedPreviousReactionType] = oldCount - 1;
          } else {
            updatedReactions.remove(normalizedPreviousReactionType);
          }
          // Add new reaction to individualReactions
          updatedIndividualReactions.add(Reaction(
            userId: event.userId,
            username: '', // Will be populated from full data refresh if needed
            reactionType: ReactionType.fromJson(event.reactionType),
            timestamp: DateTime.now(),
          ));
          // Increment new reaction count
          updatedReactions[normalizedReactionType] =
              (updatedReactions[normalizedReactionType] ?? 0) + 1;
        } else if (event.isRemoval) {
          // REMOVED event: remove the individual reaction
          // Check if user actually has this reaction to remove (duplicate event detection)
          final hasReaction = updatedIndividualReactions.any((r) =>
              r.userId == event.userId &&
              r.reactionType.toJson() == normalizedReactionType);
          if (!hasReaction) {
            debugPrint(
                'TripDetailScreen: Ignoring duplicate REMOVED event for comment ${event.commentId}');
            return; // Skip duplicate event
          }

          updatedIndividualReactions.removeWhere((r) =>
              r.userId == event.userId &&
              r.reactionType.toJson() == normalizedReactionType);
          // Decrement reaction count
          final currentCount = updatedReactions[normalizedReactionType] ?? 0;
          if (currentCount > 1) {
            updatedReactions[normalizedReactionType] = currentCount - 1;
          } else {
            updatedReactions.remove(normalizedReactionType);
          }
        } else {
          // ADDED event: add the individual reaction
          // Check if user already has this reaction (duplicate event detection)
          final hasReaction = updatedIndividualReactions.any((r) =>
              r.userId == event.userId &&
              r.reactionType.toJson() == normalizedReactionType);
          if (hasReaction) {
            debugPrint(
                'TripDetailScreen: Ignoring duplicate ADDED event for comment ${event.commentId}');
            return; // Skip duplicate event
          }

          updatedIndividualReactions.add(Reaction(
            userId: event.userId,
            username: '', // Will be populated from full data refresh if needed
            reactionType: ReactionType.fromJson(event.reactionType),
            timestamp: DateTime.now(),
          ));
          // Increment reaction count
          updatedReactions[normalizedReactionType] =
              (updatedReactions[normalizedReactionType] ?? 0) + 1;
        }

        // Calculate new total reactions count
        final newReactionsCount =
            updatedReactions.values.fold(0, (sum, count) => sum + count);

        _comments[commentIndex] = Comment(
          id: comment.id,
          tripId: comment.tripId,
          userId: comment.userId,
          username: comment.username,
          userAvatarUrl: comment.userAvatarUrl,
          message: comment.message,
          parentCommentId: comment.parentCommentId,
          reactions: updatedReactions.isEmpty ? null : updatedReactions,
          individualReactions: updatedIndividualReactions.isEmpty
              ? null
              : updatedIndividualReactions,
          replies: comment.replies,
          reactionsCount: newReactionsCount,
          responsesCount: comment.responsesCount,
          createdAt: comment.createdAt,
          updatedAt: comment.updatedAt,
        );
        return;
      }

      // Check in replies
      for (final parentId in _replies.keys) {
        final replies = _replies[parentId]!;
        final replyIndex = replies.indexWhere((c) => c.id == event.commentId);
        if (replyIndex != -1) {
          final reply = replies[replyIndex];
          final updatedReactions = Map<String, int>.from(reply.reactions ?? {});
          final updatedIndividualReactions =
              List<Reaction>.from(reply.individualReactions ?? []);

          if (normalizedPreviousReactionType != null) {
            // REPLACED event: remove old reaction and add new reaction
            // Check if user already has the new reaction (duplicate event detection)
            final hasNewReaction = updatedIndividualReactions.any((r) =>
                r.userId == event.userId &&
                r.reactionType.toJson() == normalizedReactionType);
            if (hasNewReaction) {
              debugPrint(
                  'TripDetailScreen: Ignoring duplicate REPLACED event for reply ${event.commentId}');
              return; // Skip duplicate event
            }

            updatedIndividualReactions
                .removeWhere((r) => r.userId == event.userId);
            final oldCount =
                updatedReactions[normalizedPreviousReactionType] ?? 0;
            if (oldCount > 1) {
              updatedReactions[normalizedPreviousReactionType] = oldCount - 1;
            } else {
              updatedReactions.remove(normalizedPreviousReactionType);
            }
            updatedIndividualReactions.add(Reaction(
              userId: event.userId,
              username: '',
              reactionType: ReactionType.fromJson(event.reactionType),
              timestamp: DateTime.now(),
            ));
            updatedReactions[normalizedReactionType] =
                (updatedReactions[normalizedReactionType] ?? 0) + 1;
          } else if (event.isRemoval) {
            // REMOVED event
            // Check if user actually has this reaction to remove (duplicate event detection)
            final hasReaction = updatedIndividualReactions.any((r) =>
                r.userId == event.userId &&
                r.reactionType.toJson() == normalizedReactionType);
            if (!hasReaction) {
              debugPrint(
                  'TripDetailScreen: Ignoring duplicate REMOVED event for reply ${event.commentId}');
              return; // Skip duplicate event
            }

            updatedIndividualReactions.removeWhere((r) =>
                r.userId == event.userId &&
                r.reactionType.toJson() == normalizedReactionType);
            final currentCount = updatedReactions[normalizedReactionType] ?? 0;
            if (currentCount > 1) {
              updatedReactions[normalizedReactionType] = currentCount - 1;
            } else {
              updatedReactions.remove(normalizedReactionType);
            }
          } else {
            // ADDED event
            // Check if user already has this reaction (duplicate event detection)
            final hasReaction = updatedIndividualReactions.any((r) =>
                r.userId == event.userId &&
                r.reactionType.toJson() == normalizedReactionType);
            if (hasReaction) {
              debugPrint(
                  'TripDetailScreen: Ignoring duplicate ADDED event for reply ${event.commentId}');
              return; // Skip duplicate event
            }

            updatedIndividualReactions.add(Reaction(
              userId: event.userId,
              username: '',
              reactionType: ReactionType.fromJson(event.reactionType),
              timestamp: DateTime.now(),
            ));
            updatedReactions[normalizedReactionType] =
                (updatedReactions[normalizedReactionType] ?? 0) + 1;
          }

          final newReactionsCount =
              updatedReactions.values.fold(0, (sum, count) => sum + count);

          _replies[parentId]![replyIndex] = Comment(
            id: reply.id,
            tripId: reply.tripId,
            userId: reply.userId,
            username: reply.username,
            userAvatarUrl: reply.userAvatarUrl,
            message: reply.message,
            parentCommentId: reply.parentCommentId,
            reactions: updatedReactions.isEmpty ? null : updatedReactions,
            individualReactions: updatedIndividualReactions.isEmpty
                ? null
                : updatedIndividualReactions,
            replies: reply.replies,
            reactionsCount: newReactionsCount,
            responsesCount: reply.responsesCount,
            createdAt: reply.createdAt,
            updatedAt: reply.updatedAt,
          );
          return;
        }
      }
    });
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
        // On mobile, collapse all panels by default so map is visible
        // Use post-frame callback to ensure setState works properly
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _isTimelineCollapsed = true;
              _isCommentsCollapsed = true;
              _isTripInfoCollapsed = true;
            });
          }
        });
      }
    }
  }

  @override
  void dispose() {
    debugPrint('TripDetailScreen: Disposing for trip ${_trip.id}');
    _wsSubscription?.cancel();
    debugPrint('TripDetailScreen: Cancelled WebSocket subscription');
    _webSocketService.unsubscribeFromTrip(_trip.id);
    debugPrint('TripDetailScreen: Unsubscribed from trip');
    _commentController.dispose();
    _scrollController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadUserInfo() async {
    final username = await _repository.getCurrentUsername();
    final userId = await _repository.getCurrentUserId();
    final isAdmin = await _repository.isAdmin();

    if (userId != null) {
      await _repository.refreshUserDetails();
    }

    final displayName = await _repository.getCurrentDisplayName();
    final avatarUrl = await _repository.getCurrentAvatarUrl();

    setState(() {
      _username = username;
      _userId = userId;
      _displayName = displayName;
      _avatarUrl = avatarUrl;
      _isAdmin = isAdmin;
    });

    // If logged in and viewing another user's trip, check social status
    if (userId != null && _trip.userId != userId) {
      await _loadSocialStatus();
    }
  }

  /// Load the current user's social relationship with the trip owner
  Future<void> _loadSocialStatus() async {
    try {
      // Check if following the trip owner by looking at our following list
      final following = await _userService.getFollowing();
      final isFollowing = following.any((f) => f.followedId == _trip.userId);

      // Check if already sent a friend request to the trip owner
      final sentRequests = await _userService.getSentFriendRequests();
      final pendingRequest = sentRequests.cast<FriendRequest?>().firstWhere(
            (r) =>
                r!.receiverId == _trip.userId &&
                r.status == FriendRequestStatus.pending,
            orElse: () => null,
          );
      final hasSentRequest = pendingRequest != null;
      final requestId = pendingRequest?.id;

      // Check if already friends with the trip owner
      final friends = await _userService.getFriends();
      final isAlreadyFriends = friends.any((f) => f.friendId == _trip.userId);

      if (mounted) {
        setState(() {
          _isFollowingTripOwner = isFollowing;
          _hasSentFriendRequest = hasSentRequest;
          _sentFriendRequestId = requestId;
          _isAlreadyFriends = isAlreadyFriends;
        });
      }
    } catch (e) {
      // Silently fail - social features are optional
      debugPrint('Failed to load social status: $e');
    }
  }

  Future<void> _checkLoginStatus() async {
    final isLoggedIn = await _repository.isLoggedIn();
    setState(() {
      _isLoggedIn = isLoggedIn;
    });
  }

  Future<void> _loadTripUpdates() async {
    setState(() {
      _isLoadingUpdates = true;
      _currentUpdatesPage = 0;
    });

    try {
      final pageResponse = await _repository.loadTripUpdates(
        _trip.id,
        page: 0,
        size: _updatesPageSize,
      );
      setState(() {
        _tripUpdates = pageResponse.content;
        _hasMoreUpdates = !pageResponse.last;
        _isLoadingUpdates = false;
      });
    } catch (e) {
      setState(() => _isLoadingUpdates = false);
      if (mounted) {
        UiHelpers.showErrorMessage(context, 'Error loading updates: $e');
      }
    }
  }

  Future<void> _loadMoreTripUpdates() async {
    if (_isLoadingMoreUpdates || !_hasMoreUpdates) return;

    setState(() => _isLoadingMoreUpdates = true);

    try {
      final nextPage = _currentUpdatesPage + 1;
      final pageResponse = await _repository.loadTripUpdates(
        _trip.id,
        page: nextPage,
        size: _updatesPageSize,
      );
      setState(() {
        _tripUpdates = [..._tripUpdates, ...pageResponse.content];
        _currentUpdatesPage = nextPage;
        _hasMoreUpdates = !pageResponse.last;
        _isLoadingMoreUpdates = false;
      });

      // Update the map with the newly loaded older locations so
      // the polyline extends further back in time.
      final updatedLocations = <TripLocation>[
        ...(_trip.locations ?? []),
        ...pageResponse.content,
      ];
      // Deduplicate by ID
      final seen = <String>{};
      final deduped = updatedLocations.where((l) => seen.add(l.id)).toList();
      setState(() {
        _trip = _trip.copyWith(locations: deduped);
      });
      _updateMapData();
    } catch (e) {
      setState(() => _isLoadingMoreUpdates = false);
      if (mounted) {
        UiHelpers.showErrorMessage(context, 'Error loading more updates: $e');
      }
    }
  }

  Future<void> _loadPromotionInfo() async {
    try {
      final promotion = await _promotionQueryClient.getTripPromotion(_trip.id);
      if (mounted) {
        setState(() {
          _isPromoted = true;
          _donationLink = promotion.donationLink;
        });
      }
    } catch (e) {
      // Trip is not promoted — this is expected for most trips
      if (mounted) {
        setState(() {
          _isPromoted = false;
          _donationLink = null;
        });
      }
    }
  }

  Future<void> _loadTripAchievements() async {
    try {
      final achievements =
          await _achievementService.getTripAchievements(_trip.id);
      if (mounted) {
        setState(() {
          _tripAchievements = achievements;
        });
      }
    } catch (e) {
      // Silently fail — achievements are optional
    }
  }

  void _updateMapData() {
    try {
      final mapData = TripMapHelper.createMapDataWithDirections(
        _trip,
        onMarkerTap: _onMapMarkerTapped,
        showPlannedWaypoints: _showPlannedWaypoints,
      );
      setState(() {
        _markers = mapData.markers;
        _polylines = mapData.polylines;
      });
    } catch (e) {
      // Fallback to straight lines if decoding fails
      final mapData = TripMapHelper.createMapData(
        _trip,
        onMarkerTap: _onMapMarkerTapped,
        showPlannedWaypoints: _showPlannedWaypoints,
      );
      setState(() {
        _markers = mapData.markers;
        _polylines = mapData.polylines;
      });
    }
  }

  void _onMapMarkerTapped(TripLocation location) {
    setState(() {
      _selectedMapLocation = location;
    });
  }

  void _onInfoWindowClosed() {
    setState(() {
      _selectedMapLocation = null;
    });
  }

  Future<void> _loadComments() async {
    setState(() {
      _isLoadingComments = true;
      _currentCommentPage = 0;
    });

    try {
      final pageResponse = await _repository.loadComments(
        _trip.id,
        page: 0,
        size: _commentPageSize,
      );
      setState(() {
        _comments = pageResponse.content;
        _hasMoreComments = !pageResponse.last;
        _sortComments();
        _isLoadingComments = false;
      });
    } catch (e) {
      setState(() => _isLoadingComments = false);
      if (mounted) {
        UiHelpers.showErrorMessage(context, 'Error loading comments: $e');
      }
    }
  }

  Future<void> _loadMoreComments() async {
    if (_isLoadingMoreComments || !_hasMoreComments) return;

    setState(() => _isLoadingMoreComments = true);

    try {
      final nextPage = _currentCommentPage + 1;
      final pageResponse = await _repository.loadComments(
        _trip.id,
        page: nextPage,
        size: _commentPageSize,
      );
      setState(() {
        _comments = [..._comments, ...pageResponse.content];
        _currentCommentPage = nextPage;
        _hasMoreComments = !pageResponse.last;
        _isLoadingMoreComments = false;
      });
    } catch (e) {
      setState(() => _isLoadingMoreComments = false);
      if (mounted) {
        UiHelpers.showErrorMessage(context, 'Error loading more comments: $e');
      }
    }
  }

  void _sortComments() {
    switch (_sortOption) {
      case CommentSortOption.latest:
        _comments.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case CommentSortOption.oldest:
        _comments.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case CommentSortOption.mostReplies:
        _comments.sort((a, b) => b.responsesCount.compareTo(a.responsesCount));
        break;
      case CommentSortOption.mostReactions:
        _comments.sort((a, b) => b.reactionsCount.compareTo(a.reactionsCount));
        break;
    }
  }

  void _changeSortOption(CommentSortOption option) {
    setState(() {
      _sortOption = option;
      _sortComments();
    });
  }

  Future<void> _loadReplies(String commentId) async {
    try {
      final replies = await _repository.loadReplies(commentId);
      setState(() {
        _replies[commentId] = replies;
        _expandedComments[commentId] = true;
      });
    } catch (e) {
      if (mounted) {
        UiHelpers.showErrorMessage(context, 'Error loading replies: $e');
      }
    }
  }

  Future<void> _addComment() async {
    final message = _commentController.text.trim();
    if (message.isEmpty) return;

    setState(() => _isAddingComment = true);

    try {
      String commentId;
      if (_replyingToCommentId != null) {
        // Add reply via API
        commentId = await _repository.addReply(
          _trip.id,
          _replyingToCommentId!,
          message,
        );

        // Optimistically add the reply to the UI immediately
        final optimisticReply = Comment(
          id: commentId,
          tripId: _trip.id,
          userId: _userId ?? '',
          username: _username ?? 'You',
          userAvatarUrl: _avatarUrl,
          message: message,
          parentCommentId: _replyingToCommentId,
          individualReactions: const [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        setState(() {
          final parentId = _replyingToCommentId!;
          if (!_replies.containsKey(parentId)) {
            _replies[parentId] = [];
          }
          // Check if comment already exists (shouldn't happen, but be safe)
          if (!_replies[parentId]!.any((c) => c.id == commentId)) {
            _replies[parentId] = [..._replies[parentId]!, optimisticReply];

            // Update the parent comment's responsesCount only when actually adding a new reply
            final parentIndex = _comments.indexWhere((c) => c.id == parentId);
            if (parentIndex != -1) {
              final parentComment = _comments[parentIndex];
              _comments[parentIndex] = Comment(
                id: parentComment.id,
                tripId: parentComment.tripId,
                userId: parentComment.userId,
                username: parentComment.username,
                userAvatarUrl: parentComment.userAvatarUrl,
                message: parentComment.message,
                parentCommentId: parentComment.parentCommentId,
                reactions: parentComment.reactions,
                individualReactions: parentComment.individualReactions,
                replies: parentComment.replies,
                reactionsCount: parentComment.reactionsCount,
                responsesCount: parentComment.responsesCount + 1,
                createdAt: parentComment.createdAt,
                updatedAt: parentComment.updatedAt,
              );
            }
          }

          // Ensure the replies section is expanded so the new reply is visible
          _expandedComments[parentId] = true;
          _commentController.clear();
          _replyingToCommentId = null;
        });
      } else {
        // Add top-level comment via API
        commentId = await _repository.addComment(_trip.id, message);

        // Optimistically add the comment to the UI immediately
        final optimisticComment = Comment(
          id: commentId,
          tripId: _trip.id,
          userId: _userId ?? '',
          username: _username ?? 'You',
          userAvatarUrl: _avatarUrl,
          message: message,
          parentCommentId: null,
          individualReactions: const [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        setState(() {
          // Check if comment already exists (shouldn't happen, but be safe)
          if (!_comments.any((c) => c.id == commentId)) {
            _comments.insert(0, optimisticComment);
            _sortComments();
          }
          _commentController.clear();
        });
      }

      if (mounted) {
        UiHelpers.showSuccessMessage(context, 'Comment added!');
      }
    } catch (e) {
      if (mounted) {
        UiHelpers.showErrorMessage(context, 'Error adding comment: $e');
      }
    } finally {
      setState(() => _isAddingComment = false);
    }
  }

  /// Get the current user's reaction on a comment (if any)
  ReactionType? _getUserReaction(String commentId) {
    // Check top-level comments
    final comment = _comments.firstWhere(
      (c) => c.id == commentId,
      orElse: () {
        // Check in replies
        for (final replies in _replies.values) {
          final found = replies.firstWhere(
            (r) => r.id == commentId,
            orElse: () => Comment(
              id: '',
              tripId: '',
              userId: '',
              username: '',
              message: '',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );
          if (found.id.isNotEmpty) return found;
        }
        return Comment(
          id: '',
          tripId: '',
          userId: '',
          username: '',
          message: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      },
    );

    if (comment.id.isEmpty || comment.individualReactions == null) {
      return null;
    }

    final userReaction = comment.individualReactions!.firstWhere(
      (r) => r.userId == _userId,
      orElse: () => Reaction(
        userId: '',
        username: '',
        reactionType: ReactionType.heart,
        timestamp: DateTime.now(),
      ),
    );

    return userReaction.userId.isNotEmpty ? userReaction.reactionType : null;
  }

  Future<void> _handleReactionClick(String commentId, ReactionType type) async {
    final currentReaction = _getUserReaction(commentId);

    // Determine the target reaction state for optimistic update
    // If clicking existing reaction → remove it (newReaction = null)
    // If clicking different reaction → replace it (newReaction = type)
    // If no current reaction → add it (newReaction = type)
    final newReaction = currentReaction == type ? null : type;

    // Optimistically update the UI first for immediate feedback
    _applyOptimisticReactionUpdate(commentId, currentReaction, newReaction);

    try {
      if (currentReaction == type) {
        // User clicked their existing reaction → remove it
        debugPrint(
            'Removing reaction: commentId=$commentId, type=${type.toJson()}');
        await _repository.removeReaction(commentId, type);
        if (mounted) {
          UiHelpers.showSuccessMessage(context, 'Reaction removed!');
        }
      } else if (currentReaction != null) {
        // User clicked a different reaction → backend will auto-replace
        debugPrint(
            'Replacing reaction: commentId=$commentId, from=${currentReaction.toJson()} to=${type.toJson()}');
        await _repository.addReaction(commentId, type);
        if (mounted) {
          UiHelpers.showSuccessMessage(context, 'Reaction changed!');
        }
      } else {
        // User has no reaction → add new one
        debugPrint(
            'Adding new reaction: commentId=$commentId, type=${type.toJson()}');
        await _repository.addReaction(commentId, type);
        if (mounted) {
          UiHelpers.showSuccessMessage(context, 'Reaction added!');
        }
      }
    } catch (e) {
      // Enhanced error logging for debugging backend issues
      debugPrint('Reaction error: $e');
      debugPrint(
          'Context: commentId=$commentId, targetType=${type.toJson()}, currentReaction=${currentReaction?.toJson()}');

      // Revert the optimistic update on error
      _revertOptimisticReactionUpdate(commentId, currentReaction, newReaction);

      // Handle 409 Conflict (shouldn't happen with proper UI logic, but be safe)
      final errorMessage = e.toString();
      if (errorMessage.contains('409') || errorMessage.contains('Conflict')) {
        if (mounted) {
          UiHelpers.showInfoMessage(
              context, 'You already have this reaction on the comment');
        }
      } else if (errorMessage.contains('500')) {
        // Backend error during reaction replacement
        if (mounted) {
          UiHelpers.showErrorMessage(context,
              'Server error while changing reaction. This may be a backend issue.');
        }
      } else {
        if (mounted) {
          UiHelpers.showErrorMessage(context, 'Error with reaction: $e');
        }
      }
    }
  }

  void _applyOptimisticReactionUpdate(
      String commentId, ReactionType? currentReaction, ReactionType? newType) {
    setState(() {
      _updateReactionInComments(commentId, currentReaction, newType,
          isOptimistic: true);
    });
  }

  void _revertOptimisticReactionUpdate(String commentId,
      ReactionType? previousReaction, ReactionType? attemptedType) {
    setState(() {
      // Revert by applying the reverse operation
      _updateReactionInComments(commentId, attemptedType, previousReaction,
          isOptimistic: true);
    });
  }

  void _updateReactionInComments(
      String commentId, ReactionType? oldReaction, ReactionType? newReaction,
      {bool isOptimistic = false}) {
    // Find and update the comment in top-level comments
    final commentIndex = _comments.indexWhere((c) => c.id == commentId);
    if (commentIndex != -1) {
      _updateCommentReaction(
          _comments, commentIndex, oldReaction, newReaction, isOptimistic);
      return;
    }

    // Check in replies
    for (final parentId in _replies.keys) {
      final replies = _replies[parentId]!;
      final replyIndex = replies.indexWhere((c) => c.id == commentId);
      if (replyIndex != -1) {
        _updateReplyReaction(
            parentId, replyIndex, oldReaction, newReaction, isOptimistic);
        return;
      }
    }
  }

  void _updateCommentReaction(List<Comment> comments, int commentIndex,
      ReactionType? oldReaction, ReactionType? newReaction, bool isOptimistic) {
    final comment = comments[commentIndex];
    final updatedReactions = Map<String, int>.from(comment.reactions ?? {});
    final updatedIndividualReactions =
        List<Reaction>.from(comment.individualReactions ?? []);

    // Remove old reaction if exists
    if (oldReaction != null) {
      updatedIndividualReactions.removeWhere((r) => r.userId == _userId);
      final oldCount = updatedReactions[oldReaction.toJson()] ?? 0;
      if (oldCount > 1) {
        updatedReactions[oldReaction.toJson()] = oldCount - 1;
      } else {
        updatedReactions.remove(oldReaction.toJson());
      }
    }

    // Add new reaction if specified
    if (newReaction != null) {
      updatedIndividualReactions.add(Reaction(
        userId: _userId ?? '',
        username: _username ?? '',
        reactionType: newReaction,
        timestamp: DateTime.now(),
      ));
      updatedReactions[newReaction.toJson()] =
          (updatedReactions[newReaction.toJson()] ?? 0) + 1;
    }

    final newReactionsCount =
        updatedReactions.values.fold(0, (sum, count) => sum + count);

    comments[commentIndex] = Comment(
      id: comment.id,
      tripId: comment.tripId,
      userId: comment.userId,
      username: comment.username,
      userAvatarUrl: comment.userAvatarUrl,
      message: comment.message,
      parentCommentId: comment.parentCommentId,
      reactions: updatedReactions.isEmpty ? null : updatedReactions,
      individualReactions: updatedIndividualReactions.isEmpty
          ? null
          : updatedIndividualReactions,
      replies: comment.replies,
      reactionsCount: newReactionsCount,
      responsesCount: comment.responsesCount,
      createdAt: comment.createdAt,
      updatedAt: comment.updatedAt,
    );
  }

  void _updateReplyReaction(String parentId, int replyIndex,
      ReactionType? oldReaction, ReactionType? newReaction, bool isOptimistic) {
    final reply = _replies[parentId]![replyIndex];
    final updatedReactions = Map<String, int>.from(reply.reactions ?? {});
    final updatedIndividualReactions =
        List<Reaction>.from(reply.individualReactions ?? []);

    // Remove old reaction if exists
    if (oldReaction != null) {
      updatedIndividualReactions.removeWhere((r) => r.userId == _userId);
      final oldCount = updatedReactions[oldReaction.toJson()] ?? 0;
      if (oldCount > 1) {
        updatedReactions[oldReaction.toJson()] = oldCount - 1;
      } else {
        updatedReactions.remove(oldReaction.toJson());
      }
    }

    // Add new reaction if specified
    if (newReaction != null) {
      updatedIndividualReactions.add(Reaction(
        userId: _userId ?? '',
        username: _username ?? '',
        reactionType: newReaction,
        timestamp: DateTime.now(),
      ));
      updatedReactions[newReaction.toJson()] =
          (updatedReactions[newReaction.toJson()] ?? 0) + 1;
    }

    final newReactionsCount =
        updatedReactions.values.fold(0, (sum, count) => sum + count);

    _replies[parentId]![replyIndex] = Comment(
      id: reply.id,
      tripId: reply.tripId,
      userId: reply.userId,
      username: reply.username,
      userAvatarUrl: reply.userAvatarUrl,
      message: reply.message,
      parentCommentId: reply.parentCommentId,
      reactions: updatedReactions.isEmpty ? null : updatedReactions,
      individualReactions: updatedIndividualReactions.isEmpty
          ? null
          : updatedIndividualReactions,
      replies: reply.replies,
      reactionsCount: newReactionsCount,
      responsesCount: reply.responsesCount,
      createdAt: reply.createdAt,
      updatedAt: reply.updatedAt,
    );
  }

  Future<void> _addReaction(String commentId, ReactionType type) async {
    // Delegate to the new handler
    await _handleReactionClick(commentId, type);
  }

  Future<void> _changeTripStatus(TripStatus newStatus) async {
    // Validate that user is the trip owner
    if (_userId == null || _trip.userId != _userId) {
      if (mounted) {
        UiHelpers.showErrorMessage(
            context, 'Only trip owner can change status');
      }
      return;
    }

    setState(() => _isChangingStatus = true);

    // Capture previous status before async gap — WebSocket may update _trip
    // before the optimistic setState below runs.
    final previousStatus = _trip.status;
    final isMultiDay = _trip.tripModality == TripModality.multiDay;

    try {
      // If starting/resuming with automatic updates, ensure background location
      // permission is granted (shows prominent disclosure on Android).
      if (newStatus == TripStatus.inProgress &&
          _trip.automaticUpdates &&
          _isAndroid) {
        final hasPermission =
            await _ensureLocationPermission(requireBackground: true);
        if (!hasPermission) {
          setState(() => _isChangingStatus = false);
          return;
        }
      }

      await _repository.changeTripStatus(_trip.id, newStatus);

      // Update local state optimistically - WebSocket will confirm the change
      setState(() {
        _trip = _trip.copyWith(
          status: newStatus,
          // When starting a multi-day trip, set currentDay to 1 immediately
          // so the "Day 1" badge shows right away in the trip info card.
          currentDay: (newStatus == TripStatus.inProgress &&
                  previousStatus == TripStatus.created &&
                  isMultiDay &&
                  _trip.currentDay == null)
              ? 1
              : null,
        );
        _isChangingStatus = false;
      });

      // Manage background updates based on new status (Android only)
      if (_isAndroid) {
        final backgroundManager = BackgroundUpdateManager();
        if (newStatus == TripStatus.inProgress && _trip.automaticUpdates) {
          // Start automatic updates when trip starts/resumes AND automatic updates is enabled
          await backgroundManager.startAutoUpdates(
            _trip.id,
            _trip.name,
            _trip.effectiveUpdateRefresh,
          );
        } else {
          // Stop automatic updates when trip is paused/finished or automatic updates is disabled
          await backgroundManager.stopAutoUpdates(_trip.id);
        }
      }

      // When starting a trip, center the map on the user's current location
      if (newStatus == TripStatus.inProgress) {
        await _centerMapOnCurrentLocation();
      }

      if (mounted) {
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
      setState(() => _isChangingStatus = false);
      if (mounted) {
        UiHelpers.showErrorMessage(context, 'Error changing status: $e');
      }
    }
  }

  Future<void> _changeTripVisibility(Visibility newVisibility) async {
    // Validate that user is the trip owner
    if (_userId == null || _trip.userId != _userId) {
      if (mounted) {
        UiHelpers.showErrorMessage(
            context, 'Only trip owner can change visibility');
      }
      return;
    }

    try {
      await _repository.changeTripVisibility(_trip.id, newVisibility);

      // Update local state optimistically - WebSocket will confirm the change
      setState(() {
        _trip = _trip.copyWith(visibility: newVisibility);
      });

      if (mounted) {
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
      await _repository.deleteTrip(_trip.id);
      if (mounted) {
        UiHelpers.showSuccessMessage(context, 'Trip deleted');
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
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

      setState(() => _isChangingStatus = true);

      try {
        await _repository.toggleDay(_trip.id);

        // Update local state optimistically — WebSocket will confirm
        setState(() {
          _trip = _trip.copyWith(status: TripStatus.resting);
          _isChangingStatus = false;
        });

        // Stop background updates while resting (Android only)
        if (_isAndroid) {
          final backgroundManager = BackgroundUpdateManager();
          await backgroundManager.stopAutoUpdates(_trip.id);
        }

        // Refresh timeline to show the day-end marker
        if (mounted) {
          UiHelpers.showSuccessMessage(context, 'Resting for the night');
          await _loadTripUpdates();
        }
        return true;
      } catch (e) {
        setState(() => _isChangingStatus = false);
        if (mounted) {
          UiHelpers.showErrorMessage(context, 'Error ending day: $e');
        }
        return false;
      }
    } else if (_trip.status == TripStatus.resting) {
      // --- Begin Day: no confirmation needed → toggle day ---
      setState(() => _isChangingStatus = true);

      try {
        await _repository.toggleDay(_trip.id);

        // Update local state optimistically — WebSocket will confirm
        setState(() {
          _trip = _trip.copyWith(
            status: TripStatus.inProgress,
            currentDay: _currentDay + 1,
          );
          _isChangingStatus = false;
        });

        // Resume background updates if enabled (Android only)
        if (_isAndroid && _trip.automaticUpdates) {
          final hasPermission =
              await _ensureLocationPermission(requireBackground: true);
          if (hasPermission) {
            final backgroundManager = BackgroundUpdateManager();
            await backgroundManager.startAutoUpdates(
              _trip.id,
              _trip.name,
              _trip.effectiveUpdateRefresh,
            );
          }
        }

        // Refresh timeline to show the day-start marker
        if (mounted) {
          UiHelpers.showSuccessMessage(context, 'Day $_currentDay started!');
          await _loadTripUpdates();
        }
        return true;
      } catch (e) {
        setState(() => _isChangingStatus = false);
        if (mounted) {
          UiHelpers.showErrorMessage(context, 'Error starting day: $e');
        }
        return false;
      }
    }
    return false;
  }

  Future<void> _handleSettingsChange(bool automaticUpdates, int? updateRefresh,
      TripModality? tripModality) async {
    // Only trip owner can change settings
    if (_userId == null || _trip.userId != _userId) {
      if (mounted) {
        UiHelpers.showErrorMessage(
            context, 'Only trip owner can change settings');
      }
      return;
    }

    setState(() => _isChangingSettings = true);

    try {
      // If enabling automatic updates on Android, ensure background location
      // permission is granted (shows prominent disclosure).
      if (automaticUpdates && _isAndroid) {
        final hasPermission =
            await _ensureLocationPermission(requireBackground: true);
        if (!hasPermission) {
          setState(() => _isChangingSettings = false);
          return;
        }
      }

      await _repository.changeTripSettings(
        _trip.id,
        automaticUpdates,
        updateRefresh,
        tripModality: tripModality,
      );

      // Update local state optimistically - WebSocket will confirm the change
      setState(() {
        _trip = _trip.copyWith(
          automaticUpdates: automaticUpdates,
          updateRefresh: updateRefresh,
          tripModality: tripModality ?? _trip.tripModality,
        );
        _isChangingSettings = false;
      });

      // Manage background updates based on new settings (Android only)
      if (_isAndroid && _trip.status == TripStatus.inProgress) {
        final backgroundManager = BackgroundUpdateManager();
        if (automaticUpdates && updateRefresh != null) {
          // Start/restart automatic updates with new interval
          await backgroundManager.startAutoUpdates(
              _trip.id, _trip.name, updateRefresh);
        } else {
          // Stop automatic updates when disabled
          await backgroundManager.stopAutoUpdates(_trip.id);
        }
      }

      if (mounted) {
        UiHelpers.showSuccessMessage(
            context, 'Trip settings updated successfully');
      }
    } catch (e) {
      setState(() => _isChangingSettings = false);
      if (mounted) {
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
    setState(() => _replyingToCommentId = commentId);
    FocusScope.of(context).requestFocus(FocusNode());
  }

  void _handleToggleReplies(String commentId, bool isExpanded) {
    if (isExpanded) {
      setState(() => _expandedComments[commentId] = false);
    } else {
      _loadReplies(commentId);
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
    setState(() => _isSendingUpdate = true);

    try {
      // Ensure location permissions are granted before calling the service.
      // The service intentionally does NOT request permissions (it's a UI concern).
      final permissionReady = await _ensureLocationPermission();
      if (!permissionReady) {
        return;
      }

      final result =
          await _repository.sendTripUpdate(_trip.id, message: message);

      if (mounted) {
        if (result.isSuccess) {
          UiHelpers.showSuccessMessage(context, 'Update sent successfully!');
          // Refresh timeline to show the new update
          await _loadTripUpdates();

          // Reschedule automatic updates after manual update (Android only)
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
      if (mounted) {
        setState(() => _isSendingUpdate = false);
      }
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
    if (update.isLifecycleMarker) return;
    _animateMapToLocation(LatLng(update.latitude, update.longitude));
  }

  Future<void> _logout() async {
    final confirm = await DialogHelper.showLogoutConfirmation(context);

    if (confirm) {
      await _repository.logout();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      }
    }
  }

  void _handleSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
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
      MaterialPageRoute(builder: (context) => const AuthScreen()),
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

    // Toggle between follow and unfollow
    if (_isFollowingTripOwner) {
      try {
        await _userService.unfollowUser(_trip.userId);
        setState(() {
          _isFollowingTripOwner = false;
        });
        if (mounted) {
          UiHelpers.showSuccessMessage(
              context, 'Unfollowed @${_trip.username}');
        }
      } catch (e) {
        if (mounted) {
          UiHelpers.showErrorMessage(context, 'Failed to unfollow user: $e');
        }
      }
    } else {
      try {
        await _userService.followUser(_trip.userId);
        setState(() {
          _isFollowingTripOwner = true;
        });
        if (mounted) {
          UiHelpers.showSuccessMessage(
              context, 'You are now following @${_trip.username}');
        }
      } catch (e) {
        if (mounted) {
          UiHelpers.showErrorMessage(context, 'Failed to follow user: $e');
        }
      }
    }
  }

  Future<void> _handleSendFriendRequestToTripOwner() async {
    if (!_isLoggedIn || _trip.userId == _userId) return;

    // If already friends, allow unfriending
    if (_isAlreadyFriends) {
      try {
        await _userService.removeFriend(_trip.userId);
        setState(() {
          _isAlreadyFriends = false;
        });
        if (mounted) {
          UiHelpers.showSuccessMessage(
              context, 'You are no longer friends with @${_trip.username}');
        }
      } catch (e) {
        if (mounted) {
          UiHelpers.showErrorMessage(context, 'Failed to remove friend: $e');
        }
      }
      return;
    }

    // Cancel existing friend request
    if (_hasSentFriendRequest && _sentFriendRequestId != null) {
      try {
        await _userService.deleteFriendRequest(_sentFriendRequestId!);
        setState(() {
          _hasSentFriendRequest = false;
          _sentFriendRequestId = null;
        });
        if (mounted) {
          UiHelpers.showSuccessMessage(context, 'Friend request cancelled');
        }
      } catch (e) {
        if (mounted) {
          UiHelpers.showErrorMessage(
              context, 'Failed to cancel friend request: $e');
        }
      }
      return;
    }

    // Send new friend request
    try {
      final requestId = await _userService.sendFriendRequest(_trip.userId);
      setState(() {
        _hasSentFriendRequest = true;
        _sentFriendRequestId = requestId;
      });
      if (mounted) {
        UiHelpers.showSuccessMessage(
            context, 'Friend request sent to @${_trip.username}');
      }
    } catch (e) {
      if (mounted) {
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
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
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
                        left: _isCommentsCollapsed ? 16.0 : leftPanelWidth + 8,
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
      return Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFFFFDD00), // Buy me a Coffee yellow
        child: InkWell(
          onTap: _launchDonationLink,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.network(
                  'https://cdn.buymeacoffee.com/buttons/bmc-new-btn-logo.svg',
                  height: 24,
                  width: 24,
                  errorBuilder: (context, error, stackTrace) =>
                      const Text('☕', style: TextStyle(fontSize: 20)),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Buy me a Coffee',
                  style: TextStyle(
                    color: Colors.black,
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
      onCancelReply: () => setState(() => _replyingToCommentId = null),
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
              setState(() {
                _showPlannedWaypoints = !_showPlannedWaypoints;
              });
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
