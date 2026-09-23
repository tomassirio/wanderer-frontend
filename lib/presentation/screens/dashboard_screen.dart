import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:wanderer_frontend/core/constants/api_endpoints.dart';
import 'package:wanderer_frontend/core/constants/enums.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/providers/app_providers.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/data/models/domain/comment.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/data/repositories/dashboard_repository.dart';
import 'package:wanderer_frontend/presentation/helpers/avatar_helper.dart';
import 'package:wanderer_frontend/presentation/helpers/dialog_helper.dart';
import 'package:wanderer_frontend/presentation/helpers/page_transitions.dart';
import 'package:wanderer_frontend/presentation/helpers/ui_helpers.dart';
import 'package:wanderer_frontend/presentation/screens/achievements_screen.dart';
import 'package:wanderer_frontend/presentation/screens/create_trip_screen.dart';
import 'package:wanderer_frontend/presentation/screens/friends_followers_screen.dart';
import 'package:wanderer_frontend/presentation/screens/initial_screen.dart';
import 'package:wanderer_frontend/presentation/screens/profile_screen.dart';
import 'package:wanderer_frontend/presentation/screens/settings_screen.dart';
import 'package:wanderer_frontend/presentation/screens/trip_detail_screen.dart';
import 'package:wanderer_frontend/presentation/widgets/achievements/achievement_dialog.dart';
import 'package:wanderer_frontend/presentation/widgets/common/app_sidebar.dart';
import 'package:wanderer_frontend/presentation/widgets/common/cached_trip_thumbnail.dart';
import 'package:wanderer_frontend/presentation/widgets/common/pill.dart';
import 'package:wanderer_frontend/presentation/widgets/common/wanderer_app_bar.dart';
import 'package:wanderer_frontend/presentation/widgets/common/wanderer_scaffold.dart';
import 'package:wanderer_frontend/presentation/widgets/common/web_page_header.dart';

