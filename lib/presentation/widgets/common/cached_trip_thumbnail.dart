import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/services/cache_service.dart';

/// Optimized trip thumbnail widget with caching
class CachedTripThumbnail extends StatelessWidget {
  final String thumbnailUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? placeholder;
  final Widget? errorWidget;

  const CachedTripThumbnail({
    super.key,
    required this.thumbnailUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedUrl = ApiEndpoints.resolveThumbnailUrl(thumbnailUrl);

    if (resolvedUrl.isEmpty) {
      return errorWidget ?? _buildDefaultPlaceholder(context);
    }

    return CachedNetworkImage(
      imageUrl: resolvedUrl,
      fit: fit,
      width: width,
      height: height,
      cacheManager: CacheService.tripThumbnailCache,
      placeholder: (context, url) =>
          placeholder ?? _buildDefaultPlaceholder(context),
      errorWidget: (context, url, error) =>
          errorWidget ?? _buildDefaultPlaceholder(context),
    );
  }

  Widget _buildDefaultPlaceholder(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.surface,
            Theme.of(context).colorScheme.surfaceContainerHighest,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.map,
          size: 48,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
        ),
      ),
    );
  }
}
