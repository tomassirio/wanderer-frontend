import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/core/providers/app_providers.dart';
import 'package:wanderer_frontend/data/models/notification_models.dart';
import 'package:wanderer_frontend/data/models/responses/page_response.dart';
import 'package:wanderer_frontend/data/services/notification_api_service.dart';
import 'package:wanderer_frontend/data/client/api_client.dart';
import 'package:wanderer_frontend/presentation/helpers/auth_navigation_helper.dart';
import 'package:wanderer_frontend/presentation/helpers/live_toast_bridge.dart';
import 'package:wanderer_frontend/presentation/helpers/page_transitions.dart';
import 'package:wanderer_frontend/presentation/screens/settings_screen.dart';
import 'package:wanderer_frontend/presentation/screens/trip_deep_link_screen.dart';

/// Shows a notifications dropdown anchored below a given button.
///
/// Returns `true` if any notification was read (so the caller can refresh
/// the unread badge).
Future<bool> showNotificationsDropdown({
  required BuildContext context,
  required RelativeRect position,
}) async {
  final result = await Navigator.push<bool>(
    context,
    _NotificationsDropdownRoute(position: position),
  );
  return result ?? false;
}

/// Consecutive achievements collapse into one panel item.
@visibleForTesting
List<List<NotificationDto>> groupNotifications(List<NotificationDto> items) {
  final groups = <List<NotificationDto>>[];
  for (final n in items) {
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

class _NotificationsDropdownRoute extends PopupRoute<bool> {
  _NotificationsDropdownRoute({required this.position});

  final RelativeRect position;

  @override
  Color? get barrierColor => Colors.black12;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => 'Dismiss notifications';

  @override
  Duration get transitionDuration => const Duration(milliseconds: 200);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return _NotificationsDropdownContent(
      position: position,
      animation: animation,
    );
  }
}

class _NotificationsDropdownContent extends ConsumerStatefulWidget {
  const _NotificationsDropdownContent({
    required this.position,
    required this.animation,
  });

  final RelativeRect position;
  final Animation<double> animation;

  @override
  ConsumerState<_NotificationsDropdownContent> createState() =>
      _NotificationsDropdownContentState();
}

class _NotificationsDropdownContentState
    extends ConsumerState<_NotificationsDropdownContent> {
  late final NotificationApiService _notificationService;
  final List<NotificationDto> _notifications = [];
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  int _currentPage = 0;
  bool _hasMore = true;
  int _unreadCount = 0;
  bool _unreadOnly = false;

  /// Friend requests answered from the panel; their buttons disappear.
  final Set<String> _answeredRequests = {};

  @override
  void initState() {
    super.initState();
    _notificationService = ref.read(notificationApiServiceProvider);
    _loadNotifications();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _notificationService.getMyNotifications(page: 0),
        _notificationService.getUnreadCount(),
      ]);

      final page = results[0] as PageResponse<NotificationDto>;
      final unreadCount = results[1] as int;

      if (mounted) {
        setState(() {
          _notifications.clear();
          _notifications.addAll(page.content);
          _currentPage = 0;
          _hasMore = !page.last;
          _unreadCount = unreadCount;
          _isLoading = false;
        });
      }
    } on AuthenticationRedirectException {
      if (mounted) {
        setState(() {
          _error = 'auth';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'generic';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final page = await _notificationService.getMyNotifications(
        page: _currentPage + 1,
      );

      if (mounted) {
        setState(() {
          _notifications.addAll(page.content);
          _currentPage = _currentPage + 1;
          _hasMore = !page.last;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _markAsRead(NotificationDto notification) async {
    if (notification.read) return;

    try {
      await _notificationService.markAsRead(notification.id);

      if (mounted) {
        setState(() {
          final index = _notifications.indexWhere(
            (n) => n.id == notification.id,
          );
          if (index != -1) {
            _notifications[index] = _asRead(notification);
            _unreadCount = max(0, _unreadCount - 1);
          }
        });
      }
    } catch (e) {
      // Silently fail - notification will still appear unread
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      await _notificationService.markAllAsRead();

      if (mounted) {
        setState(() {
          for (int i = 0; i < _notifications.length; i++) {
            _notifications[i] = _asRead(_notifications[i]);
          }
          _unreadCount = 0;
        });
      }
    } catch (e) {
      // Silently fail
    }
  }

  NotificationDto _asRead(NotificationDto n) => n.read
      ? n
      : NotificationDto(
          id: n.id,
          recipientId: n.recipientId,
          actorId: n.actorId,
          type: n.type,
          referenceId: n.referenceId,
          message: n.message,
          read: true,
          createdAt: n.createdAt,
        );

  Future<void> _answerFriendRequest(
      NotificationDto notification, bool accept) async {
    final requestId = notification.referenceId!;
    setState(() => _answeredRequests.add(requestId));
    const actions = NotificationActions();
    await (accept
        ? actions.acceptFriendRequest(requestId)
        : actions.declineFriendRequest(requestId));
    _markAsRead(notification);
  }

  void _onGroupTap(List<NotificationDto> group) {
    for (final n in group) {
      _markAsRead(n);
    }
    Navigator.pop(context, true);
    AuthNavigationHelper.navigateToAchievements(context);
  }

  void _onNotificationTap(NotificationDto notification) {
    _markAsRead(notification);
    Navigator.pop(context, true);
    _navigateToTarget(notification);
  }

  void _navigateToTarget(NotificationDto notification) {
    final referenceId = notification.referenceId;
    if (referenceId == null) return;

    switch (notification.type) {
      case NotificationType.friendRequestReceived:
      case NotificationType.friendRequestDeclined:
        AuthNavigationHelper.navigateToFriendsFollowers(context);
        break;
      case NotificationType.friendRequestAccepted:
        if (notification.actorId != null) {
          AuthNavigationHelper.navigateToUserProfile(
            context,
            notification.actorId!,
          );
        }
        break;
      case NotificationType.commentOnTrip:
      case NotificationType.tripStatusChanged:
      case NotificationType.tripUpdatePosted:
        Navigator.push(
          context,
          PageTransitions.slideUp(TripDeepLinkScreen(tripId: referenceId)),
        );
        break;
      case NotificationType.replyToComment:
      case NotificationType.commentReaction:
        break;
      case NotificationType.newFollower:
        AuthNavigationHelper.navigateToUserProfile(context, referenceId);
        break;
      case NotificationType.achievementUnlocked:
        AuthNavigationHelper.navigateToAchievements(context);
        break;
    }
  }

  IconData _getNotificationIcon(NotificationType type) {
    switch (type) {
      case NotificationType.friendRequestReceived:
        return Icons.person_add_alt;
      case NotificationType.friendRequestAccepted:
        return Icons.handshake_outlined;
      case NotificationType.friendRequestDeclined:
        return Icons.person_off_outlined;
      case NotificationType.commentOnTrip:
        return Icons.chat_bubble_outline;
      case NotificationType.replyToComment:
        return Icons.reply;
      case NotificationType.commentReaction:
        return Icons.favorite_border;
      case NotificationType.newFollower:
        return Icons.person_add_alt;
      case NotificationType.achievementUnlocked:
        return Icons.emoji_events_outlined;
      case NotificationType.tripStatusChanged:
        return Icons.hiking;
      case NotificationType.tripUpdatePosted:
        return Icons.location_on_outlined;
    }
  }

  /// People orange, requests blue, achievements gold, trips green.
  (Color, Color) _getNotificationColors(NotificationType type) {
    final c = WandererTheme.of(context);
    switch (type) {
      case NotificationType.friendRequestReceived:
        return (c.skyBg, c.skyFg);
      case NotificationType.friendRequestDeclined:
        return (c.neutralBg, c.neutralFg);
      case NotificationType.achievementUnlocked:
        return (c.goldBg, c.goldFg);
      case NotificationType.tripStatusChanged:
      case NotificationType.tripUpdatePosted:
        return (c.forestBg, c.forestFg);
      case NotificationType.friendRequestAccepted:
      case NotificationType.newFollower:
      case NotificationType.commentOnTrip:
      case NotificationType.replyToComment:
      case NotificationType.commentReaction:
        return (c.trailSoftBg, c.trailSoftFg);
    }
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.isNegative || diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    return '${(diff.inDays / 30).floor()}mo ago';
  }

  static final _quoted = RegExp(r'"([^"]+)"');

  /// Achievement name from `You unlocked the achievement "X"!`.
  static String _achievementName(NotificationDto n) =>
      _quoted.firstMatch(n.message)?.group(1) ?? n.message;

  /// Backend messages start with the actor's name and quote trip or
  /// achievement names: those are bold, the rest muted.
  InlineSpan _messageSpan(NotificationDto n) {
    final c = WandererTheme.of(context);
    final bold = TextStyle(fontWeight: FontWeight.w700, color: c.text);
    final spans = <InlineSpan>[];
    var rest = n.message;
    final space = rest.indexOf(' ');
    if (n.actorId != null && space > 0) {
      spans.add(TextSpan(text: rest.substring(0, space), style: bold));
      rest = rest.substring(space);
    }
    var last = 0;
    for (final m in _quoted.allMatches(rest)) {
      spans.add(TextSpan(text: rest.substring(last, m.start)));
      spans.add(TextSpan(text: m.group(1), style: bold));
      last = m.end;
    }
    spans.add(TextSpan(text: rest.substring(last)));
    return TextSpan(
      style: TextStyle(fontSize: 14, height: 1.4, color: c.textMuted),
      children: spans,
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final dropdownWidth = min(420.0, mediaQuery.size.width - 16);
    final c = WandererTheme.of(context);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.pop(context, true),
      },
      child: Focus(
        autofocus: true,
        child: FadeTransition(
          opacity: widget.animation,
          child: CustomSingleChildLayout(
            delegate: _DropdownLayoutDelegate(
              position: widget.position,
              dropdownWidth: dropdownWidth,
              screenPadding: mediaQuery.padding,
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(
                        Theme.of(context).brightness == Brightness.dark
                            ? 0.45
                            : 0.18),
                    blurRadius: 60,
                    offset: const Offset(0, 24),
                  ),
                ],
              ),
              child: Material(
                color: c.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: c.line),
                ),
                clipBehavior: Clip.antiAlias,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: dropdownWidth,
                    maxHeight: min(640.0, mediaQuery.size.height * 0.75),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildHeader(),
                      Flexible(child: _buildBody()),
                      _buildFooter(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                l10n.notifications,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: c.text,
                ),
              ),
              const Spacer(),
              if (_unreadCount > 0)
                TextButton(
                  onPressed: _markAllAsRead,
                  style: TextButton.styleFrom(
                    foregroundColor: c.accentText,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    visualDensity: VisualDensity.compact,
                    textStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  child: Text(l10n.readAll),
                ),
            ],
          ),
          const SizedBox(height: 8),
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: c.line)),
            ),
            child: Row(
              children: [
                _buildTab(l10n.notifTabAll, unreadOnly: false),
                const SizedBox(width: 20),
                _buildTab(l10n.notifTabUnread,
                    unreadOnly: true, count: _unreadCount),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String label, {required bool unreadOnly, int count = 0}) {
    final c = WandererTheme.of(context);
    final selected = _unreadOnly == unreadOnly;
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: () => setState(() => _unreadOnly = unreadOnly),
        child: Container(
          padding: const EdgeInsets.fromLTRB(2, 6, 2, 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color:
                    selected ? WandererTheme.primaryOrange : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: selected ? c.text : c.textMuted,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                  decoration: BoxDecoration(
                    color: WandererTheme.primaryOrange,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    count > 99 ? '99+' : '$count',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    final c = WandererTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: c.raised,
        border: Border(top: BorderSide(color: c.line)),
      ),
      child: Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          onPressed: () {
            Navigator.pop(context, true);
            Navigator.push(
              context,
              PageTransitions.slideFromBottom(const SettingsScreen()),
            );
          },
          style: TextButton.styleFrom(
            foregroundColor: c.textMuted,
            textStyle:
                const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          child: Text(context.l10n.settings),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final c = WandererTheme.of(context);
    final l10n = context.l10n;

    if (_error != null) {
      final errorText = _error == 'auth'
          ? l10n.pleaseLogInForNotifications
          : l10n.failedToLoadNotifications;
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 36, color: c.caption),
            const SizedBox(height: 8),
            Text(
              errorText,
              style: TextStyle(color: c.textMuted, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _loadNotifications,
              child: Text(l10n.retry),
            ),
          ],
        ),
      );
    }

    final unread = _notifications.where((n) => !n.read).toList();
    final earlier = _unreadOnly
        ? <NotificationDto>[]
        : _notifications.where((n) => n.read).toList();

    if (unread.isEmpty && earlier.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_none, size: 48, color: c.caption),
            const SizedBox(height: 12),
            Text(
              l10n.noNotificationsYet,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: c.textMuted,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.notificationsWillAppear,
              style: TextStyle(fontSize: 12, color: c.caption),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final children = <Widget>[
      if (unread.isNotEmpty) ...[
        _buildSectionLabel(l10n.notifSectionNew),
        ..._buildItems(unread),
      ],
      if (earlier.isNotEmpty) ...[
        _buildSectionLabel(l10n.notifSectionEarlier),
        ..._buildItems(earlier),
      ],
      if (_hasMore) _buildLoadMoreButton(),
    ];

    return ListView(
      controller: _scrollController,
      shrinkWrap: true,
      padding: const EdgeInsets.only(bottom: 4),
      children: children,
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.9,
          color: WandererTheme.of(context).label,
        ),
      ),
    );
  }

  List<Widget> _buildItems(List<NotificationDto> items) {
    final groups = groupNotifications(items);
    return [
      for (var i = 0; i < groups.length; i++)
        _buildNotificationTile(groups[i], divider: i > 0),
    ];
  }

  Widget _buildLoadMoreButton() {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: _isLoadingMore
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: WandererTheme.primaryOrange,
                  strokeWidth: 2,
                ),
              )
            : TextButton.icon(
                onPressed: _loadMore,
                icon: const Icon(
                  Icons.expand_more,
                  color: WandererTheme.primaryOrange,
                ),
                label: Text(
                  l10n.loadMoreNotifications,
                  style: const TextStyle(color: WandererTheme.primaryOrange),
                ),
              ),
      ),
    );
  }

  Widget _buildNotificationTile(
    List<NotificationDto> group, {
    required bool divider,
  }) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    final first = group.first;
    final isGroup = group.length > 1;
    final unread = group.any((n) => !n.read);
    final (iconBg, iconFg) = _getNotificationColors(first.type);
    final showRequestActions =
        first.type == NotificationType.friendRequestReceived &&
            !first.read &&
            first.referenceId != null &&
            !_answeredRequests.contains(first.referenceId);

    return InkWell(
      onTap:
          isGroup ? () => _onGroupTap(group) : () => _onNotificationTap(first),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: unread ? WandererTheme.primaryOrange.withAlpha(15) : null,
          border: divider ? Border(top: BorderSide(color: c.line)) : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
              child: Icon(_getNotificationIcon(first.type),
                  color: iconFg, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isGroup)
                    Text(
                      l10n.notifAchievementsUnlocked(group.length),
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        fontWeight: FontWeight.w700,
                        color: c.text,
                      ),
                    )
                  else
                    Text.rich(
                      _messageSpan(first),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (isGroup) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final n in group)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 3),
                            decoration: BoxDecoration(
                              color: c.goldBg,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              _achievementName(n),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: c.goldFg,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                  if (showRequestActions) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildRequestButton(
                          l10n.acceptRequest,
                          solid: true,
                          onPressed: () => _answerFriendRequest(first, true),
                        ),
                        const SizedBox(width: 8),
                        _buildRequestButton(
                          l10n.toastDecline,
                          solid: false,
                          onPressed: () => _answerFriendRequest(first, false),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    _formatTimeAgo(first.createdAt),
                    style: TextStyle(fontSize: 12, color: c.caption),
                  ),
                ],
              ),
            ),
            if (unread)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 6, left: 8),
                decoration: const BoxDecoration(
                  color: WandererTheme.primaryOrange,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestButton(
    String label, {
    required bool solid,
    required VoidCallback onPressed,
  }) {
    final c = WandererTheme.of(context);
    final style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(0, 32)),
      padding:
          const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 14)),
      shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(9))),
      textStyle: const WidgetStatePropertyAll(
          TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
    return solid
        ? FilledButton(
            onPressed: onPressed,
            style: style.copyWith(
              backgroundColor: WidgetStatePropertyAll(c.neutralButtonBg),
              foregroundColor: WidgetStatePropertyAll(c.neutralButtonFg),
            ),
            child: Text(label),
          )
        : OutlinedButton(
            onPressed: onPressed,
            style: style.copyWith(
              foregroundColor: WidgetStatePropertyAll(c.text),
              side: WidgetStatePropertyAll(BorderSide(color: c.line)),
            ),
            child: Text(label),
          );
  }
}

/// Layout delegate that positions the dropdown below the anchor button,
/// aligned to the right edge of the screen.
class _DropdownLayoutDelegate extends SingleChildLayoutDelegate {
  _DropdownLayoutDelegate({
    required this.position,
    required this.dropdownWidth,
    required this.screenPadding,
  });

  final RelativeRect position;
  final double dropdownWidth;
  final EdgeInsets screenPadding;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return BoxConstraints.loose(
      Size(dropdownWidth, constraints.maxHeight - position.top - 8),
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    // Position the dropdown below the anchor, right-aligned
    double left = size.width - position.right - childSize.width;
    // Clamp to stay within screen bounds
    left = left.clamp(8.0, size.width - childSize.width - 8);
    return Offset(left, position.top);
  }

  @override
  bool shouldRelayout(_DropdownLayoutDelegate oldDelegate) {
    return position != oldDelegate.position ||
        dropdownWidth != oldDelegate.dropdownWidth;
  }
}
