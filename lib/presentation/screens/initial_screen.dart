import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:wanderer_frontend/data/storage/token_storage.dart';
import 'package:wanderer_frontend/data/storage/token_refresh_manager.dart';
import 'package:wanderer_frontend/presentation/screens/home_screen.dart';
import 'package:wanderer_frontend/presentation/screens/landing_screen.dart';

/// Initial screen that checks auth state and shows appropriate content
class InitialScreen extends StatefulWidget {
  const InitialScreen({super.key});

  @override
  State<InitialScreen> createState() => _InitialScreenState();
}

class _InitialScreenState extends State<InitialScreen> {
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
      final tokenStorage = TokenStorage();
      final isLoggedIn = await tokenStorage.isLoggedIn();
      _isLoggedIn = isLoggedIn;

      if (isLoggedIn) {
        final isExpired = await tokenStorage.isAccessTokenExpired();
        if (isExpired) {
          debugPrint('InitialScreen: Access token expired, refreshing...');
          final refreshed =
              await TokenRefreshManager.instance.ensureValidToken();
          debugPrint('InitialScreen: Token refresh result: $refreshed');
        }
      }
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
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).colorScheme.primary,
                Theme.of(context).colorScheme.secondary,
              ],
            ),
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.explore, size: 80, color: Colors.white),
                SizedBox(height: 24),
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (kIsWeb && !_isLoggedIn) {
      return const LandingScreen();
    }

    // Always show HomeScreen - it will handle showing public trips or user's trips
    return const HomeScreen();
  }
}
