import 'package:flutter/material.dart' hide Visibility;
import 'package:intl/intl.dart';
import 'package:wanderer_frontend/core/constants/enums.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/presentation/helpers/auth_navigation_helper.dart';
import 'package:wanderer_frontend/presentation/strategies/desktop_layout_strategy.dart';
import 'package:wanderer_frontend/presentation/strategies/trip_detail_layout_strategy.dart';
import 'package:wanderer_frontend/presentation/widgets/common/pill.dart';
import 'package:wanderer_frontend/presentation/widgets/common/user_avatar.dart';
import 'package:wanderer_frontend/presentation/widgets/trip_detail/trip_share_dialog.dart';
import 'package:wanderer_frontend/presentation/widgets/trip_detail/trip_timeline.dart';

/// Wide-web trip detail: the map is a rounded card rather than a full-screen
/// background, with stats and achievements in their own rows and the
/// timeline and comments in a tabbed side panel.
class WebTripDetailLayout extends StatefulWidget {
  final TripDetailLayoutData data;
  final Widget map;
  final bool isMapLoading;
  final Widget? donationButton;

  const WebTripDetailLayout({
    super.key,
    required this.data,
    required this.map,
    this.isMapLoading = false,
    this.donationButton,
  });

  /// Below this width the floating-panel layout is used instead.
  static const double minWidth = 960;

  @override
  State<WebTripDetailLayout> createState() => _WebTripDetailLayoutState();
}

class _WebTripDetailLayoutState extends State<WebTripDetailLayout> {
  int _tab = 0; // 0 timeline, 1 comments
  final _strategy = DesktopLayoutStrategy();

  TripDetailLayoutData get _d => widget.data;
  Trip get _trip => _d.trip;
  bool get _isOwner =>
      _d.currentUserId != null && _trip.userId == _d.currentUserId;

  bool get _hasSettings =>
      _trip.hasPlannedRoute ||
      (_isOwner &&
          (_trip.status == TripStatus.created ||
              _trip.status == TripStatus.inProgress));

