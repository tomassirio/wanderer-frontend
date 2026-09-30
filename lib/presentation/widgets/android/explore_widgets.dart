import 'package:flutter/material.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/presentation/widgets/common/cached_trip_thumbnail.dart';

/// Rounded trip map thumbnail with a map-ground placeholder.
class ExploreTripThumb extends StatelessWidget {
  final String thumbnailUrl;
  final double size;
  final double radius;
  const ExploreTripThumb(this.thumbnailUrl,
      {super.key, this.size = 64, this.radius = 12});

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    final ground = Container(
      width: size,
      height: size,
      color: c.mapGround,
      child: Icon(Icons.route, size: size * 0.4, color: c.label),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: CachedTripThumbnail(
        thumbnailUrl: thumbnailUrl,
        width: size,
        height: size,
        placeholder: ground,
        errorWidget: ground,
      ),
    );
  }
}

/// White 18dp card row: thumbnail, title and a subtitle line.
class ExploreTripRow extends StatelessWidget {
  final String thumbnailUrl;
  final Widget title;
  final Widget subtitle;
  final VoidCallback onTap;
  final double thumbSize;
  const ExploreTripRow({
    super.key,
    required this.thumbnailUrl,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.thumbSize = 64,
  });

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    return Material(
      color: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: c.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ExploreTripThumb(thumbnailUrl,
                  size: thumbSize, radius: thumbSize > 56 ? 12 : 10),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DefaultTextStyle.merge(
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: c.text),
                      child: title,
                    ),
                    const SizedBox(height: 4),
                    DefaultTextStyle.merge(
                      style: TextStyle(fontSize: 13, color: c.caption),
                      child: subtitle,
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

/// Filter chip from the canvas: 36dp, radius 10, ink when selected.
class ExploreChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const ExploreChip(
      {super.key,
      required this.label,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? c.text : c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: selected ? c.text : c.line),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            height: 36,
            // Keeps the tap target at 48dp without growing the chip visually.
            constraints: const BoxConstraints(minWidth: 48),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            child: Text(label,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: selected ? c.ground : c.textMuted)),
          ),
        ),
      ),
    );
  }
}

/// Section heading (17 bold) with an optional trailing link.
class ExploreSectionTitle extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  const ExploreSectionTitle(this.title,
      {super.key, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(title,
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: c.text)),
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
        ],
      ),
    );
  }
}
