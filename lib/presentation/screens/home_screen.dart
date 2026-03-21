import 'dart:async';
import 'package:flutter/material.dart' hide Visibility;
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/l10n/locale_controller.dart';
import 'package:wanderer_frontend/core/constants/enums.dart'
    show TripModality, TripStatus, Visibility;
import 'package:wanderer_frontend/core/services/push_notification_manager.dart';
import 'package:wanderer_frontend/core/theme/theme_controller.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/data/client/api_client.dart';
import 'package:wanderer_frontend/data/models/responses/page_response.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/data/models/websocket/websocket_event.dart';
import 'package:wanderer_frontend/data/repositories/home_repository.dart';
import 'package:wanderer_frontend/data/services/trip_service.dart';
import 'package:wanderer_frontend/data/services/admin_service.dart';
import 'package:wanderer_frontend/data/services/websocket_service.dart';
import 'package:wanderer_frontend/presentation/helpers/dialog_helper.dart';
import 'package:wanderer_frontend/presentation/helpers/ui_helpers.dart';
import 'package:wanderer_frontend/presentation/helpers/page_transitions.dart';
import 'package:wanderer_frontend/presentation/helpers/auth_navigation_helper.dart';
import 'package:wanderer_frontend/presentation/widgets/common/wanderer_app_bar.dart';
import 'package:wanderer_frontend/presentation/widgets/common/wanderer_logo.dart';
import 'package:wanderer_frontend/presentation/widgets/common/app_sidebar.dart';
import 'package:wanderer_frontend/presentation/widgets/home/enhanced_trip_card.dart';
import 'package:wanderer_frontend/presentation/widgets/home/feed_section_header.dart';
import 'package:wanderer_frontend/presentation/widgets/home/relationship_badge.dart';
import 'package:wanderer_frontend/main.dart' show routeObserver;
import 'create_trip_screen.dart';
import 'settings_screen.dart';
import 'trip_detail_screen.dart';
import 'auth_screen.dart';

