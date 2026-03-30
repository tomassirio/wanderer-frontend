import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Lazily initialized cache managers to avoid platform channel errors
class CacheService {
  static CacheManager? _tripThumbnailCache;
  static CacheManager? _userAvatarCache;

  /// Cache for trip thumbnails (24 hours)
  static CacheManager get tripThumbnailCache {
    _tripThumbnailCache ??= CacheManager(
      Config(
        'tripThumbnails',
        stalePeriod: const Duration(hours: 24),
        maxNrOfCacheObjects: 200,
      ),
    );
    return _tripThumbnailCache!;
  }

  /// Cache for user avatars (8 seconds for real-time updates)
  static CacheManager get userAvatarCache {
    _userAvatarCache ??= CacheManager(
      Config(
        'userAvatars',
        stalePeriod: const Duration(seconds: 8),
        maxNrOfCacheObjects: 100,
      ),
    );
    return _userAvatarCache!;
  }

  /// Pre-warm the cache managers during app initialization
  static void initialize() {
    // Access the getters to trigger lazy initialization
    tripThumbnailCache;
    userAvatarCache;
  }
}
