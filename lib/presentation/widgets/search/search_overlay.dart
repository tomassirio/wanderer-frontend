import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wanderer_frontend/core/constants/enums.dart' show TripStatus;
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/providers/app_providers.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/data/models/domain/search_result.dart';
import 'package:wanderer_frontend/presentation/helpers/auth_navigation_helper.dart';
import 'package:wanderer_frontend/presentation/widgets/common/cached_trip_thumbnail.dart';
import 'package:wanderer_frontend/presentation/widgets/common/pill.dart';
import 'package:wanderer_frontend/presentation/widgets/common/user_avatar.dart';

bool _overlayOpen = false;

/// Opens the command-palette search (web). No-op if one is already open.
Future<void> showSearchOverlay(BuildContext context) async {
  if (_overlayOpen) return;
  _overlayOpen = true;
  try {
    final picked = await showGeneralDialog<Object>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: const Duration(milliseconds: 120),
      pageBuilder: (_, __, ___) => const SearchOverlay(),
    );
    if (!context.mounted) return;
    if (picked is UserSearchResult) {
      await AuthNavigationHelper.navigateToUserProfile(context, picked.id);
    } else if (picked is TripSummary) {
      // Same route SearchScreen uses: loads the trip, then TripDetailScreen.
      await Navigator.of(context).pushNamed('/trip/${picked.id}');
    }
  } finally {
    _overlayOpen = false;
  }
}

enum _Filter { all, people, trips }

/// Dialog body; pops with the picked [UserSearchResult] or [TripSummary].
class SearchOverlay extends ConsumerStatefulWidget {
  const SearchOverlay({super.key});

  @override
  ConsumerState<SearchOverlay> createState() => _SearchOverlayState();
}

class _SearchOverlayState extends ConsumerState<SearchOverlay> {
  static const _recentKey = 'search_overlay_recent';
  static const _maxRecent = 6;
  static const _pageSize = 8;

  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;
  SearchResultsResponse? _results;
  String _resultsQuery = '';
  bool _loading = false;
  bool _error = false;
  _Filter _filter = _Filter.all;
  int _highlight = 0;
  List<String> _recent = [];
  List<GlobalKey> _rowKeys = [];

