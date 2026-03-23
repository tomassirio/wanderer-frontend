import 'package:flutter/material.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/l10n/locale_controller.dart';
import 'package:wanderer_frontend/presentation/helpers/page_transitions.dart';
import 'package:wanderer_frontend/presentation/helpers/ui_helpers.dart';
import 'package:wanderer_frontend/presentation/helpers/auth_navigation_helper.dart';
import 'package:wanderer_frontend/presentation/screens/admin_users_screen.dart';
import 'package:wanderer_frontend/presentation/screens/auth_screen.dart';
import 'package:wanderer_frontend/presentation/screens/home_screen.dart';
import 'package:wanderer_frontend/presentation/screens/trip_maintenance_screen.dart';
import 'package:wanderer_frontend/presentation/screens/trip_promotion_screen.dart';
import 'package:wanderer_frontend/presentation/screens/settings_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wanderer_frontend/core/constants/api_endpoints.dart';

/// Sidebar navigation for the app
class AppSidebar extends StatelessWidget {
  final String? username;
  final String? userId;
  final String? displayName;
  final String? avatarUrl;
  final int selectedIndex;
  final VoidCallback? onLogout;
  final VoidCallback? onSettings;
  final bool isAdmin;

  const AppSidebar({
    super.key,
    this.username,
    this.userId,
    this.displayName,
    this.avatarUrl,
    required this.selectedIndex,
    this.onLogout,
    this.onSettings,
    this.isAdmin = false,
  });

