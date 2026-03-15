import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wanderer_frontend/core/services/push_notification_manager.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/data/repositories/home_repository.dart';
import 'package:wanderer_frontend/data/services/auth_service.dart';
import 'package:wanderer_frontend/data/services/user_service.dart';
import 'package:wanderer_frontend/data/models/requests/password_change_request.dart';
import 'package:wanderer_frontend/presentation/helpers/ui_helpers.dart';
import 'package:wanderer_frontend/presentation/screens/home_screen.dart';
import 'package:wanderer_frontend/presentation/screens/privacy_policy_screen.dart';
import 'package:wanderer_frontend/presentation/screens/terms_and_conditions_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _loadPushPreference();
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

  // --- Account Actions ---

  Future<void> _handleChangePassword() async {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Change Password'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: currentPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Current Password',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'New Password',
                    prefixIcon: Icon(Icons.lock),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirm New Password',
                    prefixIcon: Icon(Icons.lock),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
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

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reset Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Enter your email address and we\'ll send you a link to reset your password.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Send Reset Link'),
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
    // First confirmation
    final firstConfirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Close Account'),
        content: const Text(
          'Are you sure you want to permanently delete your account? '
          'This action cannot be undone. All your trips, plans, and data will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Continue'),
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
        title: const Text('Confirm Account Deletion'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Type DELETE to confirm you want to permanently close your account.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: confirmController,
              decoration: const InputDecoration(
                hintText: 'Type DELETE',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete My Account'),
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

  // --- Build ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: [
                _buildSectionHeader('Account'),
                _buildSettingsTile(
                  icon: Icons.lock_outline,
                  iconColor: WandererTheme.primaryOrange,
                  title: 'Change Password',
                  subtitle: 'Update your current password',
                  onTap: _handleChangePassword,
                ),
                _buildSettingsTile(
                  icon: Icons.email_outlined,
                  iconColor: WandererTheme.primaryOrange,
                  title: 'Reset Password',
                  subtitle: 'Send a password reset link to your email',
                  onTap: _handleResetPassword,
                ),
                const SizedBox(height: 8),
                _buildSectionHeader('Notifications'),
                _buildSwitchTile(
                  icon: Icons.notifications_outlined,
                  iconColor: WandererTheme.primaryOrange,
                  title: 'Push Notifications',
                  subtitle: 'Receive alerts for friend requests, comments, '
                      'achievements, and other activity',
                  value: _pushEnabled,
                  onChanged: _togglePushNotifications,
                ),
                const SizedBox(height: 8),
                _buildSectionHeader('Support'),
                _buildSettingsTile(
                  icon: Icons.help_outline,
                  iconColor: WandererTheme.statusCompleted,
                  title: 'Contact Support',
                  subtitle: 'Get help via email',
                  onTap: _handleContactSupport,
                ),
                _buildSettingsTile(
                  icon: Icons.description_outlined,
                  iconColor: WandererTheme.statusCompleted,
                  title: 'Terms of Service',
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
                  title: 'Privacy Policy',
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
                  iconColor: WandererTheme.textSecondary,
                  title: 'App Version',
                  subtitle: '1.2.8-SNAPSHOT',
                  onTap: null,
                ),
                const SizedBox(height: 8),
                _buildSectionHeader('Danger Zone'),
                _buildSettingsTile(
                  icon: Icons.delete_forever,
                  iconColor: Colors.red,
                  title: 'Close Account',
                  subtitle: 'Permanently delete your account and all data',
                  onTap: _handleCloseAccount,
                  isDestructive: true,
                ),
              ],
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
          color: WandererTheme.textTertiary,
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
          color: isDestructive ? Colors.red : WandererTheme.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 13,
          color: isDestructive
              ? Colors.red.withOpacity(0.7)
              : WandererTheme.textSecondary,
        ),
      ),
      trailing: onTap != null
          ? Icon(
              Icons.chevron_right,
              color: isDestructive ? Colors.red : WandererTheme.textTertiary,
            )
          : null,
      onTap: onTap,
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
    return SwitchListTile(
      secondary: Container(
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
          color: WandererTheme.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 13, color: WandererTheme.textSecondary),
      ),
      value: value,
      activeColor: WandererTheme.primaryOrange,
      onChanged: onChanged,
    );
  }
}
