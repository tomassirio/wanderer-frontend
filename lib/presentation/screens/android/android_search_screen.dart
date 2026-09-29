import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wanderer_frontend/core/constants/enums.dart' show TripStatus;
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/providers/app_providers.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/data/models/domain/search_result.dart';
import 'package:wanderer_frontend/presentation/helpers/auth_navigation_helper.dart';
import 'package:wanderer_frontend/presentation/widgets/android/explore_widgets.dart';
import 'package:wanderer_frontend/presentation/widgets/common/user_avatar.dart';

enum _Filter { all, people, trips }

/// [text] with every case-insensitive occurrence of [query] in orange.
@visibleForTesting
List<TextSpan> searchHighlight(String text, String query, Color color) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return [TextSpan(text: text)];
  final lower = text.toLowerCase();
  final spans = <TextSpan>[];
  var i = 0;
  while (true) {
    final hit = lower.indexOf(q, i);
    if (hit < 0) break;
    if (hit > i) spans.add(TextSpan(text: text.substring(i, hit)));
    spans.add(TextSpan(
        text: text.substring(hit, hit + q.length),
        style: TextStyle(color: color)));
    i = hit + q.length;
  }
  if (i < text.length) spans.add(TextSpan(text: text.substring(i)));
  return spans;
}

/// Android search (canvas: AndroidSearch): pill field, All / People / Trips
/// chips, grouped results and recent searches. Uses the same
/// [SearchService] and recent-search storage as the web search overlay.
class AndroidSearchScreen extends ConsumerStatefulWidget {
  const AndroidSearchScreen({super.key});

  @override
  ConsumerState<AndroidSearchScreen> createState() =>
      _AndroidSearchScreenState();
}

class _AndroidSearchScreenState extends ConsumerState<AndroidSearchScreen> {
  static const _recentKey = 'search_overlay_recent';
  static const _maxRecent = 6;

  final _controller = TextEditingController();
  Timer? _debounce;
  SearchResultsResponse? _results;
  String _resultsQuery = '';
  bool _loading = false;
  bool _error = false;
  _Filter _filter = _Filter.all;
  List<String> _recent = [];

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (mounted) setState(() => _recent = p.getStringList(_recentKey) ?? []);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _saveRecent() async {
    final q = _resultsQuery.trim();
    if (q.isEmpty) return;
    _recent = [q, ..._recent.where((r) => r.toLowerCase() != q.toLowerCase())]
        .take(_maxRecent)
        .toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_recentKey, _recent);
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
      final r = await ref.read(searchServiceProvider).search(query);
      if (!mounted || _controller.text.trim() != query) return;
      setState(() {
        _results = r;
        _resultsQuery = query;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || _controller.text.trim() != query) return;
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  void _runRecent(String q) {
    _controller.value = TextEditingValue(
        text: q, selection: TextSelection.collapsed(offset: q.length));
    _debounce?.cancel();
    _search(q);
  }

  Future<void> _openUser(UserSearchResult u) async {
    await _saveRecent();
    if (!mounted) return;
    await AuthNavigationHelper.navigateToUserProfile(context, u.id);
  }

  Future<void> _openTrip(TripSummary t) async {
    await _saveRecent();
    // Same route the web overlay and SearchScreen use.
    if (mounted) await Navigator.of(context).pushNamed('/trip/${t.id}');
  }

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    OutlineInputBorder border(Color color, double w) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(999),
        borderSide: BorderSide(color: color, width: w));

