import 'package:flutter/material.dart' hide Visibility;
import 'package:intl/intl.dart';
import 'package:wanderer_frontend/core/constants/enums.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/presentation/helpers/auth_navigation_helper.dart';
import 'package:wanderer_frontend/presentation/helpers/weather_helpers.dart';
import 'package:wanderer_frontend/presentation/strategies/mobile_layout_strategy.dart';
import 'package:wanderer_frontend/presentation/strategies/trip_detail_layout_strategy.dart';
import 'package:wanderer_frontend/presentation/widgets/android/trip_checkin_sheet.dart';
import 'package:wanderer_frontend/presentation/widgets/common/pill.dart';
import 'package:wanderer_frontend/presentation/widgets/common/user_avatar.dart';
import 'package:wanderer_frontend/presentation/widgets/common/wanderer_sheet.dart';
import 'package:wanderer_frontend/presentation/widgets/trip_detail/comment_card.dart';
import 'package:wanderer_frontend/presentation/widgets/trip_detail/comment_input.dart';
import 'package:wanderer_frontend/presentation/widgets/trip_detail/trip_settings_panel.dart';
import 'package:wanderer_frontend/presentation/widgets/trip_detail/trip_share_dialog.dart';

/// Android trip detail (canvas AndroidLive / AndroidTripView): full-screen
/// map with floating round controls, everything else in a draggable sheet.
/// Guests get a log-in call to action instead of the trip controls.
class TripDetailAndroidLayout extends StatefulWidget {
  final TripDetailLayoutData data;
  final Widget map;
  final bool isMapLoading;

  /// State buttons (owner only), built by the screen.
  final Widget? controls;
  final VoidCallback? onCenterOnMe;
  final VoidCallback onLogin;
  final ValueChanged<TripLocation> onCheckInTap;
  final Widget? donationButton;

  /// Map bottom padding: roughly the half sheet (canvas: 356).
  static const double mapBottomPadding = 360;

  const TripDetailAndroidLayout({
    super.key,
    required this.data,
    required this.map,
    required this.onLogin,
    required this.onCheckInTap,
    this.isMapLoading = false,
    this.controls,
    this.onCenterOnMe,
    this.donationButton,
  });

  @override
  State<TripDetailAndroidLayout> createState() =>
      _TripDetailAndroidLayoutState();
}

enum _Detent { collapsed, half, full }