/// Redesigned Home screen with personalized feed, visibility badges, and prioritization
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin, RouteAware {
  final HomeRepository _repository = HomeRepository();
  final TripService _tripService = TripService();
  final AdminService _adminService = AdminService();
  final WebSocketService _webSocketService = WebSocketService();
  final PushNotificationManager _pushNotificationManager =
      PushNotificationManager();
  StreamSubscription<WebSocketEvent>? _wsSubscription;

  late TabController _tabController;

  List<Trip> _allTrips = [];
  List<Trip> _myTrips = [];
  List<Trip> _feedTrips = [];
  List<Trip> _discoverTrips = [];
  Set<String> _promotedTripIds = {};
  Map<String, PromotedTrip> _promotedTripsById = {};
  Set<String> _friendIds = {};
  Set<String> _followingIds = {};

  bool _isLoading = false;
  bool _isLoadingMoreTrips = false;
  bool _hasMoreTrips = false;
  int _currentTripsPage = 0;
  static const int _tripsPageSize = 20;
  String? _error;
  String? _userId;
  String? _username;
  String? _displayName;
  String? _avatarUrl;
  bool _isLoggedIn = false;
  bool _isAdmin = false;
  final int _selectedSidebarIndex = 0;

  // Filter states
  TripStatus? _statusFilter;
  Visibility? _visibilityFilter;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    _initializeData();
    _initWebSocket();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void didPopNext() {
    // Called when a route that was pushed on top of this one is popped.
    // Reload data in case the user logged in or out while on another screen.
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _loadUserInfo();
    await _loadTrips();
    await _loadPromotedTrips();
  }

  void _onTabChanged() {
    // Rebuild to update the filter chips visibility based on selected tab
    if (mounted) {
      setState(() {
        // Reset visibility filter when switching away from My Trips tab
        // since visibility filter only applies to My Trips
        if (_tabController.index != 2) {
          _visibilityFilter = null;
          // Reset status filter if current filter is not valid for Feed/Discover
          // (only inProgress, resting, and paused are shown in those tabs)
          if (_statusFilter != null &&
              _statusFilter != TripStatus.inProgress &&
              _statusFilter != TripStatus.resting &&
              _statusFilter != TripStatus.paused) {
            _statusFilter = null;
          }
        }
      });
    }
  }

  Future<void> _initWebSocket() async {
    await _webSocketService.connect();
    _wsSubscription = _webSocketService.events.listen(_handleWebSocketEvent);
  }

  void _handleWebSocketEvent(WebSocketEvent event) {
    if (!mounted) return;

    switch (event.type) {
      case WebSocketEventType.tripStatusChanged:
        _handleTripStatusChanged(event as TripStatusChangedEvent);
        break;
      case WebSocketEventType.commentAdded:
        _handleCommentAdded(event as CommentAddedEvent);
        break;
      case WebSocketEventType.tripUpdated:
      case WebSocketEventType.tripCreated:
      case WebSocketEventType.tripDeleted:
        _loadTrips();
        break;
      default:
        break;
    }
  }

  void _handleTripStatusChanged(TripStatusChangedEvent event) {
    final tripIndex = _allTrips.indexWhere((t) => t.id == event.tripId);
    if (tripIndex != -1) {
      final trip = _allTrips[tripIndex];
      final updatedTrip = trip.copyWith(
        status: event.newStatus,
        currentDay: event.currentDay ?? trip.currentDay,
      );

      setState(() {
        _allTrips[tripIndex] = updatedTrip;

        // Also update in _myTrips if present
        final myIndex = _myTrips.indexWhere((t) => t.id == event.tripId);
        if (myIndex != -1) {
          _myTrips[myIndex] = _myTrips[myIndex].copyWith(
            status: event.newStatus,
            currentDay: event.currentDay ?? _myTrips[myIndex].currentDay,
          );
        }

        _categorizeTrips();
      });

      // For multi-day trips, re-fetch full data to ensure currentDay is
      // up-to-date (in case the payload didn't include it)
      if (trip.tripModality == TripModality.multiDay &&
          event.currentDay == null) {
        _refreshTripById(event.tripId!);
      }
    }
  }

  /// Re-fetches a single trip by ID and updates it in the local lists.
  Future<void> _refreshTripById(String tripId) async {
    try {
      final updatedTrip = await _tripService.getTripById(tripId);
      if (!mounted) return;

      setState(() {
        final allIndex = _allTrips.indexWhere((t) => t.id == tripId);
        if (allIndex != -1) {
          _allTrips[allIndex] = updatedTrip;
        }
        final myIndex = _myTrips.indexWhere((t) => t.id == tripId);
        if (myIndex != -1) {
          _myTrips[myIndex] = updatedTrip;
        }
        _categorizeTrips();
      });
    } catch (e) {
      debugPrint('Failed to refresh trip $tripId: $e');
    }
  }

  void _handleCommentAdded(CommentAddedEvent event) {
    final tripId = event.tripId;
    if (tripId == null) return;

    setState(() {
      // Update in _allTrips (used by Feed and Discover tabs)
      final allIndex = _allTrips.indexWhere((t) => t.id == tripId);
      if (allIndex != -1) {
        _allTrips[allIndex] = _allTrips[allIndex].copyWith(
          commentsCount: _allTrips[allIndex].commentsCount + 1,
        );
      }

      // Update in _myTrips (used by My Trips tab)
      final myIndex = _myTrips.indexWhere((t) => t.id == tripId);
      if (myIndex != -1) {
        _myTrips[myIndex] = _myTrips[myIndex].copyWith(
          commentsCount: _myTrips[myIndex].commentsCount + 1,
        );
      }

      if (allIndex != -1 || myIndex != -1) {
        _categorizeTrips();
      }
    });
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _wsSubscription?.cancel();
    _webSocketService.unsubscribeFromAllTrips();
    _pushNotificationManager.stop();
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserInfo() async {
    final username = await _repository.getCurrentUsername();
    final userId = await _repository.getCurrentUserId();
    final isLoggedIn = await _repository.isLoggedIn();
    final isAdmin = await _repository.isAdmin();

    // Refresh displayName and avatarUrl from API (in case they changed)
    if (isLoggedIn) {
      await _repository.refreshUserDetails();
    }

    final displayName = await _repository.getCurrentDisplayName();
    final avatarUrl = await _repository.getCurrentAvatarUrl();

    // Start push notification listener when logged in with a valid userId
    if (isLoggedIn && userId != null) {
      _pushNotificationManager.start(userId);
    } else {
      _pushNotificationManager.stop();
    }

    setState(() {
      _username = username;
      _userId = userId;
      _displayName = displayName;
      _avatarUrl = avatarUrl;
      _isLoggedIn = isLoggedIn;
      _isAdmin = isAdmin;
    });
  }

  Future<void> _loadTrips() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _currentTripsPage = 0;
    });

    try {
      if (_isLoggedIn) {
        // Load user-specific data AND public trips so the Discover tab
        // includes all public trips, not just those from the user's network.
        final results = await Future.wait([
          _repository.loadTrips(
              page: 0,
              size: _tripsPageSize), // Available trips (relationship-based)
          _repository.getMyTrips(), // User's own trips
          _repository.getFriendsIds(),
          _repository.getFollowingIds(),
          _repository.getPublicTrips(
              page: 0, size: _tripsPageSize), // All public trips for Discover
        ]);

        final availablePage = results[0] as PageResponse<Trip>;
        final publicPage = results[4] as PageResponse<Trip>;

        // Merge available trips with public trips (deduplicate by ID).
        // Available trips take priority since they may contain richer data
        // (e.g. protected trips from friends).
        final merged = <String, Trip>{};
        for (final t in availablePage.content) {
          merged[t.id] = t;
        }
        for (final t in publicPage.content) {
          merged.putIfAbsent(t.id, () => t);
        }

        setState(() {
          _allTrips = merged.values.toList();
          _hasMoreTrips = !availablePage.last || !publicPage.last;
          _myTrips = results[1] as List<Trip>;
          _friendIds = results[2] as Set<String>;
          _followingIds = results[3] as Set<String>;
          _categorizeTrips();
          _isLoading = false;
        });
      } else {
        // Not logged in, only show public trips
        final tripsPage =
            await _repository.getPublicTrips(page: 0, size: _tripsPageSize);
        final trips = tripsPage.content;

        // Merge with previously known active trips that the backend may not
        // return (e.g. RESTING trips are active but the /trips/public endpoint
        // might exclude them).  We keep any trip from the old list whose
        // status is still "active" (in_progress, resting, paused) and public,
        // as long as it is not already present in the fresh response.
        final freshIds = trips.map((t) => t.id).toSet();
        final preservedTrips = _allTrips.where((t) {
          if (freshIds.contains(t.id)) return false;
          final isActive = t.status == TripStatus.inProgress ||
              t.status == TripStatus.resting ||
              t.status == TripStatus.paused;
          final isPublic = t.visibility == Visibility.public;
          return isActive && isPublic;
        }).toList();

        setState(() {
          _allTrips = [...trips, ...preservedTrips];
          _hasMoreTrips = !tripsPage.last;
          _myTrips = [];
          _friendIds = {};
          _followingIds = {};
          _categorizeTrips();
          _isLoading = false;
        });
      }

      // Subscribe to WebSocket updates
      _webSocketService.unsubscribeFromAllTrips();
      _webSocketService.subscribeToTrips(_allTrips.map((t) => t.id).toList());
    } on AuthenticationRedirectException {
      // Token expired or user not authenticated - treat as guest
      if (mounted) {
        setState(() {
          _isLoggedIn = false;
          _isLoading = false;
        });
        _loadTrips(); // Reload as guest
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreTrips() async {
    if (_isLoadingMoreTrips || !_hasMoreTrips) return;

    setState(() => _isLoadingMoreTrips = true);

    try {
      final nextPage = _currentTripsPage + 1;

      if (_isLoggedIn) {
        // Fetch both available and public trips to keep Discover populated
        final results = await Future.wait([
          _repository.loadTrips(page: nextPage, size: _tripsPageSize),
          _repository.getPublicTrips(page: nextPage, size: _tripsPageSize),
        ]);

        final availablePage = results[0];
        final publicPage = results[1];

        // Merge new pages (deduplicate against existing + each other)
        final existingIds = _allTrips.map((t) => t.id).toSet();
        final newTrips = <String, Trip>{};
        for (final t in availablePage.content) {
          if (!existingIds.contains(t.id)) newTrips[t.id] = t;
        }
        for (final t in publicPage.content) {
          if (!existingIds.contains(t.id)) {
            newTrips.putIfAbsent(t.id, () => t);
          }
        }

        setState(() {
          _allTrips = [..._allTrips, ...newTrips.values];
          _currentTripsPage = nextPage;
          _hasMoreTrips = !availablePage.last || !publicPage.last;
          _isLoadingMoreTrips = false;
          _categorizeTrips();
        });

        _webSocketService
            .subscribeToTrips(newTrips.values.map((t) => t.id).toList());
      } else {
        final tripsPage = await _repository.loadTrips(
          page: nextPage,
          size: _tripsPageSize,
        );

        setState(() {
          _allTrips = [..._allTrips, ...tripsPage.content];
          _currentTripsPage = nextPage;
          _hasMoreTrips = !tripsPage.last;
          _isLoadingMoreTrips = false;
          _categorizeTrips();
        });

        _webSocketService
            .subscribeToTrips(tripsPage.content.map((t) => t.id).toList());
      }
    } catch (e) {
      setState(() => _isLoadingMoreTrips = false);
      if (mounted) {
        UiHelpers.showErrorMessage(context, 'Error loading more trips: $e');
      }
    }
  }

  Future<void> _loadPromotedTrips() async {
    try {
      final promoted = await _adminService.getPromotedTrips();
      if (mounted) {
        setState(() {
          _promotedTripIds = promoted.map((p) => p.tripId).toSet();
          _promotedTripsById = {for (final p in promoted) p.tripId: p};
        });

        // Fetch any promoted trips that are missing from _allTrips.
        // For example, pre-announced trips (status: created) or promoted
        // trips that weren't returned by the available/public endpoints.
        await _fetchMissingPromotedTrips(promoted);

        // Re-categorize since promoted data affects which trips appear in
        // the discover list (promoted completed / pre-announced trips).
        _categorizeTrips();
      }
    } catch (e) {
      // Silently fail — user may not have admin access
      debugPrint('Failed to load promoted trips: $e');
    }
  }

  /// Fetches promoted trips that are not yet in [_allTrips] (e.g. pre-announced
  /// trips with status `created` which the public/available endpoints exclude).
  Future<void> _fetchMissingPromotedTrips(List<PromotedTrip> promoted) async {
    final existingIds = _allTrips.map((t) => t.id).toSet();
    final missingPromoted =
        promoted.where((p) => !existingIds.contains(p.tripId)).toList();

    if (missingPromoted.isEmpty) return;

    final fetched = <Trip>[];
    for (final p in missingPromoted) {
      try {
        // Use authenticated endpoint for logged-in users, public for guests
        final trip = _isLoggedIn
            ? await _tripService.getTripById(p.tripId)
            : await _tripService.getPublicTripById(p.tripId);
        fetched.add(trip);
      } catch (e) {
        debugPrint('Could not fetch promoted trip ${p.tripId}: $e');
      }
    }

    if (fetched.isNotEmpty && mounted) {
      setState(() {
        _allTrips = [..._allTrips, ...fetched];
      });
    }
  }

  void _categorizeTrips() {
    // Build the discover list with the same criteria for both guest and
    // logged-in users so "Explore Public Trips" and the Discover tab show
    // identical content.
    //
    // Criteria for a trip to appear in Discover / Explore Public Trips:
    //   1. Public AND active (in_progress, resting, paused)  → Discover section
    //   2. Promoted AND active                               → Featured section
    //   3. Promoted AND completed (finished)                  → Featured section
    //   4. Promoted AND created + pre-announced               → Featured (pre-announced)
    //
    // Anything else (draft non-promoted, completed non-promoted, private, etc.)
    // is excluded.

    final discoverTrips = <Trip>[];

    for (final trip in _allTrips) {
      final isPublic = trip.visibility == Visibility.public;
      final isActive = trip.status == TripStatus.inProgress ||
          trip.status == TripStatus.resting ||
          trip.status == TripStatus.paused;
      final isPromoted = _promotedTripIds.contains(trip.id);

      // Rule 1 & 2: Public + active trips (promoted or not)
      if (isPublic && isActive) {
        discoverTrips.add(trip);
        continue;
      }

      // Rule 3: Promoted + completed
      if (isPromoted && trip.status == TripStatus.finished) {
        discoverTrips.add(trip);
        continue;
      }

      // Rule 4: Promoted + created + pre-announced
      if (isPromoted && trip.status == TripStatus.created) {
        final promotedTrip = _promotedTripsById[trip.id];
        if (promotedTrip != null && promotedTrip.isPreAnnounced) {
          discoverTrips.add(trip);
          continue;
        }
      }
    }

    // Sort discover by date
    discoverTrips.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (!_isLoggedIn) {
      setState(() {
        _discoverTrips = discoverTrips;
        _feedTrips = [];
      });
      _applyFilters();
      return;
    }

    // Categorize trips for feed (logged-in only)
    final feedTrips = <Trip>[];

    for (final trip in _allTrips) {
      final isActive = trip.status == TripStatus.inProgress ||
          trip.status == TripStatus.resting ||
          trip.status == TripStatus.paused;
      if (!isActive) continue;

      final isOwnTrip = trip.userId == _userId;
      final isPublic = trip.visibility == Visibility.public;

      // Skip user's own trips from feed
      if (!isOwnTrip) {
        final isFriend = _friendIds.contains(trip.userId);
        final isFollowing = _followingIds.contains(trip.userId);

        // Add to feed if from friend or following
        if (isFriend || isFollowing) {
          // Friends can see PUBLIC and PROTECTED
          if (isFriend &&
              (isPublic || trip.visibility == Visibility.protected)) {
            feedTrips.add(trip);
          }
          // Following can only see PUBLIC
          else if (isFollowing && !isFriend && isPublic) {
            feedTrips.add(trip);
          }
        }
      }
    }

    // Sort feed by priority
    feedTrips.sort(_compareTripsByPriority);

    setState(() {
      _feedTrips = feedTrips;
      _discoverTrips = discoverTrips;
    });

    _applyFilters();
  }

  /// Compare trips by priority for feed sorting
  int _compareTripsByPriority(Trip a, Trip b) {
    // Priority 1: Live and resting trips (IN_PROGRESS, RESTING)
    final aIsLive =
        a.status == TripStatus.inProgress || a.status == TripStatus.resting;
    final bIsLive =
        b.status == TripStatus.inProgress || b.status == TripStatus.resting;
    if (aIsLive != bIsLive) return aIsLive ? -1 : 1;

    // Priority 2: Friends over following
    final aIsFriend = _friendIds.contains(a.userId);
    final bIsFriend = _friendIds.contains(b.userId);
    if (aIsFriend != bIsFriend) return aIsFriend ? -1 : 1;

    // Priority 3: Most recent
    return b.createdAt.compareTo(a.createdAt);
  }

  void _applyFilters() {
    setState(() {
      // Filters are applied during rendering in _buildTripList
    });
  }

  List<Trip> _getFilteredTrips(List<Trip> trips) {
    return trips.where((trip) {
      // Apply status filter
      if (_statusFilter != null && trip.status != _statusFilter) {
        return false;
      }

      // Apply visibility filter
      if (_visibilityFilter != null && trip.visibility != _visibilityFilter) {
        return false;
      }

      return true;
    }).toList();
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

  void _handleProfile() {
    AuthNavigationHelper.navigateToOwnProfile(context);
  }

  void _handleSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
  }

  Future<void> _navigateToAuth() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AuthScreen()),
    );

    if (result == true && mounted) {
      await _loadUserInfo();
      await _loadTrips();
    }
  }

  Future<void> _navigateToCreateTrip() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreateTripScreen()),
    );

    if (mounted) {
      await _loadTrips();
    }
  }

  void _navigateToTripDetail(Trip trip) async {
    await Navigator.push(
      context,
      PageTransitions.slideUp(TripDetailScreen(trip: trip)),
    );

    if (mounted) {
      await _loadTrips();
    }
  }

  Future<void> _handleDeleteTrip(Trip trip) async {
    final l10n = context.l10n;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteTrip),
        content: Text(
          'Are you sure you want to delete "${trip.name}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      await _tripService.deleteTrip(trip.id);
      if (mounted) {
        UiHelpers.showSuccessMessage(context, 'Trip deleted');
        await _loadTrips();
      }
    } catch (e) {
      if (mounted) {
        UiHelpers.showErrorMessage(context, 'Error deleting trip: $e');
      }
    }
  }

  Widget _buildFilterChipButton<T>({
    required T? value,
    required String label,
    required IconData icon,
    required Color iconColor,
    required List<PopupMenuEntry<T>> items,
    required ValueChanged<T?> onSelected,
    bool isActive = false,
  }) {
    final theme = Theme.of(context);
    final chipColor = isActive
        ? theme.colorScheme.secondaryContainer
        : theme.colorScheme.surfaceContainerLow;
    final contentColor = isActive
        ? theme.colorScheme.onSecondaryContainer
        : theme.colorScheme.onSurfaceVariant;

    return PopupMenuButton<T>(
      onSelected: onSelected,
      itemBuilder: (_) => items,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      elevation: 2,
      child: Material(
        color: chipColor,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 32,
            padding: const EdgeInsets.only(left: 8, right: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: iconColor),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: contentColor,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.arrow_drop_down, size: 18, color: contentColor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Compact row showing EN/ES language toggle and dark/light mode toggle.
  /// Shown at the top of the home screen content area for quick access.
  Widget _buildQuickControls(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Language toggle (EN | ES)
          ValueListenableBuilder<Locale>(
            valueListenable: LocaleController().locale,
            builder: (context, locale, _) {
              final controller = LocaleController();
              final isSpanish = controller.isSpanish;
              return Container(
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withOpacity(0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _quickLangLabel('EN', !isSpanish),
                    Transform.scale(
                      scale: 0.75,
                      child: Switch(
                        value: isSpanish,
                        onChanged: (value) => controller.setLocale(
                          value ? const Locale('es') : const Locale('en'),
                        ),
                        activeColor: WandererTheme.primaryOrange,
                        inactiveThumbColor: WandererTheme.primaryOrange,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    _quickLangLabel('ES', isSpanish),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          // Dark / light mode toggle
          ValueListenableBuilder<ThemeMode>(
            valueListenable: ThemeController().themeMode,
            builder: (context, mode, _) {
              final isDark = mode == ThemeMode.dark;
              return IconButton(
                icon: Icon(
                  isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                  color: WandererTheme.primaryOrange,
                ),
                tooltip:
                    isDark ? l10n.switchToLightMode : l10n.switchToDarkMode,
                onPressed: () => ThemeController().setDarkMode(!isDark),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
              );
            },
          ),
        ],
      ),
    );
  }

  Text _quickLangLabel(String code, bool isActive) {
    return Text(
      code,
      style: TextStyle(
        color: isActive
            ? WandererTheme.primaryOrange
            : Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
        fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
        fontSize: 13,
      ),
    );
  }

  Widget _buildFilterChips() {
    final bool isMyTripsTab = _tabController.index == 2;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.inversePrimary.withOpacity(0.35),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Status filter chip
          _buildFilterChipButton<TripStatus?>(
            value: _statusFilter,
            label: _statusFilter == null
                ? 'All Status'
                : _getStatusLabel(_statusFilter!),
            icon: _getStatusIcon(_statusFilter),
            iconColor: _getStatusColor(_statusFilter),
            isActive: _statusFilter != null,
            onSelected: (value) {
              setState(() => _statusFilter = value);
            },
            items: [
              PopupMenuItem<TripStatus?>(
                value: null,
                onTap: () {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    setState(() => _statusFilter = null);
                  });
                },
                child: Row(
                  children: [
                    Icon(Icons.all_inclusive, size: 18, color: Colors.grey),
                    const SizedBox(width: 8),
                    const Text('All Status'),
                  ],
                ),
              ),
              PopupMenuItem<TripStatus?>(
                value: TripStatus.inProgress,
                child: Row(
                  children: [
                    Icon(Icons.circle, size: 18, color: Colors.green),
                    const SizedBox(width: 8),
                    const Text('Live'),
                  ],
                ),
              ),
              PopupMenuItem<TripStatus?>(
                value: TripStatus.paused,
                child: Row(
                  children: [
                    Icon(Icons.pause, size: 18, color: Colors.orange),
                    const SizedBox(width: 8),
                    const Text('Paused'),
                  ],
                ),
              ),
              if (isMyTripsTab) ...[
                PopupMenuItem<TripStatus?>(
                  value: TripStatus.finished,
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 18,
                        color: Colors.blue,
                      ),
                      const SizedBox(width: 8),
                      const Text('Completed'),
                    ],
                  ),
                ),
                PopupMenuItem<TripStatus?>(
                  value: TripStatus.created,
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 18, color: Colors.grey),
                      const SizedBox(width: 8),
                      const Text('Draft'),
                    ],
                  ),
                ),
              ],
            ],
          ),
          // Visibility filter chip (My Trips tab only)
          if (isMyTripsTab) ...[
            const SizedBox(width: 8),
            _buildFilterChipButton<Visibility?>(
              value: _visibilityFilter,
              label: _visibilityFilter == null
                  ? 'All Visibility'
                  : _getVisibilityLabel(_visibilityFilter!),
              icon: _getVisibilityIcon(_visibilityFilter),
              iconColor: _getVisibilityColor(_visibilityFilter),
              isActive: _visibilityFilter != null,
              onSelected: (value) {
                setState(() => _visibilityFilter = value);
              },
              items: [
                PopupMenuItem<Visibility?>(
                  value: null,
                  onTap: () {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      setState(() => _visibilityFilter = null);
                    });
                  },
                  child: Row(
                    children: [
                      Icon(Icons.all_inclusive, size: 18, color: Colors.grey),
                      const SizedBox(width: 8),
                      const Text('All Visibility'),
                    ],
                  ),
                ),
                PopupMenuItem<Visibility?>(
                  value: Visibility.public,
                  child: Row(
                    children: [
                      Icon(Icons.public, size: 18, color: Colors.green),
                      const SizedBox(width: 8),
                      const Text('Public'),
                    ],
                  ),
                ),
                PopupMenuItem<Visibility?>(
                  value: Visibility.protected,
                  child: Row(
                    children: [
                      Icon(Icons.lock_outline, size: 18, color: Colors.orange),
                      const SizedBox(width: 8),
                      const Text('Protected'),
                    ],
                  ),
                ),
                PopupMenuItem<Visibility?>(
                  value: Visibility.private,
                  child: Row(
                    children: [
                      Icon(Icons.lock, size: 18, color: Colors.red),
                      const SizedBox(width: 8),
                      const Text('Private'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  IconData _getStatusIcon(TripStatus? status) {
    if (status == null) return Icons.all_inclusive;
    switch (status) {
      case TripStatus.inProgress:
        return Icons.circle;
      case TripStatus.paused:
        return Icons.pause;
      case TripStatus.finished:
        return Icons.check_circle_outline;
      case TripStatus.created:
        return Icons.edit_outlined;
      case TripStatus.resting:
        return Icons.nightlight_round;
    }
  }

  Color _getStatusColor(TripStatus? status) {
    if (status == null) return Colors.grey;
    switch (status) {
      case TripStatus.inProgress:
        return Colors.green;
      case TripStatus.paused:
        return Colors.orange;
      case TripStatus.finished:
        return Colors.blue;
      case TripStatus.created:
        return Colors.grey;
      case TripStatus.resting:
        return WandererTheme.statusResting;
    }
  }

  String _getStatusLabel(TripStatus status) {
    switch (status) {
      case TripStatus.inProgress:
        return 'Live';
      case TripStatus.paused:
        return 'Paused';
      case TripStatus.finished:
        return 'Completed';
      case TripStatus.created:
        return 'Draft';
      case TripStatus.resting:
        return 'Resting';
    }
  }

  IconData _getVisibilityIcon(Visibility? visibility) {
    if (visibility == null) return Icons.all_inclusive;
    switch (visibility) {
      case Visibility.public:
        return Icons.public;
      case Visibility.protected:
        return Icons.lock_outline;
      case Visibility.private:
        return Icons.lock;
    }
  }

  Color _getVisibilityColor(Visibility? visibility) {
    if (visibility == null) return Colors.grey;
    switch (visibility) {
      case Visibility.public:
        return Colors.green;
      case Visibility.protected:
        return Colors.orange;
      case Visibility.private:
        return Colors.red;
    }
  }

  String _getVisibilityLabel(Visibility visibility) {
    switch (visibility) {
      case Visibility.public:
        return 'Public';
      case Visibility.protected:
        return 'Protected';
      case Visibility.private:
        return 'Private';
    }
  }

  Widget _buildMyTripsTab() {
    final filteredTrips = _getFilteredTrips(_myTrips);

    // Group trips by status
    // Resting trips are shown alongside active trips (like live, but with a resting badge)
    final activeTrips = filteredTrips
        .where(
          (t) =>
              t.status == TripStatus.inProgress ||
              t.status == TripStatus.resting,
        )
        .toList();
    final pausedTrips =
        filteredTrips.where((t) => t.status == TripStatus.paused).toList();
    final draftTrips =
        filteredTrips.where((t) => t.status == TripStatus.created).toList();
    final completedTrips =
        filteredTrips.where((t) => t.status == TripStatus.finished).toList();

    if (filteredTrips.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.explore_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'No trips yet',
              style: TextStyle(
                fontSize: 18,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first trip to get started!',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTrips,
      child: ListView(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: 80 + MediaQuery.of(context).padding.bottom,
        ),
        children: [
          if (activeTrips.isNotEmpty) ...[
            FeedSectionHeader(
              title: 'Active Trips',
              icon: Icons.location_on,
              count: activeTrips.length,
              subtitle: 'Currently in progress',
            ),
            const SizedBox(height: 12),
            _buildTripGrid(activeTrips, showDelete: true),
            const SizedBox(height: 24),
          ],
          if (pausedTrips.isNotEmpty) ...[
            FeedSectionHeader(
              title: 'Paused Trips',
              icon: Icons.pause_circle_outline,
              count: pausedTrips.length,
              subtitle: 'Temporarily stopped',
            ),
            const SizedBox(height: 12),
            _buildTripGrid(pausedTrips, showDelete: true),
            const SizedBox(height: 24),
          ],
          if (draftTrips.isNotEmpty) ...[
            FeedSectionHeader(
              title: 'Draft Trips',
              icon: Icons.edit_outlined,
              count: draftTrips.length,
              subtitle: 'Not yet started',
            ),
            const SizedBox(height: 12),
            _buildTripGrid(draftTrips, showDelete: true),
            const SizedBox(height: 24),
          ],
          if (completedTrips.isNotEmpty) ...[
            FeedSectionHeader(
              title: 'Completed Trips',
              icon: Icons.check_circle_outline,
              count: completedTrips.length,
              subtitle: 'Finished adventures',
            ),
            const SizedBox(height: 12),
            _buildTripGrid(completedTrips, showDelete: true),
          ],
        ],
      ),
    );
  }

  Widget _buildFeedTab() {
    final filteredTrips = _getFilteredTrips(_feedTrips);

    // Group by live (including resting) and other
    final liveTrips = filteredTrips
        .where(
          (t) =>
              t.status == TripStatus.inProgress ||
              t.status == TripStatus.resting,
        )
        .toList();
    final friendsTrips = filteredTrips
        .where(
          (t) =>
              _friendIds.contains(t.userId) &&
              t.status != TripStatus.inProgress &&
              t.status != TripStatus.resting,
        )
        .toList();
    final followingTrips = filteredTrips
        .where(
          (t) =>
              _followingIds.contains(t.userId) &&
              !_friendIds.contains(t.userId) &&
              t.status != TripStatus.inProgress &&
              t.status != TripStatus.resting,
        )
        .toList();

    if (filteredTrips.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'No trips in your feed',
              style: TextStyle(
                fontSize: 18,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Follow users or add friends to see their trips!',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTrips,
      child: ListView(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: 80 + MediaQuery.of(context).padding.bottom,
        ),
        children: [
          if (liveTrips.isNotEmpty) ...[
            FeedSectionHeader(
              title: 'Live Now',
              icon: Icons.flash_on,
              count: liveTrips.length,
              subtitle: 'Happening right now',
            ),
            const SizedBox(height: 12),
            _buildTripGrid(liveTrips, showRelationship: true),
            const SizedBox(height: 24),
          ],
          if (friendsTrips.isNotEmpty) ...[
            FeedSectionHeader(
              title: 'Friends\' Trips',
              icon: Icons.people,
              count: friendsTrips.length,
              subtitle: 'From your friends',
            ),
            const SizedBox(height: 12),
            _buildTripGrid(
              friendsTrips,
              showRelationship: true,
              defaultRelationship: RelationshipType.friend,
            ),
            const SizedBox(height: 24),
          ],
          if (followingTrips.isNotEmpty) ...[
            FeedSectionHeader(
              title: 'Following',
              icon: Icons.person_add_alt_1,
              count: followingTrips.length,
              subtitle: 'From users you follow',
            ),
            const SizedBox(height: 12),
            _buildTripGrid(
              followingTrips,
              showRelationship: true,
              defaultRelationship: RelationshipType.following,
            ),
          ],
          if (_hasMoreTrips) _buildLoadMoreTripsButton(),
        ],
      ),
    );
  }

  Widget _buildDiscoverTab() {
    final l10n = context.l10n;
    final filteredTrips = _getFilteredTrips(_discoverTrips);

    // Separate promoted trips (featured) from regular public trips.
    // Both come from the same _discoverTrips list which already applies the
    // correct inclusion criteria in _categorizeTrips().
    final promotedTripsList =
        filteredTrips.where((t) => _promotedTripIds.contains(t.id)).toList();
    final nonPromotedTrips =
        filteredTrips.where((t) => !_promotedTripIds.contains(t.id)).toList();

    if (nonPromotedTrips.isEmpty && promotedTripsList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.explore_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.noPublicTripsFound,
              style: TextStyle(
                fontSize: 18,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.checkBackLater,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await _loadTrips();
        await _loadPromotedTrips();
      },
      child: ListView(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: 80 + MediaQuery.of(context).padding.bottom,
        ),
        children: [
          if (promotedTripsList.isNotEmpty) ...[
            FeedSectionHeader(
              title: l10n.featuredTrips,
              icon: Icons.star,
              subtitle: l10n.highlightedAdventures,
            ),
            const SizedBox(height: 12),
            _buildTripGrid(promotedTripsList, showRelationship: true),
            const SizedBox(height: 24),
          ],
          if (nonPromotedTrips.isNotEmpty) ...[
            FeedSectionHeader(
              title: l10n.discover,
              icon: Icons.public,
              count: nonPromotedTrips.length,
              subtitle: l10n.explorePublicTripsSubtitle,
            ),
            const SizedBox(height: 12),
            _buildTripGrid(nonPromotedTrips, showRelationship: true),
          ],
          if (_hasMoreTrips) _buildLoadMoreTripsButton(),
        ],
      ),
    );
  }

  // Build discover section for guest users without ListView wrapper
  Widget _buildGuestDiscoverSection() {
    final l10n = context.l10n;
    final filteredTrips = _getFilteredTrips(_discoverTrips);

    // Separate promoted trips (featured) from regular public trips.
    final promotedTripsList =
        filteredTrips.where((t) => _promotedTripIds.contains(t.id)).toList();
    final nonPromotedTrips =
        filteredTrips.where((t) => !_promotedTripIds.contains(t.id)).toList();

    if (filteredTrips.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.explore_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.noPublicTripsFound,
                style: TextStyle(
                  fontSize: 18,
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.checkBackLater,
                style: TextStyle(
                  fontSize: 14,
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (promotedTripsList.isNotEmpty) ...[
          FeedSectionHeader(
            title: l10n.featuredTrips,
            icon: Icons.star,
            subtitle: l10n.highlightedAdventures,
          ),
          const SizedBox(height: 12),
          _buildTripGrid(promotedTripsList, showRelationship: false),
          const SizedBox(height: 24),
        ],
        if (nonPromotedTrips.isNotEmpty) ...[
          FeedSectionHeader(
            title: l10n.discover,
            icon: Icons.public,
            count: nonPromotedTrips.length,
            subtitle: l10n.explorePublicTripsSubtitle,
          ),
          const SizedBox(height: 12),
          _buildTripGrid(nonPromotedTrips, showRelationship: false),
        ],
      ],
    );
  }

  Widget _buildLoadMoreTripsButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: _isLoadingMoreTrips
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: WandererTheme.primaryOrange,
                  strokeWidth: 2,
                ),
              )
            : TextButton.icon(
                onPressed: _loadMoreTrips,
                icon: const Icon(
                  Icons.expand_more,
                  color: WandererTheme.primaryOrange,
                ),
                label: const Text(
                  'Load more trips',
                  style: TextStyle(color: WandererTheme.primaryOrange),
                ),
              ),
      ),
    );
  }

  Widget _buildTripGrid(
    List<Trip> trips, {
    bool showDelete = false,
    bool showRelationship = false,
    RelationshipType? defaultRelationship,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = 1;
        if (constraints.maxWidth > 1200) {
          crossAxisCount = 4;
        } else if (constraints.maxWidth > 800) {
          crossAxisCount = 3;
        } else if (constraints.maxWidth > 600) {
          crossAxisCount = 2;
        }

        // Adjust aspect ratio based on column count for better responsiveness
        final double childAspectRatio;
        if (crossAxisCount == 1) {
          childAspectRatio = 1.3; // Wider cards on mobile to avoid stretching
        } else if (crossAxisCount == 2) {
          childAspectRatio = 1.2;
        } else {
          childAspectRatio = 1.15;
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: childAspectRatio,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: trips.length,
          itemBuilder: (context, index) {
            final trip = trips[index];
            RelationshipType? relationship;

            if (showRelationship && trip.userId != _userId) {
              if (_friendIds.contains(trip.userId)) {
                relationship = RelationshipType.friend;
              } else if (_followingIds.contains(trip.userId)) {
                relationship = RelationshipType.following;
              } else if (defaultRelationship != null) {
                relationship = defaultRelationship;
              }
            }

            return EnhancedTripCard(
              trip: trip,
              onTap: () => _navigateToTripDetail(trip),
              onDelete: showDelete && trip.userId == _userId
                  ? () => _handleDeleteTrip(trip)
                  : null,
              relationship: relationship,
              showAllBadges: true,
              isPromoted: _promotedTripIds.contains(trip.id),
              promotedTrip: _promotedTripsById[trip.id],
            );
          },
        );
      },
    );
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline,
                          size: 64, color: Colors.red[300]),
                      const SizedBox(height: 16),
                      Text(
                        l10n.errorLoadingTrips,
                        style: TextStyle(
                          fontSize: 18,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.6),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.5),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadTrips,
                        child: Text(l10n.retry),
                      ),
                    ],
                  ),
                )
              : !_isLoggedIn
                  ? SingleChildScrollView(
                      child: Column(
                        children: [
                          _buildQuickControls(l10n),
                          // Hero section with better visuals
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              vertical: 48,
                              horizontal: 24,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withOpacity(0.1),
                                  Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withOpacity(0.05),
                                ],
                              ),
                            ),
                            child: Column(
                              children: [
                                const WandererLogo(size: 110),
                                const SizedBox(height: 24),
                                Text(
                                  l10n.welcomeToWanderer,
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: -1,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  l10n.trackAdventures,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.6),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 32),
                                ElevatedButton(
                                  onPressed: _navigateToAuth,
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 40,
                                      vertical: 16,
                                    ),
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Text(
                                    l10n.logIn,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Discover section with better header
                          Container(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary
                                            .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        Icons.public,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            l10n.explorePublicTrips,
                                            style: const TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: -0.5,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            l10n.discoverAdventures,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurface
                                                  .withOpacity(0.6),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),
                                // Build trip grid directly for guest users (no ListView wrapper)
                                _buildGuestDiscoverSection(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  : Stack(
                      children: [
                        Column(
                          children: [
                            _buildQuickControls(l10n),
                            _buildFilterChips(),
                            Expanded(
                              child: TabBarView(
                                controller: _tabController,
                                children: [
                                  _buildDiscoverTab(),
                                  _buildFeedTab(),
                                  _buildMyTripsTab(),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (_isLoggedIn)
                          Positioned(
                            left: 16,
                            right: 16,
                            bottom: 16 + MediaQuery.of(context).padding.bottom,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(28),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.12),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  ),
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(28),
                                child: SizedBox(
                                  height: 64,
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceAround,
                                    children: List.generate(3, (index) {
                                      final isSelected =
                                          _tabController.index == index;
                                      final icons = [
                                        Icons.explore_outlined,
                                        Icons.dynamic_feed_outlined,
                                        Icons.person_outline,
                                      ];
                                      final selectedIcons = [
                                        Icons.explore,
                                        Icons.dynamic_feed,
                                        Icons.person,
                                      ];
                                      final labels = [
                                        l10n.discover,
                                        l10n.feed,
                                        l10n.myTrips,
                                      ];
                                      return Expanded(
                                        child: InkWell(
                                          onTap: () {
                                            setState(() {
                                              _tabController.animateTo(index);
                                            });
                                          },
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                isSelected
                                                    ? selectedIcons[index]
                                                    : icons[index],
                                                color: isSelected
                                                    ? Theme.of(
                                                        context,
                                                      ).colorScheme.primary
                                                    : Theme.of(
                                                        context,
                                                      )
                                                        .colorScheme
                                                        .onSurfaceVariant,
                                                size: 24,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                labels[index],
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: isSelected
                                                      ? Theme.of(
                                                          context,
                                                        ).colorScheme.primary
                                                      : Theme.of(
                                                          context,
                                                        )
                                                          .colorScheme
                                                          .onSurfaceVariant,
                                                  fontWeight: isSelected
                                                      ? FontWeight.w600
                                                      : FontWeight.normal,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (_username != null)
                          Positioned(
                            right: 16,
                            bottom: 92 + MediaQuery.of(context).padding.bottom,
                            child: FloatingActionButton.extended(
                              onPressed: _navigateToCreateTrip,
                              icon: const Icon(Icons.add),
                              label: const Text('New Trip'),
                            ),
                          ),
                      ],
                    ),
    );
  }
}