  @override
  void initState() {
    super.initState();
    _loadRecent();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadRecent() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _recent = prefs.getStringList(_recentKey) ?? []);
  }

  Future<void> _saveRecent(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    final list = [
      q,
      ..._recent.where((r) => r.toLowerCase() != q.toLowerCase())
    ].take(_maxRecent).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_recentKey, list);
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final q = value.trim();
    if (q.isEmpty) {
      setState(() {
        _results = null;
        _loading = false;
        _error = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 250), () => _search(q));
  }

  Future<void> _search(String query) async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final results = await ref
          .read(searchServiceProvider)
          .search(query, userSize: _pageSize, tripSize: _pageSize);
      // Drop stale responses if the user kept typing.
      if (!mounted || _controller.text.trim() != query) return;
      setState(() {
        _results = results;
        _resultsQuery = query;
        _loading = false;
        _highlight = 0;
      });
    } catch (_) {
      if (!mounted || _controller.text.trim() != query) return;
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  void _runRecent(String query) {
    _controller.value = TextEditingValue(
      text: query,
      selection: TextSelection.collapsed(offset: query.length),
    );
    _debounce?.cancel();
    _search(query);
  }

  List<UserSearchResult> get _people =>
      _filter == _Filter.trips ? const [] : _results?.users.content ?? const [];

  List<TripSummary> get _trips => _filter == _Filter.people
      ? const []
      : _results?.trips.content ?? const [];

  List<Object> get _items => [..._people, ..._trips];

  void _move(int delta) {
    final count = _items.length;
    if (count == 0) return;
    setState(() => _highlight = (_highlight + delta).clamp(0, count - 1));
    final ctx = _highlight < _rowKeys.length
        ? _rowKeys[_highlight].currentContext
        : null;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx,
          alignmentPolicy: delta > 0
              ? ScrollPositionAlignmentPolicy.keepVisibleAtEnd
              : ScrollPositionAlignmentPolicy.keepVisibleAtStart);
    }
  }

  void _open(Object item) {
    _saveRecent(_resultsQuery);
    Navigator.of(context).pop(item);
  }

  void _openHighlighted() {
    final items = _items;
    if (_highlight < items.length) _open(items[_highlight]);
  }

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    final size = MediaQuery.sizeOf(context);
    final top = size.height > 600 ? 110.0 : 16.0;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).pop(),
        const SingleActivator(LogicalKeyboardKey.arrowDown): () => _move(1),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () => _move(-1),
      },
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, top, 16, 16),
          child: ConstrainedBox(
            constraints: BoxConstraints(
                maxWidth: 680, maxHeight: size.height - top - 16),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 80,
                    offset: const Offset(0, 30),
                  ),
                ],
              ),
              child: Material(
                color: c.surface,
                borderRadius: BorderRadius.circular(20),
                clipBehavior: Clip.antiAlias,
                child: Semantics(
                  scopesRoute: true,
                  explicitChildNodes: true,
                  namesRoute: true,
                  label: l10n.search,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildInput(c, l10n),
                      if (_loading)
                        LinearProgressIndicator(
                            minHeight: 2,
                            color: WandererTheme.trail,
                            backgroundColor: c.lineSoft),
                      if (_results != null && !_results!.isEmpty)
                        _buildFilters(c, l10n),
                      Flexible(child: _buildBody(c, l10n)),
                      _buildFooter(c, l10n),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInput(WandererColors c, AppLocalizations l10n) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.lineSoft)),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, size: 20, color: WandererTheme.trail),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _controller,
              autofocus: true,
              onChanged: _onChanged,
              onSubmitted: (_) => _openHighlighted(),
              style: TextStyle(fontSize: 18, color: c.text),
              cursorColor: WandererTheme.trail,
              decoration: InputDecoration(
                hintText: l10n.searchOverlayHint,
                hintStyle: TextStyle(fontSize: 18, color: c.caption),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                isCollapsed: true,
              ),
            ),
          ),
          const SizedBox(width: 12),
          _Keycap('Esc', c: c, onGround: true),
        ],
      ),
    );
  }

  Widget _buildFilters(WandererColors c, AppLocalizations l10n) {
    Widget chip(_Filter f, String label) {
      final selected = _filter == f;
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: Material(
          color: selected ? c.neutralButtonBg : c.surface,
          shape: StadiumBorder(
              side: selected ? BorderSide.none : BorderSide(color: c.line)),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: () => setState(() {
              _filter = f;
              _highlight = 0;
            }),
            child: Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: selected ? c.neutralButtonFg : c.textMuted,
                ),
              ),
            ),
          ),
        ),
      );
    }

    final r = _results!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Row(
        children: [
          chip(_Filter.all, l10n.searchOverlayAll),
          chip(_Filter.people,
              '${l10n.searchOverlayPeople} · ${r.users.totalElements}'),
          chip(_Filter.trips,
              '${l10n.searchOverlayTrips} · ${r.trips.totalElements}'),
        ],
      ),
    );
  }

  Widget _buildBody(WandererColors c, AppLocalizations l10n) {
    Widget message(String text) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
          child: Text(text,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: c.textMuted)),
        );

    if (_controller.text.trim().isEmpty) {
      if (_recent.isEmpty) return message(l10n.searchOverlayPrompt);
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionLabel(l10n.searchOverlayRecent, c: c),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final q in _recent)
                    _RecentChip(q, c: c, onTap: _runRecent),
                ],
              ),
            ),
          ],
        ),
      );
    }
    if (_error) return message(l10n.searchOverlayError);
    if (_results == null) return const SizedBox(height: 24);
    if (_results!.isEmpty) {
      return message(l10n.searchOverlayNoResults(_resultsQuery));
    }

    final people = _people;
    final trips = _trips;
    final count = people.length + trips.length;
    if (_rowKeys.length != count) {
      _rowKeys = List.generate(count, (_) => GlobalKey());
    }

    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (people.isNotEmpty) _SectionLabel(l10n.searchOverlayPeople, c: c),
          for (var i = 0; i < people.length; i++)
            _personRow(people[i], i, c, l10n),
          if (trips.isNotEmpty) _SectionLabel(l10n.searchOverlayTrips, c: c),
          for (var i = 0; i < trips.length; i++)
            _tripRow(trips[i], people.length + i, c, l10n),
        ],
      ),
    );
  }

  Widget _row({
    required int index,
    required Object item,
    required WandererColors c,
    required Widget leading,
    required String title,
    required String subtitle,
    required Widget trailing,
  }) {
    final selected = index == _highlight;
    return Padding(
      key: _rowKeys[index],
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: selected ? c.trailSoftBg : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _open(item),
          onHover: (h) {
            if (h && _highlight != index) setState(() => _highlight = index);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Row(
              children: [
                leading,
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Highlighted(title, _resultsQuery, c: c),
                      Text(subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, color: c.caption)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _openHint(WandererColors c, AppLocalizations l10n) => Text(
        '${l10n.searchOverlayOpen} ↵',
        style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w700, color: c.accentText),
      );

  Widget _personRow(UserSearchResult user, int index, WandererColors c,
      AppLocalizations l10n) {
    // Search results carry no relationship info, so the caption is the handle.
    final subtitle = user.displayName.isNotEmpty &&
            user.displayName.toLowerCase() != user.username.toLowerCase()
        ? '${user.displayName} · @${user.username}'
        : '@${user.username}';
    return _row(
      index: index,
      item: user,
      c: c,
      leading: UserAvatar(
        avatarUrl: user.avatarUrl,
        userId: user.id,
        username: user.username,
        displayName: user.displayName,
        radius: 20,
        backgroundColor: c.surface,
        textColor: c.accentText,
      ),
      title: user.username,
      subtitle: subtitle,
      trailing:
          index == _highlight ? _openHint(c, l10n) : const SizedBox.shrink(),
    );
  }

  Widget _tripRow(
      TripSummary trip, int index, WandererColors c, AppLocalizations l10n) {
    final placeholder = Container(
      color: c.mapGround,
      alignment: Alignment.center,
      child: Icon(Icons.map_outlined, size: 18, color: c.caption),
    );
    Widget status;
    try {
      status = Pill.status(context, TripStatus.fromJson(trip.status));
    } on ArgumentError {
      status = Pill(trip.status);
    }
    return _row(
      index: index,
      item: trip,
      c: c,
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 56,
          height: 40,
          child: trip.thumbnailUrl.isEmpty
              ? placeholder
              : CachedTripThumbnail(
                  thumbnailUrl: trip.thumbnailUrl,
                  width: 56,
                  height: 40,
                  placeholder: placeholder,
                  errorWidget: placeholder,
                ),
        ),
      ),
      title: trip.name,
      subtitle:
          '@${trip.username} · ${l10n.searchOverlayComments(trip.commentsCount)}',
      trailing: status,
    );
  }

  Widget _buildFooter(WandererColors c, AppLocalizations l10n) {
    Widget hint(String key, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Keycap(key, c: c),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 12, color: c.textMuted)),
          ],
        );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: c.raised,
        border: Border(top: BorderSide(color: c.lineSoft)),
      ),
      child: Wrap(
        spacing: 18,
        runSpacing: 8,
        children: [
          hint('↑↓', l10n.searchOverlayMove),
          hint('↵', l10n.searchOverlayOpen),
          hint('Ctrl K', l10n.searchOverlayAnywhere),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final WandererColors c;
  const _SectionLabel(this.text, {required this.c});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 6),
        child: Text(
          text.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.88,
            color: c.label,
          ),
        ),
      );
}

