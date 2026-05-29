import 'package:flutter/material.dart';

/// Helper for showing a prominent in-app disclosure before requesting
/// foreground location permission, as required by Google Play's
/// Prominent Disclosure and Consent policy.
///
/// This must be shown BEFORE the system permission dialog appears.
class LocationPermissionDisclosure {
  /// Shows a prominent disclosure dialog explaining why the app needs
  /// location access. Returns `true` if the user consents to proceed
  /// with the system permission request.
  static Future<bool> show(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.location_on, color: Theme.of(context).primaryColor),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Location Access',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Wanderer needs access to your device\'s location to '
                'provide trip tracking and mapping features.',
                style: TextStyle(fontSize: 14),
              ),
              SizedBox(height: 12),
              Text(
                'How your location is used:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              _DisclosureBullet(
                icon: Icons.map,
                text: 'Show your current position on the map so you can see '
                    'where you are relative to your trip route.',
              ),
              SizedBox(height: 6),
              _DisclosureBullet(
                icon: Icons.route,
                text: 'Record your GPS coordinates to build your trip timeline '
                    'and share your journey with friends and family.',
              ),
              SizedBox(height: 6),
              _DisclosureBullet(
                icon: Icons.center_focus_strong,
                text: 'Center the map on your location when planning or '
                    'viewing trips.',
              ),
              SizedBox(height: 16),
              Text(
                'Your location data is sent to Wanderer\'s servers only '
                'when you actively send a trip update. You can decline and '
                'still use the app with limited map functionality.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No thanks'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

/// A bullet point row used in the disclosure dialog.
class _DisclosureBullet extends StatelessWidget {
  final IconData icon;
  final String text;

  const _DisclosureBullet({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Theme.of(context).primaryColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 13)),
        ),
      ],
    );
  }
}
