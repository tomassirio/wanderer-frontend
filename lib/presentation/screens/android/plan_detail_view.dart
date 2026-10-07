import 'package:flutter/material.dart';
import 'package:wanderer_frontend/presentation/helpers/android_app_links.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/presentation/widgets/android/plan_editor_layout.dart';
import 'package:wanderer_frontend/presentation/widgets/android/plan_map_style.dart';
import 'package:wanderer_frontend/presentation/widgets/common/pill.dart';
import 'package:wanderer_frontend/presentation/widgets/common/wanderer_sheet.dart';

/// Android plan detail (canvas AndroidPlanDetail): map on top with floating
/// back / more buttons, plan info in a bottom sheet with Start this trip.
class AndroidPlanDetailView extends StatelessWidget {
  final TripPlan plan;
  final bool mobileWeb;
  final Widget map;
  final List<LatLng> route;
  final VoidCallback onBack;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback onStart;
  final ValueChanged<LatLng> onFocusStop;

  const AndroidPlanDetailView({
    super.key,
    required this.plan,
    this.mobileWeb = false,
    required this.map,
    required this.route,
    required this.onBack,
    required this.onDelete,
    required this.onEdit,
    required this.onStart,
    required this.onFocusStop,
  });

  static String? _place(PlanLocation? l) =>
      l == null || (l.lat == 0 && l.lon == 0)
          ? null
          : PlanMapStyle.coords(LatLng(l.lat, l.lon));

