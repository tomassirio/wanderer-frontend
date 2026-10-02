import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/providers/app_providers.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/data/client/api_client.dart';
import 'package:wanderer_frontend/data/models/notification_models.dart';
import 'package:wanderer_frontend/presentation/helpers/auth_navigation_helper.dart';
import 'package:wanderer_frontend/presentation/helpers/live_toast_bridge.dart';
import 'package:wanderer_frontend/presentation/helpers/page_transitions.dart';
import 'package:wanderer_frontend/presentation/screens/trip_deep_link_screen.dart';
import 'package:wanderer_frontend/presentation/widgets/android/android_ui.dart';

/// Quoted trip / achievement names inside a notification message.
final notificationQuoted = RegExp(r'"([^"]+)"');

/// "Just now", "5m", "3h", "2d", then the date.
String notificationAgo(AppLocalizations l10n, DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.isNegative || d.inMinutes < 1) return l10n.justNow;
  if (d.inHours < 1) return l10n.minutesAgoShort(d.inMinutes);
  if (d.inDays < 1) return l10n.hoursAgoShort(d.inHours);
  if (d.inDays <= 7) return l10n.daysAgoShort(d.inDays);
  return '${t.day}/${t.month}/${t.year}';
}

/// Actor name and quoted trip / achievement names in bold, rest muted.
InlineSpan notificationMessage(WandererColors c, NotificationDto n,
    {double fontSize = 15}) {
  final bold = TextStyle(fontWeight: FontWeight.w700, color: c.text);
  final spans = <InlineSpan>[];
  var rest = n.message;
  final space = rest.indexOf(' ');
  if (n.actorId != null && space > 0) {
    spans.add(TextSpan(text: rest.substring(0, space), style: bold));
    rest = rest.substring(space);
  }
  var last = 0;
  for (final m in notificationQuoted.allMatches(rest)) {
    spans.add(TextSpan(text: rest.substring(last, m.start)));
    spans.add(TextSpan(text: m.group(1), style: bold));
    last = m.end;
  }
  spans.add(TextSpan(text: rest.substring(last)));
  return TextSpan(
      style: TextStyle(fontSize: fontSize, height: 1.4, color: c.textMuted),
      children: spans);
}

bool _isTrip(NotificationDto n) =>
    n.referenceId != null &&
    (n.type == NotificationType.tripStatusChanged ||
        n.type == NotificationType.tripUpdatePosted);

/// Android grouping: consecutive achievements collapse into one item, and
/// every status change / update of the same trip joins the newest one.
List<List<NotificationDto>> groupAndroidNotifications(
    List<NotificationDto> items) {
  final groups = <List<NotificationDto>>[];
  final byTrip = <String, List<NotificationDto>>{};
  for (final n in items) {
    if (_isTrip(n)) {
      final g = byTrip[n.referenceId!];
      if (g != null) {
        g.add(n);
        continue;
      }
      groups.add(byTrip[n.referenceId!] = [n]);
      continue;
    }
    final prev = groups.isEmpty ? null : groups.last;
    if (prev != null &&
        n.type == NotificationType.achievementUnlocked &&
        prev.first.type == NotificationType.achievementUnlocked) {
      prev.add(n);
    } else {
      groups.add([n]);
    }
  }
  return groups;
}

/// Android notifications (canvas: AndroidNotifications), opened from the
/// Home bell. Pops `true` when something was read so the badge refreshes.
class AndroidNotificationsScreen extends ConsumerStatefulWidget {
  const AndroidNotificationsScreen({super.key});

  @override
  ConsumerState<AndroidNotificationsScreen> createState() =>
      _AndroidNotificationsScreenState();
}

