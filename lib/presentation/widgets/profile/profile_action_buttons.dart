import 'package:flutter/material.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';

/// Top-right action buttons on the profile header: an edit button when
/// viewing your own profile, or follow/friend-request buttons when viewing
/// someone else's.
class ProfileActionButtons extends StatelessWidget {
  final bool isViewingOwnProfile;
  final bool isFollowingUser;
  final bool isAlreadyFriends;
  final bool hasSentFriendRequest;
  final VoidCallback onEdit;
  final VoidCallback onFollow;
  final VoidCallback onSendFriendRequest;

  const ProfileActionButtons({
    super.key,
    required this.isViewingOwnProfile,
    required this.isFollowingUser,
    required this.isAlreadyFriends,
    required this.hasSentFriendRequest,
    required this.onEdit,
    required this.onFollow,
    required this.onSendFriendRequest,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (isViewingOwnProfile) {
      return IconButton(
        icon: const Icon(Icons.edit),
        onPressed: onEdit,
        tooltip: l10n.editProfile,
        iconSize: 20,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
      );
    } else {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              isFollowingUser ? Icons.person_remove : Icons.person_add,
            ),
            onPressed: onFollow,
            tooltip: isFollowingUser ? l10n.unfollow : l10n.follow,
            color: isFollowingUser ? Colors.blue : null,
            iconSize: 20,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(
              isAlreadyFriends
                  ? Icons.people
                  : hasSentFriendRequest
                      ? Icons.person_add_disabled
                      : Icons.person_add_alt,
            ),
            onPressed: onSendFriendRequest,
            tooltip: isAlreadyFriends
                ? l10n.unfriend
                : hasSentFriendRequest
                    ? l10n.cancelFriendRequest
                    : l10n.sendFriendRequest,
            color: isAlreadyFriends
                ? Colors.green
                : hasSentFriendRequest
                    ? Colors.orange
                    : null,
            iconSize: 20,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      );
    }
  }
}