  void _showMore(BuildContext context) {
    final l10n = context.l10n;
    final error = Theme.of(context).colorScheme.error;
    showWandererSheet<void>(
      context,
      builder: (sheet) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.delete_outline, color: error),
        title: Text(l10n.tripPlansDeleteAction, style: TextStyle(color: error)),
        onTap: () {
          Navigator.pop(sheet);
          onDelete();
        },
      ),
    );
  }

  void _showStops(BuildContext context) {
    final l10n = context.l10n;
    final c = WandererTheme.of(context);
    showWandererSheet<void>(
      context,
      title: l10n.planEditorStopsCount(plan.waypoints.length),
      builder: (sheet) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (i, w) in plan.waypoints.indexed)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                radius: 14,
                backgroundColor: c.trailSoftBg,
                child: Text('${i + 1}',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: c.trailSoftFg)),
              ),
              title: Text('${l10n.planEditorStop} ${i + 1}',
                  style: TextStyle(fontWeight: FontWeight.w700, color: c.text)),
              subtitle: Text(PlanMapStyle.coords(LatLng(w.lat, w.lon)),
                  style: TextStyle(color: c.caption)),
              onTap: () {
                Navigator.pop(sheet);
                onFocusStop(LatLng(w.lat, w.lon));
              },
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    final multiDay = plan.planType == 'MULTI_DAY';
    final km = route.length >= 2 ? PlanMapStyle.distanceKm(route) : null;
    final days = plan.startDate == null || plan.endDate == null
        ? null
        : DateUtils.dateOnly(plan.endDate!)
                .difference(DateUtils.dateOnly(plan.startDate!))
                .inDays +
            1;
    String kmText(double v) => l10n.kmValue(v.round());

    Widget stat(String label, String value) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
                border: Border.all(color: c.lineSoft),
                borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: c.caption)),
                Text(value,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: c.text)),
              ],
            ),
          ),
        );

    Widget caps(String text, Color color) => Text(text,
        style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.66,
            color: color));
    final valueStyle =
        TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.text);

    return Scaffold(
      backgroundColor: c.mapGround,
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(child: map),
                // A plan saved before its route is known.
                if (route.isEmpty &&
                    _place(plan.startLocation) == null &&
                    _place(plan.endLocation) == null)
                  Positioned.fill(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Container(
                          key: const Key('plan_no_route'),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                              color: c.overlayPillBg,
                              borderRadius: BorderRadius.circular(16)),
                          child: Text(l10n.planNoRoute,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: c.text)),
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  left: 16,
                  right: 16,
                  top: 0,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          PlanMapButton(
                              icon: Icons.arrow_back,
                              tooltip: MaterialLocalizations.of(context)
                                  .backButtonTooltip,
                              onTap: onBack),
                          PlanMapButton(
                              icon: Icons.more_vert,
                              tooltip: l10n.planMoreOptions,
                              onTap: () => _showMore(context)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: mobileWeb
                      ? MediaQuery.sizeOf(context).height * 0.62
                      : double.infinity),
              child: PlanSheet(children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Pill(multiDay
                        ? l10n.planDetailMultiDayPlan
                        : l10n.planDetailSimplePlan),
                    const SizedBox(height: 8),
                    Text(plan.name,
                        style: WandererTheme.display(24, color: c.text)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.calendar_today_outlined,
                            size: 15, color: c.textMuted),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                              planDateRange(
                                      context, plan.startDate, plan.endDate) ??
                                  l10n.noDateSet,
                              style:
                                  TextStyle(fontSize: 14, color: c.textMuted)),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: c.raised, borderRadius: BorderRadius.circular(14)),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 4, bottom: 6),
                          child: Column(
                            children: [
                              const _Dot(fill: WandererTheme.forest, size: 12),
                              Expanded(child: VerticalDivider(color: c.line)),
                              const _Dot(
                                  fill: Colors.white,
                                  ring: WandererTheme.trail,
                                  size: 10),
                              Expanded(child: VerticalDivider(color: c.line)),
                              const _Dot(fill: WandererTheme.trail, size: 12),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              caps(l10n.planEditorStartCaps, c.forestFg),
                              Text(
                                  _place(plan.startLocation) ??
                                      l10n.planEditorNotSet,
                                  style: valueStyle),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        caps(l10n.planEditorStopsCaps,
                                            c.accentText),
                                        Text(
                                            plan.waypoints.isEmpty
                                                ? l10n.planNoStops
                                                : l10n.planEditorStopsCount(
                                                    plan.waypoints.length),
                                            style: valueStyle),
                                      ],
                                    ),
                                  ),
                                  if (plan.waypoints.isNotEmpty)
                                    TextButton(
                                      onPressed: () => _showStops(context),
                                      style: TextButton.styleFrom(
                                          foregroundColor: c.accentText,
                                          textStyle: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700)),
                                      child: Text(l10n.planShowAll),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              caps(l10n.planEditorFinishCaps, c.accentText),
                              Text(
                                  _place(plan.endLocation) ??
                                      l10n.planEditorNotSet,
                                  style: valueStyle),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (km != null && !mobileWeb)
                  Row(
                    children: [
                      stat(l10n.planPlannedDistance, kmText(km)),
                      if (multiDay && days != null && days > 0) ...[
                        const SizedBox(width: 8),
                        stat(l10n.planDetailPerDay, kmText(km / days)),
                      ],
                    ],
                  ),
                Row(
                  children: [
                    Expanded(
                      child: PlanPrimaryButton(
                        label: mobileWeb
                            ? l10n.mobileWebStartInApp
                            : l10n.planDetailStartTrip,
                        icon: Icons.play_arrow_rounded,
                        onPressed: mobileWeb
                            ? () =>
                                AndroidAppLinks.open(context, planId: plan.id)
                            : onStart,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 56,
                      child: OutlinedButton(
                        onPressed: onEdit,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: c.text,
                          side: BorderSide(color: c.line),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          textStyle: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                        child: Text(l10n.edit),
                      ),
                    ),
                  ],
                ),
                if (mobileWeb)
                  TextButton(
                    onPressed: () =>
                        AndroidAppLinks.open(context, install: true),
                    child: Text(
                        '${l10n.mobileWebTrackingNeedsApp} ${l10n.mobileWebGet}',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: c.caption)),
                  ),
              ])),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final Color fill;
  final Color? ring;
  final double size;
  const _Dot({required this.fill, this.ring, required this.size});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: fill,
          shape: BoxShape.circle,
          border: ring == null ? null : Border.all(color: ring!, width: 2),
        ),
      );
}
