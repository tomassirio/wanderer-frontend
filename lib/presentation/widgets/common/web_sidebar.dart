import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wanderer_frontend/core/constants/api_endpoints.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/l10n/locale_controller.dart';
import 'package:wanderer_frontend/core/providers/app_providers.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/presentation/helpers/avatar_helper.dart';
import 'package:wanderer_frontend/presentation/helpers/page_transitions.dart';
import 'package:wanderer_frontend/presentation/screens/achievements_screen.dart';
import 'package:wanderer_frontend/presentation/screens/admin_users_screen.dart';
import 'package:wanderer_frontend/presentation/screens/auth_screen.dart';
import 'package:wanderer_frontend/presentation/screens/friends_followers_screen.dart';
import 'package:wanderer_frontend/presentation/screens/home_screen.dart';
import 'package:wanderer_frontend/presentation/screens/initial_screen.dart';
import 'package:wanderer_frontend/presentation/screens/profile_screen.dart';
import 'package:wanderer_frontend/presentation/screens/settings_screen.dart';
import 'package:wanderer_frontend/presentation/screens/trip_maintenance_screen.dart';
import 'package:wanderer_frontend/presentation/screens/trip_plans_screen.dart';
import 'package:wanderer_frontend/presentation/screens/trip_promotion_screen.dart';
import 'package:wanderer_frontend/presentation/widgets/common/app_sidebar.dart';
import 'package:wanderer_frontend/presentation/widgets/common/wanderer_logo.dart';

/// Web navigation: grouped into Adventures, Social and Admin.
///
/// Rendered persistently beside the page on wide screens (full width, or an
/// icon rail when [collapsed]) and inside a [Drawer] on narrow ones.
class WebSidebar extends ConsumerStatefulWidget {
  final AppSidebar config;
  final bool persistent;
  final bool collapsed;

  const WebSidebar({
    super.key,
    required this.config,
    required this.persistent,
    this.collapsed = false,
  });

  static const double expandedWidth = 264;
  static const double railWidth = 72;

  @override
  ConsumerState<WebSidebar> createState() => _WebSidebarState();
}

class _WebSidebarState extends ConsumerState<WebSidebar> {
  int _pendingRequests = 0;

  AppSidebar get _c => widget.config;
  bool get _isLoggedIn => _c.username != null;

  @override
  void initState() {
    super.initState();
    if (_isLoggedIn) _loadPendingRequests();
  }

  Future<void> _loadPendingRequests() async {
    try {
      final requests =
          await ref.read(userServiceProvider).getReceivedFriendRequests();
      if (mounted) setState(() => _pendingRequests = requests.length);
    } catch (_) {
      // Badge is decorative; the Friends screen shows the real list.
    }
  }

  void _go(int index) {
    if (!widget.persistent) Navigator.pop(context);
    if (index == _c.selectedIndex) return;

    final Widget? screen = switch (index) {
      AppSidebar.dashboardIndex => const InitialScreen(),
      AppSidebar.exploreIndex => const HomeScreen(),
      AppSidebar.myTripsIndex => const ProfileScreen(),
      1 => const TripPlansScreen(),
      2 => const FriendsFollowersScreen(),
      3 => const AchievementsScreen(),
      5 => const TripPromotionScreen(),
      6 => const AdminUsersScreen(),
      7 => const TripMaintenanceScreen(),
      _ => null,
    };
    if (screen == null) return;
    // Sidebar destinations are top-level, like tabs: replace the stack.
    Navigator.of(context).pushAndRemoveUntil(
      PageTransitions.fade(screen),
      (_) => false,
    );
  }

  void _openSettings() {
    if (!widget.persistent) Navigator.pop(context);
    Navigator.push(
      context,
      PageTransitions.slideFromBottom(const SettingsScreen()),
    );
  }

