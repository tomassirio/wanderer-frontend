import 'package:wanderer_frontend/presentation/screens/android/ready_trip_screen.dart';
import 'package:flutter/material.dart';
import 'package:wanderer_frontend/presentation/helpers/adaptive_layout.dart';
import 'package:wanderer_frontend/presentation/helpers/android_app_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/providers/app_providers.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/presentation/helpers/page_transitions.dart';
import 'package:wanderer_frontend/presentation/screens/trip_plan_detail_screen.dart';
import 'package:wanderer_frontend/presentation/widgets/android/plan_editor_layout.dart';
import 'package:wanderer_frontend/presentation/widgets/common/cached_trip_thumbnail.dart';
import 'package:wanderer_frontend/presentation/widgets/common/pill.dart';
import 'package:wanderer_frontend/presentation/widgets/common/wanderer_sheet.dart';

/// Android "Plans" list (canvas AndroidPlans): plan cards with a map
/// preview, Start this trip / Edit, and a hint pointing at the + button.
class AndroidPlansList extends ConsumerStatefulWidget {
  const AndroidPlansList({super.key});

  @override
  ConsumerState<AndroidPlansList> createState() => _AndroidPlansListState();
}

class _AndroidPlansListState extends ConsumerState<AndroidPlansList>
    with AutomaticKeepAliveClientMixin {
  List<TripPlan>? _plans;
  Object? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final plans = await ref.read(tripPlanServiceProvider).getUserTripPlans();
      if (mounted) {
        setState(() {
          _plans = plans;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _open(TripPlan plan, {bool edit = false}) async {
    await Navigator.push(
      context,
      PageTransitions.slideFromRight(
          TripPlanDetailScreen(tripPlan: plan, startInEdit: edit)),
    );
    if (mounted) _load();
  }

  Future<void> _start(TripPlan plan) async {
    if (AdaptiveLayout.isMobileWeb(context)) {
      await AndroidAppLinks.open(context, planId: plan.id);
      return;
    }
    await Navigator.push(
        context, PageTransitions.slideFromBottom(ReadyTripScreen(plan: plan)));
    if (mounted) _load();
  }

  Future<void> _delete(TripPlan plan) async {
    if (!await confirmPlanDelete(context, plan.name) || !mounted) return;
    try {
      await ref.read(tripPlanServiceProvider).deleteTripPlan(plan.id);
      if (!mounted) return;
      planNotify(context, context.l10n.planDeleted);
      setState(() => _plans?.removeWhere((p) => p.id == plan.id));
    } catch (e) {
      if (mounted) planNotify(context, '$e', error: true);
    }
  }

  void _more(TripPlan plan) {
    final l10n = context.l10n;
    final error = Theme.of(context).colorScheme.error;
    showWandererSheet<void>(
      context,
      title: plan.name,
      builder: (sheet) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.delete_outline, color: error),
        title: Text(l10n.tripPlansDeleteAction, style: TextStyle(color: error)),
        onTap: () {
          Navigator.pop(sheet);
          _delete(plan);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    final plans = _plans;
    if (plans == null && _error == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
        children: [
          if (_error != null && plans == null)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                children: [
                  Text(l10n.errorLoadingTripPlans,
                      style: TextStyle(color: c.textMuted)),
                  TextButton(onPressed: _load, child: Text(l10n.retry)),
                ],
              ),
            ),
          for (final plan in plans ?? const <TripPlan>[]) ...[
            _PlanCard(
              plan: plan,
              onOpen: () => _open(plan),
              onEdit: () => _open(plan, edit: true),
              onStart: () => _start(plan),
              onMore: () => _more(plan),
            ),
            const SizedBox(height: 14),
          ],
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: c.line, width: 2),
            ),
            child: Text(
                AdaptiveLayout.isMobileWeb(context)
                    ? l10n.mobileWebPlansHint
                    : l10n.plansEmptyHint,
                textAlign: TextAlign.center,
                style:
                    TextStyle(fontSize: 14, height: 1.5, color: c.textMuted)),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final TripPlan plan;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onStart;
  final VoidCallback onMore;
  const _PlanCard({
    required this.plan,
    required this.onOpen,
    required this.onEdit,
    required this.onStart,
    required this.onMore,
  });

  static bool _valid(PlanLocation? l) => l != null && l.lat != 0 && l.lon != 0;

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    final hasRoute = _valid(plan.startLocation) ||
        _valid(plan.endLocation) ||
        plan.waypoints.any(_valid);
    final placeholder = Container(
      color: c.mapGround,
      child: Icon(Icons.route, size: 40, color: c.label),
    );
    return Material(
      color: c.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
          side: BorderSide(color: c.line),
          borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 170,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  hasRoute
                      ? CachedTripThumbnail(
                          thumbnailUrl: plan.thumbnailUrl,
                          placeholder: Container(color: c.mapGround),
                          errorWidget: placeholder)
                      : placeholder,
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Pill(
                        plan.planType == 'MULTI_DAY'
                            ? l10n.tripPlansMultiDay
                            : l10n.newTripSingleDay,
                        tone: PillTone.onImage),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Material(
                      color: c.overlayPillBg,
                      shape: const CircleBorder(),
                      child: IconButton(
                        tooltip: l10n.planMoreOptions,
                        onPressed: onMore,
                        icon: Icon(Icons.more_vert, size: 20, color: c.text),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(plan.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: WandererTheme.display(19, color: c.text)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.calendar_today_outlined,
                          size: 14, color: c.caption),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                            planDateRange(
                                    context, plan.startDate, plan.endDate) ??
                                l10n.noDateSet,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13, color: c.caption)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: FilledButton.icon(
                            onPressed: AdaptiveLayout.isMobileWeb(context)
                                ? onOpen
                                : onStart,
                            style: FilledButton.styleFrom(
                              backgroundColor: c.neutralButtonBg,
                              foregroundColor: c.neutralButtonFg,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              textStyle: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w700),
                            ),
                            icon: Icon(
                                AdaptiveLayout.isMobileWeb(context)
                                    ? Icons.map_outlined
                                    : Icons.play_arrow_rounded,
                                size: 20),
                            label: Text(
                                AdaptiveLayout.isMobileWeb(context)
                                    ? l10n.mobileWebViewPlan
                                    : l10n.planDetailStartTrip,
                                overflow: TextOverflow.ellipsis),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 48,
                        child: OutlinedButton(
                          onPressed: AdaptiveLayout.isMobileWeb(context)
                              ? onStart
                              : onEdit,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: c.text,
                            side: BorderSide(color: c.line),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            textStyle: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                          child: Text(AdaptiveLayout.isMobileWeb(context)
                              ? l10n.mobileWebStartInApp
                              : l10n.edit),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