class _TripDetailAndroidLayoutState extends State<TripDetailAndroidLayout>
    with SingleTickerProviderStateMixin {
  static const double _collapsed = 52;

  int _tab = 0; // 0 timeline, 1 comments
  _Detent _detent = _Detent.half;

  /// Sheet height in px (animated between the three detents).
  late final _sheet = AnimationController.unbounded(
      vsync: this, value: TripDetailAndroidLayout.mapBottomPadding);

  /// Height of the fixed top (handle → tabs) in the half layout; the half
  /// detent is exactly that, so no list item peeks in.
  double _halfTop = TripDetailAndroidLayout.mapBottomPadding;
  double _maxHeight = 0;
  bool _dragging = false;
  final _expandedGroups = <String>{};

  TripDetailLayoutData get _d => widget.data;
  Trip get _trip => _d.trip;
  bool get _isOwner =>
      _d.currentUserId != null && _trip.userId == _d.currentUserId;
  bool get _hasSettings =>
      _trip.hasPlannedRoute ||
      (_isOwner &&
          (_trip.status == TripStatus.created ||
              _trip.status == TripStatus.inProgress));

  @override
  void dispose() {
    _sheet.dispose();
    super.dispose();
  }

  double get _bottomInset => MediaQuery.paddingOf(context).bottom;

  double _heightOf(_Detent d) => switch (d) {
        _Detent.collapsed => _collapsed + _bottomInset,
        _Detent.half => _halfTop + _bottomInset,
        _Detent.full => _maxHeight,
      };

  void _snapTo(_Detent d) {
    if (_detent != d) setState(() => _detent = d);
    _sheet.animateTo(_heightOf(d),
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic);
  }

  /// Handle tap: collapsed → half → full → collapsed (canvas `cycle`).
  void _cycle() => _snapTo(switch (_detent) {
        _Detent.collapsed => _Detent.half,
        _Detent.half => _Detent.full,
        _Detent.full => _Detent.collapsed,
      });

  void _dragBy(double dy) {
    _dragging = true;
    _sheet.value = (_sheet.value - dy)
        .clamp(_heightOf(_Detent.collapsed), _heightOf(_Detent.full));
  }

  /// Release: a fling goes to the next detent that way, otherwise nearest.
  void _settle(double velocity) {
    _dragging = false;
    final h = _sheet.value;
    final stops = _Detent.values;
    _Detent target = stops.reduce(
        (a, b) => (_heightOf(a) - h).abs() <= (_heightOf(b) - h).abs() ? a : b);
    if (velocity < -700) {
      target = stops.firstWhere((d) => _heightOf(d) > h + 1,
          orElse: () => _Detent.full);
    } else if (velocity > 700) {
      target = stops.lastWhere((d) => _heightOf(d) < h - 1,
          orElse: () => _Detent.collapsed);
    }
    _snapTo(target);
  }

  void _onTopMeasured(double top) {
    if (_detent == _Detent.full || top == _halfTop) return;
    _halfTop = top;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _dragging || _sheet.isAnimating) return;
      if (_detent == _Detent.half) _sheet.value = _heightOf(_Detent.half);
    });
  }

  void _openTab(int i) {
    setState(() => _tab = i);
    if (_detent != _Detent.full) _snapTo(_Detent.full);
  }

  void _openSettings() {
    showWandererSheet<void>(
      context,
      title: context.l10n.tripSettings,
      builder: (ctx) {
        final p = MobileLayoutStrategy().createTripSettingsPanel(_d,
            onClose: () => Navigator.of(ctx).pop());
        return TripSettingsPanel(
          isCollapsed: false,
          onToggleCollapse: () => Navigator.of(ctx).pop(),
          isOwner: p.isOwner,
          tripHasPlannedRoute: p.tripHasPlannedRoute,
          showPlannedWaypoints: p.showPlannedWaypoints,
          onTogglePlannedWaypoints: p.onTogglePlannedWaypoints,
          automaticUpdates: p.automaticUpdates,
          updateRefresh: p.updateRefresh,
          tripModality: p.tripModality,
          isLoading: p.isLoading,
          onSettingsChange: p.onSettingsChange,
          tripStatus: p.tripStatus,
          tripId: p.tripId,
          onTestBackgroundUpdate: p.onTestBackgroundUpdate,
          onDeleteTrip: p.onDeleteTrip,
          embedded: true,
        );
      },
    );
  }

  void _pickVisibility() {
    final l10n = context.l10n;
    showWandererSheet<void>(
      context,
      title: l10n.changeVisibility,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final v in Visibility.values)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(_visibility(l10n, v).$1),
              title: Text(_visibility(l10n, v).$2),
              trailing: v == _trip.visibility ? const Icon(Icons.check) : null,
              onTap: () {
                Navigator.of(ctx).pop();
                if (v != _trip.visibility) _d.onVisibilityChange?.call(v);
              },
            ),
        ],
      ),
    );
  }

  (IconData, String) _visibility(AppLocalizations l10n, Visibility v) =>
      switch (v) {
        Visibility.public => (Icons.public, l10n.publicVisibility),
        Visibility.protected => (Icons.group_outlined, l10n.friends),
        Visibility.private => (Icons.lock_outline, l10n.privateVisibility),
      };

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    final top = MediaQuery.paddingOf(context).top + 8;

    return PopScope(
      canPop: _detent != _Detent.full,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _snapTo(_Detent.half);
      },
      child: ColoredBox(
        color: c.mapGround,
        child: LayoutBuilder(builder: (context, constraints) {
          _maxHeight = constraints.maxHeight;
          return Stack(
            children: [
              Positioned.fill(child: widget.map),
              if (widget.isMapLoading)
                Positioned.fill(
                  child: ColoredBox(
                    color: c.ground.withOpacity(0.35),
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                ),
              Positioned(
                top: top,
                left: 16,
                right: 16,
                child: Row(children: [
                  _RoundButton(
                    icon: Icons.arrow_back,
                    label: MaterialLocalizations.of(context).backButtonTooltip,
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                  const Spacer(),
                  _RoundButton(
                    key: _d.shareButtonKey,
                    icon: Icons.share_outlined,
                    label: l10n.shareTrip,
                    onTap: () => TripShareDialog.show(context,
                        tripId: _trip.id, tripName: _trip.name),
                  ),
                  if (_hasSettings) ...[
                    const SizedBox(width: 10),
                    _RoundButton(
                      key: _d.settingsPanelKey,
                      icon: Icons.tune,
                      label: l10n.tripSettings,
                      onTap: _openSettings,
                    ),
                  ],
                ]),
              ),
              // Rides on top of the sheet (canvas: sheet + 20); the full
              // sheet covers the map, so it goes away there.
              if (widget.onCenterOnMe != null)
                AnimatedBuilder(
                  animation: _sheet,
                  builder: (context, child) => Positioned(
                    right: 16,
                    bottom: _sheet.value + 20,
                    child: _sheet.value > _heightOf(_Detent.half) + 1
                        ? const SizedBox.shrink()
                        : child!,
                  ),
                  child: _RoundButton(
                    icon: Icons.my_location,
                    label: l10n.tripCenterOnMe,
                    onTap: widget.onCenterOnMe!,
                    square: true,
                    color: c.skyFg,
                  ),
                ),
              _buildSheet(context),
            ],
          );
        }),
      ),
    );
  }

  /// Three detents; the header (handle → tabs) is fixed and drags the
  /// sheet, only the list scrolls. Full covers the status bar area with
  /// square corners, its content starting below the status bar.
  Widget _buildSheet(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    final statusBar = MediaQuery.paddingOf(context).top;
    final updatesCount = _trip.updateCount ?? _d.tripUpdates.length;
    final tabs = [
      l10n.tripTimelineTab('$updatesCount${_d.hasMoreUpdates ? '+' : ''}'),
      l10n.commentsTab(_trip.commentsCount),
    ];
    final isFull = _detent == _Detent.full;

    final handle = Semantics(
      button: true,
      label: switch (_detent) {
        _Detent.collapsed => l10n.tripSheetShowDetails,
        _Detent.half => l10n.tripSheetExpand,
        _Detent.full => l10n.tripSheetCollapse,
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _cycle,
        child: SizedBox(
          height: 28,
          child: Center(
            child: Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                  color: c.line, borderRadius: BorderRadius.circular(999)),
            ),
          ),
        ),
      ),
    );

    final header = Padding(
      padding: EdgeInsets.fromLTRB(20, isFull ? 4 : 0, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isFull)
            Row(children: [
              SizedBox(
                height: 40,
                child: OutlinedButton.icon(
                  key: const Key('trip_sheet_show_map'),
                  onPressed: () => _snapTo(_Detent.half),
                  icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                  label: Text(l10n.tripShowMap),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: c.text,
                    side: BorderSide(color: c.line),
                    padding: const EdgeInsets.fromLTRB(6, 0, 12, 0),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    textStyle: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Align(
                    alignment: Alignment.centerRight,
                    child: _buildPills(context)),
              ),
            ])
          else
            _buildPills(context),
          const SizedBox(height: 12),
          Semantics(
            header: true,
            child: Text(_trip.name,
                style: WandererTheme.display(23, color: c.text)),
          ),
          ..._buildMeta(context),
          const SizedBox(height: 12),
          _buildStats(context),
          if (widget.controls != null) ...[
            const SizedBox(height: 12),
            KeyedSubtree(key: _d.updatePanelKey, child: widget.controls!),
          ],
          // Guests: the log-in call to action sits where the controls go.
          if (!_d.isLoggedIn) ...[
            const SizedBox(height: 12),
            _buildGuestCta(context),
          ],
          if (_isOwner &&
              _trip.status == TripStatus.inProgress &&
              _trip.automaticUpdates) ...[
            const SizedBox(height: 12),
            _buildAutoStrip(context),
          ],
          if (widget.donationButton != null) ...[
            const SizedBox(height: 12),
            Align(
                alignment: Alignment.centerLeft, child: widget.donationButton!),
          ],
        ],
      ),
    );

    final tabBar = Container(
      margin: const EdgeInsets.only(top: 12),
      decoration:
          BoxDecoration(border: Border(bottom: BorderSide(color: c.lineSoft))),
      child: Row(children: [
        for (var i = 0; i < tabs.length; i++)
          Expanded(
            child: Semantics(
              selected: _tab == i,
              button: true,
              child: InkWell(
                key: i == 0 ? _d.timelinePanelKey : _d.commentsSectionKey,
                onTap: () => _openTab(i),
                child: Container(
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: isFull && _tab == i
                            ? WandererTheme.trail
                            : Colors.transparent,
                        width: 3,
                      ),
                    ),
                  ),
                  child: Text(tabs[i],
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: isFull && _tab == i
                              ? FontWeight.w700
                              : FontWeight.w600,
                          color: isFull && _tab == i
                              ? c.accentText
                              : c.textMuted)),
                ),
              ),
            ),
          ),
      ]),
    );

    // Dragging the fixed top moves the sheet; buttons inside still tap.
    final top = GestureDetector(
      onVerticalDragUpdate: (d) => _dragBy(d.delta.dy),
      onVerticalDragEnd: (d) => _settle(d.primaryVelocity ?? 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          handle,
          // Collapsed shows only the handle: the header fades in as the
          // sheet leaves the collapsed height (layout kept for measuring).
          _fadeAbove(_Detent.collapsed,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [header, tabBar],
              )),
        ],
      ),
    );

    // Pulling the list down past its top drags the sheet (Android style).
    final list = NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n is OverscrollNotification &&
            n.dragDetails != null &&
            (n.overscroll < 0 || _sheet.value < _heightOf(_Detent.full))) {
          _dragBy(-n.overscroll);
        } else if (n is ScrollEndNotification && _dragging) {
          _settle(n.dragDetails?.primaryVelocity ?? 0);
        }
        return false;
      },
      child: ListView(
        physics: const ClampingScrollPhysics(),
        padding: EdgeInsets.only(bottom: _bottomInset + 24),
        children: [
          ...(_tab == 0 ? _timelineItems(context) : _commentItems(context)),
        ],
      ),
    );

    final content = CustomMultiChildLayout(
      delegate: _SheetLayout(_onTopMeasured),
      children: [
        LayoutId(id: _SheetLayout.top, child: top),
        // Half shows no list items: the bottom inset below the tabs would
        // otherwise reveal the first row.
        LayoutId(
            id: _SheetLayout.list,
            child: _fadeAbove(_Detent.half, child: list)),
      ],
    );

    return AnimatedBuilder(
      animation: _sheet,
      builder: (context, child) {
        // Full tracks the screen (e.g. keyboard resizes it).
        final h = _detent == _Detent.full && !_dragging && !_sheet.isAnimating
            ? _maxHeight
            : _sheet.value.clamp(0.0, _maxHeight);
        // Entering the status bar zone: square the corners, push content.
        final inset = statusBar <= 0
            ? (h >= _maxHeight ? 1.0 : 0.0)
            : ((h - (_maxHeight - statusBar)) / statusBar).clamp(0.0, 1.0);
        return Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: h,
          child: Container(
            clipBehavior: Clip.antiAlias,
            padding: EdgeInsets.only(top: statusBar * inset),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(28 * (1 - inset))),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x241B1A17),
                    blurRadius: 30,
                    offset: Offset(0, -8)),
              ],
            ),
            child: child,
          ),
        );
      },
      child: content,
    );
  }

  /// Invisible and untouchable while the sheet is at or below [detent]'s
  /// height, fading in over the next 40px of drag.
  Widget _fadeAbove(_Detent detent, {required Widget child}) => AnimatedBuilder(
        animation: _sheet,
        builder: (context, child) {
          final t =
              ((_sheet.value - _heightOf(detent) - 4) / 40).clamp(0.0, 1.0);
          return IgnorePointer(
            ignoring: t == 0,
            child: Opacity(opacity: t, child: child),
          );
        },
        child: child,
      );

  Widget _buildPills(BuildContext context) {
    final l10n = context.l10n;
    final (icon, label) = _visibility(l10n, _trip.visibility);
    final visibility = Pill(label, icon: icon);
    return Wrap(spacing: 6, runSpacing: 6, children: [
      Pill.status(context, _trip.status),
      if (_d.isPromoted) Pill(l10n.promoted, tone: PillTone.promoted),
      if (_trip.tripModality == TripModality.multiDay &&
          _trip.currentDay != null &&
          _trip.status != TripStatus.finished)
        Pill(l10n.dayNumber(_trip.currentDay!)),
      if (_d.onVisibilityChange != null)
        InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: _pickVisibility,
          child: visibility,
        )
      else
        visibility,
    ]);
  }

  List<Widget> _buildMeta(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    final meta = TextStyle(fontSize: 13, height: 1.45, color: c.textMuted);
    final locale = Localizations.localeOf(context).toString();

    if (_isOwner) {
      // "Last check-in 22:45 · Nieuwegein" (the auto interval is in the
      // strip below).
      final latest = _latest;
      if (latest == null) return const [];
      final city = latest.city?.trim() ?? '';
      return [
        const SizedBox(height: 3),
        Text(
            [
              l10n.tripLastCheckIn(
                  DateFormat.Hm(locale).format(latest.timestamp.toLocal())),
              if (city.isNotEmpty) city,
            ].join(' · '),
            style: meta),
      ];
    }

    final date = _trip.status == TripStatus.finished && _trip.endDate != null
        ? l10n.finishedOn(DateFormat.yMd(locale).format(_trip.endDate!))
        : _trip.startDate != null
            ? l10n.startedOn(DateFormat.yMd(locale).format(_trip.startDate!))
            : null;
    return [
      const SizedBox(height: 6),
      InkWell(
        onTap: () =>
            AuthNavigationHelper.navigateToUserProfile(context, _trip.userId),
        child: Row(children: [
          UserAvatar(
            userId: _trip.userId,
            avatarUrl:
                _trip.avatarUrl?.isNotEmpty == true ? _trip.avatarUrl : null,
            username: _trip.username,
            radius: 12,
            backgroundColor: c.forestBg,
            textColor: c.forestFg,
          ),
          const SizedBox(width: 8),
          Text('@${_trip.username}',
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700, color: c.text)),
          if (date != null)
            Flexible(
              child: Text(' · $date',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, color: c.caption)),
            ),
        ]),
      ),
      if (_d.onFollowTripOwner != null ||
          _d.onSendFriendRequestToTripOwner != null) ...[
        const SizedBox(height: 10),
        Row(children: [
          if (_d.onFollowTripOwner != null)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _d.onFollowTripOwner,
                icon: Icon(
                    _d.isFollowingTripOwner
                        ? Icons.person_remove_outlined
                        : Icons.person_add_outlined,
                    size: 18),
                label:
                    Text(_d.isFollowingTripOwner ? l10n.unfollow : l10n.follow),
              ),
            ),
          if (_d.onFollowTripOwner != null &&
              _d.onSendFriendRequestToTripOwner != null)
            const SizedBox(width: 8),
          if (_d.onSendFriendRequestToTripOwner != null)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _d.onSendFriendRequestToTripOwner,
                icon: Icon(
                    _d.isAlreadyFriends ? Icons.people : Icons.person_add_alt,
                    size: 18),
                label: Text(_d.isAlreadyFriends
                    ? l10n.unfriend
                    : _d.hasSentFriendRequest
                        ? l10n.requestSent
                        : l10n.addFriend),
              ),
            ),
        ]),
      ],
    ];
  }

  TripLocation? get _latest => _d.tripUpdates.isEmpty
      ? null
      : _d.tripUpdates
          .reduce((a, b) => a.timestamp.isAfter(b.timestamp) ? a : b);

  String _interval(AppLocalizations l10n) =>
      l10n.newTripMinutes((_trip.effectiveUpdateRefresh / 60).round());

  Widget _buildStats(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final km =
        NumberFormat.decimalPatternDigits(locale: locale, decimalDigits: 1)
            .format(_trip.accruedDistanceKm ?? 0);
    final start = _trip.startDate;
    final span = start == null
        ? null
        : (_trip.endDate ?? DateTime.now()).difference(start);
    final (String, String) time = span == null
        ? (l10n.categoryDuration, '—')
        : span.inHours < 24
            ? (
                l10n.tripStatTime,
                l10n.tripHoursMinutes(span.inHours, span.inMinutes % 60)
              )
            : (l10n.categoryDuration, l10n.daysCount(span.inDays + 1));
    final distance = (l10n.categoryDistance, l10n.kmValue(km));
    final updates = (
      l10n.tripStatCheckIns,
      '${_trip.updateCount ?? _d.tripUpdates.length}${_d.hasMoreUpdates ? '+' : ''}'
    );
    final stats = _trip.status == TripStatus.inProgress
        ? [time, distance, updates]
        : [distance, time, updates];

    return Row(children: [
      for (var i = 0; i < stats.length; i++) ...[
        if (i > 0) const SizedBox(width: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
                color: c.raised, borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(stats[i].$1,
                    style: TextStyle(fontSize: 12, color: c.caption)),
                Text(stats[i].$2,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: c.text)),
              ],
            ),
          ),
        ),
      ],
    ]);
  }

  Widget _buildAutoStrip(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    return Material(
      color: c.skyBg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _openSettings,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(children: [
            Icon(Icons.schedule, size: 18, color: c.skyFg),
            const SizedBox(width: 10),
            Expanded(
              child: Text(l10n.tripAutoCheckInEvery(_interval(l10n)),
                  style: TextStyle(fontSize: 13, color: c.skyFg)),
            ),
            Text(l10n.tripChange,
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700, color: c.skyFg)),
          ]),
        ),
      ),
    );
  }

  List<Widget> _timelineItems(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    if (_d.isLoadingUpdates) {
      return const [
        Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (_d.tripUpdates.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Text(l10n.tripUpdatesWillAppear,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: c.textMuted)),
        ),
      ];
    }
    final locale = Localizations.localeOf(context).toString();
    final now = DateTime.now();
    String when(DateTime t) {
      final l = t.toLocal();
      final hm = DateFormat.Hm(locale).format(l);
      final today =
          l.year == now.year && l.month == now.month && l.day == now.day;
      return today ? hm : '${DateFormat('d/M').format(l)} · $hm';
    }

    Widget row(TripLocation u, {double indent = 0}) => InkWell(
          onTap: () => widget.onCheckInTap(u),
          child: Padding(
            padding: EdgeInsets.fromLTRB(20 + indent, 14, 20, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _dot(tripCheckInColor(c, u)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tripCheckInTitle(l10n, u),
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: c.text)),
                      const SizedBox(height: 2),
                      Text(
                        [
                          when(u.timestamp),
                          if (u.temperatureCelsius != null)
                            WeatherHelpers.formatTemperature(
                                u.temperatureCelsius!),
                          if ((u.distanceSoFarKm ?? 0) > 0)
                            l10n.kmValue(u.distanceSoFarKm!.toStringAsFixed(1)),
                          if (u.updateType == TripUpdateType.regular)
                            tripCheckInKind(l10n, u),
                        ].join(' · '),
                        style: TextStyle(fontSize: 13, color: c.textMuted),
                      ),
                      if (tripCheckInMessage(u) case final message?) ...[
                        const SizedBox(height: 4),
                        Text(message,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13, color: c.text)),
                      ],
                    ],
                  ),
                ),
                if (u.battery != null) _battery(c, u.battery!),
              ],
            ),
          ),
        );

    // A run of check-ins at one place folds into "Nieuwegein · 6 check-ins"
    // (latest time); tapping expands it in place.
    Widget group(List<TripLocation> g) {
      final latest =
          g.reduce((a, b) => a.timestamp.isAfter(b.timestamp) ? a : b);
      final open = _expandedGroups.contains(latest.id);
      final place = latest.city?.trim().isNotEmpty == true
          ? latest.city!.trim()
          : tripCheckInPlace(latest);
      return Column(children: [
        InkWell(
          onTap: () => setState(() => open
              ? _expandedGroups.remove(latest.id)
              : _expandedGroups.add(latest.id)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _dot(tripCheckInColor(c, latest)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$place · ${l10n.tripCheckInGroup(g.length)}',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: c.text)),
                      const SizedBox(height: 2),
                      Text(
                        [
                          when(latest.timestamp),
                          if (latest.temperatureCelsius != null)
                            WeatherHelpers.formatTemperature(
                                latest.temperatureCelsius!),
                        ].join(' · '),
                        style: TextStyle(fontSize: 13, color: c.textMuted),
                      ),
                    ],
                  ),
                ),
                if (latest.battery != null) _battery(c, latest.battery!),
                const SizedBox(width: 4),
                Icon(open ? Icons.expand_less : Icons.expand_more,
                    size: 20, color: c.caption),
              ],
            ),
          ),
        ),
        if (open)
          for (final u in g) row(u, indent: 22),
      ]);
    }

    final divider = Divider(height: 1, thickness: 1, color: c.lineSoft);
    final groups = groupCheckIns(_d.tripUpdates);
    return [
      for (var i = 0; i < groups.length; i++) ...[
        if (i > 0) divider,
        groups[i].length == 1 ? row(groups[i].single) : group(groups[i]),
      ],
      if (_d.hasMoreUpdates)
        Center(
          child: _d.isLoadingMoreUpdates
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(strokeWidth: 2))
              : TextButton(
                  onPressed: _d.onLoadMoreUpdates,
                  child: Text(l10n.loadOlderUpdates)),
        ),
    ];
  }

  List<Widget> _commentItems(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    return [
      if (_d.isLoadingComments)
        const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        )
      else if (_d.comments.isEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Text(l10n.noCommentsYet,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: c.textMuted)),
        )
      else
        for (final comment in _d.comments)
          CommentCard(
            comment: comment,
            tripUserId: _trip.userId,
            currentUserId: _d.currentUserId,
            isExpanded: _d.expandedComments[comment.id] ?? false,
            replies: _d.replies[comment.id] ?? const [],
            onReact: () => _d.onReact(comment.id),
            onReactionChipTap: (type) => _d.onReactionChipTap(comment.id, type),
            onReply: () => _d.onReply(comment.id),
            onToggleReplies: () => _d.onToggleReplies(
                comment.id, _d.expandedComments[comment.id] ?? false),
            isLoggedIn: _d.isLoggedIn,
          ),
      if (_d.hasMoreComments)
        Center(
          child: _d.isLoadingMoreComments
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(strokeWidth: 2))
              : TextButton(
                  onPressed: _d.onLoadMoreComments,
                  child: Text(l10n.loadMoreComments)),
        ),
      if (_d.isLoggedIn)
        CommentInput(
          controller: _d.commentController,
          isAddingComment: _d.isAddingComment,
          isReplyMode: _d.replyingToCommentId != null,
          onSend: _d.onSendComment,
          onCancelReply: _d.onCancelReply,
        ),
    ];
  }

  Widget _dot(Color color) => Container(
        width: 10,
        height: 10,
        margin: const EdgeInsets.only(top: 5),
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );

  Widget _battery(WandererColors c, int battery) => Text('$battery%',
      style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: battery >= 30 ? c.forestFg : const Color(0xFFB42318)));

  Widget _buildGuestCta(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
          color: c.trailSoftBg, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Expanded(
          child: Text(l10n.tripGuestCta,
              style: TextStyle(fontSize: 14, color: c.trailSoftFg)),
        ),
        const SizedBox(width: 12),
        SizedBox(
          height: 48,
          child: FilledButton(
            key: const Key('trip_guest_login'),
            onPressed: widget.onLogin,
            style: FilledButton.styleFrom(
              backgroundColor: c.neutralButtonBg,
              foregroundColor: c.neutralButtonFg,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              textStyle:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            child: Text(l10n.tripLogIn),
          ),
        ),
      ]),
    );
  }
}

