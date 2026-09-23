import 'package:flutter/material.dart' hide Visibility;
import 'package:wanderer_frontend/core/constants/api_endpoints.dart';
import 'package:wanderer_frontend/core/constants/enums.dart'
    show TripStatus, Visibility;
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/presentation/helpers/avatar_helper.dart';
import 'package:wanderer_frontend/presentation/helpers/date_format_helper.dart';
import 'package:wanderer_frontend/presentation/widgets/common/cached_trip_thumbnail.dart';
import 'package:wanderer_frontend/presentation/widgets/common/pill.dart';
import 'package:wanderer_frontend/presentation/widgets/common/web_page_header.dart';

enum _StatusFilter { all, live, completed }

/// Web "Explore" page: header, Discover / Friends' feed tabs with search and
/// status filter, featured (promoted) trips and a grid of public trips.
///
/// Data and actions come from HomeScreen; this only owns the view filters.
class WebExploreView extends StatefulWidget {
  final bool isLoggedIn;
  final String? userId;
  final List<Trip> discoverTrips;
  final List<Trip> feedTrips;
  final bool hasMore;
  final bool isLoadingMore;
  final VoidCallback onLoadMore;
  final Future<void> Function() onRefresh;
  final ValueChanged<Trip> onOpenTrip;
  final VoidCallback onNewTrip;
  final VoidCallback onLogIn;
  final VoidCallback onGetStarted;
  final VoidCallback onFindFriends;

  const WebExploreView({
    super.key,
    required this.isLoggedIn,
    required this.userId,
    required this.discoverTrips,
    required this.feedTrips,
    required this.hasMore,
    required this.isLoadingMore,
    required this.onLoadMore,
    required this.onRefresh,
    required this.onOpenTrip,
    required this.onNewTrip,
    required this.onLogIn,
    required this.onGetStarted,
    required this.onFindFriends,
  });

  @override
  State<WebExploreView> createState() => _WebExploreViewState();
}

class _WebExploreViewState extends State<WebExploreView> {
  bool _feed = false;
  String _query = '';
  _StatusFilter _status = _StatusFilter.all;

