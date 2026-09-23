import 'package:flutter/material.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/presentation/widgets/common/user_avatar.dart';

/// Web Friends page building blocks (see the "Friends" design board).

/// Small count badge; [strong] = orange (pending things to act on).
class FriendsCountBadge extends StatelessWidget {
  final int count;
  final bool strong;

  const FriendsCountBadge(this.count, {super.key, this.strong = false});

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      decoration: BoxDecoration(
        color: strong ? WandererTheme.trail : c.neutralBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: strong ? Colors.white : c.neutralFg,
        ),
      ),
    );
  }
}

/// Underline tabs: "Friends · n", "Requests · n", …
class FriendsUnderlineTabs extends StatelessWidget {
  final List<(String label, int count, bool strong)> tabs;
  final int selected;
  final ValueChanged<int> onSelected;

  const FriendsUnderlineTabs({
    super.key,
    required this.tabs,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.lineSoft)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < tabs.length; i++) ...[
              if (i > 0) const SizedBox(width: 28),
              Semantics(
                selected: i == selected,
                button: true,
                child: InkWell(
                  onTap: () => onSelected(i),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(2, 16, 2, 14),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          width: 2,
                          color: i == selected
                              ? WandererTheme.trail
                              : Colors.transparent,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          tabs[i].$1,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: i == selected
                                ? FontWeight.w700
                                : FontWeight.w600,
                            color: i == selected ? c.text : c.textMuted,
                          ),
                        ),
                        const SizedBox(width: 8),
                        FriendsCountBadge(tabs[i].$2, strong: tabs[i].$3),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One person row: 44px avatar, name, pills, actions.
class FriendRow extends StatelessWidget {
  final String username;
  final String? displayName;
  final String? avatarUrl;
  final List<Widget> pills;
  final List<Widget> actions;
  final VoidCallback onTap;

  const FriendRow({
    super.key,
    required this.username,
    this.displayName,
    this.avatarUrl,
    this.pills = const [],
    this.actions = const [],
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    final info = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(WandererTheme.radiusControl),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          UserAvatar(
            avatarUrl: avatarUrl,
            username: username,
            displayName: displayName,
            radius: 22,
            backgroundColor: c.trailSoftBg,
            textColor: c.accentText,
          ),
          const SizedBox(width: 14),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(username,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: c.text)),
                if (displayName != null && displayName!.isNotEmpty)
                  Text(displayName!,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: c.textMuted)),
                if (pills.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Wrap(spacing: 6, runSpacing: 4, children: pills),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.lineSoft)),
      ),
      child: Wrap(
        spacing: 14,
        runSpacing: 10,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 200),
            child: info,
          ),
          Wrap(spacing: 8, runSpacing: 8, children: actions),
        ],
      ),
    );
  }
}

/// Small row button style (40px, radius 10) matching the board.
ButtonStyle friendsRowButtonStyle(BuildContext context, {Color? foreground}) {
  final c = WandererTheme.of(context);
  return OutlinedButton.styleFrom(
    minimumSize: const Size(0, 40),
    padding: const EdgeInsets.symmetric(horizontal: 14),
    foregroundColor: foreground ?? c.text,
    side: BorderSide(color: c.line),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
  );
}

/// Neutral dark "Accept" button.
class FriendsAcceptButton extends StatelessWidget {
  final VoidCallback onPressed;
  final double height;

  const FriendsAcceptButton(
      {super.key, required this.onPressed, this.height = 40});

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: c.neutralButtonBg,
        foregroundColor: c.neutralButtonFg,
        minimumSize: Size(0, height),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
      child: Text(context.l10n.acceptRequest),
    );
  }
}

/// Outlined "x" decline button.
class FriendsDeclineButton extends StatelessWidget {
  final VoidCallback onPressed;
  final double size;

  const FriendsDeclineButton(
      {super.key, required this.onPressed, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    return IconButton.outlined(
      tooltip: context.l10n.declineRequest,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        fixedSize: Size(size, size),
        minimumSize: Size(size, size),
        side: BorderSide(color: c.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      icon: Icon(Icons.close, size: 16, color: c.textMuted),
    );
  }
}

/// Green-circle empty state.
class FriendsEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const FriendsEmptyState({
    super.key,
    this.icon = Icons.group_outlined,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 40, 0, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration:
                    BoxDecoration(color: c.forestBg, shape: BoxShape.circle),
                child: Icon(icon, color: c.forestFg),
              ),
              const SizedBox(height: 8),
              Text(title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: c.text)),
              const SizedBox(height: 8),
              Text(body,
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(fontSize: 14, height: 1.5, color: c.textMuted)),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Add friends" card: search field (opens search) + copy invite link.
class AddFriendsCard extends StatelessWidget {
  final VoidCallback onSearch;
  final VoidCallback? onCopyInviteLink;

  const AddFriendsCard(
      {super.key, required this.onSearch, this.onCopyInviteLink});

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: WandererTheme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.friendsAddFriendsTitle,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700, color: c.text)),
          const SizedBox(height: 14),
          // ponytail: tapping opens the existing SearchScreen (users + trips);
          // inline results would need SearchService wiring here.
          TextField(
            readOnly: true,
            onTap: onSearch,
            decoration: InputDecoration(
              hintText: l10n.friendsSearchByUsername,
              prefixIcon: Icon(Icons.search, size: 18, color: c.label),
              filled: true,
              fillColor: c.raised,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(WandererTheme.radiusControl),
                borderSide: BorderSide(color: c.line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(WandererTheme.radiusControl),
                borderSide: BorderSide(color: c.line),
              ),
            ),
          ),
          if (onCopyInviteLink != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: Divider(color: c.lineSoft, height: 1)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(l10n.friendsOr,
                      style: TextStyle(fontSize: 12, color: c.label)),
                ),
                Expanded(child: Divider(color: c.lineSoft, height: 1)),
              ],
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: onCopyInviteLink,
              icon: const Icon(Icons.link, size: 18),
              label: Text(l10n.friendsCopyInviteLink),
            ),
          ],
        ],
      ),
    );
  }
}

/// A received request in the "Waiting for you" card.
typedef WaitingRequest = ({
  String id,
  String username,
  String? displayName,
  String? avatarUrl,
  VoidCallback onOpen,
});

/// "Waiting for you" card listing received friend requests.
class WaitingForYouCard extends StatelessWidget {
  final List<WaitingRequest> requests;
  final ValueChanged<String> onAccept;
  final ValueChanged<String> onDecline;

  const WaitingForYouCard({
    super.key,
    required this.requests,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: WandererTheme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(l10n.friendsWaitingForYou,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: c.text)),
              ),
              FriendsCountBadge(requests.length, strong: requests.isNotEmpty),
            ],
          ),
          const SizedBox(height: 6),
          if (requests.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(l10n.noFriendRequests,
                  style: TextStyle(fontSize: 14, color: c.textMuted)),
            ),
          for (final r in requests)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: r.onOpen,
                      child: Row(
                        children: [
                          UserAvatar(
                            avatarUrl: r.avatarUrl,
                            username: r.username,
                            displayName: r.displayName,
                            radius: 18,
                            backgroundColor: c.skyBg,
                            textColor: c.skyFg,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(r.username,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: c.text)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  FriendsAcceptButton(
                      onPressed: () => onAccept(r.id), height: 34),
                  const SizedBox(width: 6),
                  FriendsDeclineButton(
                      onPressed: () => onDecline(r.id), size: 34),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
