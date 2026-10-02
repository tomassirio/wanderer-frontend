import 'package:flutter/material.dart';
import 'package:wanderer_frontend/core/constants/enums.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/data/models/achievement_models.dart';
import 'package:wanderer_frontend/data/models/notification_models.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/presentation/screens/achievements_screen.dart';
import 'package:wanderer_frontend/presentation/screens/android/android_notifications_screen.dart';
import 'package:wanderer_frontend/presentation/widgets/common/cached_trip_thumbnail.dart';
import 'package:wanderer_frontend/presentation/widgets/common/pill.dart';

/// Days a started trip has been out (start to end, or to now while open).
int tripDaysOut(Trip t, {DateTime? now}) {
  final start = t.startDate;
  if (start == null || t.status == TripStatus.created) return 0;
  final end = t.endDate ?? now ?? DateTime.now();
  return end.difference(start).inDays + 1;
}

/// Progress toward an achievement from what the app already knows: per-trip
/// goals use the best single trip, social goals the profile counters. Null
/// when the app cannot tell (e.g. profile completed).
double? achievementProgress(Achievement a, List<Trip> trips,
    {required int followers, required int friends, DateTime? now}) {
  final type = a.type.toJson();
  double best(double Function(Trip) f) =>
      trips.fold(0.0, (m, t) => f(t) > m ? f(t) : m);
  if (type == 'FIRST_TRIP') {
    return trips.any((t) => t.status != TripStatus.created) ? 1 : 0;
  }
  if (type.startsWith('DISTANCE_')) {
    return best((t) => t.accruedDistanceKm ?? 0);
  }
  if (type.startsWith('UPDATES_')) {
    return best((t) => (t.updateCount ?? 0).toDouble());
  }
  if (type.startsWith('DURATION_')) {
    return best((t) => tripDaysOut(t, now: now).toDouble());
  }
  if (type.startsWith('FOLLOWERS_')) return followers.toDouble();
  if (type.startsWith('FRIENDS_')) return friends.toDouble();
  return null;
}

/// The locked achievement closest to done (highest share of its threshold,
/// smaller threshold on ties), with the current value.
({Achievement achievement, double value})? nextBadge(
    List<Achievement> all, Set<String> unlockedIds, List<Trip> trips,
    {required int followers, required int friends, DateTime? now}) {
  ({Achievement achievement, double value})? pick;
  double pickRatio = -1;
  for (final a in all) {
    if (unlockedIds.contains(a.id) || a.thresholdValue <= 0) continue;
    final v = achievementProgress(a, trips,
        followers: followers, friends: friends, now: now);
    if (v == null) continue;
    final ratio = (v / a.thresholdValue).clamp(0.0, 1.0);
    if (ratio > pickRatio ||
        (ratio == pickRatio &&
            a.thresholdValue < pick!.achievement.thresholdValue)) {
      pick = (achievement: a, value: v);
      pickRatio = ratio;
    }
  }
  return pick;
}

/// Section heading with an optional trailing link (canvas: 17 / 700).
class HomeSectionTitle extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  const HomeSectionTitle(this.title, {super.key, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(title,
                style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w700, color: c.text)),
          ),
        ),
        if (action != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: c.accentText,
              minimumSize: const Size(48, 40),
              textStyle:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            child: Text(action!),
          ),
      ]),
    );
  }
}

/// Horizontal, swipeable trip cards (300dp, map thumbnail + pill) with
/// page dots. Used for "Your recent trips" and "Get inspired".
class HomeTripCarousel extends StatefulWidget {
  final List<Trip> trips;
  final String Function(Trip) subtitle;
  final ValueChanged<Trip> onTap;
  const HomeTripCarousel(
      {super.key,
      required this.trips,
      required this.subtitle,
      required this.onTap});

  @override
  State<HomeTripCarousel> createState() => _HomeTripCarouselState();
}

