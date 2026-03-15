import 'dart:math';

import 'package:flutter/material.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/data/models/notification_models.dart';
import 'package:wanderer_frontend/data/models/responses/page_response.dart';
import 'package:wanderer_frontend/data/services/notification_api_service.dart';
import 'package:wanderer_frontend/data/client/api_client.dart';
import 'package:wanderer_frontend/presentation/helpers/auth_navigation_helper.dart';
import 'package:wanderer_frontend/presentation/helpers/page_transitions.dart';
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

class _NotificationsDropdownContent extends StatefulWidget {
  const _NotificationsDropdownContent({
    required this.position,
    required this.animation,
  });

  final RelativeRect position;
  final Animation<double> animation;

  @override
  State<_NotificationsDropdownContent> createState() =>
      _NotificationsDropdownContentState();
}

class _NotificationsDropdownContentState
    extends State<_NotificationsDropdownContent> {
  final NotificationApiService _notificationService = NotificationApiService();
  final List<NotificationDto> _notifications = [];
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  int _currentPage = 0;
  bool _hasMore = true;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadNotifications();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMore();
    }
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
          _error = 'Please log in to view notifications';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load notifications';
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
            _notifications[index] = NotificationDto(
              id: notification.id,
              recipientId: notification.recipientId,
              actorId: notification.actorId,
              type: notification.type,
              referenceId: notification.referenceId,
              message: notification.message,
              read: true,
              createdAt: notification.createdAt,
            );
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
            final n = _notifications[i];
            if (!n.read) {
              _notifications[i] = NotificationDto(
                id: n.id,
                recipientId: n.recipientId,
                actorId: n.actorId,
                type: n.type,
                referenceId: n.referenceId,
                message: n.message,
                read: true,
                createdAt: n.createdAt,
              );
            }
          }
          _unreadCount = 0;
        });
      }
    } catch (e) {
      // Silently fail
    }
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
        return Icons.person_add;
      case NotificationType.friendRequestAccepted:
        return Icons.handshake;
      case NotificationType.friendRequestDeclined:
        return Icons.person_off;
      case NotificationType.commentOnTrip:
        return Icons.chat_bubble_outline;
      case NotificationType.replyToComment:
        return Icons.reply;
      case NotificationType.commentReaction:
        return Icons.favorite_border;
      case NotificationType.newFollower:
        return Icons.person_add;
      case NotificationType.achievementUnlocked:
        return Icons.emoji_events;
      case NotificationType.tripStatusChanged:
        return Icons.hiking;
      case NotificationType.tripUpdatePosted:
        return Icons.location_on;
    }
  }

  Color _getNotificationColor(NotificationType type) {
    switch (type) {
      case NotificationType.friendRequestReceived:
      case NotificationType.friendRequestAccepted:
      case NotificationType.newFollower:
        return Colors.blue;
      case NotificationType.friendRequestDeclined:
        return Colors.grey;
      case NotificationType.commentOnTrip:
      case NotificationType.replyToComment:
        return WandererTheme.primaryOrange;
      case NotificationType.commentReaction:
        return Colors.red;
      case NotificationType.achievementUnlocked:
        return Colors.amber;
      case NotificationType.tripStatusChanged:
      case NotificationType.tripUpdatePosted:
        return Colors.green;
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

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final dropdownWidth = min(360.0, mediaQuery.size.width - 16);

    return FadeTransition(
      opacity: widget.animation,
      child: CustomSingleChildLayout(
        delegate: _DropdownLayoutDelegate(
          position: widget.position,
          dropdownWidth: dropdownWidth,
          screenPadding: mediaQuery.padding,
        ),
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: dropdownWidth,
              maxHeight: min(440.0, mediaQuery.size.height * 0.6),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(),
                const Divider(height: 1),
                Flexible(child: _buildBody()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
      child: Row(
        children: [
          const Text(
            'Notifications',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          if (_unreadCount > 0)
            TextButton.icon(
              onPressed: _markAllAsRead,
              icon: const Icon(Icons.done_all, size: 18),
              label: const Text('Read all', style: TextStyle(fontSize: 13)),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                visualDensity: VisualDensity.compact,
              ),
            ),
        ],
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

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 36, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _loadNotifications,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_notifications.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_none, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              'No notifications yet',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'When you receive notifications,\nthey\'ll appear here',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      controller: _scrollController,
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      itemCount: _notifications.length + (_isLoadingMore ? 1 : 0),
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        if (index >= _notifications.length) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        return _buildNotificationTile(_notifications[index]);
      },
    );
  }

  Widget _buildNotificationTile(NotificationDto notification) {
    final icon = _getNotificationIcon(notification.type);
    final color = _getNotificationColor(notification.type);
    final timeAgo = _formatTimeAgo(notification.createdAt);

    return InkWell(
      onTap: () => _onNotificationTap(notification),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        color: notification.read
            ? null
            : WandererTheme.primaryOrange.withAlpha(15),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withAlpha(26),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.message,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: notification.read
                          ? FontWeight.normal
                          : FontWeight.w600,
                      color: Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    timeAgo,
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            if (!notification.read)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 4, left: 4),
                decoration: BoxDecoration(
                  color: WandererTheme.primaryOrange,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
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