  Future<void> _openSupport() async {
    await launchUrl(
      Uri.parse('https://buymeacoffee.com/tomassirio'),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? const Color(0xFF1C1A18) : WandererTheme.sandSidebar;
    final border = Theme.of(context).colorScheme.outline;
    final rail = widget.collapsed;

    final groups = <_NavGroup>[
      _NavGroup(l10n.navAdventures, [
        _NavItem(AppSidebar.dashboardIndex, Icons.home_outlined, l10n.navHome,
            requiresLogin: true),
        _NavItem(AppSidebar.myTripsIndex, Icons.map_outlined, l10n.navMyTrips,
            requiresLogin: true),
        _NavItem(1, Icons.calendar_month_outlined, l10n.tripPlans,
            requiresLogin: true),
        _NavItem(
            AppSidebar.exploreIndex, Icons.explore_outlined, l10n.navExplore),
      ]),
      _NavGroup(l10n.navSocial, [
        _NavItem(2, Icons.people_outline, l10n.friends,
            requiresLogin: true, badge: _pendingRequests),
        _NavItem(3, Icons.emoji_events_outlined, l10n.achievements,
            requiresLogin: true),
      ]),
      if (_c.isAdmin)
        _NavGroup(l10n.navAdmin, [
          _NavItem(5, Icons.campaign_outlined, l10n.tripPromotion),
          _NavItem(6, Icons.shield_outlined, l10n.userManagement),
          _NavItem(7, Icons.build_outlined, l10n.tripDataMaintenance),
        ]),
    ];

    final content = Container(
      width: rail ? WebSidebar.railWidth : WebSidebar.expandedWidth,
      decoration: BoxDecoration(
        color: bg,
        border:
            widget.persistent ? Border(right: BorderSide(color: border)) : null,
      ),
      child: SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment:
              rail ? CrossAxisAlignment.center : CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(
                    horizontal: rail ? 14 : 16, vertical: 20),
                children: [
                  _buildBrand(rail),
                  if (_isLoggedIn && !rail) _buildUserCard(context),
                  for (final group in groups)
                    ..._buildGroup(context, group, rail),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                  rail ? 14 : 16, 0, rail ? 14 : 16, rail ? 20 : 16),
              child: Column(
                crossAxisAlignment: rail
                    ? CrossAxisAlignment.center
                    : CrossAxisAlignment.stretch,
                children: _buildFooter(context, l10n, rail),
              ),
            ),
          ],
        ),
      ),
    );

    if (widget.persistent) return content;
    return Drawer(
      width: WebSidebar.expandedWidth,
      shape: const RoundedRectangleBorder(),
      backgroundColor: bg,
      child: content,
    );
  }

  Widget _buildBrand(bool rail) {
    final logo = Semantics(
      label: 'Wanderer',
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => _go(
            _isLoggedIn ? AppSidebar.dashboardIndex : AppSidebar.exploreIndex),
        child: const WandererLogo(size: 36),
      ),
    );
    if (rail) {
      return Padding(padding: const EdgeInsets.only(bottom: 16), child: logo);
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
      child: Row(
        children: [
          logo,
          const SizedBox(width: 10),
          Text('Wanderer', style: WandererTheme.display(21)),
        ],
      ),
    );
  }

  Widget _avatar(double size) {
    final url = _c.avatarUrl;
    final hasUrl = url != null && url.isNotEmpty;
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: WandererTheme.forestSoft,
      foregroundImage:
          hasUrl ? NetworkImage(ApiEndpoints.resolveThumbnailUrl(url)) : null,
      onForegroundImageError: hasUrl ? (_, __) {} : null,
      child: Text(
        AvatarHelper.getInitials(_c.displayName, _c.username ?? '?'),
        style: TextStyle(
          color: WandererTheme.forest,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.35,
        ),
      ),
    );
  }

  Widget _buildUserCard(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(WandererTheme.radiusCard),
          side: BorderSide(color: Theme.of(context).colorScheme.outline),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(WandererTheme.radiusCard),
          onTap: () => _go(AppSidebar.myTripsIndex),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
            child: Row(
              children: [
                _avatar(40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _c.displayName ?? _c.username!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '@${_c.username}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.settings_outlined, size: 18),
                  tooltip: l10n.settings,
                  onPressed: _openSettings,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildGroup(BuildContext context, _NavGroup group, bool rail) {
    final items =
        group.items.where((i) => _isLoggedIn || !i.requiresLogin).toList();
    if (items.isEmpty) return const [];
    return [
      if (rail)
        Center(
          child: Container(
            width: 28,
            height: 1,
            margin: const EdgeInsets.symmetric(vertical: 8),
            color: Theme.of(context).colorScheme.outline,
          ),
        )
      else
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 6),
          child: Text(
            group.label.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.9,
              color: WandererTheme.stoneLabel,
            ),
          ),
        ),
      for (final item in items) _buildItem(context, item, rail),
    ];
  }

  Widget _buildItem(BuildContext context, _NavItem item, bool rail) {
    final selected = item.index == _c.selectedIndex;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = selected
        ? (dark ? const Color(0xFFF0A36F) : WandererTheme.trailDeep)
        : Theme.of(context).colorScheme.onSurfaceVariant;
    final bg = selected
        ? (dark ? const Color(0xFF3A2618) : WandererTheme.trailSoft)
        : Colors.transparent;

    final badge = item.badge > 0
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: WandererTheme.trail,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '${item.badge}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          )
        : null;

    final tile = Material(
      color: bg,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _go(item.index),
        child: SizedBox(
          height: 44,
          width: rail ? 44 : null,
          child: rail
              ? Badge(
                  isLabelVisible: item.badge > 0,
                  backgroundColor: WandererTheme.trail,
                  smallSize: 8,
                  child: Center(child: Icon(item.icon, size: 20, color: fg)),
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Icon(item.icon, size: 18, color: fg),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          item.label,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            color: selected
                                ? fg
                                : Theme.of(context).colorScheme.onSurface,
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ),
                      if (badge != null) badge,
                    ],
                  ),
                ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Semantics(
        selected: selected,
        button: true,
        label: rail ? item.label : null,
        child: rail ? Tooltip(message: item.label, child: tile) : tile,
      ),
    );
  }

  List<Widget> _buildFooter(
      BuildContext context, AppLocalizations l10n, bool rail) {
    if (rail) {
      return [
        if (_isLoggedIn)
          Tooltip(
            message: l10n.myProfile,
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => _go(AppSidebar.myTripsIndex),
              child: _avatar(40),
            ),
          )
        else
          IconButton(
            icon: const Icon(Icons.login),
            tooltip: l10n.logIn,
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const AuthScreen())),
          ),
      ];
    }

    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return [
      Material(
        color: const Color(0xFFFFF7E6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(WandererTheme.radiusControl),
          side: const BorderSide(color: Color(0xFFF3DFB5)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(WandererTheme.radiusControl),
          onTap: _openSupport,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.coffee_outlined,
                    size: 18, color: WandererTheme.gold),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.navSupport,
                    style: const TextStyle(
                      color: WandererTheme.gold,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 4),
      Row(
        children: [
          Expanded(
            child: TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: muted,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                textStyle:
                    const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
              ),
              icon: Icon(_isLoggedIn ? Icons.logout : Icons.login, size: 18),
              label: Text(_isLoggedIn ? l10n.logout : l10n.logIn),
              onPressed: () {
                if (!widget.persistent) Navigator.pop(context);
                if (_isLoggedIn) {
                  _c.onLogout?.call();
                } else {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const AuthScreen()));
                }
              },
            ),
          ),
          _LanguageButton(),
        ],
      ),
    ];
  }
}

class _LanguageButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final controller = LocaleController();
    return PopupMenuButton<String>(
      tooltip: 'Change language',
      onSelected: (code) => controller.setLocale(Locale(code)),
      itemBuilder: (_) => LocaleController.supportedLocales.map((locale) {
        final code = locale.languageCode;
        return PopupMenuItem<String>(
          value: code,
          child: Text(
            LocaleController.localeLabels[code] ?? code,
            style: TextStyle(
              fontWeight: code == controller.languageCode
                  ? FontWeight.w700
                  : FontWeight.w500,
            ),
          ),
        );
      }).toList(),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Theme.of(context).colorScheme.outline),
        ),
        child: Text(
          LocaleController.localeLabels[controller.languageCode] ?? 'EN',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _NavGroup {
  final String label;
  final List<_NavItem> items;
  const _NavGroup(this.label, this.items);
}

class _NavItem {
  final int index;
  final IconData icon;
  final String label;
  final bool requiresLogin;
  final int badge;
  const _NavItem(this.index, this.icon, this.label,
      {this.requiresLogin = false, this.badge = 0});
}
