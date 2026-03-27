import 'package:flutter/material.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/presentation/widgets/auth/auth_header.dart';
import 'package:wanderer_frontend/presentation/widgets/auth/auth_mode_toggle.dart';
import 'package:wanderer_frontend/presentation/widgets/auth/auth_submit_button.dart';
import 'package:wanderer_frontend/presentation/widgets/auth/email_field.dart';
import 'package:wanderer_frontend/presentation/widgets/auth/error_message.dart';
import 'package:wanderer_frontend/presentation/widgets/auth/password_field.dart';
import 'package:wanderer_frontend/presentation/widgets/auth/username_field.dart';

/// Main authentication form widget
class AuthForm extends StatefulWidget {
  final GlobalKey<FormState> formKey;
  final bool isLogin;
  final bool isLoading;
  final String? errorMessage;
  final TextEditingController usernameController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final VoidCallback onSubmit;
  final VoidCallback onToggleMode;
  final VoidCallback onForgotPassword;

  const AuthForm({
    super.key,
    required this.formKey,
    required this.isLogin,
    required this.isLoading,
    this.errorMessage,
    required this.usernameController,
    required this.emailController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.onSubmit,
    required this.onToggleMode,
    required this.onForgotPassword,
  });

  @override
  State<AuthForm> createState() => _AuthFormState();
}

class _AuthFormState extends State<AuthForm> {
  String _password = '';

  @override
  void initState() {
    super.initState();
    _password = widget.passwordController.text;
    widget.passwordController.addListener(_onPasswordChanged);
  }

  @override
  void didUpdateWidget(AuthForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.passwordController != widget.passwordController) {
      oldWidget.passwordController.removeListener(_onPasswordChanged);
      widget.passwordController.addListener(_onPasswordChanged);
      _password = widget.passwordController.text;
    }
  }

  @override
  void dispose() {
    widget.passwordController.removeListener(_onPasswordChanged);
    super.dispose();
  }

  void _onPasswordChanged() {
    setState(() {
      _password = widget.passwordController.text;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(widget.isLogin ? 24 : 20),
        child: Form(
          key: widget.formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AuthHeader(isLogin: widget.isLogin),
              SizedBox(height: widget.isLogin ? 32 : 20),

              // Username field
              UsernameField(
                controller: widget.usernameController,
                isLogin: widget.isLogin,
                textInputAction: TextInputAction.next,
              ),
              SizedBox(height: widget.isLogin ? 16 : 12),

              // Email field (only for registration)
              if (!widget.isLogin) ...[
                EmailField(
                  controller: widget.emailController,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
              ],

              // Password field
              PasswordField(
                controller: widget.passwordController,
                label: l10n.passwordLabel,
                isLogin: widget.isLogin,
                textInputAction: widget.isLogin
                    ? TextInputAction.done
                    : TextInputAction.next,
                onFieldSubmitted: widget.isLogin
                    ? (_) => widget.isLoading ? null : widget.onSubmit()
                    : null,
              ),
              SizedBox(height: widget.isLogin ? 16 : 12),

              // Confirm password field (only for registration)
              if (!widget.isLogin) ...[
                PasswordField(
                  controller: widget.confirmPasswordController,
                  label: l10n.confirmPassword,
                  isLogin: false,
                  compareController: widget.passwordController,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) =>
                      widget.isLoading ? null : widget.onSubmit(),
                ),
                const SizedBox(height: 8),
                _buildPasswordRequirements(context, l10n),
                const SizedBox(height: 12),
              ],

              // Forgot password button (only for login)
              if (widget.isLogin)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed:
                        widget.isLoading ? null : widget.onForgotPassword,
                    child: Text(l10n.forgotPassword),
                  ),
                ),

              // Error message
              if (widget.errorMessage != null) ...[
                const SizedBox(height: 8),
                ErrorMessage(message: widget.errorMessage!),
              ],

              const SizedBox(height: 16),

              // Submit button
              AuthSubmitButton(
                isLogin: widget.isLogin,
                isLoading: widget.isLoading,
                onPressed: widget.onSubmit,
              ),

              SizedBox(height: widget.isLogin ? 16 : 12),

              // Toggle login/register
              AuthModeToggle(
                isLogin: widget.isLogin,
                isLoading: widget.isLoading,
                onToggle: widget.onToggleMode,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordRequirements(
      BuildContext context, AppLocalizations l10n) {
    final hintColor =
        Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey;
    return Padding(
      padding: const EdgeInsets.only(left: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.passwordRequirements,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: hintColor,
            ),
          ),
          const SizedBox(height: 4),
          _buildRequirement(
            l10n.passwordRequirement8Chars,
            _password.length >= 8,
            hintColor,
          ),
          _buildRequirement(
            l10n.passwordRequirementUppercase,
            RegExp(r'[A-Z]').hasMatch(_password),
            hintColor,
          ),
          _buildRequirement(
            l10n.passwordRequirementLowercase,
            RegExp(r'[a-z]').hasMatch(_password),
            hintColor,
          ),
          _buildRequirement(
            l10n.passwordRequirementNumber,
            RegExp(r'\d').hasMatch(_password),
            hintColor,
          ),
          _buildRequirement(
            l10n.passwordRequirementSpecial,
            RegExp(r'[@$!%*?&#]').hasMatch(_password),
            hintColor,
          ),
        ],
      ),
    );
  }

  Widget _buildRequirement(String text, bool isMet, Color defaultColor) {
    final color = isMet ? Colors.green : defaultColor;
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 2),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.check_circle_outline,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(fontSize: 10, color: color),
          ),
        ],
      ),
    );
  }
}