class _Keycap extends StatelessWidget {
  final String text;
  final WandererColors c;

  /// Esc keycap sits on the page-ground colour; footer keycaps on surface.
  final bool onGround;
  const _Keycap(this.text, {required this.c, this.onGround = false});

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(
            horizontal: onGround ? 8 : 6, vertical: onGround ? 3 : 1),
        decoration: BoxDecoration(
          color: onGround ? c.ground : c.surface,
          border: Border.all(color: c.line),
          borderRadius: BorderRadius.circular(onGround ? 6 : 5),
        ),
        child: Text(text,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: c.textMuted)),
      );
}

class _RecentChip extends StatelessWidget {
  final String query;
  final WandererColors c;
  final ValueChanged<String> onTap;
  const _RecentChip(this.query, {required this.c, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
        color: c.raised,
        shape: StadiumBorder(side: BorderSide(color: c.line)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: () => onTap(query),
          child: Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.schedule, size: 13, color: c.textMuted),
                const SizedBox(width: 6),
                Text(query,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: c.textMuted)),
              ],
            ),
          ),
        ),
      );
}

/// [text] with the first case-insensitive match of [query] in accent colour.
class _Highlighted extends StatelessWidget {
  final String text;
  final String query;
  final WandererColors c;
  const _Highlighted(this.text, this.query, {required this.c});

  @override
  Widget build(BuildContext context) {
    final base =
        TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.text);
    var i =
        query.isEmpty ? -1 : text.toLowerCase().indexOf(query.toLowerCase());
    // Case folding can change length (e.g. 'İ'); skip the highlight then.
    if (i + query.length > text.length) i = -1;
    return Text.rich(
      i < 0
          ? TextSpan(text: text)
          : TextSpan(children: [
              TextSpan(text: text.substring(0, i)),
              TextSpan(
                  text: text.substring(i, i + query.length),
                  style: TextStyle(color: c.accentText)),
              TextSpan(text: text.substring(i + query.length)),
            ]),
      style: base,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
