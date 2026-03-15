import 'package:flutter/material.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';

/// Empty state widget when no trips are available
class EmptyTripsView extends StatelessWidget {
  final bool isLoggedIn;
  final VoidCallback? onLoginPressed;

  const EmptyTripsView({
    super.key,
    required this.isLoggedIn,
    this.onLoginPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated-looking container with icon
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    WandererTheme.primaryOrange.withOpacity(0.08),
                    WandererTheme.primaryOrangeLight.withOpacity(0.12),
                  ],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: WandererTheme.primaryOrange.withOpacity(0.15),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Icon(
                  isLoggedIn ? Icons.explore_off : Icons.public_off,
                  size: 64,
                  color: WandererTheme.primaryOrange.withOpacity(0.7),
                ),
              ),
            ),
            const SizedBox(height: 32),
            // Title
            Text(
              isLoggedIn ? 'No trips yet' : 'No public trips available',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            // Subtitle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                isLoggedIn
                    ? 'Create your first trip to start tracking your adventures!'
                    : 'Check back later or log in to create your own trips',
                style: TextStyle(
                  fontSize: 15,
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            if (!isLoggedIn && onLoginPressed != null) ...[
              const SizedBox(height: 32),
              // Login button with enhanced styling
              ElevatedButton.icon(
                onPressed: onLoginPressed,
                icon: const Icon(Icons.login),
                label: const Text('Login / Register'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: WandererTheme.primaryOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            if (isLoggedIn) ...[
              const SizedBox(height: 24),
              // Hint for logged-in users
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: WandererTheme.primaryOrange.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: WandererTheme.primaryOrange.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      size: 20,
                      color: WandererTheme.primaryOrange,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Tap the + button to create a trip',
                      style: TextStyle(
                        fontSize: 14,
                        color: WandererTheme.primaryOrange,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
