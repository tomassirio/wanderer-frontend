import 'package:flutter/material.dart' hide Visibility;
import 'package:wanderer_frontend/core/constants/enums.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/presentation/widgets/common/cached_trip_thumbnail.dart';
import 'package:wanderer_frontend/presentation/widgets/common/pill.dart';

/// One cell of the profile stat box. Tappable when [onTap] is set.
class ProfileStat {
  final String label;
  final int value;
  final VoidCallback? onTap;

  const ProfileStat(this.label, this.value, [this.onTap]);
}

/// Bordered 4-cell stat box (Trips · Followers · Following · Friends).
class ProfileStatBox extends StatelessWidget {
  final List<ProfileStat> stats;

  const ProfileStatBox({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    final radius = BorderRadius.circular(WandererTheme.radiusCard);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: c.lineSoft),
        borderRadius: radius,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: IntrinsicHeight(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < stats.length; i++) ...[
                if (i > 0) VerticalDivider(width: 1, color: c.lineSoft),
                InkWell(
                  onTap: stats[i].onTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 22, vertical: 14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${stats[i].value}',
                            style: WandererTheme.display(24, color: c.text)),
                        Text(stats[i].label,
                            style: TextStyle(fontSize: 12, color: c.textMuted)),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Segmented control: neutral track with the selected segment on surface.
class ProfileSegmentedFilter extends StatelessWidget {
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;

  const ProfileSegmentedFilter({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.neutralBg,
        borderRadius: BorderRadius.circular(WandererTheme.radiusControl),
      ),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (var i = 0; i < labels.length; i++)
            Material(
              color: i == selected ? c.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
              child: InkWell(
                borderRadius: BorderRadius.circular(9),
                onTap: () => onSelected(i),
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.center,
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          i == selected ? FontWeight.w700 : FontWeight.w600,
                      color: i == selected ? c.text : c.textMuted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Horizontal trip card: thumbnail left, name/status/meta/link right.
class WebProfileTripCard extends StatelessWidget {
  final Trip trip;
  final VoidCallback onTap;

  const WebProfileTripCard(
      {super.key, required this.trip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    final cta = switch (trip.status) {
      TripStatus.created => l10n.profileContinueEditing,
      TripStatus.finished => l10n.viewTrip,
      _ => l10n.profileOpenLiveMap,
    };
    final (visibilityLabel, visibilityIcon) = switch (trip.visibility) {
      Visibility.public => (l10n.publicVisibility, Icons.public),
      Visibility.protected => (l10n.protectedVisibility, Icons.group_outlined),
      Visibility.private => (l10n.privateVisibility, Icons.lock_outline),
    };
    final empty = Container(
      color: c.mapGround,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.map_outlined, size: 28, color: c.caption),
          const SizedBox(height: 6),
          Text(l10n.profileNoRouteYet,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: c.caption)),
        ],
      ),
    );
    final meta = TextStyle(fontSize: 13, color: c.textMuted);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(WandererTheme.radiusPanel),
        child: Ink(
          decoration: WandererTheme.cardDecoration(context),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(WandererTheme.radiusPanel),
            child: SizedBox(
              height: 140,
              child: Row(
                children: [
                  SizedBox(
                    width: 180,
                    height: 140,
                    child: CachedTripThumbnail(
                      thumbnailUrl: trip.thumbnailUrl,
                      placeholder: Container(color: c.mapGround),
                      errorWidget: empty,
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  trip.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style:
                                      WandererTheme.display(19, color: c.text),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Pill.status(context, trip.status),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 14,
                            runSpacing: 4,
                            children: [
                              Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.chat_bubble_outline,
                                    size: 14, color: c.textMuted),
                                const SizedBox(width: 5),
                                Text(l10n.commentsCount(trip.commentsCount),
                                    style: meta),
                              ]),
                              Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(visibilityIcon,
                                    size: 14, color: c.textMuted),
                                const SizedBox(width: 5),
                                Text(visibilityLabel, style: meta),
                              ]),
                            ],
                          ),
                          const Spacer(),
                          Text(
                            '$cta →',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: c.accentText,
                            ),
                          ),
                        ],
                      ),
                    ),
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
