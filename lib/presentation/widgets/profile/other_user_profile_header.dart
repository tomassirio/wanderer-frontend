import 'package:flutter/material.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/presentation/widgets/common/pill.dart';
import 'package:wanderer_frontend/presentation/widgets/common/web_page_header.dart';
import 'package:wanderer_frontend/presentation/widgets/profile/web_profile_widgets.dart';

/// Web header for someone else's profile: breadcrumb (origin / username),
/// "Profile" title and the identity card with relationship pill, stats,
/// Follow (primary), Add friend and a More options menu.
///
/// No user ID and no Edit profile / New trip: those are own-profile only.
class OtherUserProfileHeader extends StatelessWidget {
  /// Label of the section the profile was opened from (first crumb).
  final String originLabel;
  final VoidCallback onOriginTap;
  final Widget avatar;
  final String displayName;
  final String username;
  final String bio;
  final List<ProfileStat> stats;
  final bool isFollowing;
  final bool isFriend;
  final bool hasSentRequest;
  final bool followsYou;

  /// Toggles follow / unfollow.
  final VoidCallback onFollow;

  /// Sends a request, or cancels it / unfriends when already in that state.
  final VoidCallback onFriend;
  final bool isLoggedIn;
  final String? currentUserId;

  const OtherUserProfileHeader({
    super.key,
    required this.originLabel,
    required this.onOriginTap,
    required this.avatar,
    required this.displayName,
    required this.username,
    this.bio = '',
    required this.stats,
    required this.isFollowing,
    required this.isFriend,
    required this.hasSentRequest,
    required this.followsYou,
    required this.onFollow,
    required this.onFriend,
    this.isLoggedIn = true,
    this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = WandererTheme.of(context);

    final crumbStyle = TextStyle(
        fontSize: 13, fontWeight: FontWeight.w600, color: c.textMuted);
    final breadcrumb = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onOriginTap,
          child: Text(originLabel, style: crumbStyle),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text('/', style: crumbStyle),
        ),
        Flexible(
          child: Text(username,
              overflow: TextOverflow.ellipsis,
              style: crumbStyle.copyWith(color: c.text)),
        ),
      ],
    );

    final (pillLabel, pillTone) = isFriend
        ? (l10n.friend, PillTone.completed)
        : hasSentRequest
            ? (l10n.requestSent, PillTone.gold)
            : followsYou
                ? (l10n.friendsPillFollowsYou, PillTone.progress)
                : (l10n.profileNotConnected, PillTone.neutral);

    final identity = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: WandererTheme.display(24, color: c.text)),
        const SizedBox(height: 6),
        Text('@$username',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 14, color: c.textMuted)),
        const SizedBox(height: 8),
        Pill(pillLabel, tone: pillTone),
        if (bio.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(bio, style: TextStyle(fontSize: 14, color: c.text, height: 1.4)),
        ],
      ],
    );

    final buttons = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ElevatedButton.icon(
          onPressed: onFollow,
          icon: Icon(isFollowing ? Icons.check : Icons.add, size: 16),
          label: Text(isFollowing ? l10n.following : l10n.follow),
        ),
        const SizedBox(width: 10),
        // Pending / friend are states; undo them from More options.
        OutlinedButton.icon(
          onPressed: isFriend || hasSentRequest ? null : onFriend,
          icon: Icon(
              isFriend
                  ? Icons.people_outline
                  : hasSentRequest
                      ? Icons.schedule
                      : Icons.person_add_alt,
              size: 16),
          label: Text(isFriend
              ? l10n.friend
              : hasSentRequest
                  ? l10n.requestSent
                  : l10n.addFriend),
        ),
        const SizedBox(width: 10),
        PopupMenuButton<VoidCallback>(
          tooltip: l10n.profileMoreOptions,
          onSelected: (action) => action(),
          itemBuilder: (_) => [
            PopupMenuItem(
              value: onFollow,
              child: Text(isFollowing ? l10n.unfollow : l10n.follow),
            ),
            PopupMenuItem(
              value: onFriend,
              child: Text(isFriend
                  ? l10n.unfriend
                  : hasSentRequest
                      ? l10n.cancelFriendRequest
                      : l10n.sendFriendRequest),
            ),
          ],
          icon: const Icon(Icons.more_vert, size: 18),
          style: IconButton.styleFrom(
            fixedSize: const Size(44, 44),
            backgroundColor: c.surface,
            foregroundColor: c.neutralFg,
            side: BorderSide(color: c.line),
            shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(WandererTheme.radiusControl)),
          ),
        ),
      ],
    );

    final statBox = ProfileStatBox(stats: stats);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        breadcrumb,
        const SizedBox(height: 8),
        WebPageHeader(
          title: l10n.profile,
          userId: currentUserId,
          isLoggedIn: isLoggedIn,
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: WandererTheme.cardDecoration(context),
          child: LayoutBuilder(builder: (context, constraints) {
            final head = Row(children: [
              avatar,
              const SizedBox(width: 24),
              Expanded(child: identity),
            ]);
            if (constraints.maxWidth >= 1000) {
              return Row(children: [
                Expanded(child: head),
                const SizedBox(width: 24),
                statBox,
                const SizedBox(width: 24),
                buttons,
              ]);
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                head,
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [statBox, buttons],
                ),
              ],
            );
          }),
        ),
      ],
    );
  }
}

/// Dashed box shown when another user has no visible trips.
class PublicTripsEmptyState extends StatelessWidget {
  final String username;

  const PublicTripsEmptyState({super.key, required this.username});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = WandererTheme.of(context);
    return CustomPaint(
      painter: _DashedBorderPainter(color: c.line),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              children: [
                Text(l10n.profileNoPublicTripsTitle(username),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: c.text)),
                const SizedBox(height: 8),
                Text(l10n.profileNoPublicTripsBody,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 14, color: c.textMuted, height: 1.5)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;

  const _DashedBorderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Offset.zero & size, const Radius.circular(18)));
    for (final metric in path.computeMetrics()) {
      for (double d = 0; d < metric.length; d += 10) {
        canvas.drawPath(metric.extractPath(d, d + 6), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) => old.color != color;
}