  List<Trip> _filter(List<Trip> trips) {
    final q = _query.trim().toLowerCase();
    return trips.where((t) {
      final live =
          t.status == TripStatus.inProgress || t.status == TripStatus.resting;
      if (_status == _StatusFilter.live && !live) return false;
      if (_status == _StatusFilter.completed &&
          t.status != TripStatus.finished) {
        return false;
      }
      return q.isEmpty ||
          t.name.toLowerCase().contains(q) ||
          t.username.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final feed = _feed && widget.isLoggedIn;
    final trips = _filter(feed ? widget.feedTrips : widget.discoverTrips);
    final featured =
        feed ? <Trip>[] : trips.where((t) => t.isPromoted).toList();
    final latest = feed ? trips : trips.where((t) => !t.isPromoted).toList();
    final filtered = _query.trim().isNotEmpty || _status != _StatusFilter.all;

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.extentAfter < 400 &&
              widget.hasMore &&
              !widget.isLoadingMore) {
            widget.onLoadMore();
          }
          return false;
        },
        child: LayoutBuilder(builder: (context, box) {
          final gutter = box.maxWidth >= 720 ? 40.0 : 16.0;
          return ListView(
            padding: EdgeInsets.fromLTRB(gutter, 28, gutter, 40),
            children: [
              WebPageHeader(
                title: l10n.navExplore,
                subtitle: l10n.exploreSubtitle,
                isLoggedIn: widget.isLoggedIn,
                userId: widget.userId,
                actions: [
                  if (!widget.isLoggedIn)
                    OutlinedButton(
                        onPressed: widget.onLogIn, child: Text(l10n.logIn)),
                ],
                primaryAction: widget.isLoggedIn
                    ? ElevatedButton.icon(
                        onPressed: widget.onNewTrip,
                        icon: const Icon(Icons.add, size: 18),
                        label: Text(l10n.newTrip),
                      )
                    : ElevatedButton(
                        onPressed: widget.onGetStarted,
                        child: Text(l10n.getStarted),
                      ),
              ),
              const SizedBox(height: 24),
              _toolbar(context),
              const SizedBox(height: 24),
              if (featured.isNotEmpty) ...[
                _SectionTitle(
                  icon: Icons.star_rounded,
                  title: l10n.exploreFeatured,
                  subtitle: l10n.exploreFeaturedSubtitle,
                ),
                const SizedBox(height: 14),
                for (final t in featured) ...[
                  _FeaturedCard(trip: t, onOpen: () => widget.onOpenTrip(t)),
                  const SizedBox(height: 16),
                ],
                const SizedBox(height: 8),
              ],
              _SectionTitle(
                title:
                    feed ? l10n.exploreFriendsFeed : l10n.exploreLatestPublic,
                count: latest.length,
              ),
              const SizedBox(height: 14),
              _grid(context, latest, feed: feed, filtered: filtered),
              if (widget.hasMore)
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Center(
                    child: widget.isLoadingMore
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : TextButton(
                            onPressed: widget.onLoadMore,
                            child: Text(l10n.loadMoreTrips),
                          ),
                  ),
                ),
            ],
          );
        }),
      ),
    );
  }

  Widget _toolbar(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;

    Widget tab(String label, bool feed) {
      final active = _feed == feed;
      return InkWell(
        onTap: () => setState(() {
          _feed = feed;
          // The feed only holds active trips.
          if (feed && _status == _StatusFilter.completed) {
            _status = _StatusFilter.all;
          }
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: active ? WandererTheme.trail : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                color: active ? c.text : c.textMuted,
              )),
        ),
      );
    }

    Widget segment(String label, _StatusFilter value) {
      final active = _status == value;
      return Material(
        color: active ? c.surface : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => setState(() => _status = value),
          child: Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            child: Text(label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                  color: active ? c.text : c.textMuted,
                )),
          ),
        ),
      );
    }

    return Container(
      decoration:
          BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.end,
        runSpacing: 12,
        spacing: 16,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              tab(l10n.discover, false),
              if (widget.isLoggedIn) ...[
                const SizedBox(width: 28),
                tab(l10n.exploreFriendsFeed, true),
              ],
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 260,
                  height: 40,
                  child: TextField(
                    onChanged: (v) => setState(() => _query = v),
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: l10n.exploreSearchHint,
                      prefixIcon: Icon(Icons.search, size: 18, color: c.label),
                      isDense: true,
                      filled: true,
                      fillColor: c.surface,
                      contentPadding: EdgeInsets.zero,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: c.line),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: WandererTheme.trail),
                      ),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: c.neutralBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      segment(l10n.exploreFilterAll, _StatusFilter.all),
                      const SizedBox(width: 4),
                      segment(l10n.live, _StatusFilter.live),
                      if (!(_feed && widget.isLoggedIn)) ...[
                        const SizedBox(width: 4),
                        segment(l10n.completed, _StatusFilter.completed),
                      ],
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

  Widget _grid(BuildContext context, List<Trip> trips,
      {required bool feed, required bool filtered}) {
    final l10n = context.l10n;
    return LayoutBuilder(builder: (context, box) {
      const gap = 20.0;
      final cols = box.maxWidth >= 900
          ? 3
          : box.maxWidth >= 560
              ? 2
              : 1;
      final w = (box.maxWidth - gap * (cols - 1)) / cols;
      final remaining = cols - trips.length % cols;
      // Dashed tile fills the rest of the last row once everything is loaded.
      final String title;
      final String body;
      if (trips.isNotEmpty) {
        title = l10n.exploreAllCaughtUp;
        body = l10n.exploreAllCaughtUpBody;
      } else if (filtered) {
        title = l10n.exploreNoMatches;
        body = l10n.checkBackLater;
      } else if (feed) {
        title = l10n.noTripsInYourFeed;
        body = l10n.followUsersToSeeFeed;
      } else {
        title = l10n.noPublicTripsFound;
        body = l10n.exploreAllCaughtUpBody;
      }
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final t in trips)
            SizedBox(
              width: w,
              height: _TripTile.height,
              child: _TripTile(trip: t, onOpen: () => widget.onOpenTrip(t)),
            ),
          if (!widget.hasMore)
            SizedBox(
              width: remaining == cols
                  ? box.maxWidth
                  : w * remaining + gap * (remaining - 1),
              height: _TripTile.height,
              child: _EndTile(
                title: title,
                body: body,
                onFindFriends: widget.onFindFriends,
              ),
            ),
        ],
      );
    });
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData? icon;
  final String title;
  final String? subtitle;
  final int? count;

  const _SectionTitle(
      {this.icon, required this.title, this.subtitle, this.count});

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    return Wrap(
      spacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (icon != null) Icon(icon, size: 20, color: c.goldFg),
        Semantics(
          header: true,
          child: Text(title,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        ),
        if (subtitle != null)
          Text(subtitle!, style: TextStyle(fontSize: 13, color: c.caption)),
        if (count != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: c.trailSoftBg,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text('$count',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: c.accentText)),
          ),
      ],
    );
  }
}

