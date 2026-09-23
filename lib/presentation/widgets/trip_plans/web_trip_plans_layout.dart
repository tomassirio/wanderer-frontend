import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/presentation/widgets/common/cached_trip_thumbnail.dart';
import 'package:wanderer_frontend/presentation/widgets/common/pill.dart';
import 'package:wanderer_frontend/presentation/widgets/common/web_page_header.dart';

/// Web layout of the Trip plans page: header, 3-column plan cards grid and a
/// dashed "Plan a new trip" tile. Mobile keeps [TripPlansContent].
class WebTripPlansLayout extends StatelessWidget {
  final bool isLoading;
  final String? error;
  final List<TripPlan> tripPlans;
  final bool isLoggedIn;
  final String? userId;
  final Future<void> Function() onRefresh;
  final void Function(TripPlan) onOpen;
  final void Function(TripPlan) onStartTrip;
  final void Function(TripPlan) onDelete;
  final VoidCallback onLogin;
  final VoidCallback onCreate;

  const WebTripPlansLayout({
    super.key,
    required this.isLoading,
    required this.error,
    required this.tripPlans,
    required this.isLoggedIn,
    required this.userId,
    required this.onRefresh,
    required this.onOpen,
    required this.onStartTrip,
    required this.onDelete,
    required this.onLogin,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: LayoutBuilder(builder: (context, constraints) {
        final width = constraints.maxWidth;
        final gutter = width >= 720 ? 40.0 : 16.0;
        final columns = width >= 1000
            ? 3
            : width >= 640
                ? 2
                : 1;
        return ListView(
          padding: EdgeInsets.fromLTRB(gutter, 28, gutter, 40),
          children: [
            WebPageHeader(
              title: l10n.tripPlansTitle,
              subtitle: l10n.tripPlansSubtitle,
              isLoggedIn: isLoggedIn,
              userId: userId,
              primaryAction: isLoggedIn
                  ? ElevatedButton.icon(
                      onPressed: onCreate,
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(l10n.tripPlansNewPlan),
                    )
                  : null,
            ),
            const SizedBox(height: 28),
            _buildContent(context, columns),
          ],
        );
      }),
    );
  }

  Widget _buildContent(BuildContext context, int columns) {
    final l10n = context.l10n;
    if (!isLoggedIn) {
      return _StatePanel(
        icon: Icons.calendar_today_outlined,
        title: l10n.loginRequired,
        message: l10n.pleaseLogInForPlans,
        action: ElevatedButton.icon(
          onPressed: onLogin,
          icon: const Icon(Icons.login, size: 18),
          label: Text(l10n.login),
        ),
      );
    }
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 64),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (error != null) {
      return _StatePanel(
        icon: Icons.error_outline,
        title: l10n.errorLoadingTripPlans,
        message: error!,
        action: OutlinedButton(onPressed: onRefresh, child: Text(l10n.retry)),
      );
    }

    final cells = <Widget>[
      for (final plan in tripPlans)
        _PlanCard(
          plan: plan,
          onOpen: () => onOpen(plan),
          onStartTrip: () => onStartTrip(plan),
          onDelete: () => onDelete(plan),
        ),
      _NewPlanTile(
        title: tripPlans.isEmpty ? l10n.noTripPlansYet : null,
        onTap: onCreate,
      ),
    ];

