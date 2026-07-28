import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/core/services/cache_service.dart';
import 'package:wanderer_frontend/core/constants/api_endpoints.dart';

/// A circular avatar image with proper aspect ratio handling, used by
/// [ProfileScreen] for both the header avatar and the app-bar-sized avatar.
///
/// Shows (in priority order): an optimistic locally-uploaded avatar, then a
/// cached network avatar, then an initials fallback.
class ProfileAvatarImage extends StatelessWidget {
  final Uint8List? optimisticAvatarBytes;
  final String? avatarUrl;
  final String initials;
  final double radius;

  const ProfileAvatarImage({
    super.key,
    required this.optimisticAvatarBytes,
    required this.avatarUrl,
    required this.initials,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    // Show optimistic avatar if available (user just uploaded)
    if (optimisticAvatarBytes != null) {
      return ClipOval(
        child: Container(
          width: radius * 2,
          height: radius * 2,
          decoration: BoxDecoration(
            color: Colors.grey[300],
          ),
          child: Image.memory(
            optimisticAvatarBytes!,
            fit: BoxFit.cover,
            key: const ValueKey('optimistic-avatar'),
          ),
        ),
      );
    }

    final url = avatarUrl ?? '';

    // Build the initials fallback widget (used when no avatar or image fails)
    Widget buildInitialsFallback() {
      return Container(
        width: radius * 2,
        height: radius * 2,
        decoration: const BoxDecoration(
          color: WandererTheme.primaryOrange,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          initials,
          style: TextStyle(
            fontSize: radius * 0.8,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    // No valid avatar URL - show initials
    if (url.isEmpty) {
      return buildInitialsFallback();
    }

    // Has avatar - use ClipOval with CachedNetworkImage for proper aspect ratio
    return ClipOval(
      child: Container(
        width: radius * 2,
        height: radius * 2,
        decoration: const BoxDecoration(
          color: WandererTheme.primaryOrange,
        ),
        child: CachedNetworkImage(
          imageUrl: ApiEndpoints.resolveThumbnailUrl(url),
          key: ValueKey(url),
          fit: BoxFit.cover,
          cacheManager: CacheService.userAvatarCache,
          placeholder: (context, url) => Container(
            alignment: Alignment.center,
            color: WandererTheme.primaryOrange,
            child: Text(
              initials,
              style: TextStyle(
                fontSize: radius * 0.8,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          errorWidget: (context, url, error) => Container(
            alignment: Alignment.center,
            color: WandererTheme.primaryOrange,
            child: Text(
              initials,
              style: TextStyle(
                fontSize: radius * 0.8,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