class _HomeTripCarouselState extends State<HomeTripCarousel> {
  int _page = 0;
  PageController? _controller;

  /// Cards stay 300dp (+ gap) whatever the width.
  PageController _controllerFor(double width) {
    final fraction = (312 / width).clamp(0.5, 0.92);
    if (_controller?.viewportFraction != fraction) {
      // The PageView detaches the old controller during this build.
      final old = _controller;
      WidgetsBinding.instance.addPostFrameCallback((_) => old?.dispose());
      _controller =
          PageController(viewportFraction: fraction, initialPage: _page);
    }
    return _controller!;
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    final trips = widget.trips;
    return LayoutBuilder(builder: (context, box) {
      return Column(children: [
        SizedBox(
          height: 222,
          child: PageView.builder(
            key: const Key('home_trip_carousel'),
            controller: _controllerFor(box.maxWidth),
            padEnds: false,
            itemCount: trips.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _TripCard(
                  trip: trips[i],
                  subtitle: widget.subtitle(trips[i]),
                  onTap: () => widget.onTap(trips[i])),
            ),
          ),
        ),
        if (trips.length > 1) ...[
          const SizedBox(height: 10),
          ExcludeSemantics(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < trips.length && i < 8; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _page ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == _page ? c.text : c.line,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ]);
    });
  }
}

class _TripCard extends StatelessWidget {
  final Trip trip;
  final String subtitle;
  final VoidCallback onTap;
  const _TripCard(
      {required this.trip, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    final ground = Container(
        color: c.mapGround, child: Icon(Icons.route, size: 40, color: c.label));
    return Material(
      color: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: c.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 140,
              child: Stack(fit: StackFit.expand, children: [
                CachedTripThumbnail(
                  thumbnailUrl: trip.thumbnailUrl,
                  placeholder: ground,
                  errorWidget: ground,
                ),
                Positioned(
                    top: 10,
                    left: 10,
                    child: Pill.status(context, trip.status)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(trip.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: WandererTheme.display(17, color: c.text)),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: c.caption)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Friends lately": the latest notifications with an actor, one row each.
class HomeFriendsActivity extends StatelessWidget {
  final List<NotificationDto> items;
  final ValueChanged<NotificationDto> onTap;
  const HomeFriendsActivity(
      {super.key, required this.items, required this.onTap});

  static bool _isTrip(NotificationDto n) =>
      n.referenceId != null &&
      (n.type == NotificationType.commentOnTrip ||
          n.type == NotificationType.tripStatusChanged ||
          n.type == NotificationType.tripUpdatePosted);

  /// Friend-made activity worth a Home row.
  static bool shows(NotificationDto n) =>
      n.actorId != null &&
      n.type != NotificationType.achievementUnlocked &&
      n.type != NotificationType.friendRequestDeclined;

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    final tints = [
      (c.trailSoftBg, c.trailSoftFg),
      (c.skyBg, c.skyFg),
      (c.forestBg, c.forestFg),
    ];
    return Container(
      decoration: WandererTheme.cardDecoration(context, radius: 18),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        for (final (i, n) in items.indexed)
          Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: () => onTap(n),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: i == items.length - 1
                    ? null
                    : BoxDecoration(
                        border: Border(bottom: BorderSide(color: c.lineSoft))),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                          color: tints[i % 3].$1, shape: BoxShape.circle),
                      child: Text(
                          n.message.isEmpty
                              ? '?'
                              : n.message.characters.first.toUpperCase(),
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: tints[i % 3].$2)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text.rich(notificationMessage(c, n, fontSize: 14),
                              maxLines: 3, overflow: TextOverflow.ellipsis),
                          if (_isTrip(n)) ...[
                            const SizedBox(height: 4),
                            Text('${l10n.viewTrip} →',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: c.accentText)),
                          ],
                          const SizedBox(height: 3),
                          Text(notificationAgo(l10n, n.createdAt),
                              style: TextStyle(fontSize: 12, color: c.caption)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ]),
    );
  }
}

/// "Next badge": trophy, goal, distance to go and a progress bar.
class HomeNextBadge extends StatelessWidget {
  final Achievement achievement;
  final double value;
  final VoidCallback onTap;
  const HomeNextBadge(
      {super.key,
      required this.achievement,
      required this.value,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    final goal = achievement.thresholdValue;
    final left = (goal - value).clamp(0, goal).toDouble();
    final leftLabel = achievementThresholdLabel(
        l10n,
        Achievement(
            id: achievement.id,
            type: achievement.type,
            name: achievement.name,
            description: achievement.description,
            thresholdValue: left.ceil()));
    return Material(
      color: c.surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: c.line)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(
              width: 52,
              height: 52,
              decoration:
                  BoxDecoration(color: c.goldBg, shape: BoxShape.circle),
              child:
                  Icon(Icons.emoji_events_outlined, size: 24, color: c.goldFg),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(achievementThresholdLabel(l10n, achievement),
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: c.text)),
                    ),
                    Text(l10n.homeToGo(leftLabel),
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: c.caption)),
                  ]),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: goal > 0 ? (value / goal).clamp(0.0, 1.0) : 0,
                      minHeight: 8,
                      backgroundColor: c.lineSoft,
                      valueColor:
                          const AlwaysStoppedAnimation(WandererTheme.trail),
                    ),
                  ),
                  if (achievement.description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(achievement.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: c.caption)),
                  ],
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Small stat tile: big number over a caption.
class HomeStat extends StatelessWidget {
  final String value;
  final String label;
  const HomeStat(this.value, this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: WandererTheme.cardDecoration(context, radius: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child:
                  Text(value, style: WandererTheme.display(22, color: c.text)),
            ),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: c.caption)),
          ],
        ),
      ),
    );
  }
}

