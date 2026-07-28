import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/services/cache_service.dart';
import 'package:wanderer_frontend/core/constants/api_endpoints.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/presentation/helpers/ui_helpers.dart';

/// Trip card for profile screen with mini map
class ProfileTripCard extends StatefulWidget {
  final Trip trip;
  final VoidCallback onTap;

  const ProfileTripCard({super.key, required this.trip, required this.onTap});

  @override
  State<ProfileTripCard> createState() => _ProfileTripCardState();
}

class _ProfileTripCardState extends State<ProfileTripCard> {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mini map preview (120x120)
            SizedBox(width: 120, height: 120, child: _buildMiniMap()),
            // Trip info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Trip title
                    Text(
                      widget.trip.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: UiHelpers.getStatusColor(widget.trip.status),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        UiHelpers.getStatusLabel(widget.trip.status, l10n),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Metadata
                    Row(
                      children: [
                        Icon(Icons.comment, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          '${widget.trip.commentsCount}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          UiHelpers.getVisibilityIcon(widget.trip.visibility),
                          size: 14,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          UiHelpers.getVisibilityLabel(
                              widget.trip.visibility, l10n),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniMap() {
    final thumbnailUrl =
        ApiEndpoints.resolveThumbnailUrl(widget.trip.thumbnailUrl);

    if (thumbnailUrl.isEmpty) {
      return Container(
        color: Colors.grey[300],
        child: Center(
          child: Icon(Icons.map_outlined, size: 32, color: Colors.grey[500]),
        ),
      );
    }

    return CachedNetworkImage(
      imageUrl: thumbnailUrl,
      fit: BoxFit.cover,
      cacheManager: CacheService.tripThumbnailCache,
      placeholder: (context, url) => Container(
        color: Colors.grey[300],
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      errorWidget: (context, url, error) => Container(
        color: Colors.grey[300],
        child: Center(
          child: Icon(Icons.map, size: 32, color: Colors.grey[500]),
        ),
      ),
    );
  }
}
