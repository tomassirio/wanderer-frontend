import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/l10n/locale_controller.dart';
import 'package:wanderer_frontend/core/services/push_notification_manager.dart';
import 'package:wanderer_frontend/core/theme/theme_controller.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/data/repositories/home_repository.dart';
import 'package:wanderer_frontend/data/services/auth_service.dart';
import 'package:wanderer_frontend/data/services/user_service.dart';
import 'package:wanderer_frontend/data/models/requests/password_change_request.dart';
import 'package:wanderer_frontend/presentation/helpers/ui_helpers.dart';
import 'package:wanderer_frontend/presentation/screens/home_screen.dart';
import 'package:wanderer_frontend/presentation/screens/privacy_policy_screen.dart';
import 'package:wanderer_frontend/presentation/screens/terms_and_conditions_screen.dart';
import 'package:wanderer_frontend/presentation/widgets/common/floating_notification.dart';

/// Settings screen with categorized options for the user.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();
  final HomeRepository _homeRepository = HomeRepository();
  final PushNotificationManager _pushNotificationManager =
      PushNotificationManager();

  bool _isLoading = false;
  bool _pushEnabled = true;
  bool _isDarkMode = false;
  String _appVersion = '';

  // Easter egg state
  int _easterEggTapCount = 0;
  OverlayEntry? _easterEggOverlay;

  @override
  void initState() {
    super.initState();
    _loadPushPreference();
    _loadAppVersion();
    _isDarkMode = ThemeController().isDarkMode;
  }

  @override
  void dispose() {
    _easterEggOverlay?.remove();
    _easterEggOverlay = null;
    super.dispose();
  }

  Future<void> _loadAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _appVersion = packageInfo.version;
      });
    }
  }

  Future<void> _loadPushPreference() async {
    final enabled = await _pushNotificationManager.loadEnabled();
    if (mounted) {
      setState(() {
        _pushEnabled = enabled;
      });
    }
  }

  Future<void> _togglePushNotifications(bool value) async {
    final previousValue = _pushEnabled;
    setState(() {
      _pushEnabled = value;
    });
    try {
      await _pushNotificationManager.setEnabled(value);
    } catch (e) {
      if (mounted) {
        setState(() {
          _pushEnabled = previousValue;
        });
        UiHelpers.showErrorMessage(
          context,
          'Failed to update notification preference',
        );
      }
    }
  }

  // --- Appearance ---

  Future<void> _toggleDarkMode(bool value) async {
    await ThemeController().setDarkMode(value);
    if (mounted) {
      setState(() => _isDarkMode = value);
    }
  }

  // --- Account Actions ---

  Future<void> _handleChangePassword() async {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.changePasswordTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: currentPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: l10n.currentPassword,
                    prefixIcon: const Icon(Icons.lock_outline),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: l10n.newPassword,
                    prefixIcon: const Icon(Icons.lock),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: l10n.confirmNewPassword,
                    prefixIcon: const Icon(Icons.lock),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Change'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    final currentPassword = currentPasswordController.text.trim();
    final newPassword = newPasswordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();

    currentPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();

    if (currentPassword.isEmpty || newPassword.isEmpty) {
      UiHelpers.showErrorMessage(context, 'All fields are required');
      return;
    }

    if (newPassword != confirmPassword) {
      UiHelpers.showErrorMessage(context, 'New passwords do not match');
      return;
    }

    if (newPassword.length < 8) {
      UiHelpers.showErrorMessage(
        context,
        'New password must be at least 8 characters',
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _authService.changePassword(
        PasswordChangeRequest(
          currentPassword: currentPassword,
          newPassword: newPassword,
        ),
      );
      if (mounted) {
        UiHelpers.showSuccessMessage(context, 'Password changed successfully');
      }
    } catch (e) {
      if (mounted) {
        UiHelpers.showErrorMessage(context, 'Failed to change password: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleResetPassword() async {
    final emailController = TextEditingController();

    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.resetPassword),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.enterEmailForReset),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: l10n.emailLabel,
                  prefixIcon: const Icon(Icons.email_outlined),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.sendResetLink),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    final email = emailController.text.trim();
    emailController.dispose();

    if (email.isEmpty) {
      UiHelpers.showErrorMessage(context, 'Please enter your email');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _authService.requestPasswordReset(email);
      if (mounted) {
        UiHelpers.showSuccessMessage(
          context,
          'Password reset link sent to $email',
        );
      }
    } catch (e) {
      if (mounted) {
        UiHelpers.showErrorMessage(context, 'Failed to send reset link: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- Support ---

  Future<void> _handleContactSupport() async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'support@wanderer.app',
      queryParameters: {'subject': 'Wanderer App Support Request'},
    );

    try {
      final launched = await launchUrl(uri);
      if (!launched && mounted) {
        UiHelpers.showErrorMessage(context, 'Could not open email client');
      }
    } catch (e) {
      if (mounted) {
        UiHelpers.showErrorMessage(context, 'Error opening email client: $e');
      }
    }
  }

  // --- Danger Zone ---

  Future<void> _handleCloseAccount() async {
    final l10n = context.l10n;
    // First confirmation
    final firstConfirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.closeAccount),
        content: const Text(
          'Are you sure you want to permanently delete your account? '
          'This action cannot be undone. All your trips, plans, and data will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.continue_),
          ),
        ],
      ),
    );

    if (firstConfirm != true || !mounted) return;

    // Second confirmation with typed input
    final confirmController = TextEditingController();
    final secondConfirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.confirmAccountDeletion),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.typeDELETEConfirm),
            const SizedBox(height: 16),
            TextField(
              controller: confirmController,
              decoration: InputDecoration(
                hintText: l10n.typeDELETE,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.deleteMyAccount),
          ),
        ],
      ),
    );

    final typedValue = confirmController.text.trim();
    confirmController.dispose();

    if (secondConfirm != true || typedValue != 'DELETE' || !mounted) {
      if (secondConfirm == true && typedValue != 'DELETE' && mounted) {
        UiHelpers.showErrorMessage(context, 'You must type DELETE to confirm');
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _userService.deleteMyAccount();
      await _homeRepository.logout();
      if (mounted) {
        UiHelpers.showSuccessMessage(context, 'Account deleted successfully');
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        UiHelpers.showErrorMessage(context, 'Failed to delete account: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  // --- Easter Egg ---

  void _handleVersionTap() {
    setState(() {
      _easterEggTapCount++;
    });

    final remaining = 10 - _easterEggTapCount;

    if (_easterEggTapCount >= 8 && _easterEggTapCount < 10) {
      FloatingNotification.show(
        context,
        '$remaining taps away from a surprise... 🥚',
        NotificationType.info,
        duration: const Duration(seconds: 1),
      );
    } else if (_easterEggTapCount == 10) {
      FloatingNotification.show(
        context,
        'You found it! 🐣',
        NotificationType.success,
        duration: const Duration(seconds: 2),
      );
      _showEasterEggOverlay();
    }
    // If tapping beyond 10 while overlay is not shown, reset
    if (_easterEggTapCount > 10) {
      _dismissEasterEggOverlay();
    }
  }

  void _showEasterEggOverlay() {
    _easterEggOverlay?.remove();
    _easterEggOverlay = OverlayEntry(
      builder: (context) => _EasterEggOverlay(
        onDismiss: _dismissEasterEggOverlay,
      ),
    );
    Overlay.of(context).insert(_easterEggOverlay!);
  }

  void _dismissEasterEggOverlay() {
    _easterEggOverlay?.remove();
    _easterEggOverlay = null;
    setState(() {
      _easterEggTapCount = 0;
    });
  }

  // --- Build ---

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: [
                _buildSectionHeader(l10n.appearance),
                _buildSwitchTile(
                  icon: Icons.dark_mode_outlined,
                  iconColor:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  title: l10n.darkMode,
                  subtitle: l10n.darkModeSubtitle,
                  value: _isDarkMode,
                  onChanged: _toggleDarkMode,
                ),
                _buildLanguageTile(l10n),
                const SizedBox(height: 8),
                _buildSectionHeader(l10n.account),
                _buildSettingsTile(
                  icon: Icons.lock_outline,
                  iconColor: WandererTheme.primaryOrange,
                  title: l10n.changePassword,
                  subtitle: l10n.changePasswordSubtitle,
                  onTap: _handleChangePassword,
                ),
                _buildSettingsTile(
                  icon: Icons.email_outlined,
                  iconColor: WandererTheme.primaryOrange,
                  title: l10n.resetPassword,
                  subtitle: l10n.resetPasswordSubtitle,
                  onTap: _handleResetPassword,
                ),
                const SizedBox(height: 8),
                _buildSectionHeader(l10n.notificationsSection),
                _buildSwitchTile(
                  icon: Icons.notifications_outlined,
                  iconColor: WandererTheme.primaryOrange,
                  title: l10n.pushNotifications,
                  subtitle: l10n.pushNotificationsSubtitle,
                  value: _pushEnabled,
                  onChanged: _togglePushNotifications,
                ),
                const SizedBox(height: 8),
                _buildSectionHeader(l10n.support),
                _buildSettingsTile(
                  icon: Icons.help_outline,
                  iconColor: WandererTheme.statusCompleted,
                  title: l10n.contactSupport,
                  subtitle: l10n.contactSupportSubtitle,
                  onTap: _handleContactSupport,
                ),
                _buildSettingsTile(
                  icon: Icons.description_outlined,
                  iconColor: WandererTheme.statusCompleted,
                  title: l10n.termsOfService,
                  subtitle: 'Read our terms and conditions',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const TermsAndConditionsScreen(),
                      ),
                    );
                  },
                ),
                _buildSettingsTile(
                  icon: Icons.privacy_tip_outlined,
                  iconColor: WandererTheme.statusCompleted,
                  title: l10n.privacyPolicy,
                  subtitle: 'Review our privacy practices',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PrivacyPolicyScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                _buildSectionHeader('About'),
                _buildSettingsTile(
                  icon: Icons.info_outline,
                  iconColor:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  title: l10n.appVersion,
                  subtitle: _appVersion.isEmpty ? 'Loading...' : _appVersion,
                  onTap: _handleVersionTap,
                ),
                const SizedBox(height: 8),
                _buildSectionHeader('Danger Zone'),
                _buildSettingsTile(
                  icon: Icons.delete_forever,
                  iconColor: Colors.red,
                  title: l10n.closeAccount,
                  subtitle: l10n.closeAccountSubtitle,
                  onTap: _handleCloseAccount,
                  isDestructive: true,
                ),
              ],
            ),
    );
  }

  Widget _buildLanguageTile(AppLocalizations l10n) {
    final controller = LocaleController();
    final currentCode = controller.languageCode;
    final flag = LocaleController.localeFlags[currentCode] ?? '🌐';
    final nativeName = l10n.languageNameFor(currentCode);

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: WandererTheme.primaryOrange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.language,
            color: WandererTheme.primaryOrange, size: 22),
      ),
      title: Text(
        l10n.language,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      subtitle: Text(
        '$flag $nativeName',
        style: TextStyle(
          fontSize: 13,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
        ),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showLanguagePicker(l10n),
    );
  }

  void _showLanguagePicker(AppLocalizations l10n) {
    final controller = LocaleController();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  l10n.language,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ...LocaleController.supportedLocales.map((locale) {
                final code = locale.languageCode;
                final flag = LocaleController.localeFlags[code] ?? '🌐';
                final name = l10n.languageNameFor(code);
                final isSelected = code == controller.languageCode;
                return ListTile(
                  leading: Text(flag, style: const TextStyle(fontSize: 24)),
                  title: Text(
                    name,
                    style: TextStyle(
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  trailing: isSelected
                      ? Icon(Icons.check, color: WandererTheme.primaryOrange)
                      : null,
                  onTap: () {
                    controller.setLocale(Locale(code));
                    Navigator.pop(ctx);
                    setState(() {}); // Rebuild to reflect new locale
                  },
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 13,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: WandererTheme.primaryOrange,
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    bool isDestructive = false,
  }) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: isDestructive ? Colors.red : onSurface,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 13,
          color: isDestructive
              ? Colors.red.withOpacity(0.7)
              : onSurface.withOpacity(0.6),
        ),
      ),
      trailing: onTap != null
          ? Icon(
              Icons.chevron_right,
              color: isDestructive ? Colors.red : onSurface.withOpacity(0.4),
            )
          : null,
      onTap: onTap,
    );
  }
}

/// Fullscreen overlay that displays the easter egg image with a fade-in animation.
/// Tapping anywhere on the overlay dismisses it.
class _EasterEggOverlay extends StatefulWidget {
  final VoidCallback onDismiss;

  const _EasterEggOverlay({required this.onDismiss});

  @override
  State<_EasterEggOverlay> createState() => _EasterEggOverlayState();
}

class _EasterEggOverlayState extends State<_EasterEggOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    ));

    _controller.forward();
  }

  Future<void> _dismiss() async {
    await _controller.reverse();
    widget.onDismiss();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _dismiss,
      child: Material(
        color: Colors.transparent,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Container(
            color: Colors.black.withValues(alpha: 0.7),
            child: Center(
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/images/egg/PixelEgg.png',
                      width: 250,
                      height: 250,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      '🎉 Thanks for using Wanderer! 🎉',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap anywhere to close',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 14,
                        fontWeight: FontWeight.normal,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