/// One "Get started" step: done steps are checked and struck through.
class HomeChecklistStep {
  final String label;
  final bool done;
  final VoidCallback onTap;
  const HomeChecklistStep(this.label,
      {required this.done, required this.onTap});
}

/// Brand-new user checklist card with a progress bar (canvas: AndroidHomeNew).
class HomeGetStarted extends StatelessWidget {
  final List<HomeChecklistStep> steps;

  /// The ✕ in the header hides the checklist for good.
  final VoidCallback? onDismiss;
  const HomeGetStarted({super.key, required this.steps, this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    final done = steps.where((s) => s.done).length;
    return Container(
      decoration: WandererTheme.cardDecoration(context, radius: 18),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(l10n.homeGetStarted,
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: c.text)),
                  ),
                  Text(l10n.homeStepsOf(done, steps.length),
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: c.caption)),
                  if (onDismiss != null)
                    IconButton(
                      key: const Key('home_checklist_close'),
                      tooltip: l10n.homeChecklistHide,
                      onPressed: onDismiss,
                      visualDensity: VisualDensity.compact,
                      icon: Icon(Icons.close, size: 20, color: c.caption),
                    ),
                ]),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: steps.isEmpty ? 0 : done / steps.length,
                    minHeight: 8,
                    backgroundColor: c.lineSoft,
                    valueColor:
                        const AlwaysStoppedAnimation(WandererTheme.trail),
                  ),
                ),
              ],
            ),
          ),
          for (final s in steps)
            Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: s.done ? null : s.onTap,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 52),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: c.lineSoft))),
                  child: Row(children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: s.done ? c.forestFg : null,
                        border:
                            s.done ? null : Border.all(color: c.line, width: 2),
                      ),
                      child: s.done
                          ? Icon(Icons.check, size: 16, color: c.surface)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(s.label,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: s.done ? c.caption : c.text,
                              decoration:
                                  s.done ? TextDecoration.lineThrough : null,
                            )),
                      ),
                    ),
                    if (!s.done)
                      Icon(Icons.chevron_right, size: 18, color: c.label),
                  ]),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