class _AndroidNotificationsScreenState
    extends ConsumerState<AndroidNotificationsScreen> {
  final List<NotificationDto> _items = [];
  final Set<String> _answered = {};
  bool _loading = true, _loadingMore = false, _hasMore = false;
  bool _unreadOnly = false, _changed = false;
  String? _error;
  int _page = 0, _unread = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = ref.read(notificationApiServiceProvider);
    try {
      final page = await api.getMyNotifications(page: 0);
      final unread = await api.getUnreadCount();
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(page.content);
        _page = 0;
        _hasMore = !page.last;
        _unread = unread;
        _loading = false;
        _error = null;
      });
    } on AuthenticationRedirectException {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'auth';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'generic';
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final page = await ref
          .read(notificationApiServiceProvider)
          .getMyNotifications(page: _page + 1);
      if (!mounted) return;
      setState(() {
        _items.addAll(page.content);
        _page++;
        _hasMore = !page.last;
      });
    } catch (_) {
      // Keep what we have; the button stays for another try.
    }
    if (mounted) setState(() => _loadingMore = false);
  }

  NotificationDto _asRead(NotificationDto n) => NotificationDto(
        id: n.id,
        recipientId: n.recipientId,
        actorId: n.actorId,
        type: n.type,
        referenceId: n.referenceId,
        message: n.message,
        read: true,
        createdAt: n.createdAt,
      );

  Future<void> _markRead(List<NotificationDto> group) async {
    final api = ref.read(notificationApiServiceProvider);
    for (final n in group.where((n) => !n.read)) {
      try {
        await api.markAsRead(n.id);
        if (!mounted) return;
        setState(() {
          final i = _items.indexWhere((x) => x.id == n.id);
          if (i != -1) _items[i] = _asRead(n);
          _unread = max(0, _unread - 1);
          _changed = true;
        });
      } catch (_) {
        // Stays unread; harmless.
      }
    }
  }

  Future<void> _markAllRead() async {
    try {
      await ref.read(notificationApiServiceProvider).markAllAsRead();
      if (!mounted) return;
      setState(() {
        for (var i = 0; i < _items.length; i++) {
          _items[i] = _asRead(_items[i]);
        }
        _unread = 0;
        _changed = true;
      });
    } catch (_) {}
  }

  Future<void> _answer(NotificationDto n, bool accept) async {
    final id = n.referenceId!;
    setState(() => _answered.add(id));
    const actions = NotificationActions();
    await (accept
        ? actions.acceptFriendRequest(id)
        : actions.declineFriendRequest(id));
    _markRead([n]);
  }

  void _open(List<NotificationDto> group) {
    _markRead(group);
    final n = group.first;
    final rid = n.referenceId;
    switch (n.type) {
      case NotificationType.achievementUnlocked:
        AuthNavigationHelper.navigateToAchievements(context);
      case NotificationType.friendRequestReceived:
      case NotificationType.friendRequestDeclined:
        AuthNavigationHelper.navigateToFriendsFollowers(context);
      case NotificationType.friendRequestAccepted:
        if (n.actorId != null) {
          AuthNavigationHelper.navigateToUserProfile(context, n.actorId!);
        }
      case NotificationType.newFollower:
        if (rid != null) {
          AuthNavigationHelper.navigateToUserProfile(context, rid);
        }
      case NotificationType.commentOnTrip:
      case NotificationType.tripStatusChanged:
      case NotificationType.tripUpdatePosted:
        if (rid != null) {
          Navigator.push(context,
              PageTransitions.slideUp(TripDeepLinkScreen(tripId: rid)));
        }
      case NotificationType.replyToComment:
      case NotificationType.commentReaction:
        break;
    }
  }

  String _ago(DateTime t) => notificationAgo(context.l10n, t);

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        backgroundColor: c.ground,
        appBar: AndroidTopBar(
          title: l10n.notifications,
          actions: [
            if (_unread > 0)
              TextButton(
                onPressed: _markAllRead,
                style: TextButton.styleFrom(
                  foregroundColor: c.accentText,
                  textStyle: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700),
                ),
                child: Text(l10n.readAll),
              ),
            const SizedBox(width: 4),
          ],
        ),
        body: Column(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: c.line))),
            child: Row(children: [
              _tab(c, l10n.notifTabAll, false),
              const SizedBox(width: 24),
              _tab(c, l10n.notifTabUnread, true, count: _unread),
            ]),
          ),
          Expanded(child: _body(c, l10n)),
        ]),
      ),
    );
  }

  Widget _tab(WandererColors c, String label, bool unreadOnly,
      {int count = 0}) {
    final selected = _unreadOnly == unreadOnly;
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: () => setState(() => _unreadOnly = unreadOnly),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                  width: 3,
                  color: selected ? WandererTheme.trail : Colors.transparent),
            ),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: selected ? c.accentText : c.textMuted,
                )),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: BoxDecoration(
                    color: WandererTheme.trail,
                    borderRadius: BorderRadius.circular(999)),
                child: Text(count > 99 ? '99+' : '$count',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _body(WandererColors c, AppLocalizations l10n) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
              _error == 'auth'
                  ? l10n.pleaseLogInForNotifications
                  : l10n.failedToLoadNotifications,
              style: TextStyle(color: c.textMuted)),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: _load, child: Text(l10n.retry)),
        ]),
      );
    }
    final unread = _items.where((n) => !n.read).toList();
    final earlier = _unreadOnly
        ? <NotificationDto>[]
        : _items.where((n) => n.read).toList();
    if (unread.isEmpty && earlier.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.notifications_none, size: 48, color: c.caption),
            const SizedBox(height: 12),
            Text(l10n.noNotificationsYet,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: c.textMuted)),
            const SizedBox(height: 4),
            Text(l10n.notificationsWillAppear,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: c.caption)),
          ]),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ColoredBox(
        color: c.surface,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            if (unread.isNotEmpty) ...[
              _section(c, l10n.notifSectionNew),
              for (final g in groupAndroidNotifications(unread)) _item(c, g),
            ],
            if (earlier.isNotEmpty) ...[
              _section(c, l10n.notifSectionEarlier),
              for (final g in groupAndroidNotifications(earlier)) _item(c, g),
            ],
            if (_hasMore)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Center(
                  child: _loadingMore
                      ? const CircularProgressIndicator(strokeWidth: 2)
                      : TextButton(
                          onPressed: _loadMore,
                          style: TextButton.styleFrom(
                              foregroundColor: c.accentText),
                          child: Text(l10n.loadMoreNotifications),
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _section(WandererColors c, String label) => Container(
        color: c.ground,
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
        child: Text(label.toUpperCase(),
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.96,
                color: c.label)),
      );

  (IconData, Color, Color) _look(WandererColors c, NotificationType t) =>
      switch (t) {
        NotificationType.achievementUnlocked => (
            Icons.emoji_events_outlined,
            c.goldBg,
            c.goldFg
          ),
        NotificationType.tripStatusChanged ||
        NotificationType.tripUpdatePosted =>
          (Icons.hiking, c.skyBg, c.skyFg),
        NotificationType.friendRequestReceived => (
            Icons.person_add_alt,
            c.trailSoftBg,
            WandererTheme.trail
          ),
        NotificationType.friendRequestDeclined => (
            Icons.person_off_outlined,
            c.neutralBg,
            c.neutralFg
          ),
        NotificationType.friendRequestAccepted => (
            Icons.handshake_outlined,
            c.forestBg,
            c.forestFg
          ),
        NotificationType.newFollower => (
            Icons.person_add_alt,
            c.trailSoftBg,
            WandererTheme.trail
          ),
        NotificationType.commentOnTrip => (
            Icons.chat_bubble_outline,
            c.trailSoftBg,
            WandererTheme.trail
          ),
        NotificationType.replyToComment => (
            Icons.reply,
            c.trailSoftBg,
            WandererTheme.trail
          ),
        NotificationType.commentReaction => (
            Icons.favorite_border,
            c.trailSoftBg,
            WandererTheme.trail
          ),
      };

  InlineSpan _message(WandererColors c, NotificationDto n) =>
      notificationMessage(c, n);

  /// "Started the trip · Posted 2 updates" for the older items of a trip.
  String _tripSummary(List<NotificationDto> older) {
    final l10n = context.l10n;
    final updates =
        older.where((n) => n.type == NotificationType.tripUpdatePosted).length;
    final status =
        older.where((n) => n.type == NotificationType.tripStatusChanged);
    return [
      if (status.any((n) => n.message.contains(' started ')))
        l10n.notifTripStarted,
      if (status.any((n) => n.message.contains(' finished ')))
        l10n.notifTripFinished,
      if (updates == 1) l10n.notifTripOneUpdate,
      if (updates > 1) l10n.notifTripUpdates(updates),
    ].join(' · ');
  }

  Widget _item(WandererColors c, List<NotificationDto> group) {
    final l10n = context.l10n;
    final n = group.first;
    final unread = group.any((x) => !x.read);
    final (icon, bg, fg) = _look(c, n.type);
    final achievements =
        group.length > 1 && n.type == NotificationType.achievementUnlocked;
    final trip = _isTrip(n);
    final summary = trip ? _tripSummary(group.skip(1).toList()) : '';
    final showRequest = n.type == NotificationType.friendRequestReceived &&
        !n.read &&
        n.referenceId != null &&
        !_answered.contains(n.referenceId);

    return InkWell(
      onTap: () => _open(group),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: unread ? WandererTheme.trail.withAlpha(14) : null,
          border: Border(bottom: BorderSide(color: c.lineSoft)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: Icon(icon, size: 20, color: fg),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (achievements) ...[
                  Text(l10n.notifAchievementsUnlocked(group.length),
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: c.text)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    for (final a in group)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(
                            color: c.goldBg,
                            borderRadius: BorderRadius.circular(999)),
                        child: Text(
                            notificationQuoted
                                    .firstMatch(a.message)
                                    ?.group(1) ??
                                a.message,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: c.goldFg)),
                      ),
                  ]),
                ] else
                  Text.rich(_message(c, n),
                      maxLines: 3, overflow: TextOverflow.ellipsis),
                if (summary.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(summary,
                      style: TextStyle(fontSize: 13, color: c.textMuted)),
                ],
                if (trip) ...[
                  const SizedBox(height: 8),
                  Text('${l10n.viewTrip} →',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: c.accentText)),
                ],
                if (showRequest) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    FilledButton(
                      onPressed: () => _answer(n, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: WandererTheme.trail,
                        minimumSize: const Size(0, 40),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(l10n.acceptRequest),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () => _answer(n, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: c.text,
                        side: BorderSide(color: c.line),
                        minimumSize: const Size(0, 40),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(l10n.toastDecline),
                    ),
                  ]),
                ],
                const SizedBox(height: 4),
                Text(_ago(n.createdAt),
                    style: TextStyle(fontSize: 12, color: c.caption)),
              ],
            ),
          ),
          if (unread)
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(top: 8, left: 8),
              decoration: const BoxDecoration(
                  color: WandererTheme.trail, shape: BoxShape.circle),
            ),
        ]),
      ),
    );
  }
}
