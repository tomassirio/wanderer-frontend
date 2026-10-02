import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:wanderer_frontend/presentation/helpers/adaptive_layout.dart';
import 'package:wanderer_frontend/presentation/widgets/mobile_web/app_handoff.dart';
import 'package:wanderer_frontend/presentation/widgets/mobile_web/mobile_web_trip_card.dart';
import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:wanderer_frontend/core/constants/enums.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/providers/app_providers.dart';
import 'package:wanderer_frontend/core/services/background_update_manager.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/data/models/domain/user_profile.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/presentation/helpers/location_permission_disclosure.dart';
import 'package:wanderer_frontend/presentation/helpers/page_transitions.dart';
import 'package:wanderer_frontend/presentation/screens/android/android_notifications_screen.dart';
import 'package:wanderer_frontend/presentation/screens/android/android_search_screen.dart';
import 'package:wanderer_frontend/presentation/screens/android/android_shell.dart';
import 'package:wanderer_frontend/presentation/screens/trip_detail_screen.dart';
import 'package:wanderer_frontend/presentation/widgets/android/explore_widgets.dart';
import 'package:wanderer_frontend/presentation/widgets/android/home_live_trip_card.dart';
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
  Set<String> _friendIds = const {};
  List<Trip> _friendTrips = const [];
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
      final unreadF =
          _optional(ref.read(notificationApiServiceProvider).getUnreadCount());

      final profile = await profileF;
      final trips = [...(await tripsF).content]
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      final friendIds = await friendsF;
      final available = (await availableF)?.content ?? const <Trip>[];
      final badges = (await badgesF)?.length ?? 0;
      final unread = await unreadF;
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _trips = trips;
        _badges = badges;
        _friendIds = friendIds;
        _friendTrips = friendsOnTheRoad(available, friendIds);
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
    final live =
        _trips.where((t) => t.status == TripStatus.inProgress).firstOrNull;
    final drafts = _trips.where((t) => t.status == TripStatus.created).toList();
    final subtitle = live != null
        ? l10n.homeSubtitleLive
        : _trips.isEmpty
            ? l10n.dashboardSubtitleEmpty
            : l10n.homeSubtitleIdle;

    return ListView(
      // Bottom room for the shell's + button.
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(homeGreeting(l10n, DateTime.now().hour, name),
                  style: WandererTheme.display(28, color: c.text)),
              const SizedBox(height: 4),
              Text(subtitle,
                  style: TextStyle(fontSize: 15, color: c.textMuted)),
            ],
          ),
        ),
        if (AdaptiveLayout.isMobileWeb(context)) ...[
          const SizedBox(height: 18),
          const MobileWebTrackingCard(),
        ] else if (live != null) ...[
          const SizedBox(height: 18),
          HomeLiveTripCard(
            trip: live,
            checkingIn: _checkingIn,
            onCheckIn: () => _checkIn(live),
            onOpen: () => _push(TripDetailScreen(trip: live)),
          ),
        ],
        const SizedBox(height: 18),
        Row(children: [
          _Stat('${_trips.length}', l10n.trips),
          const SizedBox(width: 10),
          _Stat(
              AdaptiveLayout.isMobileWeb(context)
                  ? '$_badges'
                  : '${drafts.length}',
              AdaptiveLayout.isMobileWeb(context)
                  ? l10n.homeBadges
                  : l10n.homeDrafts),
          const SizedBox(width: 10),
          _Stat(
              AdaptiveLayout.isMobileWeb(context)
                  ? '${_friendIds.length}'
                  : '$_badges',
              AdaptiveLayout.isMobileWeb(context)
                  ? l10n.friends
                  : l10n.homeBadges),
        ]),
        if (AdaptiveLayout.isMobileWeb(context)) ...[
          const SizedBox(height: 18),
          ExploreSectionTitle(l10n.mobileWebLatestTrip,
              action: l10n.exploreFilterAll,
              onAction: () =>
                  AndroidShell.selectTab(context, AndroidTab.trips)),
          if (_trips.isNotEmpty)
            MobileWebTripCard(
                trip: _trips.first,
                onTap: () => _push(TripDetailScreen(trip: _trips.first))),
        ] else ...[
          if (drafts.isNotEmpty) ...[
            const SizedBox(height: 18),
            ExploreSectionTitle(
              l10n.homePickUp,
              action: l10n.exploreFilterAll,
              onAction: () => AndroidShell.selectTab(context, AndroidTab.trips),
            ),
            for (final d in drafts.take(3)) ...[
              const SizedBox(height: 10),
              _DraftRow(trip: d, onTap: () => _push(TripDetailScreen(trip: d))),
            ],
          ],
          const SizedBox(height: 18),
          ExploreSectionTitle(l10n.homeFriendsOnRoad),
          const SizedBox(height: 10),
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
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  const _Stat(this.value, this.label);

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: WandererTheme.cardDecoration(context, radius: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: WandererTheme.display(22, color: c.text)),
            Text(label, style: TextStyle(fontSize: 12, color: c.caption)),
          ],
        ),
      ),
    );
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