  void _handleNavigation(BuildContext context, int index) {
    // Close drawer first
    Navigator.pop(context);

    // If already on the selected screen, do nothing
    if (selectedIndex == index) {
      return;
    }

    switch (index) {
      case 0:
        // Navigate to Trips (Home) - center position
        if (selectedIndex == -1) {
          // From trip detail - pop all routes until we're back at home
          Navigator.popUntil(context, (route) => route.isFirst);
        } else if (selectedIndex == 1) {
          // Coming from Trip Plans (left) - slide right
          Navigator.pushReplacement(
            context,
            PageTransitions.slideRight(const HomeScreen()),
          );
        } else if (selectedIndex == 3) {
          // Coming from Profile (right) - slide left
          Navigator.pushReplacement(
            context,
            PageTransitions.slideLeft(const HomeScreen()),
          );
        } else if (selectedIndex != 0) {
          // From other screens - use default
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        }
        break;
      case 1:
        // Navigate to Trip Plans (left of home) - requires auth
        AuthNavigationHelper.navigateToTripPlans(context);
        break;
      case 2:
        // Navigate to Friends & Followers - requires auth
        AuthNavigationHelper.navigateToFriendsFollowers(context);
        break;
      case 3:
        // Navigate to Achievements - requires auth
        AuthNavigationHelper.navigateToAchievements(context);
        break;
      case 4:
        // Navigate to Profile (right of home) - requires auth
        AuthNavigationHelper.navigateToOwnProfile(context);
        break;
      case 5:
        // Navigate to Trip Promotion Management (admin only)
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const TripPromotionScreen(),
          ),
        );
        break;
      case 6:
        // Navigate to User Management (admin only)
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const AdminUsersScreen(),
          ),
        );
        break;
      case 7:
        // Navigate to Trip Data Maintenance (admin only)
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const TripMaintenanceScreen(),
          ),
        );
        break;
    }
  }

  Future<void> _launchBuyMeACoffee(BuildContext context) async {
    final url = Uri.parse('https://buymeacoffee.com/tomassirio');
    try {
      final launched =
          await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!launched && context.mounted) {
        UiHelpers.showErrorMessage(
          context,
          'Could not open Buy Me a Coffee link',
        );
      }
    } catch (e) {
      if (context.mounted) {
        UiHelpers.showErrorMessage(
          context,
          'Error opening link: $e',
        );
      }
    }
  }

  /// Language toggle widget placed at the bottom-left of the header.
  Widget _buildLanguageToggle(bool isSpanish) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _langLabel('EN', !isSpanish),
        Transform.scale(
          scale: 0.75,
          child: Switch(
            value: isSpanish,
            onChanged: (value) => LocaleController().setLocale(
              value ? const Locale('es') : const Locale('en'),
            ),
            activeColor: Colors.white,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: Colors.white38,
            activeTrackColor: Colors.white38,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        _langLabel('ES', isSpanish),
      ],
    );
  }

  Widget _langLabel(String code, bool isActive) {
    return Text(
      code,
      style: TextStyle(
        color: isActive ? Colors.white : Colors.white54,
        fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
        fontSize: 13,
      ),
    );
  }

  /// Custom drawer header that replicates [UserAccountsDrawerHeader] styling
  /// and places the language switch inline with the display name row.
  Widget _buildHeader(BuildContext context, AppLocalizations l10n) {
    final isLoggedIn = username != null;
    final isSpanish = LocaleController().isSpanish;

    return Container(
      color: Theme.of(context).colorScheme.primary,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top row: avatar + action icons
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: Colors.white,
                    backgroundImage: avatarUrl != null && avatarUrl!.isNotEmpty
                        ? NetworkImage(
                            ApiEndpoints.resolveThumbnailUrl(avatarUrl),
                            headers:
                                avatarUrl != null && avatarUrl!.contains('?v=')
                                    ? const {
                                        'Cache-Control': 'no-cache',
                                        'Pragma': 'no-cache'
                                      }
                                    : null,
                          )
                        : null,
                    child: avatarUrl == null || avatarUrl!.isEmpty
                        ? (isLoggedIn
                            ? Text(
                                (displayName ?? username ?? '?')
                                    .substring(0, 1)
                                    .toUpperCase(),
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              )
                            : Icon(
                                Icons.person_outline,
                                size: 40,
                                color: Theme.of(context).colorScheme.primary,
                              ))
                        : null,
                  ),
                  const Spacer(),
                  if (isLoggedIn) ...[
                    IconButton(
                      icon: const Icon(Icons.person, color: Colors.white),
                      onPressed: () => _handleNavigation(context, 4),
                      tooltip: l10n.myProfile,
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings, color: Colors.white),
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SettingsScreen(),
                          ),
                        );
                      },
                      tooltip: l10n.settings,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              // Display name + language toggle on the same row
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      displayName ?? username ?? l10n.guest,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 16,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isLoggedIn) _buildLanguageToggle(isSpanish),
                ],
              ),
              // Username
              if (isLoggedIn)
                Text(
                  '@${username ?? ''}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: LocaleController().locale,
      builder: (context, locale, _) {
        final l10n = AppLocalizations(locale.languageCode);
        final isLoggedIn = username != null;

        return Drawer(
          child: Column(
            children: [
              _buildHeader(context, l10n),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.map),
                      title: Text(l10n.trips),
                      selected: selectedIndex == 0,
                      onTap: () => _handleNavigation(context, 0),
                    ),
                    if (isLoggedIn) ...[
                      ListTile(
                        leading: const Icon(Icons.calendar_today),
                        title: Text(l10n.tripPlans),
                        selected: selectedIndex == 1,
                        onTap: () => _handleNavigation(context, 1),
                      ),
                      ListTile(
                        leading: const Icon(Icons.people),
                        title: Text(l10n.friends),
                        selected: selectedIndex == 2,
                        onTap: () => _handleNavigation(context, 2),
                      ),
                      ListTile(
                        leading: const Icon(Icons.emoji_events),
                        title: Text(l10n.achievements),
                        selected: selectedIndex == 3,
                        onTap: () => _handleNavigation(context, 3),
                      ),
                      if (isAdmin) ...[
                        const Divider(),
                        ListTile(
                          leading: const Icon(Icons.admin_panel_settings),
                          title: Text(l10n.tripPromotion),
                          selected: selectedIndex == 5,
                          onTap: () => _handleNavigation(context, 5),
                        ),
                        ListTile(
                          leading: const Icon(Icons.people_outline),
                          title: Text(l10n.userManagement),
                          selected: selectedIndex == 6,
                          onTap: () => _handleNavigation(context, 6),
                        ),
                        ListTile(
                          leading: const Icon(Icons.build_outlined),
                          title: Text(l10n.tripDataMaintenance),
                          selected: selectedIndex == 7,
                          onTap: () => _handleNavigation(context, 7),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.coffee),
                title: Text(l10n.buyMeACoffee),
                onTap: () {
                  Navigator.pop(context);
                  _launchBuyMeACoffee(context);
                },
              ),
              if (isLoggedIn)
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: Text(l10n.logout),
                  onTap: () {
                    Navigator.pop(context);
                    onLogout?.call();
                  },
                ),
              if (!isLoggedIn)
                ListTile(
                  leading: const Icon(Icons.login),
                  title: Text(l10n.logIn),
                  onTap: () {
                    Navigator.pop(context);
                    // Navigate to auth screen
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AuthScreen(),
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}
