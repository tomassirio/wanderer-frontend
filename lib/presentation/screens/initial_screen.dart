import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wanderer_frontend/core/providers/app_providers.dart';
import 'package:wanderer_frontend/data/storage/token_refresh_manager.dart';
import 'package:wanderer_frontend/presentation/screens/dashboard_screen.dart';
import 'package:wanderer_frontend/presentation/screens/android/android_shell.dart';
import 'package:wanderer_frontend/presentation/screens/android/android_welcome_screen.dart';
import 'package:wanderer_frontend/presentation/widgets/common/wanderer_logo.dart';
import 'package:wanderer_frontend/presentation/screens/landing_screen.dart';

/// Initial screen that checks auth state and shows appropriate content
class InitialScreen extends ConsumerStatefulWidget {
  const InitialScreen({super.key});

  @override
  ConsumerState<InitialScreen> createState() => _InitialScreenState();
}

class _InitialScreenState extends ConsumerState<InitialScreen> {
  bool _isChecking = true;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    // Proactively refresh the access token if it has expired while the app
    // was closed.  This prevents the user from appearing "logged out" when
    // they still have a valid refresh token.
    try {
      final tokenStorage = ref.read(tokenStorageProvider);
      if (await tokenStorage.isLoggedIn()) {
        await TokenRefreshManager.instance
            .ensureValidToken(tokenStorage: tokenStorage);
      }
      // Re-read: a rejected refresh clears the session.
      _isLoggedIn = await tokenStorage.isLoggedIn();
    } catch (e) {
      debugPrint('InitialScreen: Error during startup token check: $e');
      // Continue to HomeScreen regardless — it handles guest mode gracefully
    }

    if (mounted) {
      setState(() {
        _isChecking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Scaffold(
        body: Center(child: WandererLogo(size: 64)),
      );
    }
    if (kIsWeb) {
      return _isLoggedIn ? const DashboardScreen() : const LandingScreen();
    }

    return _isLoggedIn ? const AndroidShell() : const AndroidWelcomeScreen();
  }
}
