import 'dart:math';

import 'package:flutter/material.dart' hide Visibility;
import 'package:intl/intl.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/presentation/widgets/common/pill.dart';

/// Web trip plan detail (canvas "Trip plan"): breadcrumb header with
/// delete / edit / start actions, the map card and a 380px column with the
/// route, dates and a "what happens when you start" note.
///
/// Purely presentational: `TripPlanDetailScreen` owns state and the map.
class WebPlanDetailLayout extends StatelessWidget {
  final TripPlan plan;
  final Widget map;
  final VoidCallback onBack;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback onStartTrip;
  final VoidCallback? onZoomIn;
  final VoidCallback? onZoomOut;
  final VoidCallback? onFitRoute;

  const WebPlanDetailLayout({
    super.key,
    required this.plan,
    required this.map,
    required this.onBack,
    required this.onDelete,
    required this.onEdit,
    required this.onStartTrip,
    this.onZoomIn,
    this.onZoomOut,
    this.onFitRoute,
  });

  /// Inclusive day count, or null when dates are missing.
  static int? dayCount(DateTime? start, DateTime? end) =>
      start == null || end == null ? null : end.difference(start).inDays + 1;

  /// Great-circle distance in km between two plan locations.
  static double haversineKm(PlanLocation a, PlanLocation b) {
    double rad(double d) => d * pi / 180;
    final dLat = rad(b.lat - a.lat);
    final dLon = rad(b.lon - a.lon);
    final h = pow(sin(dLat / 2), 2) +
        cos(rad(a.lat)) * cos(rad(b.lat)) * pow(sin(dLon / 2), 2);
    return 2 * 6371 * asin(sqrt(h));
  }

