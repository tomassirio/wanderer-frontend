import 'package:flutter/material.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/presentation/widgets/common/cached_trip_thumbnail.dart';
import 'package:wanderer_frontend/presentation/widgets/common/pill.dart';

class MobileWebTripCard extends StatelessWidget {
  final Trip trip;
  final VoidCallback onTap;
  const MobileWebTripCard({super.key, required this.trip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    return Material(
      color: c.surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: c.line)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(
              height: 150,
              child: Stack(fit: StackFit.expand, children: [
                CachedTripThumbnail(
                  thumbnailUrl: trip.thumbnailUrl,
                  placeholder: ColoredBox(color: c.mapGround),
                  errorWidget: ColoredBox(
                      color: c.mapGround,
                      child: Icon(Icons.route, color: c.caption)),
                ),
                Positioned(
                    top: 12,
                    left: 12,
                    child: Pill.status(context, trip.status, onImage: true)),
              ])),
          Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(trip.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: WandererTheme.display(18, color: c.text)),
                  const SizedBox(height: 4),
                  Text(
                      '@${trip.username} · ${context.l10n.kmValue((trip.accruedDistanceKm ?? 0).toStringAsFixed(1))}'
                      ' · ${context.l10n.commentsTab(trip.commentsCount)}',
                      style: TextStyle(fontSize: 12, color: c.caption)),
                ],
              )),
        ]),
      ),
    );
  }
}
