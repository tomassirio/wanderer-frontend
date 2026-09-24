import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/presentation/widgets/common/notification_bell.dart';
import 'package:wanderer_frontend/core/theme/theme_controller.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/presentation/widgets/common/wanderer_logo.dart';
import 'package:wanderer_frontend/presentation/helpers/avatar_helper.dart';
import 'package:wanderer_frontend/core/constants/api_endpoints.dart';
import 'package:wanderer_frontend/presentation/screens/search_screen.dart';
import 'package:wanderer_frontend/presentation/widgets/search/search_overlay.dart';
import 'package:wanderer_frontend/presentation/widgets/common/wanderer_scaffold.dart';

/// Reusable AppBar for the Wanderer application
class WandererAppBar extends ConsumerStatefulWidget
    implements PreferredSizeWidget {
  final bool isLoggedIn;
  final VoidCallback? onLoginPressed;
  final String? username;
  final String? userId;
  final String? displayName;
  final String? avatarUrl;
  final VoidCallback? onProfile;
  final VoidCallback? onSettings;
  final VoidCallback? onLogout;
  final Widget? leading;
  final GlobalKey? menuButtonKey;
  final GlobalKey? searchButtonKey;
  final GlobalKey? notificationButtonKey;

  const WandererAppBar({
    super.key,
    required this.isLoggedIn,
    this.onLoginPressed,
    this.username,
    this.userId,
    this.displayName,
    this.avatarUrl,
    this.onProfile,
    this.onSettings,
    this.onLogout,
    this.leading,
    this.menuButtonKey,
    this.searchButtonKey,
    this.notificationButtonKey,
  });

  @override
  ConsumerState<WandererAppBar> createState() => _WandererAppBarState();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _WandererAppBarState extends ConsumerState<WandererAppBar> {
  String get _avatarInitial {
    return AvatarHelper.getInitials(widget.displayName, widget.username ?? '?');
  }

  void _navigateToSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SearchScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 600;
    final l10n = context.l10n;
    // Web with the sidebar beside the page: it already carries the logo and
    // navigation, so the bar only keeps its actions.
    final sidebarShown = WandererScaffold.hasPersistentSidebar(context);
    return AppBar(
      backgroundColor: kIsWeb
          ? Theme.of(context).scaffoldBackgroundColor
          : Theme.of(context).colorScheme.inversePrimary,
      scrolledUnderElevation: kIsWeb ? 0 : null,
      centerTitle: isDesktop && !kIsWeb,
      titleSpacing: isDesktop ? null : 0,
      leading: widget.leading ??
          (widget.menuButtonKey != null && !sidebarShown
              ? IconButton(
                  key: widget.menuButtonKey,
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                )
              : null),
      title: sidebarShown
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  borderRadius: BorderRadius.circular(15),
                  child: const Padding(
                    padding: EdgeInsets.all(2.0),
                    child: WandererLogo(size: 30),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Wanderer',
                  style: kIsWeb
                      ? WandererTheme.display(18)
                      : const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
      actions: [
        // Dark mode toggle — logged-in users, and everyone on web
        if (widget.isLoggedIn || kIsWeb)
          ValueListenableBuilder<ThemeMode>(
            valueListenable: ThemeController().themeMode,
            builder: (context, mode, _) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              return IconButton(
                icon: Icon(
                  isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                ),
                tooltip:
                    isDark ? l10n.switchToLightMode : l10n.switchToDarkMode,
                onPressed: () => ThemeController().setDarkMode(!isDark),
              );
            },
          ),
        // Search icon — only for logged in users
        if (widget.isLoggedIn)
          IconButton(
            key: widget.searchButtonKey,
            icon: const Icon(Icons.search),
            tooltip: l10n.search,
            onPressed:
                kIsWeb ? () => showSearchOverlay(context) : _navigateToSearch,
          ),
        // Notifications icon with badge (only for logged in users)
        if (widget.isLoggedIn)
          NotificationBell(
            isLoggedIn: widget.isLoggedIn,
            userId: widget.userId,
            notificationButtonKey: widget.notificationButtonKey,
          ),
        if (!widget.isLoggedIn && widget.onLoginPressed != null)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: widget.onLoginPressed,
              icon: Icon(Icons.login,
                  size: 18, color: kIsWeb ? null : Colors.white),
              label: Text(l10n.login,
                  style: TextStyle(
                      fontSize: 13, color: kIsWeb ? null : Colors.white)),
            ),
          ),
        if (widget.isLoggedIn && widget.username != null)
          Padding(
            padding: EdgeInsets.only(right: isDesktop ? 16 : 4),
            child: PopupMenuButton<String>(
              icon: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundImage:
                    widget.avatarUrl != null && widget.avatarUrl!.isNotEmpty
                        ? NetworkImage(
                            ApiEndpoints.resolveThumbnailUrl(widget.avatarUrl))
                        : null,
                onForegroundImageError:
                    widget.avatarUrl != null && widget.avatarUrl!.isNotEmpty
                        ? (_, __) {}
                        : null,
                child: Text(
                  _avatarInitial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              tooltip: l10n.profile,
              onSelected: (value) {
                switch (value) {
                  case 'profile':
                    widget.onProfile?.call();
                    break;
                  case 'settings':
                    widget.onSettings?.call();
                    break;
                  case 'logout':
                    widget.onLogout?.call();
                    break;
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem<String>(
                  enabled: false,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor:
                                  Theme.of(context).colorScheme.primary,
                              foregroundImage: widget.avatarUrl != null &&
                                      widget.avatarUrl!.isNotEmpty
                                  ? NetworkImage(
                                      ApiEndpoints.resolveThumbnailUrl(
                                          widget.avatarUrl))
                                  : null,
                              onForegroundImageError:
                                  widget.avatarUrl != null &&
                                          widget.avatarUrl!.isNotEmpty
                                      ? (_, __) {}
                                      : null,
                              child: Text(
                                _avatarInitial,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.displayName ?? widget.username!,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    '@${widget.username!}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Divider(),
                      ],
                    ),
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'profile',
                  child: Row(
                    children: [
                      const Icon(Icons.person),
                      const SizedBox(width: 12),
                      Text(l10n.userProfile),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'settings',
                  child: Row(
                    children: [
                      const Icon(Icons.settings),
                      const SizedBox(width: 12),
                      Text(l10n.settings),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'logout',
                  child: Row(
                    children: [
                      const Icon(Icons.logout, color: Colors.red),
                      const SizedBox(width: 12),
                      Text(l10n.logout,
                          style: const TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