/// Web home after login: greeting, stats, latest trip, friend requests,
/// achievements, recent comments and the user's trips.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  late final DashboardRepository _repository;
  DashboardData? _data;
  Object? _error;
  bool _isAdmin = false;
  String? _userId;
  String? _username;
  String? _displayName;
  String? _avatarUrl;
  final Set<String> _busyRequests = {};

  @override
  void initState() {
    super.initState();
    _repository = ref.read(dashboardRepositoryProvider);
    _loadUser();
    _load();
  }

  Future<void> _loadUser() async {
    final home = ref.read(homeRepositoryProvider);
    final results = await Future.wait([
      home.getCurrentUserId(),
      home.getCurrentUsername(),
      home.getCurrentDisplayName(),
      home.getCurrentAvatarUrl(),
    ]);
    final isAdmin = await home.isAdmin();
    if (!mounted) return;
    setState(() {
      _userId = results[0];
      _username = results[1];
      _displayName = results[2];
      _avatarUrl = results[3];
      _isAdmin = isAdmin;
    });
  }

  Future<void> _load() async {
    try {
      final data = await _repository.load();
      if (mounted) {
        setState(() {
          _data = data;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _logout() async {
    if (!await DialogHelper.showLogoutConfirmation(context)) return;
    await ref.read(homeRepositoryProvider).logout();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        PageTransitions.fade(const InitialScreen()),
        (_) => false,
      );
    }
  }

  Future<void> _push(Widget screen) async {
    await Navigator.push(context, PageTransitions.slideFromRight(screen));
    if (mounted) _load();
  }

  Future<void> _answerRequest(DashboardFriendRequest r, bool accept) async {
    final l10n = context.l10n;
    setState(() => _busyRequests.add(r.request.id));
    try {
      if (accept) {
        await _repository.acceptFriendRequest(r.request.id);
      } else {
        await _repository.declineFriendRequest(r.request.id);
      }
      if (!mounted) return;
      UiHelpers.showSuccessMessage(
          context,
          accept
              ? l10n.friendRequestAcceptedMsg
              : l10n.friendRequestDeclinedMsg);
      await _load();
    } catch (e) {
      if (mounted) {
        UiHelpers.showErrorMessage(
            context,
            accept
                ? l10n.failedToAcceptFriendRequest(e.toString())
                : l10n.failedToDeclineFriendRequest(e.toString()));
      }
    } finally {
      if (mounted) setState(() => _busyRequests.remove(r.request.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return WandererScaffold(
      hideAppBarWithSidebar: true,
      appBar: WandererAppBar(
        isLoggedIn: true,
        username: _username,
        userId: _userId,
        displayName: _displayName,
        avatarUrl: _avatarUrl,
        onProfile: () => _push(const ProfileScreen()),
        onSettings: () => Navigator.push(
            context, PageTransitions.slideFromBottom(const SettingsScreen())),
        onLogout: _logout,
      ),
      drawer: AppSidebar(
        username: _username,
        userId: _userId,
        displayName: _displayName,
        avatarUrl: _avatarUrl,
        selectedIndex: AppSidebar.dashboardIndex,
        onLogout: _logout,
        isAdmin: _isAdmin,
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final l10n = context.l10n;
    final data = _data;
    if (data == null && _error == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (data == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.errorLoadingTrips),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: _load, child: Text(l10n.retry)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: LayoutBuilder(builder: (context, constraints) {
        final c = WandererTheme.of(context);
        final wide = constraints.maxWidth >= 1000;
        final gutter = constraints.maxWidth >= 720 ? 40.0 : 16.0;
        final sideColumn = [
          _FriendRequestsCard(
            data: data,
            busy: _busyRequests,
            onAnswer: _answerRequest,
            onSeeAll: () => _push(const FriendsFollowersScreen()),
          ),
          const SizedBox(height: 24),
          _AchievementsCard(
            data: data,
            onSeeAll: () => _push(const AchievementsScreen()),
          ),
        ];
        final latest = data.latestTrip == null
            ? _Panel(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(l10n.noTripsDashboard,
                      style: TextStyle(color: c.textMuted)),
                ),
              )
            : _LatestTripCard(
                trip: data.latestTrip!,
                achievements: data.latestTripAchievements,
                onOpen: () => _push(TripDetailScreen(trip: data.latestTrip!)),
              );
        final activity =
            _ActivityCard(comments: data.recentComments, data: data);
        final trips = _TripsCard(
          data: data,
          onOpen: (t) => _push(TripDetailScreen(trip: t)),
          onSeeAll: () => _push(const ProfileScreen()),
        );

        return ListView(
          padding: EdgeInsets.fromLTRB(gutter, 28, gutter, 40),
          children: [
            _Header(
              data: data,
              onStartTrip: () => _push(const CreateTripScreen()),
            ),
            const SizedBox(height: 24),
            _StatStrip(data: data, compact: !wide),
            const SizedBox(height: 24),
            if (wide)
              // No IntrinsicHeight: the latest-trip card uses LayoutBuilder.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: latest),
                  const SizedBox(width: 24),
                  SizedBox(
                    width: 360,
                    child: Column(children: sideColumn),
                  ),
                ],
              )
            else ...[
              latest,
              const SizedBox(height: 24),
              ...sideColumn,
            ],
            const SizedBox(height: 24),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: activity),
                  const SizedBox(width: 24),
                  Expanded(child: trips),
                ],
              )
            else ...[
              activity,
              const SizedBox(height: 24),
              trips,
            ],
          ],
        );
      }),
    );
  }
}

// ---------------------------------------------------------------------------
// Sections
// ---------------------------------------------------------------------------

String _km(BuildContext context, double km, {int decimals = 0}) {
  final format = NumberFormat.decimalPatternDigits(
    locale: Localizations.localeOf(context).toString(),
    decimalDigits: decimals,
  );
  return context.l10n.kmValue(format.format(km));
}

int? _tripDays(Trip trip) {
  final start = trip.startDate;
  if (start == null) return null;
  final end = trip.endDate ?? DateTime.now();
  return end.difference(start).inDays + 1;
}

class _Header extends StatelessWidget {
  final DashboardData data;
  final VoidCallback onStartTrip;

  const _Header({required this.data, required this.onStartTrip});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final name = (data.profile.displayName?.isNotEmpty ?? false)
        ? data.profile.displayName!.split(' ').first
        : data.profile.username;
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? l10n.greetingMorning(name)
        : hour < 18
            ? l10n.greetingAfternoon(name)
            : l10n.greetingEvening(name);
    final latest = data.latestTrip;
    final subtitle = latest == null
        ? l10n.dashboardSubtitleEmpty
        : latest.status == TripStatus.inProgress
            ? l10n.dashboardSubtitleLive(latest.name)
            : l10n.dashboardSubtitleFinished(latest.name);

    return WebPageHeader(
      title: greeting,
      subtitle: subtitle,
      userId: data.profile.id,
      primaryAction: ElevatedButton.icon(
        onPressed: onStartTrip,
        icon: const Icon(Icons.add, size: 18),
        label: Text(l10n.startATrip),
      ),
    );
  }
}

