import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wanderer_frontend/core/constants/enums.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/providers/app_providers.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/presentation/helpers/date_format_helper.dart';
import 'package:wanderer_frontend/presentation/helpers/page_transitions.dart';
import 'package:wanderer_frontend/presentation/screens/android/trips_plans_list.dart';
import 'package:wanderer_frontend/presentation/screens/android/android_search_screen.dart';
import 'package:wanderer_frontend/presentation/screens/trip_detail_screen.dart';
import 'package:wanderer_frontend/presentation/widgets/common/cached_trip_thumbnail.dart';
import 'package:wanderer_frontend/presentation/widgets/common/pill.dart';

/// Filter chips on My trips; Live covers every started, unfinished state.
enum TripsFilter {
  all,
  live,
  drafts,
  finished;

  bool matches(TripStatus s) => switch (this) {
        TripsFilter.all => true,
        TripsFilter.live => s == TripStatus.inProgress ||
            s == TripStatus.paused ||
            s == TripStatus.resting,
        TripsFilter.drafts => s == TripStatus.created,
        TripsFilter.finished => s == TripStatus.finished,
      };
}

/// Android "Trips" tab root (canvas AndroidTrips / AndroidPlans): My trips
/// with state filters, and the user's trip plans. Shown inside
/// [AndroidShell], which provides the bottom nav and the + button.
class AndroidTripsTab extends StatelessWidget {
  const AndroidTripsTab({super.key});

  /// Bumped to ask the tab to show its Plans sub tab (a counter, so asking
  /// twice in a row still fires after the user swiped back).
  static final ValueNotifier<int> _plansRequests = ValueNotifier(0);

  /// Show the Plans sub tab (e.g. from the You tab's "Trip plans" link).
  static void showPlans() => _plansRequests.value++;

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: c.ground,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              SizedBox(
                height: 64,
                child: Padding(
                  padding: const EdgeInsets.only(left: 20, right: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(l10n.trips,
                            style: WandererTheme.display(24, color: c.text)),
                      ),
                      IconButton(
                        tooltip: l10n.searchTrips,
                        icon: Icon(Icons.search, size: 24, color: c.text),
                        onPressed: () => Navigator.push(
                            context,
                            PageTransitions.slideFromRight(
                                const AndroidSearchScreen(tripsFirst: true))),
                      ),
                    ],
                  ),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: c.line))),
                child: TabBar(
                  indicatorColor: WandererTheme.trail,
                  indicatorWeight: 3,
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerHeight: 0,
                  labelColor: c.accentText,
                  unselectedLabelColor: c.textMuted,
                  labelStyle: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700),
                  unselectedLabelStyle: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                  tabs: [
                    Tab(height: 48, text: l10n.navMyTrips),
                    Tab(height: 48, text: l10n.tripsTabPlans),
                  ],
                ),
              ),
              const Expanded(
                child: _PlansRequestListener(
                  child: TabBarView(
                    children: [_MyTripsList(), AndroidPlansList()],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Switches to the Plans sub tab whenever [AndroidTripsTab.showPlans] runs.
class _PlansRequestListener extends StatefulWidget {
  final Widget child;
  const _PlansRequestListener({required this.child});

  @override
  State<_PlansRequestListener> createState() => _PlansRequestListenerState();
}

class _PlansRequestListenerState extends State<_PlansRequestListener> {
  @override
  void initState() {
    super.initState();
    AndroidTripsTab._plansRequests.addListener(_showPlans);
  }

  @override
  void dispose() {
    AndroidTripsTab._plansRequests.removeListener(_showPlans);
    super.dispose();
  }

  void _showPlans() => DefaultTabController.of(context).animateTo(1);

  @override
  Widget build(BuildContext context) => widget.child;
}

class _MyTripsList extends ConsumerStatefulWidget {
  const _MyTripsList();

  @override
  ConsumerState<_MyTripsList> createState() => _MyTripsListState();
}

class _MyTripsListState extends ConsumerState<_MyTripsList>
    with AutomaticKeepAliveClientMixin {
  List<Trip>? _trips;
  TripsFilter _filter = TripsFilter.all;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // ponytail: first 100 trips only; add paging when someone has more.
    final page =
        await ref.read(homeRepositoryProvider).getMyTrips(page: 0, size: 100);
    if (mounted) setState(() => _trips = page.content);
  }

  Future<void> _open(Trip trip) async {
    await Navigator.push(
        context, PageTransitions.slideFromRight(TripDetailScreen(trip: trip)));
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    final trips = _trips;
    if (trips == null) return const Center(child: CircularProgressIndicator());
    final shown = trips.where((t) => _filter.matches(t.status)).toList();
    String label(TripsFilter f) => switch (f) {
          TripsFilter.all => l10n.profileFilterAll,
          TripsFilter.live => l10n.live,
          TripsFilter.drafts => l10n.profileFilterDrafts,
          TripsFilter.finished => l10n.tripsFilterFinished,
        };
    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              for (final f in TripsFilter.values) ...[
                if (f != TripsFilter.all) const SizedBox(width: 8),
                _FilterChip(
                  label: l10n.tripsFilterCount(
                      label(f), trips.where((t) => f.matches(t.status)).length),
                  selected: _filter == f,
                  onTap: () => setState(() => _filter = f),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: shown.isEmpty
                ? ListView(
                    padding: const EdgeInsets.fromLTRB(16, 48, 16, 110),
                    children: [
                      Icon(Icons.map_outlined, size: 40, color: c.label),
                      const SizedBox(height: 12),
                      Text(
                          trips.isEmpty
                              ? l10n.noTripsYet
                              : l10n.tripsNoneForFilter,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 15, color: c.textMuted)),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
                    itemCount: shown.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) =>
                        _TripRow(trip: shown[i], onTap: () => _open(shown[i])),
                  ),
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? c.neutralButtonBg : c.surface,
        shape: RoundedRectangleBorder(
            side: BorderSide(color: selected ? c.neutralButtonBg : c.line),
            borderRadius: BorderRadius.circular(10)),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            child: Text(label,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: selected ? c.neutralButtonFg : c.textMuted)),
          ),
        ),
      ),
    );
  }
}

class _TripRow extends StatelessWidget {
  final Trip trip;
  final VoidCallback onTap;
  const _TripRow({required this.trip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    final visibility = switch (trip.visibility) {
      Visibility.public => l10n.publicVisibility,
      Visibility.protected => l10n.tripsVisibilityFriends,
      Visibility.private => l10n.privateVisibility,
    };
    final meta = TripsFilter.live.matches(trip.status)
        ? '$visibility · ${DateFormatHelper.formatRelativeDate(l10n, trip.updatedAt)}'
        : visibility;
    return Material(
      color: c.surface,
      shape: RoundedRectangleBorder(
          side: BorderSide(color: c.line),
          borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedTripThumbnail(
                  thumbnailUrl: trip.thumbnailUrl,
                  width: 76,
                  height: 76,
                  placeholder:
                      Container(width: 76, height: 76, color: c.mapGround),
                  errorWidget: Container(
                    width: 76,
                    height: 76,
                    color: c.mapGround,
                    child: Icon(Icons.route, color: c.label),
                  ),
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
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: c.text)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Pill.status(context, trip.status),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(meta,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: c.caption)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
