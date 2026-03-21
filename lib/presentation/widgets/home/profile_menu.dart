import 'package:flutter/material.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';

/// Profile menu button for authenticated users
class ProfileMenu extends StatelessWidget {
  final String username;
  final String? userId;
  final VoidCallback onLogout;
  final VoidCallback onProfile;

  const ProfileMenu({
    super.key,
    required this.username,
    this.userId,
    required this.onLogout,
    required this.onProfile,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PopupMenuButton<String>(
      icon: const Icon(Icons.account_circle),
      tooltip: l10n.profile,
      onSelected: (value) {
        if (value == 'logout') {
          onLogout();
        } else if (value == 'profile') {
          onProfile();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: Text(
                        username.isNotEmpty ? username[0].toUpperCase() : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            username,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          if (userId != null)
                            Text(
                              'ID: ${userId?.substring(0, 8)}...',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(),
              ],
            ),
          ),
        ),
        PopupMenuItem<String>(
          value: 'profile',
          child: Row(
            children: [
              const Icon(Icons.person),
              const SizedBox(width: 12),
              Text(l10n.userProfile),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'logout',
          child: Row(
            children: [
              const Icon(Icons.logout, color: Colors.red),
              const SizedBox(width: 12),
              Text(l10n.logout, style: const TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
    );
  }
}