class _StatStrip extends StatelessWidget {
  final DashboardData data;
  final bool compact;

  const _StatStrip({required this.data, required this.compact});

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    final stats = [
      (
        Icons.map_outlined,
        c.trailSoftBg,
        c.trailSoftFg,
        '${data.trips.length}',
        l10n.trips
      ),
      (
        Icons.emoji_events_outlined,
        c.goldBg,
        c.goldFg,
        '${data.achievements.length}',
        l10n.achievements
      ),
      (
        Icons.people_outline,
        c.forestBg,
        c.forestFg,
        '${data.profile.friendsCount}',
        l10n.friends
      ),
      (
        Icons.place_outlined,
        c.skyBg,
        c.skyFg,
        _km(context, data.longestTripKm),
        l10n.longestTrip
      ),
    ];
    final tiles = [
      for (final (icon, bg, fg, value, label) in stats)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: fg),
              ),
              const SizedBox(width: 14),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: WandererTheme.display(26)),
                    const SizedBox(height: 4),
                    Text(label,
                        style: TextStyle(fontSize: 13, color: c.caption)),
                  ],
                ),
              ),
            ],
          ),
        ),
    ];

    return Container(
      decoration: WandererTheme.cardDecoration(context, radius: 16),
      child: compact
          ? GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              childAspectRatio: 2.6,
              physics: const NeverScrollableScrollPhysics(),
              children: tiles,
            )
          : IntrinsicHeight(
              child: Row(
                children: [
                  for (var i = 0; i < tiles.length; i++) ...[
                    if (i > 0) VerticalDivider(width: 1, color: c.lineSoft),
                    Expanded(child: tiles[i]),
                  ],
                ],
              ),
            ),
    );
  }
}

/// White panel with a 1px border, optional title row and "see all" link.
class _Panel extends StatelessWidget {
  final String? title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? trailing;
  final Widget child;
  final EdgeInsets padding;

  const _Panel({
    this.title,
    this.actionLabel,
    this.onAction,
    this.trailing,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: WandererTheme.cardDecoration(context),
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null) ...[
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(title!,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
                if (trailing != null) trailing!,
                if (actionLabel != null)
                  TextButton(
                    onPressed: onAction,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      textStyle: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    child: Text(actionLabel!),
                  ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          child,
        ],
      ),
    );
  }
}

class _LatestTripCard extends StatelessWidget {
  final Trip trip;
  final int achievements;
  final VoidCallback onOpen;

