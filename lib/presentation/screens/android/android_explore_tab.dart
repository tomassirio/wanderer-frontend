import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:wanderer_frontend/core/constants/enums.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/providers/app_providers.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/presentation/helpers/page_transitions.dart';
import 'package:wanderer_frontend/presentation/screens/android/android_search_screen.dart';
import 'package:wanderer_frontend/presentation/screens/trip_detail_screen.dart';
import 'package:wanderer_frontend/presentation/widgets/android/explore_widgets.dart';
import 'package:wanderer_frontend/presentation/widgets/common/cached_trip_thumbnail.dart';
import 'package:wanderer_frontend/presentation/widgets/common/pill.dart';

enum ExploreFilter { all, live, completed, friends }

/// Trips for an Explore chip. "All/Live/Completed" follow the web Discover
/// rules (public + active, or promoted completed / pre-announced); "Friends"
/// is every trip of a friend that friends may see. Newest first.
@visibleForTesting
List<Trip> exploreTrips(
    Iterable<Trip> trips, ExploreFilter filter, Set<String> friendIds) {
  bool active(Trip t) =>
      t.status == TripStatus.inProgress ||
      t.status == TripStatus.resting ||
      t.status == TripStatus.paused;
  bool discover(Trip t) =>
      (t.visibility == Visibility.public && active(t)) ||
      (t.isPromoted &&
          (t.status == TripStatus.finished || t.status == TripStatus.created));
  final out = trips.where((t) => switch (filter) {
        ExploreFilter.all => discover(t),
        ExploreFilter.live => discover(t) &&
            (t.status == TripStatus.inProgress ||
                t.status == TripStatus.resting),
        ExploreFilter.completed =>
          discover(t) && t.status == TripStatus.finished,
        ExploreFilter.friends =>
          friendIds.contains(t.userId) && t.visibility != Visibility.private,
      });
  return out.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
}

/// Android "Explore" tab root (canvas: AndroidExplore). Shown inside
/// [AndroidShell], which provides the bottom nav.
class AndroidExploreTab extends ConsumerStatefulWidget {
  const AndroidExploreTab({super.key});

  @override
  ConsumerState<AndroidExploreTab> createState() => _AndroidExploreTabState();
}

class _AndroidExploreTabState extends ConsumerState<AndroidExploreTab> {
  List<Trip>? _trips;
  Set<String> _friendIds = const {};
  bool _error = false;
  ExploreFilter _filter = ExploreFilter.all;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ponytail: first 50 trips only, no infinite scroll; add paging like
  // HomeScreen._loadMoreTrips when the public list outgrows it.
  Future<void> _load() async {
    final home = ref.read(homeRepositoryProvider);
    try {
      final public = await home.getPublicTrips(size: 50);
      // Guests (Welcome's "See all") only get public trips.
      final loggedIn = await home.isLoggedIn();
      // available (includes friends' trips)
      final available =
          loggedIn ? (await home.loadTrips(size: 50)).content : const <Trip>[];
      final friendIds =
          loggedIn ? await home.getFriendsIds() : const <String>{};
      // Same merge as HomeScreen: available trips win over public ones.
      final merged = <String, Trip>{
        for (final t in public.content) t.id: t,
        for (final t in available) t.id: t,
      };
      if (!mounted) return;
      setState(() {
        _trips = merged.values.toList();
        _friendIds = friendIds;
        _error = false;
      });
    } catch (e) {
      debugPrint('AndroidExploreTab: load failed: $e');
      if (mounted) setState(() => _error = true);
    }
  }

  void _open(Widget screen) =>
      Navigator.of(context).push(PageTransitions.slideFromRight(screen));

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    final all = _trips;
    final trips =
        all == null ? const <Trip>[] : exploreTrips(all, _filter, _friendIds);
    final featured = trips.where((t) => t.isPromoted).toList();
    final latest = trips.where((t) => !t.isPromoted).toList();

    final chips = [
      (ExploreFilter.all, l10n.exploreFilterAll),
      (ExploreFilter.live, l10n.live),
      (ExploreFilter.completed, l10n.completed),
      (ExploreFilter.friends, l10n.friends),
    ];