  /// "8.4 km" under 10 km, "124 km" above.
  static String formatKm(double km) =>
      '${km < 10 ? km.toStringAsFixed(1) : km.round()} km';

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 900;
      final gutter = constraints.maxWidth >= 600 ? 40.0 : 16.0;
      final header = _header(context);
      final mapCard = _mapCard(context);
      final side = [
        _routeCard(context),
        const SizedBox(height: 16),
        _datesCard(context),
        const SizedBox(height: 16),
        _infoCard(context),
      ];
      final padding = EdgeInsets.fromLTRB(gutter, 24, gutter, 28);
      if (!wide) {
        return ListView(
          padding: padding,
          children: [
            header,
            const SizedBox(height: 20),
            SizedBox(height: 420, child: mapCard),
            const SizedBox(height: 20),
            ...side,
          ],
        );
      }
      return Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            const SizedBox(height: 20),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: mapCard),
                  const SizedBox(width: 20),
                  SizedBox(
                    width: 380,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: side,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _header(BuildContext context) {
    final l10n = context.l10n;
    final c = WandererTheme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final crumb = TextStyle(
        fontSize: 13, fontWeight: FontWeight.w600, color: c.textMuted);
    final days = dayCount(plan.startDate, plan.endDate);
    final dateLine = days == null
        ? l10n.noDateSet
        : '${DateFormat('EEE d MMM', locale).format(plan.startDate!)} – '
            '${DateFormat('EEE d MMM yyyy', locale).format(plan.endDate!)} · '
            '${l10n.daysCount(days)}';

    final left = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: 'Breadcrumb',
          child: Wrap(
            spacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              InkWell(
                onTap: onBack,
                borderRadius: BorderRadius.circular(6),
                child: Text(l10n.tripPlansTitle, style: crumb),
              ),
              Text('/', style: crumb.copyWith(color: c.caption)),
              Text(plan.name, style: crumb.copyWith(color: c.text)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Semantics(
              header: true,
              child: Text(plan.name, style: WandererTheme.display(32)),
            ),
            Pill(
              plan.planType == 'MULTI_DAY'
                  ? l10n.planDetailMultiDayPlan
                  : l10n.planDetailSimplePlan,
              tone: PillTone.neutral,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today_outlined, size: 16, color: c.textMuted),
            const SizedBox(width: 8),
            Flexible(
              child: Text(dateLine,
                  style: TextStyle(fontSize: 14, color: c.textMuted)),
            ),
          ],
        ),
      ],
    );

    final actions = Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        IconButton(
          tooltip: l10n.tripPlansDeleteAction,
          onPressed: onDelete,
          style: IconButton.styleFrom(
            fixedSize: const Size(44, 44),
            backgroundColor: c.surface,
            foregroundColor: Theme.of(context).colorScheme.error,
            side: BorderSide(color: c.line),
            shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(WandererTheme.radiusControl)),
          ),
          icon: const Icon(Icons.delete_outline, size: 18),
        ),
        OutlinedButton.icon(
          onPressed: onEdit,
          icon: const Icon(Icons.edit_outlined, size: 16),
          label: Text(l10n.planDetailEditPlan),
        ),
        ElevatedButton.icon(
          onPressed: onStartTrip,
          icon: const Icon(Icons.play_arrow_rounded, size: 18),
          label: Text(l10n.planDetailStartTrip),
        ),
      ],
    );

    return Wrap(
      spacing: 24,
      runSpacing: 16,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.end,
      children: [left, actions],
    );
  }

  Widget _mapCard(BuildContext context) {
    final l10n = context.l10n;
    final c = WandererTheme.of(context);
    const shadow = [
      BoxShadow(color: Color(0x141B1A17), blurRadius: 16, offset: Offset(0, 4)),
    ];
    final buttons = [
      (Icons.add, l10n.planEditorZoomIn, onZoomIn),
      (Icons.remove, l10n.planEditorZoomOut, onZoomOut),
      (Icons.center_focus_strong_outlined, l10n.planDetailFitRoute, onFitRoute),
    ];
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration:
          WandererTheme.cardDecoration(context).copyWith(color: c.mapGround),
      child: Stack(
        fit: StackFit.expand,
        children: [
          map,
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius:
                    BorderRadius.circular(WandererTheme.radiusControl),
                boxShadow: shadow,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.route_outlined, size: 16, color: c.textMuted),
                  const SizedBox(width: 8),
                  Text(l10n.planDetailPlannedChip,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: c.neutralFg)),
                ],
              ),
            ),
          ),
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius:
                    BorderRadius.circular(WandererTheme.radiusControl),
                boxShadow: shadow,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < buttons.length; i++) ...[
                    if (i > 0)
                      Container(width: 44, height: 1, color: c.lineSoft),
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: IconButton(
                        tooltip: buttons[i].$2,
                        onPressed: buttons[i].$3,
                        color: c.text,
                        iconSize: 18,
                        icon: Icon(buttons[i].$1),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardHeader(BuildContext context, String title) {
    final c = WandererTheme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(title,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700, color: c.text)),
        ),
        TextButton(
          onPressed: onEdit,
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 32),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            textStyle:
                const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          child: Text(context.l10n.planDetailChange),
        ),
      ],
    );
  }

  Widget _routeCard(BuildContext context) {
    final l10n = context.l10n;
    final c = WandererTheme.of(context);
    final start = plan.startLocation;
    final end = plan.endLocation;
    final km = start != null && end != null ? haversineKm(start, end) : null;
    final days = dayCount(plan.startDate, plan.endDate);

    Widget dot(Color color) => Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle));

    Widget point(String caps, Color capsColor, PlanLocation? loc) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(caps,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: capsColor)),
            const SizedBox(height: 2),
            Text(
              loc == null
                  ? l10n.planEditorNotSet
                  : '${loc.lat.toStringAsFixed(4)}, ${loc.lon.toStringAsFixed(4)}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
                fontFamilyFallback: const ['Menlo', 'Courier'],
                color: loc == null ? c.label : c.text,
              ),
            ),
          ],
        );

    Widget stat(String label, String value) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: c.raised,
              borderRadius: BorderRadius.circular(WandererTheme.radiusControl),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: c.caption)),
                const SizedBox(height: 2),
                Text(value,
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: c.text)),
              ],
            ),
          ),
        );

    return Container(
      decoration: WandererTheme.cardDecoration(context),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _cardHeader(context, l10n.planEditorRoute),
          const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Column(
                    children: [
                      dot(c.forestFg),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: CustomPaint(
                            size: const Size(2, double.infinity),
                            painter: _DashPainter(c.line),
                          ),
                        ),
                      ),
                      dot(WandererTheme.trail),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      point(l10n.planEditorStartCaps, c.forestFg, start),
                      const SizedBox(height: 22),
                      point(
                          l10n.planEditorFinishCaps, WandererTheme.trail, end),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              stat(
                  l10n.planDetailStraightLine, km == null ? '—' : formatKm(km)),
              const SizedBox(width: 10),
              stat(
                l10n.planDetailPerDay,
                km == null || days == null || days < 1
                    ? '—'
                    : formatKm(km / days),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _datesCard(BuildContext context) {
    final l10n = context.l10n;
    final c = WandererTheme.of(context);
    final locale = Localizations.localeOf(context).toString();
    Widget tile(String label, DateTime? date) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: c.lineSoft),
              borderRadius: BorderRadius.circular(WandererTheme.radiusControl),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: c.caption)),
                const SizedBox(height: 2),
                Text(
                  date == null
                      ? l10n.planEditorNotSet
                      : DateFormat('EEE d MMM', locale).format(date),
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: date == null ? c.label : c.text),
                ),
              ],
            ),
          ),
        );
    return Container(
      decoration: WandererTheme.cardDecoration(context),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _cardHeader(context, l10n.planEditorDates),
          const SizedBox(height: 10),
          Row(
            children: [
              tile(l10n.planEditorLeave, plan.startDate),
              const SizedBox(width: 10),
              tile(l10n.planEditorArrive, plan.endDate),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoCard(BuildContext context) {
    final l10n = context.l10n;
    final c = WandererTheme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: c.trailSoftBg,
        borderRadius: BorderRadius.circular(WandererTheme.radiusPanel),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: c.trailSoftFg),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(
                    text: '${l10n.planDetailWhatHappensTitle} ',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                TextSpan(text: l10n.planDetailWhatHappensBody),
              ]),
              style:
                  TextStyle(fontSize: 14, height: 1.55, color: c.trailSoftFg),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashPainter extends CustomPainter {
  final Color color;
  const _DashPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2;
    final x = size.width / 2;
    for (double y = 0; y < size.height; y += 8) {
      canvas.drawLine(Offset(x, y), Offset(x, min(y + 4, size.height)), paint);
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => old.color != color;
}
