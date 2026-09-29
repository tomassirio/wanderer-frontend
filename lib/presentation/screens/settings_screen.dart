import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/providers/app_providers.dart';
import 'package:wanderer_frontend/core/l10n/locale_controller.dart';
import 'package:wanderer_frontend/core/services/push_notification_manager.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/data/repositories/home_repository.dart';
import 'package:wanderer_frontend/data/services/auth_service.dart';
import 'package:wanderer_frontend/data/services/user_service.dart';
import 'package:wanderer_frontend/data/models/requests/password_change_request.dart';
import 'package:wanderer_frontend/data/storage/onboarding_storage.dart';
import 'package:wanderer_frontend/presentation/helpers/dialog_helper.dart';
import 'package:wanderer_frontend/presentation/helpers/tutorial_helper.dart';
import 'package:wanderer_frontend/presentation/helpers/ui_helpers.dart';
import 'package:wanderer_frontend/presentation/helpers/page_transitions.dart';
import 'package:wanderer_frontend/presentation/screens/privacy_policy_screen.dart';
import 'package:wanderer_frontend/presentation/screens/terms_and_conditions_screen.dart';
import 'package:wanderer_frontend/presentation/widgets/common/floating_notification.dart';
import 'package:wanderer_frontend/presentation/widgets/common/fireworks_widget.dart';
import 'package:wanderer_frontend/presentation/screens/initial_screen.dart';
import 'package:wanderer_frontend/presentation/widgets/common/app_sidebar.dart';
import 'package:wanderer_frontend/presentation/widgets/common/toasts.dart';
import 'package:wanderer_frontend/presentation/widgets/android/android_ui.dart';
import 'package:wanderer_frontend/presentation/widgets/android/settings_android.dart';
import 'package:wanderer_frontend/presentation/widgets/common/wanderer_dialog.dart';
import 'package:wanderer_frontend/presentation/widgets/common/wanderer_scaffold.dart';
import 'package:wanderer_frontend/presentation/widgets/settings/web_settings_layout.dart';