    Widget message(String text) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Column(children: [
            Text(text,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: c.textMuted)),
            if (_error) ...[
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _load, child: Text(l10n.retry)),
            ],
          ]),
        );

    return Scaffold(
      backgroundColor: c.ground,
      appBar: AppBar(
        toolbarHeight: 64,
        backgroundColor: c.ground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        // Back arrow only when pushed on its own (Welcome's "See all"),
        // never as a tab root inside the shell.
        titleSpacing: ModalRoute.of(context)?.canPop == true ? 4 : 20,
        title:
            Text(l10n.explore, style: WandererTheme.display(24, color: c.text)),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
          children: [
            Semantics(
              button: true,
              label: l10n.search,
              child: Material(
                color: c.surface,
                shape: StadiumBorder(side: BorderSide(color: c.line)),
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: () => _open(const AndroidSearchScreen()),
                  child: SizedBox(
                    height: 52,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(children: [
                        Icon(Icons.search, size: 20, color: c.caption),
                        const SizedBox(width: 10),
                        Text(l10n.searchOverlayHint,
                            style: TextStyle(fontSize: 15, color: c.caption)),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (final (f, label) in chips) ...[
                  ExploreChip(
                    label: label,
                    selected: _filter == f,
                    onTap: () => setState(() => _filter = f),
                  ),
                  const SizedBox(width: 8),
                ],
              ]),
            ),
            if (all == null && !_error)
              const Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (all == null)
              message(l10n.errorLoadingTrips)
            else if (trips.isEmpty)
              message(_filter == ExploreFilter.all
                  ? l10n.exploreNoTrips
                  : l10n.noTripsMatchFilters)
            else ...[
              if (featured.isNotEmpty) ...[
                const SizedBox(height: 18),
                ExploreSectionTitle(l10n.exploreFeatured),
                for (final t in featured) ...[
                  const SizedBox(height: 10),
                  _FeaturedCard(
                      trip: t, onTap: () => _open(TripDetailScreen(trip: t))),
                ],
              ],
              if (latest.isNotEmpty) ...[
                const SizedBox(height: 18),
                ExploreSectionTitle(l10n.exploreLatestPublic),
                for (final t in latest) ...[
                  const SizedBox(height: 10),
                  ExploreTripRow(
                    thumbnailUrl: t.thumbnailUrl,
                    title: Text(t.name),
                    subtitle: Row(children: [
                      Pill.status(context, t.status),
                      const SizedBox(width: 8),
                      Flexible(
                          child: Text('@${t.username}',
                              overflow: TextOverflow.ellipsis)),
                    ]),
                    onTap: () => _open(TripDetailScreen(trip: t)),
                  ),
                ],
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  final Trip trip;
  final VoidCallback onTap;
  const _FeaturedCard({required this.trip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    final km = trip.accruedDistanceKm;
    final meta = [
      '@${trip.username}',
      if (km != null && km > 0)
        l10n.kmValue(NumberFormat.decimalPatternDigits(
                locale: Localizations.localeOf(context).toString(),
                decimalDigits: 1)
            .format(km)),
      if (trip.commentsCount > 0) l10n.commentsCount(trip.commentsCount),
    ].join(' · ');
    return Material(
      color: c.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: c.line),
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 160,
              child: Stack(fit: StackFit.expand, children: [
                CachedTripThumbnail(
                  thumbnailUrl: trip.thumbnailUrl,
                  placeholder: ColoredBox(color: c.mapGround),
                  errorWidget: ColoredBox(color: c.mapGround),
                ),
                Positioned(
                    top: 12,
                    left: 12,
                    child: Pill.status(context, trip.status, onImage: true)),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Pill(l10n.promoted,
                      tone: PillTone.onImage,
                      foregroundTone: PillTone.promoted),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(trip.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: WandererTheme.display(19, color: c.text)),
                  const SizedBox(height: 3),
                  Text(meta, style: TextStyle(fontSize: 13, color: c.caption)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