/// Fixed top (natural height) with the list filling whatever is left; when
/// the sheet is shorter than the top it is simply clipped.
class _SheetLayout extends MultiChildLayoutDelegate {
  static const top = 'top';
  static const list = 'list';
  final ValueChanged<double> onTop;

  _SheetLayout(this.onTop);

  @override
  void performLayout(Size size) {
    final topH =
        layoutChild(top, BoxConstraints.tightFor(width: size.width)).height;
    layoutChild(
        list,
        BoxConstraints.tightFor(
            width: size.width,
            height: (size.height - topH).clamp(0.0, double.infinity)));
    positionChild(top, Offset.zero);
    positionChild(list, Offset(0, topH));
    onTop(topH);
  }

  @override
  bool shouldRelayout(_SheetLayout oldDelegate) => true;
}

/// White round map control (square-ish for "center on me").
class _RoundButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool square;
  final Color? color;

  const _RoundButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.square = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    final radius = BorderRadius.circular(square ? 14 : 999);
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: c.surface,
        borderRadius: radius,
        elevation: 0,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: radius,
              boxShadow: const [
                BoxShadow(
                    color: Color(0x261B1A17),
                    blurRadius: 12,
                    offset: Offset(0, 4)),
              ],
            ),
            child: Icon(icon, color: color ?? c.text, size: 22),
          ),
        ),
      ),
    );
  }
}