  const _LatestTripCard({
    required this.trip,
    required this.achievements,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    final days = _tripDays(trip);
    final visibility = switch (trip.visibility) {
      Visibility.public => (Icons.public, l10n.publicVisibility),
      Visibility.protected => (Icons.group_outlined, l10n.protectedVisibility),
      Visibility.private => (Icons.lock_outline, l10n.privateVisibility),
    };
    final stats = [
      (
        l10n.categoryDistance,
        _km(context, trip.accruedDistanceKm ?? 0, decimals: 1)
      ),
      (l10n.categoryDuration, days == null ? '—' : l10n.daysCount(days)),
      (l10n.comments, '${trip.commentsCount}'),
      (l10n.achievements, l10n.achievementsEarnedCount(achievements)),
    ];

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: WandererTheme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 290,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedTripThumbnail(
                  thumbnailUrl: trip.thumbnailUrl,
                  placeholder: Container(color: c.mapGround),
                  errorWidget: Container(
                    color: c.mapGround,
                    child: Icon(Icons.route, size: 48, color: c.label),
                  ),
                ),
                Positioned(
                  top: 16,
                  left: 16,
                  child: Wrap(spacing: 8, children: [
                    Pill.status(context, trip.status, onImage: true),
                    if (trip.isPromoted)
                      Pill(l10n.promoted,
                          tone: PillTone.onImage,
                          foregroundTone: PillTone.promoted),
                  ]),
                ),
                Positioned(
                  top: 16,
                  right: 16,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xC71B1A17),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(l10n.latestTrip,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(trip.name, style: WandererTheme.display(24)),
                          const SizedBox(height: 6),
                          Row(children: [
                            Icon(visibility.$1, size: 14, color: c.caption),
                            const SizedBox(width: 4),
                            Text(visibility.$2,
                                style:
                                    TextStyle(fontSize: 13, color: c.caption)),
                          ]),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    OutlinedButton.icon(
                      onPressed: onOpen,
                      iconAlignment: IconAlignment.end,
                      icon: const Icon(Icons.arrow_forward, size: 16),
                      label: Text(l10n.viewTrip),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                LayoutBuilder(builder: (context, box) {
                  final perRow = box.maxWidth >= 520 ? 4 : 2;
                  final w = (box.maxWidth - 12 * (perRow - 1)) / perRow;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final (label, value) in stats)
                        Container(
                          width: w,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: c.raised,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(label,
                                  style: TextStyle(
                                      fontSize: 12, color: c.caption)),
                              const SizedBox(height: 2),
                              Text(value,
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                    ],
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Initials extends StatelessWidget {
  final String text;
  final Color background;
  final Color foreground;
  final String? imageUrl;

  const _Initials(this.text,
      {required this.background, required this.foreground, this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final hasUrl = imageUrl != null && imageUrl!.isNotEmpty;
    return CircleAvatar(
      radius: 18,
      backgroundColor: background,
      foregroundImage: hasUrl
          ? NetworkImage(ApiEndpoints.resolveThumbnailUrl(imageUrl))
          : null,
      onForegroundImageError: hasUrl ? (_, __) {} : null,
      child: Text(text,
          style: TextStyle(
              color: foreground, fontSize: 13, fontWeight: FontWeight.w700)),
    );
  }
}

class _FriendRequestsCard extends StatelessWidget {
  final DashboardData data;
  final Set<String> busy;
  final void Function(DashboardFriendRequest, bool accept) onAnswer;
  final VoidCallback onSeeAll;

  const _FriendRequestsCard({
    required this.data,
    required this.busy,
    required this.onAnswer,
    required this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    return _Panel(
      title: l10n.friendRequestsTitle,
      actionLabel: data.friendRequestCount > 0
          ? l10n.seeAllCount(data.friendRequestCount)
          : null,
      onAction: onSeeAll,
      child: data.friendRequests.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(l10n.noFriendRequests,
                  style: TextStyle(color: c.textMuted)),
            )
          : Column(
              children: [
                for (final r in data.friendRequests)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        _Initials(
                          AvatarHelper.getInitials(
                              r.sender.displayName, r.sender.username),
                          background: c.trailSoftBg,
                          foreground: c.accentText,
                          imageUrl: r.sender.avatarUrl,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(r.sender.username,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w600)),
                        ),
                        // Neutral dark: the orange is reserved for the page's
                        // main action.
                        FilledButton(
                          onPressed: busy.contains(r.request.id)
                              ? null
                              : () => onAnswer(r, true),
                          style: FilledButton.styleFrom(
                            backgroundColor: c.neutralButtonBg,
                            foregroundColor: c.neutralButtonFg,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            textStyle: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                          child: Text(l10n.acceptRequest),
                        ),
                        const SizedBox(width: 6),
                        IconButton.outlined(
                          tooltip: l10n.declineRequest,
                          onPressed: busy.contains(r.request.id)
                              ? null
                              : () => onAnswer(r, false),
                          style: IconButton.styleFrom(
                            side: BorderSide(color: c.line),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: Icon(Icons.close, size: 16, color: c.textMuted),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

class _AchievementsCard extends StatelessWidget {
  final DashboardData data;
  final VoidCallback onSeeAll;

  const _AchievementsCard({required this.data, required this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    final recent = data.recentAchievements.take(3).toList();
    return _Panel(
      title: l10n.recentAchievements,
      actionLabel: data.achievements.isEmpty
          ? null
          : l10n.allCount(data.achievements.length),
      onAction: onSeeAll,
      child: recent.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(l10n.noAchievementsDashboard,
                  style: TextStyle(color: c.textMuted)),
            )
          : Row(
              children: [
                for (var i = 0; i < recent.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(
                    child: InkWell(
                      borderRadius:
                          BorderRadius.circular(WandererTheme.radiusCard),
                      onTap: () => showAchievementDialog(
                          context, recent[i].achievement,
                          unlocked: recent[i],
                          shareUsername: data.profile.username),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 14),
                        decoration: BoxDecoration(
                          color: c.goldBg,
                          borderRadius:
                              BorderRadius.circular(WandererTheme.radiusCard),
                          border: Border.all(color: c.line),
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: const BoxDecoration(
                                color: Color(0xFFF5B83D),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.emoji_events_outlined,
                                  size: 20, color: Color(0xFF5B3A00)),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              l10n.achievementNameFor(
                                  recent[i].achievement.type.toJson()),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final List<Comment> comments;
  final DashboardData data;

  const _ActivityCard({required this.comments, required this.data});

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    final tripNames = {for (final t in data.trips) t.id: t.name};
    final dateFormat =
        DateFormat.yMd(Localizations.localeOf(context).toString());
    return _Panel(
      title: l10n.recentActivity,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      trailing: Text(l10n.onYourTrips,
          style: TextStyle(fontSize: 13, color: c.caption)),
      child: comments.isEmpty
          ? Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 16),
              child: Text(l10n.noRecentActivity,
                  style: TextStyle(color: c.textMuted)),
            )
          : Column(
              children: [
                for (var i = 0; i < comments.length; i++)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      border: i == comments.length - 1
                          ? null
                          : Border(bottom: BorderSide(color: c.lineSoft)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Initials(
                          AvatarHelper.getInitials(null, comments[i].username),
                          background: c.skyBg,
                          foreground: c.skyFg,
                          imageUrl: comments[i].userAvatarUrl,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text.rich(
                                TextSpan(children: [
                                  TextSpan(
                                      text: '@${comments[i].username} ',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700)),
                                  TextSpan(
                                    text: l10n.commentedOn(
                                        tripNames[comments[i].tripId] ?? ''),
                                    style: TextStyle(color: c.textMuted),
                                  ),
                                ]),
                                style: const TextStyle(fontSize: 14),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: c.raised,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(comments[i].message,
                                    style: const TextStyle(fontSize: 14)),
                              ),
                              const SizedBox(height: 6),
                              Text(dateFormat.format(comments[i].createdAt),
                                  style:
                                      TextStyle(fontSize: 12, color: c.label)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

class _TripsCard extends StatelessWidget {
  final DashboardData data;
  final void Function(Trip) onOpen;
  final VoidCallback onSeeAll;

  const _TripsCard({
    required this.data,
    required this.onOpen,
    required this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    return _Panel(
      title: l10n.yourTrips,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      actionLabel:
          data.trips.isEmpty ? null : l10n.viewAllCount(data.trips.length),
      onAction: onSeeAll,
      child: data.trips.isEmpty
          ? Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 12),
              child:
                  Text(l10n.noTripsYet, style: TextStyle(color: c.textMuted)),
            )
          : Column(
              children: [
                for (final trip in data.trips.take(4))
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => onOpen(trip),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: CachedTripThumbnail(
                              thumbnailUrl: trip.thumbnailUrl,
                              width: 64,
                              height: 48,
                              placeholder: Container(
                                  width: 64, height: 48, color: c.mapGround),
                              errorWidget: Container(
                                  width: 64, height: 48, color: c.mapGround),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(trip.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700)),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 8,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Pill.status(context, trip.status),
                                    Text(
                                      '${switch (trip.visibility) {
                                        Visibility.public =>
                                          l10n.publicVisibility,
                                        Visibility.protected =>
                                          l10n.protectedVisibility,
                                        Visibility.private =>
                                          l10n.privateVisibility,
                                      }} · ${l10n.commentsCount(trip.commentsCount)}',
                                      style: TextStyle(
                                          fontSize: 12, color: c.caption),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right, size: 18, color: c.label),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
