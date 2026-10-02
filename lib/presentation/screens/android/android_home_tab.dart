import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:wanderer_frontend/presentation/helpers/adaptive_layout.dart';
import 'package:wanderer_frontend/presentation/widgets/mobile_web/app_handoff.dart';
import 'package:wanderer_frontend/presentation/widgets/mobile_web/mobile_web_trip_card.dart';
import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:wanderer_frontend/core/constants/enums.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/providers/app_providers.dart';
import 'package:wanderer_frontend/core/services/background_update_manager.dart';
import 'package:wanderer_frontend/core/services/notification_service.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/data/models/achievement_models.dart';
import 'package:wanderer_frontend/data/models/domain/user_profile.dart';
import 'package:wanderer_frontend/data/models/notification_models.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/presentation/helpers/android_app_links.dart';
import 'package:wanderer_frontend/presentation/helpers/auth_navigation_helper.dart';
import 'package:wanderer_frontend/presentation/helpers/location_permission_disclosure.dart';
import 'package:wanderer_frontend/presentation/helpers/page_transitions.dart';
import 'package:wanderer_frontend/presentation/screens/android/android_notifications_screen.dart';
import 'package:wanderer_frontend/presentation/screens/android/android_search_screen.dart';
import 'package:wanderer_frontend/presentation/screens/android/android_shell.dart';
import 'package:wanderer_frontend/presentation/screens/create_trip_plan_screen.dart';
import 'package:wanderer_frontend/presentation/screens/create_trip_screen.dart';
import 'package:wanderer_frontend/presentation/screens/trip_deep_link_screen.dart';
import 'package:wanderer_frontend/presentation/screens/trip_detail_screen.dart';
import 'package:wanderer_frontend/presentation/widgets/android/explore_widgets.dart';
import 'package:wanderer_frontend/presentation/widgets/android/home_live_trip_card.dart';
import 'package:wanderer_frontend/presentation/widgets/android/home_sections.dart';
import 'package:wanderer_frontend/presentation/widgets/common/pill.dart';
import 'package:wanderer_frontend/presentation/widgets/common/toasts.dart';
import 'package:wanderer_frontend/presentation/widgets/common/wanderer_logo.dart';

/// Greeting for the hour: morning before 12, afternoon before 18.
@visibleForTesting
String homeGreeting(AppLocalizations l10n, int hour, String name) => hour < 12
    ? l10n.homeGreetingMorning(name)
    : hour < 18
        ? l10n.homeGreetingAfternoon(name)
        : l10n.homeGreetingEvening(name);

/// Friends' trips that are on the road (live, paused or resting) and that
/// friends may see (public or friends-only), live ones first.
@visibleForTesting
List<Trip> friendsOnTheRoad(Iterable<Trip> trips, Set<String> friendIds) =>
    trips
        .where((t) =>
            friendIds.contains(t.userId) &&
            t.visibility != Visibility.private &&
            (t.status == TripStatus.inProgress ||
                t.status == TripStatus.paused ||
                t.status == TripStatus.resting))
        .toList()
      ..sort((a, b) {
        final live = (b.status == TripStatus.inProgress ? 1 : 0) -
            (a.status == TripStatus.inProgress ? 1 : 0);
        return live != 0 ? live : b.updatedAt.compareTo(a.updatedAt);
      });

/// Android "Home" tab root (canvas: AndroidHome). Shown inside
/// [AndroidShell], which provides the bottom nav and the + button.
class AndroidHomeTab extends ConsumerStatefulWidget {
  const AndroidHomeTab({super.key});

  @override
  ConsumerState<AndroidHomeTab> createState() => _AndroidHomeTabState();
}

class _AndroidHomeTabState extends ConsumerState<AndroidHomeTab> {
  UserProfile? _profile;
  List<Trip> _trips = const [];
  int _badges = 0;
  Set<String> _unlockedIds = const {};
  List<Achievement> _allBadges = const [];
  Set<String> _friendIds = const {};
  List<Trip> _friendTrips = const [];
  List<Trip> _publicTrips = const [];
  List<NotificationDto> _activity = const [];
  bool _notificationsOn = true;
  bool _followsSomeone = false;
  int _unread = 0;
  Object? _error;
  bool _checkingIn = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  static Future<T?> _optional<T>(Future<T> f) async {
    try {
      return await f;
    } catch (e) {
      debugPrint('AndroidHomeTab: optional section failed: $e');
      return null;
    }
  }

