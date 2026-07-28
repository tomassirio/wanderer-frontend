import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/constants/enums.dart'
    show TripStatus, Visibility;
import 'package:wanderer_frontend/core/providers/app_providers.dart';
import 'package:wanderer_frontend/core/services/push_notification_manager.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/data/services/trip_service.dart';
import 'package:wanderer_frontend/presentation/helpers/tutorial_helper.dart';
import 'package:wanderer_frontend/presentation/helpers/dialog_helper.dart';
import 'package:wanderer_frontend/presentation/helpers/ui_helpers.dart';
import 'package:wanderer_frontend/presentation/helpers/page_transitions.dart';
import 'package:wanderer_frontend/presentation/helpers/auth_navigation_helper.dart';
import 'package:wanderer_frontend/presentation/state/home_feed/home_feed_notifier.dart';
import 'package:wanderer_frontend/presentation/state/user_chrome/user_chrome_notifier.dart';
import 'package:wanderer_frontend/presentation/widgets/common/wanderer_app_bar.dart';
import 'package:wanderer_frontend/presentation/widgets/common/wanderer_logo.dart';
import 'package:wanderer_frontend/presentation/widgets/common/app_sidebar.dart';
import 'package:wanderer_frontend/presentation/widgets/home/feed_section_header.dart';
import 'package:wanderer_frontend/presentation/widgets/home/filter_chip_button.dart';
import 'package:wanderer_frontend/presentation/widgets/home/hero_lang_toggle.dart';
import 'package:wanderer_frontend/presentation/widgets/home/hero_theme_toggle.dart';
import 'package:wanderer_frontend/presentation/widgets/home/load_more_trips_button.dart';
import 'package:wanderer_frontend/presentation/widgets/home/relationship_badge.dart';
import 'package:wanderer_frontend/presentation/widgets/home/trip_grid.dart';
import 'package:wanderer_frontend/presentation/widgets/home/zero_trips_takeover.dart';
import 'package:wanderer_frontend/main.dart' show routeObserver;
import 'create_trip_screen.dart';
import 'settings_screen.dart';
import 'trip_detail_screen.dart';
import 'auth_screen.dart';