/// Settings screen with categorized options for the user.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final AuthService _authService;
  late final UserService _userService;
  late final HomeRepository _homeRepository;
  final PushNotificationManager _pushNotificationManager =
      PushNotificationManager();

  bool _isLoading = false;
  bool _pushEnabled = true;
  bool _isAdmin = false;
  String _appVersion = '';

  // Web sidebar / account ID
  String? _userId;
  String? _username;
  String? _displayName;
  String? _avatarUrl;

  // Easter egg state
  int _easterEggTapCount = 0;
  OverlayEntry? _easterEggOverlay;

  @override
  void initState() {
    super.initState();
    _authService = ref.read(authServiceProvider);
    _userService = ref.read(userServiceProvider);
    _homeRepository = ref.read(homeRepositoryProvider);
    _loadPushPreference();
    _loadAppVersion();
    _loadAdminStatus();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final userId = await _homeRepository.getCurrentUserId();
    final username = await _homeRepository.getCurrentUsername();
    final displayName = await _homeRepository.getCurrentDisplayName();
    final avatarUrl = await _homeRepository.getCurrentAvatarUrl();
    if (mounted) {
      setState(() {
        _userId = userId;
        _username = username;
        _displayName = displayName;
        _avatarUrl = avatarUrl;
      });
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await DialogHelper.showLogoutConfirmation(context);
    if (!confirm) return;
    await _homeRepository.logout();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        PageTransitions.fade(const InitialScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _loadAdminStatus() async {
    final isAdmin = await _homeRepository.isAdmin();
    if (mounted) {
      setState(() {
        _isAdmin = isAdmin;
      });
    }
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
        _notify('Failed to update notification preference', error: true);
      }
    }
  }

  /// Web keeps its floating notifications; Android shows toasts.
  void _notify(String message, {bool error = false}) {
    if (kIsWeb) {
      error
          ? UiHelpers.showErrorMessage(context, message)
          : UiHelpers.showSuccessMessage(context, message);
      return;
    }
    Toasts.show(ToastData(
        kind: error ? ToastKind.error : ToastKind.success, title: message));
  }

  // --- Account Actions ---

  Future<void> _handleChangePassword() async {
    if (!kIsWeb) {
      final result = await showSettingsChangePasswordSheet(context);
      if (result == null || !mounted) return;
      return _submitPasswordChange(result.$1, result.$2);
    }
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    final confirmed = await showWebChangePasswordDialog(
      context,
      current: currentPasswordController,
      next: newPasswordController,
      confirm: confirmPasswordController,
    );

    if (confirmed != true || !mounted) return;

    final currentPassword = currentPasswordController.text.trim();
    final newPassword = newPasswordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();

    currentPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();

    if (currentPassword.isEmpty || newPassword.isEmpty) {
      _notify(context.l10n.msgAllFieldsRequired, error: true);
      return;
    }

    if (newPassword != confirmPassword) {
      _notify(context.l10n.msgPasswordsDontMatch, error: true);
      return;
    }

    if (newPassword.length < 8) {
      _notify('New password must be at least 8 characters', error: true);
      return;
    }

    await _submitPasswordChange(currentPassword, newPassword);
  }

  Future<void> _submitPasswordChange(
      String currentPassword, String newPassword) async {
    setState(() => _isLoading = true);

    try {
      await _authService.changePassword(
        PasswordChangeRequest(
          currentPassword: currentPassword,
          newPassword: newPassword,
        ),
      );
      if (mounted) {
        _notify(context.l10n.msgPasswordChanged);
      }
    } catch (e) {
      if (mounted) {
        _notify(context.l10n.msgPasswordChangeFailed(e), error: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleResetPassword() async {
    if (!kIsWeb) {
      final email = await showSettingsResetPasswordSheet(context);
      if (email == null || !mounted) return;
      return _submitPasswordReset(email);
    }
    final emailController = TextEditingController();

    final confirmed =
        await showWebResetPasswordDialog(context, email: emailController);

    if (confirmed != true || !mounted) return;

    final email = emailController.text.trim();
    emailController.dispose();

    if (email.isEmpty) {
      _notify(context.l10n.msgEnterEmail, error: true);
      return;
    }

    await _submitPasswordReset(email);
  }

  Future<void> _submitPasswordReset(String email) async {
    setState(() => _isLoading = true);

    try {
      await _authService.requestPasswordReset(email);
      if (mounted) {
        _notify(kIsWeb
            ? 'Password reset link sent to $email'
            : context.l10n.passwordResetEmailSent(email));
      }
    } catch (e) {
      if (mounted) {
        _notify(context.l10n.msgResetLinkFailed(e), error: true);
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
        _notify(context.l10n.msgEmailClientUnavailable, error: true);
      }
    } catch (e) {
      if (mounted) {
        _notify(context.l10n.msgEmailClientError(e), error: true);
      }
    }
  }

  Future<void> _handleResetTutorials() async {
    final l10n = context.l10n;
    final storage = OnboardingStorage();
    await Future.wait(TutorialKeys.all.map(storage.resetTutorial));

    if (mounted) {
      _notify(l10n.resetTutorialsSuccess);
    }
  }

  // --- Danger Zone ---

  Future<void> _handleCloseAccount() async {
    if (!kIsWeb) {
      final confirmed =
          await showSettingsCloseAccountSheet(context, username: _username);
      if (!confirmed || !mounted) return;
      return _deleteAccount();
    }
    final l10n = context.l10n;
    // First confirmation
    final firstConfirm = await WandererDialog.confirm(
      context,
      title: l10n.closeAccount,
      message: l10n.settingsCloseAccountMessage,
      confirmLabel: l10n.continue_,
      icon: Icons.delete_forever,
      destructive: true,
    );

    if (firstConfirm != true || !mounted) return;

    // Second confirmation with typed input
    final confirmController = TextEditingController();
    final secondConfirm =
        await showWebTypeDeleteDialog(context, controller: confirmController);

    final typedValue = confirmController.text.trim();
    confirmController.dispose();

    if (secondConfirm != true || typedValue != 'DELETE' || !mounted) {
      if (secondConfirm == true && typedValue != 'DELETE' && mounted) {
        _notify(context.l10n.msgTypeDeleteToConfirm, error: true);
      }
      return;
    }

    await _deleteAccount();
  }

  Future<void> _deleteAccount() async {
    setState(() => _isLoading = true);

    try {
      await _userService.deleteMyAccount();
      await _homeRepository.logout();
      if (mounted) {
        _notify(context.l10n.msgAccountDeleted);
        Navigator.of(context).pushAndRemoveUntil(
          PageTransitions.fade(const InitialScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        _notify(context.l10n.msgAccountDeleteFailed(e), error: true);
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
    final l10n = context.l10n;

    if (!kIsWeb && _easterEggTapCount >= 8 && _easterEggTapCount < 10) {
      Toasts.show(ToastData(
        kind: ToastKind.hint,
        title: l10n.settingsAndroidEggHintTitle,
        body: remaining == 1
            ? l10n.settingsAndroidEggOneMore
            : l10n.settingsAndroidEggMore(remaining),
      ));
    } else if (!kIsWeb && _easterEggTapCount == 10) {
      Toasts.show(ToastData(
        kind: ToastKind.achievement,
        title: l10n.easterEggFound,
        body: l10n.easterEggThanks,
      ));
      _showEasterEggOverlay();
    } else if (_easterEggTapCount >= 8 && _easterEggTapCount < 10) {
      FloatingNotification.show(
        context,
        l10n.easterEggTapsRemaining(remaining),
        NotificationType.info,
        duration: const Duration(seconds: 1),
      );
    } else if (_easterEggTapCount == 10) {
      FloatingNotification.show(
        context,
        l10n.easterEggFound,
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
    final appBar = AppBar(
      title: Text(l10n.settings),
      backgroundColor: Theme.of(context).colorScheme.inversePrimary,
    );
    if (kIsWeb) return _buildWeb(appBar);
    return _buildAndroid();
  }

  /// Web redesign. Push notifications are Android-only
  /// ([PushNotificationManager]), so the Notifications section is omitted.
  Widget _buildWeb(PreferredSizeWidget appBar) {
    // Narrow web keeps the back button: only pass the sidebar when it sits
    // beside the page.
    final wide = WandererScaffold.hasPersistentSidebar(context);
    return WandererScaffold(
      hideAppBarWithSidebar: true,
      appBar: appBar,
      drawer: wide
          ? AppSidebar(
              username: _username,
              userId: _userId,
              displayName: _displayName,
              avatarUrl: _avatarUrl,
              selectedIndex: -1,
              onLogout: _handleLogout,
              isAdmin: _isAdmin,
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : WebSettingsLayout(
              userId: _userId,
              isAdmin: _isAdmin,
              appVersion: _appVersion,
              onChangePassword: _handleChangePassword,
              onResetPassword: _handleResetPassword,
              onContactSupport: _handleContactSupport,
              onResetTutorials: _handleResetTutorials,
              onTerms: () => Navigator.push(
                context,
                PageTransitions.slideFromRight(
                    const TermsAndConditionsScreen()),
              ),
              onPrivacy: () => Navigator.push(
                context,
                PageTransitions.slideFromRight(const PrivacyPolicyScreen()),
              ),
              onCloseAccount: _handleCloseAccount,
              onVersionTap: _handleVersionTap,
              onLocaleChanged: () => setState(() {}),
            ),
    );
  }

  /// Android redesign (canvas "AndroidSettings"): grouped cards, sheets
  /// instead of dialogs, toasts instead of floating notifications.
  Widget _buildAndroid() {
    final l10n = context.l10n;
    final c = WandererTheme.of(context);
    final danger = Theme.of(context).colorScheme.error;
    void push(Widget screen) =>
        Navigator.push(context, PageTransitions.slideFromRight(screen));
    return Scaffold(
      backgroundColor: c.ground,
      appBar: AndroidTopBar(title: l10n.settings),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                SettingsGroup(label: l10n.appearance, children: [
                  SettingsRow(
                    title: l10n.settingsTheme,
                    trailing: const SettingsThemeSelector(),
                  ),
                  SettingsRow(
                    title: l10n.language,
                    subtitle:
                        l10n.languageNameFor(LocaleController().languageCode),
                    onTap: () async {
                      await showSettingsLanguageSheet(context);
                      if (mounted) setState(() {});
                    },
                  ),
                ]),
                const SizedBox(height: 14),
                SettingsGroup(label: l10n.account, children: [
                  SettingsRow(
                    title: l10n.settingsChangePasswordButton,
                    onTap: _handleChangePassword,
                  ),
                  SettingsRow(
                    title: l10n.settingsAndroidForgotPassword,
                    subtitle: l10n.settingsAndroidForgotCaption,
                    onTap: _handleResetPassword,
                  ),
                ]),
                const SizedBox(height: 14),
                SettingsGroup(label: l10n.notificationsSection, children: [
                  SettingsRow(
                    title: l10n.settingsAndroidPush,
                    subtitle: l10n.settingsAndroidPushCaption,
                    onTap: () => _togglePushNotifications(!_pushEnabled),
                    trailing: Switch(
                      value: _pushEnabled,
                      onChanged: _togglePushNotifications,
                      activeTrackColor: WandererTheme.trail,
                    ),
                  ),
                ]),
                const SizedBox(height: 14),
                SettingsGroup(label: l10n.settingsHelp, children: [
                  SettingsRow(
                    title: l10n.settingsAndroidContactSupport,
                    onTap: _handleContactSupport,
                  ),
                  if (_isAdmin)
                    SettingsRow(
                      title: l10n.settingsAndroidShowTutorials,
                      onTap: _handleResetTutorials,
                    ),
                  SettingsRow(
                    title: l10n.settingsAndroidTerms,
                    onTap: () => push(const TermsAndConditionsScreen()),
                  ),
                  SettingsRow(
                    title: l10n.settingsAndroidPrivacy,
                    onTap: () => push(const PrivacyPolicyScreen()),
                  ),
                ]),
                const SizedBox(height: 14),
                SettingsGroup(children: [
                  SettingsRow(
                    title: l10n.dialogLogoutAction,
                    chevron: false,
                    onTap: _handleLogout,
                  ),
                  SettingsRow(
                    title: l10n.settingsCloseAccountButton,
                    color: danger,
                    chevron: false,
                    onTap: _handleCloseAccount,
                  ),
                ]),
                const SizedBox(height: 6),
                Center(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: _handleVersionTap,
                    child: Container(
                      height: 48,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        l10n.settingsAndroidVersion(_appVersion).trim(),
                        style: TextStyle(fontSize: 12, color: c.label),
                      ),
                    ),
                  ),
                ),
              ],
            ),
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
    final l10n = AppLocalizations.fromController();
    return GestureDetector(
      onTap: _dismiss,
      child: Material(
        color: Colors.transparent,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Stack(
            children: [
              // Dark backdrop
              Container(color: Colors.black.withValues(alpha: 0.7)),
              // Fireworks layer (behind the egg content)
              const Positioned.fill(
                child: FireworksWidget(
                  burstCount: 6,
                  burstInterval: Duration(milliseconds: 600),
                ),
              ),
              // Egg + text content
              Center(
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
                      Text(
                        l10n.easterEggThanks,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.easterEggDismiss,
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
            ],
          ),
        ),
      ),
    );
  }
}
