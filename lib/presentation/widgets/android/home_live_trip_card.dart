import 'package:flutter/material.dart' hide Visibility;
import 'package:intl/intl.dart';
import 'package:wanderer_frontend/core/constants/enums.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/presentation/widgets/common/cached_trip_thumbnail.dart';

/// "Live · 1 h 12 min", or "Live · Day 3" for multi-day trips.
String homeLiveLabel(AppLocalizations l10n, Trip trip, DateTime now) {
  final start = trip.startDate;
  if (trip.tripModality == TripModality.multiDay && trip.currentDay != null) {
    return l10n.homeLiveFor(l10n.dayNumber(trip.currentDay!));
  }
  if (start == null) return l10n.live;
  final d = now.difference(start);
  if (d.inHours >= 24) return l10n.homeLiveFor(l10n.dayNumber(d.inDays + 1));
  final m = l10n.newTripMinutes(d.inMinutes.remainder(60).clamp(0, 59));
  return l10n
      .homeLiveFor(d.inHours == 0 ? m : '${l10n.newTripHours(d.inHours)} $m');
}

/// "20 min" / "1 h" for an update interval in seconds.
String homeIntervalLabel(AppLocalizations l10n, int seconds) {
  final min = (seconds / 60).round();
  return min < 60 ? l10n.newTripMinutes(min) : l10n.newTripHours(min ~/ 60);
}

/// Home card for the user's trip in progress: map, Live and visibility
/// pills, last update, "Check in now" (the screen's one orange button) and
/// "Open map".
class HomeLiveTripCard extends StatelessWidget {
  final Trip trip;
  final bool checkingIn;
  final VoidCallback onCheckIn;
  final VoidCallback onOpen;

  const HomeLiveTripCard({
    super.key,
    required this.trip,
    required this.checkingIn,
    required this.onCheckIn,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final (visIcon, visLabel) = switch (trip.visibility) {
      Visibility.public => (Icons.public, l10n.publicVisibility),
      Visibility.protected => (Icons.group_outlined, l10n.friends),
      Visibility.private => (Icons.lock_outline, l10n.privateVisibility),
    };

    final last = (trip.locations?.isNotEmpty ?? false)
        ? ([...trip.locations!]
              ..sort((a, b) => a.timestamp.compareTo(b.timestamp)))
            .last
        : null;
    final at = (last?.timestamp ?? trip.updatedAt).toLocal();
    final now = DateTime.now();
    final sameDay =
        at.year == now.year && at.month == now.month && at.day == now.day;
    final time = sameDay
        ? DateFormat.Hm(locale).format(at)
        : DateFormat.MMMd(locale).add_Hm().format(at);
    final place = last?.city;
    final lastLine = [
      place != null && place.isNotEmpty
          ? l10n.homeLastUpdatePlace(place, time)
          : l10n.homeLastUpdateTime(time),
      if (trip.automaticUpdates)
        l10n.homeAutoEvery(
            homeIntervalLabel(l10n, trip.effectiveUpdateRefresh)),
    ].join(' · ');

    Widget pill(Widget child) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: c.overlayPillBg,
            borderRadius: BorderRadius.circular(999),
          ),
          child: child,
        );
    const pillText = TextStyle(fontSize: 12, fontWeight: FontWeight.w700);

    return Material(
      color: c.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: c.line),
      ),
      child: InkWell(
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 150,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedTripThumbnail(
                    thumbnailUrl: trip.thumbnailUrl,
                    placeholder: ColoredBox(color: c.mapGround),
                    errorWidget: ColoredBox(color: c.mapGround),
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: pill(Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                            color: c.skyFg, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Text(homeLiveLabel(l10n, trip, now),
                          style: pillText.copyWith(color: c.skyFg)),
                    ])),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: pill(Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(visIcon, size: 12, color: c.textMuted),
                      const SizedBox(width: 5),
                      Text(visLabel,
                          style: pillText.copyWith(color: c.textMuted)),
                    ])),
                  ),
                ],
              ),
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
                  const SizedBox(height: 2),
                  Text(lastLine,
                      style: TextStyle(fontSize: 13, color: c.caption)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: checkingIn ? null : onCheckIn,
                          style: FilledButton.styleFrom(
                            backgroundColor: WandererTheme.trail,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            textStyle: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                          icon: checkingIn
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.place_outlined, size: 18),
                          label: Text(l10n.homeCheckInNow),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: onOpen,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: c.text,
                          minimumSize: const Size(0, 48),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          side: BorderSide(color: c.line),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          textStyle: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                        child: Text(l10n.homeOpenMap),
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