/// Redesigned Home screen with personalized feed, visibility badges, and prioritization
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin, RouteAware {
  late final TripService _tripService;
  final PushNotificationManager _pushNotificationManager =
      PushNotificationManager();

  late TabController _tabController;

  final int _selectedSidebarIndex = 0;

  String? get _username => ref.watch(userChromeNotifierProvider).username;
  String? get _userId => ref.watch(userChromeNotifierProvider).userId;
  String? get _displayName => ref.watch(userChromeNotifierProvider).displayName;
  String? get _avatarUrl => ref.watch(userChromeNotifierProvider).avatarUrl;
  bool get _isLoggedIn => ref.watch(userChromeNotifierProvider).isLoggedIn;
  bool get _isAdmin => ref.watch(userChromeNotifierProvider).isAdmin;

  List<Trip> get _myTrips => ref.watch(homeFeedNotifierProvider).myTrips;
  List<Trip> get _feedTrips => ref.watch(homeFeedNotifierProvider).feedTrips;
  List<Trip> get _discoverTrips =>
      ref.watch(homeFeedNotifierProvider).discoverTrips;
  Set<String> get _friendIds => ref.watch(homeFeedNotifierProvider).friendIds;
  Set<String> get _followingIds =>
      ref.watch(homeFeedNotifierProvider).followingIds;
  bool get _isLoading => ref.watch(homeFeedNotifierProvider).isLoading;
  bool get _isLoadingMoreTrips =>
      ref.watch(homeFeedNotifierProvider).isLoadingMoreTrips;
  bool get _hasMoreTrips => ref.watch(homeFeedNotifierProvider).hasMoreTrips;
  String? get _error => ref.watch(homeFeedNotifierProvider).error;

  // Filter states
  TripStatus? get _statusFilter =>
      ref.watch(homeFeedNotifierProvider).statusFilter;
  Visibility? get _visibilityFilter =>
      ref.watch(homeFeedNotifierProvider).visibilityFilter;

  // First-time home screen tutorial (coach marks)
  final GlobalKey _tutorialMenuKey = GlobalKey();
  final GlobalKey _tutorialBottomNavKey = GlobalKey();
  final GlobalKey _tutorialSearchKey = GlobalKey();
  final GlobalKey _tutorialNotificationsKey = GlobalKey();
  final GlobalKey _tutorialNewTripKey = GlobalKey();
  bool _tutorialCheckDone = false;

  @override
  void initState() {
    super.initState();
    _tripService = ref.read(tripServiceProvider);

    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    _initializeData();
    ref.read(homeFeedNotifierProvider.notifier).startWebSocketAndPolling();
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
  }

  void _onTabChanged() {
    if (mounted) {
      ref
          .read(homeFeedNotifierProvider.notifier)
          .resetFiltersForTab(_tabController.index == 2);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _pushNotificationManager.stop();
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserInfo() async {
    await ref.read(userChromeNotifierProvider.notifier).loadUserInfo();

    final identity = ref.read(userChromeNotifierProvider);
    _ensurePushAndUserTopic(identity.isLoggedIn, identity.userId);
  }

  /// Screen-local extra behavior layered on top of the shared identity
  /// notifier — push notifications and WebSocket user-topic subscription
  /// are NOT generic identity concerns (other screens reusing
  /// UserChromeNotifier won't necessarily want either), so they stay here
  /// rather than inside UserChromeNotifier itself.
  void _ensurePushAndUserTopic(bool isLoggedIn, String? userId) {
    if (isLoggedIn && userId != null) {
      _pushNotificationManager.start(userId);
      ref.read(homeFeedNotifierProvider.notifier).ensureUserTopicSubscribed(userId);
    } else {
      _pushNotificationManager.stop();
    }
  }

  /// Shows the first-time home screen tutorial (coach marks) once per
  /// device, the first time a logged-in user with a resolved username
  /// reaches this screen.
  Future<void> _maybeShowHomeTutorial() async {
    if (_tutorialCheckDone || !_isLoggedIn || _username == null) return;
    _tutorialCheckDone = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final l10n = context.l10n;
      showFirstTimeTutorial(
        context: context,
        tutorialKey: TutorialKeys.home,
        steps: [
          TutorialStep(
            key: _tutorialMenuKey,
            title: l10n.tutorialMenuTitle,
            description: l10n.tutorialMenuDescription,
          ),
          TutorialStep(
            key: _tutorialBottomNavKey,
            title: l10n.tutorialBottomNavTitle,
            description: l10n.tutorialBottomNavDescription,
            shape: ShapeLightFocus.RRect,
            radius: 28,
            align: ContentAlign.top,
          ),
          TutorialStep(
            key: _tutorialSearchKey,
            title: l10n.tutorialSearchTitle,
            description: l10n.tutorialSearchDescription,
          ),
          TutorialStep(
            key: _tutorialNotificationsKey,
            title: l10n.tutorialNotificationsTitle,
            description: l10n.tutorialNotificationsDescription,
          ),
          TutorialStep(
            key: _tutorialNewTripKey,
            title: l10n.tutorialNewTripTitle,
            description: l10n.tutorialNewTripDescription,
            shape: ShapeLightFocus.RRect,
            radius: 16,
            align: ContentAlign.top,
          ),
        ],
      );
    });
  }

  Future<void> _loadTrips() async {
    // WebSocket trip-topic resubscription now happens inside the notifier's
    // loadTrips() itself (see HomeFeedNotifier._resyncTripSubscriptions),
    // as does categorization (feedTrips/discoverTrips) - _feedTrips/
    // _discoverTrips are ref.watch getters, so no local setState is needed
    // here.
    await ref.read(homeFeedNotifierProvider.notifier).loadTrips();

    // Trigger after loading settles (not from _loadUserInfo) so the coach
    // marks' target widgets (FAB, bottom nav) are actually mounted — showing
    // it mid-load risks the tutorial silently marking itself "seen" without
    // ever appearing, since tutorial_coach_mark treats a missing first
    // target as an immediate finish.
    _maybeShowHomeTutorial();
  }

  Future<void> _loadMoreTrips() async {
    try {
      // WebSocket subscription for newly-loaded trips now happens inside
      // the notifier's loadMoreTrips() itself (see
      // HomeFeedNotifier._subscribeToNewTrips).
      await ref.read(homeFeedNotifierProvider.notifier).loadMoreTrips();
    } catch (e) {
      if (mounted) {
        UiHelpers.showErrorMessage(context, 'Error loading more trips: $e');
      }
    }
  }

  /// Removed _loadPromotedTrips() and _fetchMissingPromotedTrips()
  /// Backend now includes isPromoted/promotedAt in Trip data
  /// Note: Admin promotion screen still uses separate endpoint for full PromotedTrip details

  Future<void> _logout() async {
    final confirm = await DialogHelper.showLogoutConfirmation(context);

    if (confirm) {
      await ref.read(userChromeNotifierProvider.notifier).logout();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          PageTransitions.fade(const HomeScreen()),
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
      PageTransitions.slideFromBottom(const SettingsScreen()),
    );
  }

  Future<void> _navigateToAuth({bool startInSignup = false}) async {
    final result = await Navigator.push(
      context,
      PageTransitions.fade(AuthScreen(startInSignup: startInSignup)),
    );

    if (result == true && mounted) {
      await _loadUserInfo();
      await _loadTrips();
    }
  }

  Future<void> _navigateToCreateTrip() async {
    await Navigator.push(
      context,
      PageTransitions.slideFromBottom(const CreateTripScreen()),
    );

    if (mounted) {
      await _loadTrips();
    }
  }

  void _navigateToTripDetail(Trip trip) async {
    await Navigator.push(
      context,
      PageTransitions.slideFromRight(TripDetailScreen(trip: trip)),
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
          '${l10n.deleteTripConfirm} "${trip.name}"? ${l10n.deleteTripWarning}',
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

  Widget _buildFilterChips() {
    final bool isMyTripsTab = _tabController.index == 2;
    final l10n = context.l10n;

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
          FilterChipButton<TripStatus?>(
            value: _statusFilter,
            label: _statusFilter == null
                ? l10n.allStatus
                : _getStatusLabel(_statusFilter!, l10n),
            icon: _statusFilter == null
                ? Icons.all_inclusive
                : UiHelpers.getStatusIcon(_statusFilter!),
            iconColor: _statusFilter == null
                ? Colors.grey
                : UiHelpers.getStatusColor(_statusFilter!),
            isActive: _statusFilter != null,
            onSelected: (value) {
              ref.read(homeFeedNotifierProvider.notifier).setStatusFilter(value);
            },
            items: [
              PopupMenuItem<TripStatus?>(
                value: null,
                onTap: () {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    ref
                        .read(homeFeedNotifierProvider.notifier)
                        .setStatusFilter(null);
                  });
                },
                child: Row(
                  children: [
                    Icon(Icons.all_inclusive, size: 18, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(l10n.allStatus),
                  ],
                ),
              ),
              PopupMenuItem<TripStatus?>(
                value: TripStatus.inProgress,
                child: Row(
                  children: [
                    Icon(Icons.circle, size: 18, color: Colors.green),
                    const SizedBox(width: 8),
                    Text(l10n.live),
                  ],
                ),
              ),
              PopupMenuItem<TripStatus?>(
                value: TripStatus.paused,
                child: Row(
                  children: [
                    Icon(Icons.pause, size: 18, color: Colors.orange),
                    const SizedBox(width: 8),
                    Text(l10n.paused),
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
                      Text(l10n.completed),
                    ],
                  ),
                ),
                PopupMenuItem<TripStatus?>(
                  value: TripStatus.created,
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 18, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(l10n.draft),
                    ],
                  ),
                ),
              ],
            ],
          ),
          // Visibility filter chip (My Trips tab only)
          if (isMyTripsTab) ...[
            const SizedBox(width: 8),
            FilterChipButton<Visibility?>(
              value: _visibilityFilter,
              label: _visibilityFilter == null
                  ? l10n.allVisibility
                  : _getVisibilityLabel(_visibilityFilter!, l10n),
              icon: _getVisibilityIcon(_visibilityFilter),
              iconColor: _getVisibilityColor(_visibilityFilter),
              isActive: _visibilityFilter != null,
              onSelected: (value) {
                ref
                    .read(homeFeedNotifierProvider.notifier)
                    .setVisibilityFilter(value);
              },
              items: [
                PopupMenuItem<Visibility?>(
                  value: null,
                  onTap: () {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      ref
                          .read(homeFeedNotifierProvider.notifier)
                          .setVisibilityFilter(null);
                    });
                  },
                  child: Row(
                    children: [
                      Icon(Icons.all_inclusive, size: 18, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(l10n.allVisibility),
                    ],
                  ),
                ),
                PopupMenuItem<Visibility?>(
                  value: Visibility.public,
                  child: Row(
                    children: [
                      Icon(Icons.public, size: 18, color: Colors.green),
                      const SizedBox(width: 8),
                      Text(l10n.publicVisibility),
                    ],
                  ),
                ),
                PopupMenuItem<Visibility?>(
                  value: Visibility.protected,
                  child: Row(
                    children: [
                      Icon(Icons.lock_outline, size: 18, color: Colors.orange),
                      const SizedBox(width: 8),
                      Text(l10n.protectedVisibility),
                    ],
                  ),
                ),
                PopupMenuItem<Visibility?>(
                  value: Visibility.private,
                  child: Row(
                    children: [
                      Icon(Icons.lock, size: 18, color: Colors.red),
                      const SizedBox(width: 8),
                      Text(l10n.privateVisibility),
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

  String _getStatusLabel(TripStatus status, AppLocalizations l10n) {
    return UiHelpers.getStatusLabel(status, l10n);
  }

  IconData _getVisibilityIcon(Visibility? visibility) {
    return visibility == null
        ? Icons.all_inclusive
        : UiHelpers.getVisibilityIcon(visibility);
  }

  // _getVisibilityColor stays local: this screen's filter chip uses flat
  // Colors.green/.orange/.red, a different (simpler) visual treatment than
  // VisibilityBadge's shade700+border scheme - not a literal duplicate, see
  // plan Global Constraints for why color isn't unified across both.
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

  String _getVisibilityLabel(Visibility visibility, AppLocalizations l10n) {
    return UiHelpers.getVisibilityLabel(visibility, l10n);
  }

  Widget _buildMyTripsTab() {
    final filteredTrips = ref.watch(homeFeedNotifierProvider).filtered(_myTrips);
    final l10n = context.l10n;

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
              l10n.noTripsYet,
              style: TextStyle(
                fontSize: 18,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.createYourFirstTrip,
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
              title: l10n.activeTripsSection,
              icon: Icons.location_on,
              count: activeTrips.length,
              subtitle: l10n.currentlyInProgress,
            ),
            const SizedBox(height: 12),
            TripGrid(
              trips: activeTrips,
              currentUserId: _userId,
              friendIds: _friendIds,
              followingIds: _followingIds,
              showDelete: true,
              onTripTap: _navigateToTripDetail,
              onDeleteTrip: _handleDeleteTrip,
            ),
            const SizedBox(height: 24),
          ],
          if (pausedTrips.isNotEmpty) ...[
            FeedSectionHeader(
              title: l10n.pausedTripsSection,
              icon: Icons.pause_circle_outline,
              count: pausedTrips.length,
              subtitle: l10n.temporarilyStopped,
            ),
            const SizedBox(height: 12),
            TripGrid(
              trips: pausedTrips,
              currentUserId: _userId,
              friendIds: _friendIds,
              followingIds: _followingIds,
              showDelete: true,
              onTripTap: _navigateToTripDetail,
              onDeleteTrip: _handleDeleteTrip,
            ),
            const SizedBox(height: 24),
          ],
          if (draftTrips.isNotEmpty) ...[
            FeedSectionHeader(
              title: l10n.draftTripsSection,
              icon: Icons.edit_outlined,
              count: draftTrips.length,
              subtitle: l10n.notYetStarted,
            ),
            const SizedBox(height: 12),
            TripGrid(
              trips: draftTrips,
              currentUserId: _userId,
              friendIds: _friendIds,
              followingIds: _followingIds,
              showDelete: true,
              onTripTap: _navigateToTripDetail,
              onDeleteTrip: _handleDeleteTrip,
            ),
            const SizedBox(height: 24),
          ],
          if (completedTrips.isNotEmpty) ...[
            FeedSectionHeader(
              title: l10n.completedTripsSection,
              icon: Icons.check_circle_outline,
              count: completedTrips.length,
              subtitle: l10n.finishedAdventures,
            ),
            const SizedBox(height: 12),
            TripGrid(
              trips: completedTrips,
              currentUserId: _userId,
              friendIds: _friendIds,
              followingIds: _followingIds,
              showDelete: true,
              onTripTap: _navigateToTripDetail,
              onDeleteTrip: _handleDeleteTrip,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFeedTab() {
    final filteredTrips = ref.watch(homeFeedNotifierProvider).filtered(_feedTrips);
    final l10n = context.l10n;

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
              l10n.noTripsInYourFeed,
              style: TextStyle(
                fontSize: 18,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.followUsersToSeeFeed,
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
              title: l10n.liveNow,
              icon: Icons.flash_on,
              count: liveTrips.length,
              subtitle: l10n.happeningRightNow,
            ),
            const SizedBox(height: 12),
            TripGrid(
              trips: liveTrips,
              currentUserId: _userId,
              friendIds: _friendIds,
              followingIds: _followingIds,
              showRelationship: true,
              onTripTap: _navigateToTripDetail,
              onDeleteTrip: _handleDeleteTrip,
            ),
            const SizedBox(height: 24),
          ],
          if (friendsTrips.isNotEmpty) ...[
            FeedSectionHeader(
              title: l10n.friendsTripsSection,
              icon: Icons.people,
              count: friendsTrips.length,
              subtitle: l10n.fromYourFriends,
            ),
            const SizedBox(height: 12),
            TripGrid(
              trips: friendsTrips,
              currentUserId: _userId,
              friendIds: _friendIds,
              followingIds: _followingIds,
              showRelationship: true,
              defaultRelationship: RelationshipType.friend,
              onTripTap: _navigateToTripDetail,
              onDeleteTrip: _handleDeleteTrip,
            ),
            const SizedBox(height: 24),
          ],
          if (followingTrips.isNotEmpty) ...[
            FeedSectionHeader(
              title: l10n.following,
              icon: Icons.person_add_alt_1,
              count: followingTrips.length,
              subtitle: l10n.fromUsersYouFollow,
            ),
            const SizedBox(height: 12),
            TripGrid(
              trips: followingTrips,
              currentUserId: _userId,
              friendIds: _friendIds,
              followingIds: _followingIds,
              showRelationship: true,
              defaultRelationship: RelationshipType.following,
              onTripTap: _navigateToTripDetail,
              onDeleteTrip: _handleDeleteTrip,
            ),
          ],
          if (_hasMoreTrips)
            LoadMoreTripsButton(
              isLoading: _isLoadingMoreTrips,
              onLoadMore: _loadMoreTrips,
            ),
        ],
      ),
    );
  }

  Widget _buildDiscoverTab() {
    final l10n = context.l10n;
    final filteredTrips = ref.watch(homeFeedNotifierProvider).filtered(_discoverTrips);

    // Separate promoted trips (featured) from regular public trips.
    // Backend now includes isPromoted field in Trip model
    final promotedTripsList = filteredTrips.where((t) => t.isPromoted).toList();
    final nonPromotedTrips = filteredTrips.where((t) => !t.isPromoted).toList();

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
        // Reload trips to get latest data (including promoted status)
        await _loadTrips();
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
            TripGrid(
              trips: promotedTripsList,
              currentUserId: _userId,
              friendIds: _friendIds,
              followingIds: _followingIds,
              showRelationship: true,
              onTripTap: _navigateToTripDetail,
              onDeleteTrip: _handleDeleteTrip,
            ),
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
            TripGrid(
              trips: nonPromotedTrips,
              currentUserId: _userId,
              friendIds: _friendIds,
              followingIds: _followingIds,
              showRelationship: true,
              onTripTap: _navigateToTripDetail,
              onDeleteTrip: _handleDeleteTrip,
            ),
          ],
          if (_hasMoreTrips)
            LoadMoreTripsButton(
              isLoading: _isLoadingMoreTrips,
              onLoadMore: _loadMoreTrips,
            ),
        ],
      ),
    );
  }

  // Build discover section for guest users without ListView wrapper
  Widget _buildGuestDiscoverSection() {
    final l10n = context.l10n;
    final filteredTrips = ref.watch(homeFeedNotifierProvider).filtered(_discoverTrips);

    // Separate promoted trips (featured) from regular public trips.
    // Backend now includes isPromoted field in Trip model
    final promotedTripsList = filteredTrips.where((t) => t.isPromoted).toList();
    final nonPromotedTrips = filteredTrips.where((t) => !t.isPromoted).toList();

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
          TripGrid(
            trips: promotedTripsList,
            currentUserId: _userId,
            friendIds: _friendIds,
            followingIds: _followingIds,
            showRelationship: false,
            onTripTap: _navigateToTripDetail,
            onDeleteTrip: _handleDeleteTrip,
          ),
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
          TripGrid(
            trips: nonPromotedTrips,
            currentUserId: _userId,
            friendIds: _friendIds,
            followingIds: _followingIds,
            showRelationship: false,
            onTripTap: _navigateToTripDetail,
            onDeleteTrip: _handleDeleteTrip,
          ),
        ],
      ],
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
        menuButtonKey: _tutorialMenuKey,
        searchButtonKey: _tutorialSearchKey,
        notificationButtonKey: _tutorialNotificationsKey,
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
                          // Hero section — quick controls overlaid top-right
                          Stack(
                            children: [
                              TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0.0, end: 1.0),
                                duration: const Duration(milliseconds: 500),
                                curve: Curves.easeOut,
                                builder: (context, value, child) {
                                  return Opacity(
                                    opacity: value,
                                    child: Transform.translate(
                                      offset: Offset(0, (1 - value) * 20),
                                      child: child,
                                    ),
                                  );
                                },
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 40,
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
                                    boxShadow: [
                                      BoxShadow(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary
                                            .withOpacity(0.08),
                                        blurRadius: 24,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
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
                                      Wrap(
                                        alignment: WrapAlignment.center,
                                        spacing: 16,
                                        runSpacing: 12,
                                        children: [
                                          ElevatedButton(
                                            onPressed: () => _navigateToAuth(
                                                startInSignup: true),
                                            style: ElevatedButton.styleFrom(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 40,
                                                vertical: 16,
                                              ),
                                              elevation: 2,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                            ),
                                            child: Text(
                                              l10n.getStarted,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          OutlinedButton(
                                            onPressed: () => _navigateToAuth(
                                                startInSignup: false),
                                            style: OutlinedButton.styleFrom(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 40,
                                                vertical: 16,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
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
                                    ],
                                  ),
                                ),
                              ),
                              // Language toggle — top-left corner
                              Positioned(
                                top: 8,
                                left: 8,
                                child: const HeroLangToggle(),
                              ),
                              // Dark/light mode toggle — top-right corner
                              Positioned(
                                top: 8,
                                right: 8,
                                child: HeroThemeToggle(l10n: l10n),
                              ),
                            ],
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
                  : _myTrips.isEmpty
                      ? ZeroTripsTakeover(
                          l10n: l10n,
                          onCreateTrip: _navigateToCreateTrip,
                        )
                      : Stack(
                          children: [
                            Column(
                              children: [
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
                                bottom:
                                    16 + MediaQuery.of(context).padding.bottom,
                                child: Container(
                                  key: _tutorialBottomNavKey,
                                  decoration: BoxDecoration(
                                    color:
                                        Theme.of(context).colorScheme.surface,
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
                                                  _tabController
                                                      .animateTo(index);
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
                                                            )
                                                              .colorScheme
                                                              .primary
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
                                bottom:
                                    92 + MediaQuery.of(context).padding.bottom,
                                child: FloatingActionButton.extended(
                                  key: _tutorialNewTripKey,
                                  onPressed: _navigateToCreateTrip,
                                  icon: const Icon(Icons.add),
                                  label: Text(l10n.newTrip),
                                ),
                              ),
                          ],
                        ),
    );
  }
}
