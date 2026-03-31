import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/theme/wanderer_theme.dart';
import '../../../core/services/cache_service.dart';

/// Optimized avatar widget with caching and proper fallback
class CachedUserAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String initials;
  final double radius;
  final Color? backgroundColor;

  const CachedUserAvatar({
    super.key,
    required this.avatarUrl,
    required this.initials,
    this.radius = 20,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    if (avatarUrl == null || avatarUrl!.isEmpty) {
      return _buildInitialsFallback();
    }

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: ApiEndpoints.resolveThumbnailUrl(avatarUrl!),
        key: ValueKey(avatarUrl),
        fit: BoxFit.cover,
        width: radius * 2,
        height: radius * 2,
        cacheManager: CacheService.userAvatarCache,
        placeholder: (context, url) => _buildInitialsFallback(),
        errorWidget: (context, url, error) => _buildInitialsFallback(),
      ),
    );
  }

  Widget _buildInitialsFallback() {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        color: backgroundColor ?? WandererTheme.primaryOrange,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            fontSize: radius * 0.8,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