    return Scaffold(
      backgroundColor: c.ground,
      appBar: AppBar(
        toolbarHeight: 72,
        backgroundColor: c.ground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const BackButton(),
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 12),
          child: TextField(
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onChanged: (v) {
              setState(() {}); // clear button visibility
              _onChanged(v);
            },
            onSubmitted: (v) {
              if (v.trim().isNotEmpty) _search(v.trim());
            },
            style: TextStyle(fontSize: 16, color: c.text),
            decoration: InputDecoration(
              hintText: l10n.searchOverlayHint,
              hintStyle: TextStyle(color: c.caption),
              filled: true,
              fillColor: c.surface,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              border: border(c.line, 1),
              enabledBorder: border(c.line, 1),
              focusedBorder: border(WandererTheme.trail, 2),
              suffixIcon: _controller.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip:
                          MaterialLocalizations.of(context).deleteButtonTooltip,
                      icon: Icon(Icons.close, size: 18, color: c.textMuted),
                      onPressed: () {
                        _controller.clear();
                        _onChanged('');
                      },
                    ),
            ),
          ),
        ),
      ),
      body: _body(context),
    );
  }

  Widget _body(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    final r = _results;
    final hasQuery = _controller.text.trim().isNotEmpty;

    Widget label(String text, {double top = 14}) => Padding(
          padding: EdgeInsets.fromLTRB(4, top, 4, 8),
          child: Text(text.toUpperCase(),
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  color: c.label)),
        );
    Widget message(String text) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 4),
          child: Text(text,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: c.textMuted)),
        );

    final recent = _recent.isEmpty
        ? const <Widget>[]
        : [
            label(l10n.searchOverlayRecent),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final q in _recent)
                ActionChip(
                  avatar: Icon(Icons.schedule, size: 14, color: c.textMuted),
                  label: Text(q),
                  labelStyle: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: c.textMuted),
                  backgroundColor: c.surface,
                  side: BorderSide(color: c.line),
                  shape: const StadiumBorder(),
                  onPressed: () => _runRecent(q),
                ),
            ]),
          ];

    final people = _filter == _Filter.trips
        ? const <UserSearchResult>[]
        : r?.users.content ?? const <UserSearchResult>[];
    final trips = _filter == _Filter.people
        ? const <TripSummary>[]
        : r?.trips.content ?? const <TripSummary>[];

    final children = <Widget>[
      if (r != null && hasQuery)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            ExploreChip(
                label: l10n.searchOverlayAll,
                selected: _filter == _Filter.all,
                onTap: () => setState(() => _filter = _Filter.all)),
            ExploreChip(
                label: '${l10n.searchOverlayPeople} · ${r.users.totalElements}',
                selected: _filter == _Filter.people,
                onTap: () => setState(() => _filter = _Filter.people)),
            ExploreChip(
                label: '${l10n.searchOverlayTrips} · ${r.trips.totalElements}',
                selected: _filter == _Filter.trips,
                onTap: () => setState(() => _filter = _Filter.trips)),
          ]),
        ),
      if (!hasQuery) ...[
        if (_recent.isEmpty) message(l10n.searchOverlayPrompt),
        ...recent,
      ] else if (_loading && r == null)
        const Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        )
      else if (_error)
        message(l10n.searchOverlayError)
      else if (r != null && people.isEmpty && trips.isEmpty)
        message(l10n.searchOverlayNoResults(_resultsQuery))
      else ...[
        if (people.isNotEmpty) label(l10n.searchOverlayPeople, top: 8),
        for (final u in people) ...[
          _PersonRow(user: u, query: _resultsQuery, onTap: () => _openUser(u)),
          const SizedBox(height: 6),
        ],
        if (trips.isNotEmpty) label(l10n.searchOverlayTrips),
        for (final t in trips) ...[
          _TripRow(trip: t, query: _resultsQuery, onTap: () => _openTrip(t)),
          const SizedBox(height: 6),
        ],
      ],
    ];

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: children,
    );
  }
}

class _PersonRow extends StatelessWidget {
  final UserSearchResult user;
  final String query;
  final VoidCallback onTap;
  const _PersonRow(
      {required this.user, required this.query, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    final hasName = user.displayName.isNotEmpty;
    return Material(
      color: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: c.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(children: [
              UserAvatar(
                userId: user.id,
                avatarUrl: user.avatarUrl,
                username: user.username,
                displayName: user.displayName,
                radius: 22,
                backgroundColor: c.trailSoftBg,
                textColor: c.accentText,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                          children: searchHighlight(
                              hasName ? user.displayName : user.username,
                              query,
                              c.accentText)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: c.text),
                    ),
                    // Search results carry no relationship info: show the
                    // handle.
                    if (hasName)
                      Text.rich(
                        TextSpan(children: [
                          const TextSpan(text: '@'),
                          ...searchHighlight(
                              user.username, query, c.accentText),
                        ]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: c.caption),
                      ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 18, color: c.label),
            ]),
          ),
        ),
      ),
    );
  }
}

class _TripRow extends StatelessWidget {
  final TripSummary trip;
  final String query;
  final VoidCallback onTap;
  const _TripRow(
      {required this.trip, required this.query, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    final status = switch (TripStatus.fromJson(trip.status)) {
      TripStatus.finished => l10n.completed,
      TripStatus.inProgress => l10n.live,
      TripStatus.paused => l10n.paused,
      TripStatus.resting => l10n.resting,
      TripStatus.created => l10n.draft,
    };
    final by = l10n.searchByUser(trip.username);
    final at = by.indexOf(trip.username);
    return ExploreTripRow(
      thumbnailUrl: trip.thumbnailUrl,
      thumbSize: 52,
      title: Text.rich(
          TextSpan(children: searchHighlight(trip.name, query, c.accentText))),
      subtitle: Text.rich(
        TextSpan(children: [
          if (at < 0)
            TextSpan(text: by)
          else ...[
            TextSpan(text: by.substring(0, at)),
            ...searchHighlight(trip.username, query, c.accentText),
            TextSpan(text: by.substring(at + trip.username.length)),
          ],
          TextSpan(text: ' · $status'),
        ]),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: onTap,
    );
  }
}
