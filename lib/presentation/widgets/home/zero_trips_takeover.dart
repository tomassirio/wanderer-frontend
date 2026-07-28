import 'package:flutter/material.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';

/// Full-screen CTA replacing the tabbed feed for a logged-in user with no
/// trips of their own yet — the feed/discover tabs have nothing relevant to
/// show them, so it's a single focused prompt to create their first trip.
class ZeroTripsTakeover extends StatelessWidget {
  final AppLocalizations l10n;
  final VoidCallback onCreateTrip;

  const ZeroTripsTakeover({
    super.key,
    required this.l10n,
    required this.onCreateTrip,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.explore_outlined,
              size: 96,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.trackFirstAdventure,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.createYourFirstTrip,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onCreateTrip,
              icon: const Icon(Icons.add),
              label: Text(l10n.createTrip),
            ),
          ],
        ),
      ),
    );
  }
}