/// Trip image with the "No route yet" style empty state.
class _TripImage extends StatelessWidget {
  final Trip trip;
  const _TripImage({required this.trip});

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    final empty = Container(
      color: c.mapGround,
      alignment: Alignment.center,
      child: Icon(Icons.map_outlined, size: 36, color: c.label),
    );
    return CachedTripThumbnail(
      thumbnailUrl: trip.thumbnailUrl,
      placeholder: Container(color: c.mapGround),
      errorWidget: empty,
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  final Trip trip;
  final VoidCallback onOpen;
  const _FeaturedCard({required this.trip, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    final (visLabel, visTone) = switch (trip.visibility) {
      Visibility.public => (l10n.publicVisibility, PillTone.completed),
      Visibility.protected => (l10n.protectedVisibility, PillTone.neutral),
      Visibility.private => (l10n.privateVisibility, PillTone.neutral),
    };
    final hasAvatar = trip.avatarUrl?.isNotEmpty ?? false;

    final image = Stack(
      fit: StackFit.expand,
      children: [
        _TripImage(trip: trip),
        Positioned(
          top: 16,
          left: 16,
          child: Pill(l10n.promoted,
              tone: PillTone.onImage, foregroundTone: PillTone.promoted),
        ),
      ],
    );
    final details = Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(spacing: 6, runSpacing: 6, children: [
            Pill.status(context, trip.status),
            Pill(visLabel, tone: visTone),
          ]),
          const SizedBox(height: 12),
          Text(trip.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: WandererTheme.display(28)),
          const SizedBox(height: 12),
          Row(children: [
            CircleAvatar(
              radius: 13,
              backgroundColor: c.trailSoftBg,
              foregroundImage: hasAvatar
                  ? NetworkImage(
                      ApiEndpoints.resolveThumbnailUrl(trip.avatarUrl))
                  : null,
              onForegroundImageError: hasAvatar ? (_, __) {} : null,
              child: Text(AvatarHelper.getInitials(null, trip.username),
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: c.accentText)),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text('@${trip.username}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: 12),
          DefaultTextStyle.merge(
            style: TextStyle(fontSize: 13, color: c.caption),
            child: Wrap(spacing: 16, children: [
              Text(l10n.exploreUpdated(
                  DateFormatHelper.formatRelativeDate(l10n, trip.updatedAt))),
              Text(l10n.commentsCount(trip.commentsCount)),
            ]),
          ),
          const Spacer(),
          Text('${l10n.exploreFollowTrip} →',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: c.accentText)),
        ],
      ),
    );

    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: WandererTheme.cardDecoration(context),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onOpen,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(17),
            child: LayoutBuilder(builder: (context, box) {
              if (box.maxWidth < 640) {
                return Column(children: [
                  SizedBox(height: 180, width: double.infinity, child: image),
                  SizedBox(height: 250, child: details),
                ]);
              }
              return SizedBox(
                height: 260,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 13, child: image),
                    Expanded(flex: 10, child: details),
                  ],
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _TripTile extends StatelessWidget {
  static const double height = 232;
  final Trip trip;
  final VoidCallback onOpen;
  const _TripTile({required this.trip, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: WandererTheme.cardDecoration(context),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onOpen,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(17),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 150,
                  child: Stack(fit: StackFit.expand, children: [
                    _TripImage(trip: trip),
                    Positioned(
                      top: 14,
                      left: 14,
                      child: Pill.status(context, trip.status, onImage: true),
                    ),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(trip.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: WandererTheme.display(18)),
                      const SizedBox(height: 6),
                      Text(
                        '@${trip.username} · ${DateFormatHelper.formatRelativeDate(l10n, trip.updatedAt)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: c.caption),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EndTile extends StatelessWidget {
  final String title;
  final String body;
  final VoidCallback onFindFriends;
  const _EndTile(
      {required this.title, required this.body, required this.onFindFriends});

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    return CustomPaint(
      painter: _DashedBorder(c.line),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Text(body,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style:
                      TextStyle(fontSize: 14, height: 1.5, color: c.textMuted)),
            ),
            const SizedBox(height: 14),
            OutlinedButton(
              onPressed: onFindFriends,
              child: Text(context.l10n.exploreFindFriends),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashedBorder extends CustomPainter {
  final Color color;
  _DashedBorder(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final path = Path()
      ..addRRect(
          RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(18))
              .deflate(1));
    for (final metric in path.computeMetrics()) {
      for (double d = 0; d < metric.length; d += 10) {
        canvas.drawPath(metric.extractPath(d, d + 6), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) => old.color != color;
}