    // Rows of equal-height cells so the dashed tile matches the cards.
    return Column(
      children: [
        for (var i = 0; i < cells.length; i += columns) ...[
          if (i > 0) const SizedBox(height: 24),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var j = i; j < i + columns; j++) ...[
                  if (j > i) const SizedBox(width: 24),
                  Expanded(
                      child: j < cells.length ? cells[j] : const SizedBox()),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  final TripPlan plan;
  final VoidCallback onOpen;
  final VoidCallback onStartTrip;
  final VoidCallback onDelete;

  const _PlanCard({
    required this.plan,
    required this.onOpen,
    required this.onStartTrip,
    required this.onDelete,
  });

  static bool _valid(PlanLocation? l) => l != null && l.lat != 0 && l.lon != 0;

  bool get _hasRoute =>
      _valid(plan.startLocation) ||
      _valid(plan.endLocation) ||
      plan.waypoints.any(_valid);

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    final (modality, modalityIcon) = switch (plan.planType) {
      'SIMPLE' => (l10n.simple, Icons.place_outlined),
      'MULTI_DAY' => (l10n.tripPlansMultiDay, Icons.date_range_outlined),
      _ => (
          plan.planType
              .split('_')
              .map((w) => w.isEmpty ? w : w[0] + w.substring(1).toLowerCase())
              .join(' '),
          Icons.map_outlined
        ),
    };

    final noRoute = Container(
      color: c.mapGround,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(l10n.noRouteSet,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: c.caption)),
          const SizedBox(height: 4),
          TextButton(
            onPressed: onOpen,
            style: TextButton.styleFrom(
              foregroundColor: c.accentText,
              textStyle:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            child: Text(l10n.tripPlansDrawRoute),
          ),
        ],
      ),
    );

    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: WandererTheme.cardDecoration(context),
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(WandererTheme.radiusPanel),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(WandererTheme.radiusPanel),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 180,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (_hasRoute)
                        CachedTripThumbnail(
                          thumbnailUrl: plan.thumbnailUrl,
                          placeholder: Container(color: c.mapGround),
                          errorWidget: Container(
                            color: c.mapGround,
                            child: Icon(Icons.route, size: 40, color: c.label),
                          ),
                        )
                      else
                        noRoute,
                      Positioned(
                        top: 14,
                        left: 14,
                        child: Pill(modality,
                            tone: PillTone.onImage, icon: modalityIcon),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(plan.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: WandererTheme.display(20, color: c.text)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.calendar_today_outlined,
                              size: 14, color: c.caption),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _dates(context),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  TextStyle(fontSize: 13, color: c.textMuted),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: onStartTrip,
                              style: FilledButton.styleFrom(
                                backgroundColor: c.neutralButtonBg,
                                foregroundColor: c.neutralButtonFg,
                              ),
                              icon: const Icon(Icons.play_arrow_rounded,
                                  size: 20),
                              label: Text(l10n.tripPlansStartTrip,
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: onOpen,
                            style: OutlinedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 14),
                            ),
                            child: Text(l10n.edit),
                          ),
                          const SizedBox(width: 8),
                          IconButton.outlined(
                            tooltip: l10n.deleteTripPlan,
                            onPressed: onDelete,
                            color: Theme.of(context).colorScheme.error,
                            style: IconButton.styleFrom(
                              fixedSize: const Size(44, 44),
                              side: BorderSide(color: c.line),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                    WandererTheme.radiusControl),
                              ),
                            ),
                            icon: const Icon(Icons.delete_outline, size: 20),
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
      ),
    );
  }

  String _dates(BuildContext context) {
    final start = plan.startDate, end = plan.endDate;
    if (start == null || end == null) return context.l10n.noDateSet;
    final locale = Localizations.localeOf(context).toString();
    final days =
        DateUtils.dateOnly(end).difference(DateUtils.dateOnly(start)).inDays +
            1;
    return '${DateFormat('d MMM', locale).format(start)} – '
        '${DateFormat('d MMM yyyy', locale).format(end)} · '
        '${context.l10n.daysCount(days)}';
  }
}

class _NewPlanTile extends StatelessWidget {
  final String? title;
  final VoidCallback onTap;

  const _NewPlanTile({this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    final radius = BorderRadius.circular(WandererTheme.radiusPanel);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 320),
      child: CustomPaint(
        painter: _DashedBorderPainter(color: c.line),
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                        color: c.trailSoftBg, shape: BoxShape.circle),
                    child: Icon(Icons.add, color: c.trailSoftFg),
                  ),
                  const SizedBox(height: 12),
                  Text(title ?? l10n.tripPlansPlanNewTrip,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: c.text)),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 220),
                    child: Text(l10n.tripPlansPlanNewTripHint,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 13, height: 1.5, color: c.textMuted)),
                  ),
                ],
              ),
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
      ..addRRect(RRect.fromRectAndRadius((Offset.zero & size).deflate(1),
          const Radius.circular(WandererTheme.radiusPanel)));
    for (final metric in path.computeMetrics()) {
      for (double d = 0; d < metric.length; d += 12) {
        canvas.drawPath(metric.extractPath(d, d + 6), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) => old.color != color;
}

class _StatePanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget action;

  const _StatePanel({
    required this.icon,
    required this.title,
    required this.message,
    required this.action,
  });

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 56),
      decoration: WandererTheme.cardDecoration(context),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration:
                BoxDecoration(color: c.neutralBg, shape: BoxShape.circle),
            child: Icon(icon, color: c.neutralFg),
          ),
          const SizedBox(height: 16),
          Text(title,
              textAlign: TextAlign.center,
              style: WandererTheme.display(22, color: c.text)),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: c.textMuted)),
          ),
          const SizedBox(height: 24),
          action,
        ],
      ),
    );
  }
}