  Future<void> _load() async {
    final home = ref.read(homeRepositoryProvider);
    try {
      final profileF = ref.read(userServiceProvider).getMyProfile();
      final tripsF = home.getMyTrips(size: 50);
      final badgesF =
          _optional(ref.read(achievementServiceProvider).getMyAchievements());
      final friendsF = home.getFriendsIds();
      final availableF = _optional(home.loadTrips(size: 50));
      final notifications = ref.read(notificationApiServiceProvider);
      final unreadF = _optional(notifications.getUnreadCount());
      final activityF = _optional(notifications.getMyNotifications(size: 20));
      final allBadgesF =
          _optional(ref.read(achievementServiceProvider).getAllAchievements());
      // The profile carries no following count: ask for one follow.
      final followingF =
          _optional(ref.read(userServiceProvider).getFollowing(size: 1));
      final notificationsOnF =
          kIsWeb ? Future.value(true) : NotificationService().areEnabled();

      final profile = await profileF;
      final trips = [...(await tripsF).content]
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      final friendIds = await friendsF;
      final available = (await availableF)?.content ?? const <Trip>[];
      final myBadges = await badgesF ?? const <UserAchievement>[];
      final allBadges = await allBadgesF ?? const <Achievement>[];
      final unlockedIds = {for (final b in myBadges) b.achievement.id};
      final unread = await unreadF;
      final activity = (await activityF)?.content ?? const <NotificationDto>[];
      final notificationsOn = await notificationsOnF;
      final following = await followingF;
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _trips = trips;
        // Distinct badges: per-trip ones unlock once per trip.
        _badges = allBadges.isEmpty
            ? unlockedIds.length
            : allBadges.where((a) => unlockedIds.contains(a.id)).length;
        _unlockedIds = unlockedIds;
        _allBadges = allBadges;
        _friendIds = friendIds;
        _friendTrips = friendsOnTheRoad(available, friendIds);
        _publicTrips = available
            .where((t) =>
                t.userId != profile.id &&
                t.visibility == Visibility.public &&
                t.status != TripStatus.created)
            .toList()
          ..sort((a, b) => (b.status == TripStatus.inProgress ? 1 : 0)
              .compareTo(a.status == TripStatus.inProgress ? 1 : 0));
        _activity = activity.where(HomeFriendsActivity.shows).take(3).toList();
        _notificationsOn = notificationsOn;
        _followsSomeone = (following?.content.isNotEmpty ?? false) ||
            (following?.totalElements ?? 0) > 0;
        if (unread != null) _unread = unread;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  // ponytail: unread count refreshes on load, pull and return from the
  // notifications screen; add a WebSocket listener (see NotificationBell)
  // if it must tick live.
  Future<void> _push(Widget screen) async {
    await Navigator.of(context).push(PageTransitions.slideFromRight(screen));
    if (mounted) _load();
  }

  Future<void> _checkIn(Trip trip) async {
    final l10n = context.l10n;
    setState(() => _checkingIn = true);
    try {
      // The service does not ask for permission (UI concern): show the
      // disclosure first. Other failures come back as a userMessage.
      if (await Geolocator.checkPermission() == LocationPermission.denied) {
        if (!mounted ||
            (!kIsWeb && !await LocationPermissionDisclosure.show(context))) {
          return;
        }
        await Geolocator.requestPermission();
      }
      final result =
          await ref.read(tripDetailRepositoryProvider).sendTripUpdate(trip.id);
      if (!mounted) return;
      if (!result.isSuccess) {
        Toasts.show(
            ToastData(kind: ToastKind.error, title: result.userMessage));
        return;
      }
      Toasts.show(ToastData(
          kind: ToastKind.success, title: l10n.homeCheckedIn, body: trip.name));
      // Same as trip detail: a check-in restarts the automatic schedule.
      if (!kIsWeb && trip.automaticUpdates) {
        await BackgroundUpdateManager()
            .startAutoUpdates(trip.id, trip.name, trip.effectiveUpdateRefresh);
      }
      // Give the CQRS read side a moment before reloading.
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) _load();
      });
    } catch (e) {
      if (mounted) {
        Toasts.show(ToastData(kind: ToastKind.error, title: e.toString()));
      }
    } finally {
      if (mounted) setState(() => _checkingIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: c.ground,
      appBar: AppBar(
        toolbarHeight: 64,
        backgroundColor: c.ground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 20,
        title: Row(children: [
          const WandererLogo(size: 32),
          const SizedBox(width: 10),
          Text('Wanderer', style: WandererTheme.display(20, color: c.text)),
        ]),
        actions: [
          IconButton(
            tooltip: l10n.search,
            icon: Icon(Icons.search, color: c.text),
            onPressed: () => _push(const AndroidSearchScreen()),
          ),
          IconButton(
            tooltip: _unread > 0
                ? l10n.homeNotificationsNew(_unread)
                : l10n.notifications,
            icon: Badge(
              isLabelVisible: _unread > 0,
              backgroundColor: WandererTheme.trail,
              label: Text(_unread > 99 ? '99+' : '$_unread'),
              child: Icon(Icons.notifications_none, color: c.text),
            ),
            onPressed: () => _push(const AndroidNotificationsScreen()),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(onRefresh: _load, child: _body(context)),
    );
  }

  Widget _body(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    final profile = _profile;
    if (profile == null) {
      return ListView(children: [
        const SizedBox(height: 160),
        Center(
          child: _error == null
              ? const CircularProgressIndicator()
              : Column(children: [
                  Text(l10n.errorLoadingTrips,
                      style: TextStyle(color: c.textMuted)),
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: _load, child: Text(l10n.retry)),
                ]),
        ),
      ]);
    }

    final name = (profile.displayName?.isNotEmpty ?? false)
        ? profile.displayName!.split(' ').first
        : profile.username;
    if (AdaptiveLayout.isMobileWeb(context)) {
      return _mobileWebBody(context, name);
    }
    final live =
        _trips.where((t) => t.status == TripStatus.inProgress).firstOrNull;
    if (_trips.isEmpty) return _newUserBody(context, name, profile);

    final drafts = _trips.where((t) => t.status == TripStatus.created).toList();
    final finished =
        _trips.where((t) => t.status == TripStatus.finished).toList();
    final next = nextBadge(_allBadges, _unlockedIds, _trips,
        followers: profile.followersCount,
        friends: profile.friendsCount > 0
            ? profile.friendsCount
            : _friendIds.length);
    final tripCount =
        profile.tripsCount > _trips.length ? profile.tripsCount : _trips.length;
    const gap = SizedBox(height: 20);

    return ListView(
      // Bottom room for the shell's + button.
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 130),
      children: [
        _greeting(c, homeGreeting(l10n, DateTime.now().hour, name),
            live != null ? l10n.homeSubtitleLive : l10n.homeSubtitleIdle),
        gap,
        if (live != null) ...[
          HomeLiveTripCard(
            trip: live,
            checkingIn: _checkingIn,
            onCheckIn: () => _checkIn(live),
            onOpen: () => _push(TripDetailScreen(trip: live)),
          ),
          const SizedBox(height: 18),
          Row(children: [
            HomeStat('$tripCount', l10n.trips),
            const SizedBox(width: 10),
            HomeStat('${drafts.length}', l10n.homeDrafts),
            const SizedBox(width: 10),
            HomeStat('$_badges', l10n.homeBadges),
          ]),
        ] else
          Row(children: [
            Expanded(
              child: _bigButton(
                key: const Key('home_start_trip'),
                icon: Icons.play_arrow_rounded,
                label: l10n.homeStartTrip,
                primary: true,
                onTap: () => _push(const CreateTripScreen()),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _bigButton(
                key: const Key('home_plan_trip'),
                icon: Icons.map_outlined,
                label: l10n.homePlanOne,
                onTap: () => _push(const CreateTripPlanScreen()),
              ),
            ),
          ]),
        if (drafts.isNotEmpty) ...[
          gap,
          HomeSectionTitle(l10n.homePickUp,
              action: l10n.exploreFilterAll,
              onAction: () =>
                  AndroidShell.selectTab(context, AndroidTab.trips)),
          for (final d in drafts.take(3)) ...[
            const SizedBox(height: 10),
            _DraftRow(trip: d, onTap: () => _push(TripDetailScreen(trip: d))),
          ],
        ],
        if (live != null || _friendTrips.isNotEmpty) ...[
          gap,
          HomeSectionTitle(l10n.homeFriendsOnRoad),
          const SizedBox(height: 4),
          if (_friendTrips.isEmpty)
            _FriendsEmpty(_friendIds.isEmpty
                ? l10n.homeNoFriends
                : l10n.homeNoFriendsLive)
          else
            for (final t in _friendTrips) ...[
              ExploreTripRow(
                thumbnailUrl: t.thumbnailUrl,
                thumbSize: 52,
                title: Text(t.name),
                subtitle: Row(children: [
                  Pill.status(context, t.status),
                  const SizedBox(width: 8),
                  Flexible(
                      child: Text('@${t.username}',
                          overflow: TextOverflow.ellipsis)),
                ]),
                onTap: () => _push(TripDetailScreen(trip: t)),
              ),
              const SizedBox(height: 10),
            ],
        ],
        if (finished.isNotEmpty) ...[
          gap,
          HomeSectionTitle(l10n.homeRecentTrips,
              action: l10n.homeAllN(tripCount),
              onAction: () =>
                  AndroidShell.selectTab(context, AndroidTab.trips)),
          const SizedBox(height: 4),
          HomeTripCarousel(
            trips: finished.take(8).toList(),
            subtitle: (t) => _tripLine(l10n, t),
            onTap: (t) => _push(TripDetailScreen(trip: t)),
          ),
        ],
        gap,
        HomeSectionTitle(l10n.homeFriendsLately,
            action: _activity.isEmpty ? null : l10n.homeSeeAll,
            onAction: () => _push(const AndroidNotificationsScreen())),
        const SizedBox(height: 4),
        if (_activity.isEmpty)
          _FriendsEmpty(_friendIds.isEmpty
              ? l10n.homeNoFriends
              : l10n.homeNoFriendsActivity)
        else
          HomeFriendsActivity(items: _activity, onTap: _openActivity),
        if (next != null) ...[
          gap,
          HomeSectionTitle(l10n.homeNextBadge,
              action:
                  _allBadges.isEmpty ? null : l10n.homeAllN(_allBadges.length),
              onAction: _openBadges),
          const SizedBox(height: 4),
          HomeNextBadge(
              achievement: next.achievement,
              value: next.value,
              onTap: _openBadges),
        ],
        if (live == null) ..._yearSection(c, l10n),
        if (live == null && _publicTrips.isNotEmpty) ...[
          gap,
          HomeSectionTitle(l10n.homeTrending,
              action: l10n.explore,
              onAction: () =>
                  AndroidShell.selectTab(context, AndroidTab.explore)),
          const SizedBox(height: 4),
          _publicRow(_publicTrips.first),
        ],
      ],
    );
  }

  /// Brand-new user (no trips yet): checklist, first-trip CTA, other
  /// people's trips for inspiration, the first badge and an invite.
  Widget _newUserBody(BuildContext context, String name, UserProfile profile) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    const gap = SizedBox(height: 20);
    bool unlocked(AchievementType type) =>
        _allBadges.any((a) => a.type == type && _unlockedIds.contains(a.id));
    final steps = [
      HomeChecklistStep(l10n.homeStepAccount, done: true, onTap: () {}),
      HomeChecklistStep(l10n.homeStepProfile,
          done: unlocked(AchievementType.profileCompleted),
          onTap: () => AndroidShell.selectTab(context, AndroidTab.you)),
      HomeChecklistStep(l10n.homeStepFirstTrip,
          done: false, onTap: () => _push(const CreateTripScreen())),
      HomeChecklistStep(l10n.homeStepFriend,
          done: _friendIds.isNotEmpty ||
              _followsSomeone ||
              profile.followingCount > 0,
          onTap: () => _push(const AndroidSearchScreen())),
      if (!kIsWeb)
        HomeChecklistStep(l10n.homeStepNotifications, done: _notificationsOn,
            onTap: () async {
          await NotificationService().requestPermission();
          _load();
        }),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 130),
      children: [
        _greeting(c, l10n.homeWelcomeNew(name), l10n.homeSubtitleNew),
        gap,
        HomeGetStarted(steps: steps),
        gap,
        _bigButton(
          key: const Key('home_first_trip'),
          icon: Icons.play_arrow_rounded,
          label: l10n.homeStartFirstTrip,
          primary: true,
          onTap: () => _push(const CreateTripScreen()),
        ),
        if (_publicTrips.isNotEmpty) ...[
          gap,
          HomeSectionTitle(l10n.homeGetInspired,
              action: l10n.explore,
              onAction: () =>
                  AndroidShell.selectTab(context, AndroidTab.explore)),
          const SizedBox(height: 4),
          HomeTripCarousel(
            trips: _publicTrips.take(8).toList(),
            subtitle: (t) => ['@${t.username}', _tripLine(l10n, t)]
                .where((s) => s.isNotEmpty)
                .join(' · '),
            onTap: (t) => _push(TripDetailScreen(trip: t)),
          ),
        ],
        gap,
        HomeSectionTitle(l10n.homeFirstBadge),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: WandererTheme.cardDecoration(context, radius: 18),
          child: Row(children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: c.raised,
                shape: BoxShape.circle,
                border: Border.all(color: c.line, width: 2),
              ),
              child: Icon(Icons.lock_outline, size: 22, color: c.caption),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.welcomeArtFirstTrip,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: c.text)),
                  const SizedBox(height: 2),
                  Text(l10n.homeFirstBadgeBody,
                      style: TextStyle(fontSize: 13, color: c.caption)),
                ],
              ),
            ),
          ]),
        ),
        gap,
        Material(
          color: c.forestBg,
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: const Key('home_invite'),
            onTap: _invite,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Icon(Icons.group_add_outlined, color: c.forestFg),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(l10n.homeInviteBody,
                      style: TextStyle(
                          fontSize: 14, height: 1.4, color: c.forestFg)),
                ),
                const SizedBox(width: 8),
                Text(l10n.homeInvite,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: c.forestFg)),
              ]),
            ),
          ),
        ),
      ],
    );
  }

  /// Mobile web keeps its own Home: tracking happens in the app.
  Widget _mobileWebBody(BuildContext context, String name) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
      children: [
        _greeting(
            c,
            homeGreeting(l10n, DateTime.now().hour, name),
            _trips.isEmpty
                ? l10n.dashboardSubtitleEmpty
                : l10n.homeSubtitleIdle),
        const SizedBox(height: 18),
        const MobileWebTrackingCard(),
        const SizedBox(height: 18),
        Row(children: [
          HomeStat('${_trips.length}', l10n.trips),
          const SizedBox(width: 10),
          HomeStat('$_badges', l10n.homeBadges),
          const SizedBox(width: 10),
          HomeStat('${_friendIds.length}', l10n.friends),
        ]),
        const SizedBox(height: 18),
        ExploreSectionTitle(l10n.mobileWebLatestTrip,
            action: l10n.exploreFilterAll,
            onAction: () => AndroidShell.selectTab(context, AndroidTab.trips)),
        if (_trips.isNotEmpty)
          MobileWebTripCard(
              trip: _trips.first,
              onTap: () => _push(TripDetailScreen(trip: _trips.first))),
      ],
    );
  }

  Widget _greeting(WandererColors c, String title, String subtitle) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: WandererTheme.display(28, color: c.text)),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(fontSize: 15, color: c.textMuted)),
          ],
        ),
      );

  Widget _bigButton(
      {required Key key,
      required IconData icon,
      required String label,
      required VoidCallback onTap,
      bool primary = false}) {
    final c = WandererTheme.of(context);
    final shape =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));
    final child = Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 20),
      const SizedBox(width: 8),
      Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
    ]);
    const text = TextStyle(fontSize: 15, fontWeight: FontWeight.w700);
    return SizedBox(
      height: 52,
      child: primary
          ? FilledButton(
              key: key,
              onPressed: onTap,
              style: FilledButton.styleFrom(
                  backgroundColor: WandererTheme.trail,
                  foregroundColor: Colors.white,
                  textStyle: text,
                  shape: shape),
              child: child)
          : OutlinedButton(
              key: key,
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                  backgroundColor: c.surface,
                  foregroundColor: c.text,
                  side: BorderSide(color: c.line),
                  textStyle: text,
                  shape: shape),
              child: child),
    );
  }

  /// "2115 km · 45 days · 97 comments", skipping what is zero.
  String _tripLine(AppLocalizations l10n, Trip t) {
    final km = t.accruedDistanceKm ?? 0;
    final days = tripDaysOut(t);
    return [
      if (km > 0) l10n.achievementKm(km.roundToDouble()),
      if (days > 0) l10n.achievementDays(days),
      if (t.commentsCount > 0) l10n.commentsCount(t.commentsCount),
    ].join(' · ');
  }

  /// "Your 2026": trips started this year, distance and days out.
  List<Widget> _yearSection(WandererColors c, AppLocalizations l10n) {
    final year = DateTime.now().year;
    final trips = _trips
        .where((t) =>
            t.status != TripStatus.created &&
            (t.startDate ?? t.createdAt).year == year)
        .toList();
    if (trips.isEmpty) return const [];
    final km = trips.fold(0.0, (s, t) => s + (t.accruedDistanceKm ?? 0));
    final days = trips.fold(0, (s, t) => s + tripDaysOut(t));
    return [
      const SizedBox(height: 20),
      HomeSectionTitle(l10n.homeYourYear(year)),
      const SizedBox(height: 4),
      Row(children: [
        HomeStat('${trips.length}', l10n.trips),
        const SizedBox(width: 10),
        HomeStat(l10n.achievementKm(km.roundToDouble()), l10n.homeTraveled),
        const SizedBox(width: 10),
        HomeStat('$days', l10n.homeDaysOut),
      ]),
    ];
  }

  Widget _publicRow(Trip t) => ExploreTripRow(
        thumbnailUrl: t.thumbnailUrl,
        title: Text(t.name),
        subtitle: Row(children: [
          Pill.status(context, t.status),
          const SizedBox(width: 8),
          Flexible(
              child: Text('@${t.username}', overflow: TextOverflow.ellipsis)),
        ]),
        onTap: () => _push(TripDetailScreen(trip: t)),
      );

  void _openActivity(NotificationDto n) {
    final rid = n.referenceId;
    final trip = rid != null &&
        (n.type == NotificationType.commentOnTrip ||
            n.type == NotificationType.tripStatusChanged ||
            n.type == NotificationType.tripUpdatePosted);
    _push(trip
        ? TripDeepLinkScreen(
            tripId: rid,
            focusLatestUpdate: n.type == NotificationType.tripUpdatePosted)
        : const AndroidNotificationsScreen());
  }

  Future<void> _openBadges() async {
    await AuthNavigationHelper.navigateToAchievements(context);
    if (mounted) _load();
  }

  Future<void> _invite() async {
    final l10n = context.l10n;
    await Clipboard.setData(ClipboardData(
        text: 'https://play.google.com/store/apps/details?id='
            '${AndroidAppLinks.packageName}'));
    Toasts.show(
        ToastData(kind: ToastKind.success, title: l10n.homeInviteCopied));
  }
}

class _DraftRow extends StatelessWidget {
  final Trip trip;
  final VoidCallback onTap;
  const _DraftRow({required this.trip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    final vis = switch (trip.visibility) {
      Visibility.public => l10n.publicVisibility,
      Visibility.protected => l10n.friends,
      Visibility.private => l10n.privateVisibility,
    };
    return Material(
      color: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: c.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                  color: c.neutralBg, borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.edit_outlined, size: 20, color: c.textMuted),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(trip.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: c.text)),
                  const SizedBox(height: 2),
                  Text('${l10n.draft} · $vis',
                      style: TextStyle(fontSize: 13, color: c.caption)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: c.label),
          ]),
        ),
      ),
    );
  }
}

class _FriendsEmpty extends StatelessWidget {
  final String text;
  const _FriendsEmpty(this.text);

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: WandererTheme.cardDecoration(context, radius: 16),
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: c.forestBg, shape: BoxShape.circle),
          child:
              Icon(Icons.person_add_alt_outlined, size: 20, color: c.forestFg),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(text,
              style: TextStyle(fontSize: 14, color: c.textMuted, height: 1.4)),
        ),
      ]),
    );
  }
}