  void _openSettings() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: SizedBox(
          width: 340,
          child: _strategy.createTripSettingsPanel(
            _d,
            onClose: () => Navigator.of(dialogContext).pop(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final content = Padding(
        padding: const EdgeInsets.fromLTRB(32, 8, 32, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context),
            const SizedBox(height: 20),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: _buildMapCard(context)),
                        const SizedBox(height: 16),
                        _buildStats(context),
                        if (_d.tripAchievements.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _buildAchievements(context),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  SizedBox(width: 380, child: _buildSidePanel(context)),
                ],
              ),
            ),
          ],
        ),
      );
      // Short windows scroll instead of squashing the map.
      if (constraints.maxHeight >= 700) return content;
      return SingleChildScrollView(
        child: SizedBox(height: 820, child: content),
      );
    });
  }

  Widget _buildHeader(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final dateFormat = DateFormat.yMd(locale);
    final date = _trip.status == TripStatus.finished && _trip.endDate != null
        ? l10n.finishedOn(dateFormat.format(_trip.endDate!))
        : _trip.startDate != null
            ? l10n.startedOn(dateFormat.format(_trip.startDate!))
            : null;
    final meta = TextStyle(fontSize: 14, color: c.textMuted);

    final actions = <Widget>[
      if (!_isOwner && _d.onFollowTripOwner != null)
        OutlinedButton.icon(
          onPressed: _d.onFollowTripOwner,
          icon: Icon(
              _d.isFollowingTripOwner
                  ? Icons.person_remove_outlined
                  : Icons.person_add_outlined,
              size: 16),
          label: Text(_d.isFollowingTripOwner ? l10n.unfollow : l10n.follow),
        ),
      if (!_isOwner && _d.onSendFriendRequestToTripOwner != null)
        OutlinedButton.icon(
          onPressed: _d.onSendFriendRequestToTripOwner,
          icon: Icon(_d.isAlreadyFriends ? Icons.people : Icons.person_add_alt,
              size: 16),
          label: Text(_d.isAlreadyFriends
              ? l10n.unfriend
              : _d.hasSentFriendRequest
                  ? l10n.requestSent
                  : l10n.addFriend),
        ),
      if (_hasSettings)
        OutlinedButton.icon(
          key: _d.settingsPanelKey,
          onPressed: _openSettings,
          icon: const Icon(Icons.tune, size: 16),
          label: Text(l10n.tripSettings),
        ),
      ElevatedButton.icon(
        key: _d.shareButtonKey,
        onPressed: () => TripShareDialog.show(context,
            tripId: _trip.id, tripName: _trip.name),
        icon: const Icon(Icons.share_outlined, size: 16),
        label: Text(l10n.shareTrip),
      ),
    ];

    return Wrap(
      spacing: 24,
      runSpacing: 12,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.end,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Semantics(
                    header: true,
                    child: Text(_trip.name, style: WandererTheme.display(32)),
                  ),
                  Pill.status(context, _trip.status),
                  if (_d.isPromoted)
                    Pill(l10n.promoted, tone: PillTone.promoted),
                  if (_trip.tripModality == TripModality.multiDay &&
                      _trip.currentDay != null)
                    Pill(l10n.dayNumber(_trip.currentDay!)),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () => AuthNavigationHelper.navigateToUserProfile(
                        context, _trip.userId),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      UserAvatar(
                        userId: _trip.userId,
                        avatarUrl: _trip.avatarUrl?.isNotEmpty == true
                            ? _trip.avatarUrl
                            : null,
                        username: _trip.username,
                        radius: 12,
                        backgroundColor: c.forestBg,
                        textColor: c.forestFg,
                      ),
                      const SizedBox(width: 8),
                      Text('@${_trip.username}',
                          style: meta.copyWith(
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).colorScheme.onSurface)),
                    ]),
                  ),
                  if (date != null) ...[
                    Text('·', style: meta),
                    Text(date, style: meta),
                  ],
                  Text('·', style: meta),
                  _buildVisibility(context, meta),
                ],
              ),
              if (_trip.description?.isNotEmpty ?? false) ...[
                const SizedBox(height: 8),
                Text(_trip.description!,
                    style: meta.copyWith(height: 1.5),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis),
              ],
            ],
          ),
        ),
        Wrap(spacing: 10, runSpacing: 10, children: actions),
      ],
    );
  }

  Widget _buildVisibility(BuildContext context, TextStyle style) {
    final l10n = context.l10n;
    (IconData, String) describe(Visibility v) => switch (v) {
          Visibility.public => (Icons.public, l10n.publicVisibility),
          Visibility.protected => (
              Icons.group_outlined,
              l10n.protectedVisibility
            ),
          Visibility.private => (Icons.lock_outline, l10n.privateVisibility),
        };
    final (icon, label) = describe(_trip.visibility);
    final row = Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: style.color),
      const SizedBox(width: 4),
      Text(label, style: style),
      if (_d.onVisibilityChange != null) ...[
        const SizedBox(width: 2),
        Icon(Icons.expand_more, size: 16, color: style.color),
      ],
    ]);
    if (_d.onVisibilityChange == null) return row;

    return PopupMenuButton<Visibility>(
      tooltip: l10n.changeVisibility,
      initialValue: _trip.visibility,
      onSelected: (v) {
        if (v != _trip.visibility) _d.onVisibilityChange!(v);
      },
      itemBuilder: (_) => [
        for (final v in Visibility.values)
          PopupMenuItem(
            value: v,
            child: Row(children: [
              Icon(describe(v).$1, size: 18),
              const SizedBox(width: 10),
              Text(describe(v).$2),
            ]),
          ),
      ],
      child: row,
    );
  }

  Widget _buildMapCard(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    final latest = _d.tripUpdates.isEmpty
        ? null
        : _d.tripUpdates
            .reduce((a, b) => a.timestamp.isAfter(b.timestamp) ? a : b);
    final place = [latest?.city, latest?.country]
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .join(', ');

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: WandererTheme.cardDecoration(context).copyWith(
        color: c.mapGround,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.map,
          if (place.isNotEmpty)
            Positioned(
              top: 16,
              left: 16,
              child: _FloatingCard(
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                        color: WandererTheme.trail, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _trip.status == TripStatus.finished
                            ? l10n.mapFinish
                            : l10n.mapLatestUpdate,
                        style: TextStyle(fontSize: 12, color: c.caption),
                      ),
                      Text(place,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: c.text)),
                    ],
                  ),
                ]),
              ),
            ),
          if (widget.donationButton != null)
            Positioned(left: 16, bottom: 16, child: widget.donationButton!),
          if (widget.isMapLoading)
            ColoredBox(
              color: c.ground.withOpacity(0.2),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildStats(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final km =
        NumberFormat.decimalPatternDigits(locale: locale, decimalDigits: 1)
            .format(_trip.accruedDistanceKm ?? 0);
    final start = _trip.startDate;
    final days = start == null
        ? null
        : (_trip.endDate ?? DateTime.now()).difference(start).inDays + 1;
    final updates = _trip.updateCount ?? _d.tripUpdates.length;
    final stats = [
      (l10n.categoryDistance, l10n.kmValue(km)),
      (l10n.categoryDuration, days == null ? '—' : l10n.daysCount(days)),
      (l10n.categoryUpdates, '$updates${_d.hasMoreUpdates ? '+' : ''}'),
      (l10n.comments, '${_trip.commentsCount}'),
    ];
    return Row(
      children: [
        for (var i = 0; i < stats.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: WandererTheme.cardDecoration(context,
                  radius: WandererTheme.radiusCard),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(stats[i].$1,
                      style: TextStyle(fontSize: 12, color: c.caption)),
                  const SizedBox(height: 2),
                  Text(stats[i].$2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: WandererTheme.display(22)),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAchievements(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: WandererTheme.cardDecoration(context,
          radius: WandererTheme.radiusCard),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              l10n.achievementsCountLabel(_d.tripAchievements.length),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final ua in _d.tripAchievements)
                  Pill(
                    l10n.achievementNameFor(ua.achievement.type.toJson()),
                    tone: PillTone.gold,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidePanel(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    final tabs = [
      l10n.timeline,
      l10n.commentsTab(_trip.commentsCount),
    ];
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: WandererTheme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(WandererTheme.radiusControl),
            ),
            child: Row(
              children: [
                for (var i = 0; i < tabs.length; i++)
                  Expanded(
                    child: Semantics(
                      selected: _tab == i,
                      button: true,
                      child: Material(
                        color: _tab == i
                            ? Theme.of(context).colorScheme.surface
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                        elevation: _tab == i ? 0.5 : 0,
                        child: InkWell(
                          key: i == 0
                              ? _d.timelinePanelKey
                              : _d.commentsSectionKey,
                          borderRadius: BorderRadius.circular(9),
                          onTap: () => setState(() => _tab = i),
                          child: SizedBox(
                            height: 38,
                            child: Center(
                              child: Text(
                                tabs[i],
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: _tab == i
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                  color: _tab == i
                                      ? Theme.of(context).colorScheme.onSurface
                                      : c.textMuted,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: IndexedStack(
              index: _tab,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: TripTimeline(
                    updates: _d.tripUpdates,
                    isLoading: _d.isLoadingUpdates,
                    isLoadingMore: _d.isLoadingMoreUpdates,
                    hasMore: _d.hasMoreUpdates,
                    onRefresh: _d.onRefreshTimeline,
                    onLoadMore: _d.onLoadMoreUpdates,
                    onUpdateTap: _d.onTimelineUpdateTap,
                  ),
                ),
                _strategy.createCommentsSection(_d, embedded: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// White floating control over the map.
class _FloatingCard extends StatelessWidget {
  final Widget child;
  const _FloatingCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: WandererTheme.of(context).surface,
        borderRadius: BorderRadius.circular(WandererTheme.radiusCard),
        boxShadow: const [
          BoxShadow(
              color: Color(0x141B1A17), blurRadius: 16, offset: Offset(0, 4)),
        ],
      ),
      child: child,
    );
  }
}
