import 'package:flutter/material.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/data/services/user_service.dart';
import 'package:wanderer_frontend/presentation/helpers/page_transitions.dart';
import 'package:wanderer_frontend/presentation/screens/profile_screen.dart';

/// Wrapper screen that resolves a username from a deep link URL
/// and navigates to the full ProfileScreen once the user ID is resolved.
class UserDeepLinkScreen extends StatefulWidget {
  final String username;

  const UserDeepLinkScreen({super.key, required this.username});

  @override
  State<UserDeepLinkScreen> createState() => _UserDeepLinkScreenState();
}

class _UserDeepLinkScreenState extends State<UserDeepLinkScreen> {
  final UserService _userService = UserService();
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    try {
      final profile = await _userService.getUserByUsername(widget.username);
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageTransitions.slideFromRight(ProfileScreen(userId: profile.id)),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error =
              'Could not find user "${widget.username}": ${e.toString().replaceAll('Exception: ', '')}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      body: Center(
        child: _isLoading
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.loadingProfileDeepLink,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      _error ?? 'An unknown error occurred',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 15),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context)
                        .pushNamedAndRemoveUntil('/', (_) => false),
                    child: Text(l10n.goHome),
                  ),
                ],
              ),
      ),
    );
  }
}
