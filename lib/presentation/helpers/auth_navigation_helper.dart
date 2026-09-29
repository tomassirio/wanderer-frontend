import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:wanderer_frontend/presentation/screens/android/android_shell.dart';
import 'package:wanderer_frontend/data/storage/token_storage.dart';
import 'package:wanderer_frontend/presentation/screens/auth_screen.dart';
import 'package:wanderer_frontend/presentation/screens/profile_screen.dart';
import 'package:wanderer_frontend/presentation/screens/friends_followers_screen.dart';
import 'package:wanderer_frontend/presentation/screens/trip_plans_screen.dart';
import 'package:wanderer_frontend/presentation/screens/achievements_screen.dart';
import 'package:wanderer_frontend/presentation/helpers/page_transitions.dart';

/// Helper class for handling navigation to auth-protected screens.
///
/// This ensures that when a guest user tries to access protected features,
/// they are redirected to the auth screen properly without leaving
/// broken screens in the navigation stack.
class AuthNavigationHelper {
  static final TokenStorage _tokenStorage = TokenStorage();

  /// Check if user is currently logged in
  static Future<bool> isLoggedIn() async {
    final token = await _tokenStorage.getAccessToken();
    return token != null && token.isNotEmpty;
  }

  /// Navigate to a user's profile screen.
  /// If not logged in, redirects to auth screen first.
  static Future<void> navigateToUserProfile(
    BuildContext context,
    String userId, {
    ProfileOrigin origin = ProfileOrigin.explore,
  }) async {
    final loggedIn = await isLoggedIn();

    if (!loggedIn) {
      // Redirect to auth screen
      if (context.mounted) {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AuthScreen()),
        );

        // After auth, if successful, navigate to profile
        if (result == true && context.mounted) {
          Navigator.push(
            context,
            PageTransitions.slideRight(
                ProfileScreen(userId: userId, origin: origin)),
          );
        }
      }
      return;
    }

    // User is logged in, navigate directly
    if (context.mounted) {
      Navigator.push(
        context,
        PageTransitions.slideRight(
            ProfileScreen(userId: userId, origin: origin)),
      );
    }
  }

  /// Navigate to own profile screen.
  /// If not logged in, redirects to auth screen first.
  static Future<void> navigateToOwnProfile(BuildContext context) async {
    final loggedIn = await isLoggedIn();

    if (!loggedIn) {
      if (context.mounted) {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AuthScreen()),
        );

        if (result == true && context.mounted) {
          Navigator.push(
            context,
            PageTransitions.slideRight(const ProfileScreen()),
          );
        }
      }
      return;
    }

    if (!context.mounted) return;
    // Android: your own profile is the You tab.
    if (!kIsWeb && AndroidShell.selectTab(context, AndroidTab.you)) return;
    Navigator.push(
      context,
      PageTransitions.slideRight(const ProfileScreen()),
    );
  }

  /// Navigate to friends/followers screen.
  /// If not logged in, redirects to auth screen first.
  static Future<void> navigateToFriendsFollowers(BuildContext context) async {
    final loggedIn = await isLoggedIn();

    if (!loggedIn) {
      if (context.mounted) {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AuthScreen()),
        );

        if (result == true && context.mounted) {
          Navigator.push(
            context,
            PageTransitions.slideUp(const FriendsFollowersScreen()),
          );
        }
      }
      return;
    }

    if (context.mounted) {
      Navigator.push(
        context,
        PageTransitions.slideUp(const FriendsFollowersScreen()),
      );
    }
  }

  /// Navigate to trip plans screen.
  /// If not logged in, redirects to auth screen first.
  static Future<void> navigateToTripPlans(BuildContext context) async {
    final loggedIn = await isLoggedIn();

    if (!loggedIn) {
      if (context.mounted) {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AuthScreen()),
        );

        if (result == true && context.mounted) {
          Navigator.push(
            context,
            PageTransitions.slideLeft(const TripPlansScreen()),
          );
        }
      }
      return;
    }

    if (context.mounted) {
      Navigator.push(
        context,
        PageTransitions.slideLeft(const TripPlansScreen()),
      );
    }
  }

  /// Navigate to achievements screen.
  /// If not logged in, redirects to auth screen first.
  static Future<void> navigateToAchievements(BuildContext context) async {
    final loggedIn = await isLoggedIn();

    if (!loggedIn) {
      if (context.mounted) {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AuthScreen()),
        );

        if (result == true && context.mounted) {
          Navigator.push(
            context,
            PageTransitions.slideUp(const AchievementsScreen()),
          );
        }
      }
      return;
    }

    if (context.mounted) {
      Navigator.push(
        context,
        PageTransitions.slideUp(const AchievementsScreen()),
      );
    }
  }
}
