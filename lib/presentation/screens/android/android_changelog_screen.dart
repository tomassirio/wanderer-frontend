import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wanderer_frontend/core/constants/enums.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/data/models/domain/trip.dart';
import 'package:wanderer_frontend/core/providers/app_providers.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/data/models/domain/release_note.dart';
import 'package:wanderer_frontend/data/services/release_notes_service.dart';
import 'package:wanderer_frontend/presentation/helpers/page_transitions.dart';
import 'package:wanderer_frontend/presentation/widgets/android/android_ui.dart';
import 'package:wanderer_frontend/presentation/widgets/android/explore_widgets.dart';
import 'package:wanderer_frontend/presentation/widgets/android/release_notes_widgets.dart';

/// A trip is on the road (live, paused or resting overnight).
bool isTripRunning(Trip t) =>
    t.status == TripStatus.inProgress ||
    t.status == TripStatus.paused ||
    t.status == TripStatus.resting;

bool _whatsNewBusy = false;
final _whatsNewShown = <String>{};

@visibleForTesting
void resetWhatsNewSession() {
  _whatsNewShown.clear();
  _whatsNewBusy = false;
}

/// Shows the What's new sheet (A) once for a release the user hasn't seen.
/// Never while a trip is running: Home calls this again on its next load.
Future<void> maybeShowWhatsNew(
    BuildContext context, ReleaseNotesService service,
    {required bool tripRunning}) async {
  if (tripRunning || _whatsNewBusy) return;
  _whatsNewBusy = true;
  try {
    final note = await service.popupRelease();
    // The session set keeps it to once even if marking it seen fails.
    if (note == null || !context.mounted || !_whatsNewShown.add(note.version)) {
      return;
    }
    final seeAll = await showWhatsNewSheet(context, note);
    await service.markSeen(await service.appVersion());
    if (seeAll == true && context.mounted) {
      await Navigator.of(context)
          .push(PageTransitions.slideFromRight(const AndroidChangelogScreen()));
    }
  } catch (e) {
    debugPrint('maybeShowWhatsNew: $e');
  } finally {
    _whatsNewBusy = false;
  }
}

/// Every published version, newest first (canvas "C · Full changelog").
/// Opening it marks the running version's notes as read.
class AndroidChangelogScreen extends ConsumerStatefulWidget {
  const AndroidChangelogScreen({super.key});

  @override
  ConsumerState<AndroidChangelogScreen> createState() =>
      _AndroidChangelogScreenState();
}

class _AndroidChangelogScreenState
    extends ConsumerState<AndroidChangelogScreen> {
  List<ReleaseNote>? _releases;
  String _appVersion = '';
  bool _offline = false;
  ReleaseChangeType? _filter;
  String? _open;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final service = ref.read(releaseNotesServiceProvider);
    final version = await service.appVersion();
    final cached = await service.cachedReleases();
    if (mounted && cached != null) _show(cached, version, offline: false);
    try {
      final fresh = await service.getReleases();
      if (mounted) _show(fresh, version, offline: false);
      await service.markSeen(version);
    } catch (e) {
      debugPrint('AndroidChangelogScreen: load failed: $e');
      if (mounted) _show(cached ?? const [], version, offline: true);
    }
  }

  void _show(List<ReleaseNote> releases, String version,
      {required bool offline}) {
    setState(() {
      _open ??= releases.firstOrNull?.version;
      _releases = releases;
      _appVersion = version;
      _offline = offline;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    final releases = _releases;
    return Scaffold(
      backgroundColor: c.ground,
      appBar: AndroidTopBar(title: l10n.whatsNewTitle),
      body: releases == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                if (_offline) ...[
                  _Banner(
                      icon: Icons.cloud_off_outlined,
                      bg: c.neutralBg,
                      fg: c.neutralFg,
                      title: releases.isEmpty
                          ? l10n.changelogLoadFailed
                          : l10n.changelogOffline),
                  const SizedBox(height: 12),
                ],
                if (releases.isNotEmpty) ...[
                  _versionBanner(c, l10n, releases.first.version),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: [
                      for (final (type, label) in [
                        (null, l10n.changelogAll),
                        (ReleaseChangeType.newFeature, l10n.releaseTypeNew),
                        (ReleaseChangeType.improved, l10n.releaseTypeImproved),
                        (ReleaseChangeType.fixed, l10n.releaseTypeFixed),
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ExploreChip(
                            label: label,
                            selected: _filter == type,
                            onTap: () => setState(() => _filter = type),
                          ),
                        ),
                    ]),
                  ),
                  const SizedBox(height: 12),
                ],
                if (releases.isEmpty && !_offline)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: Text(l10n.changelogEmpty,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 15, color: c.textMuted)),
                  ),
                for (final (i, r) in releases.indexed) ...[
                  if (i > 0) const SizedBox(height: 12),
                  _ReleaseCard(
                    release: r,
                    latest: i == 0,
                    open: _open == r.version,
                    filter: _filter,
                    onToggle: () => setState(
                        () => _open = _open == r.version ? null : r.version),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _versionBanner(
      WandererColors c, AppLocalizations l10n, String latest) {
    final behind =
        _appVersion.isNotEmpty && compareVersions(_appVersion, latest) < 0;
    return behind
        ? _Banner(
            icon: Icons.system_update_outlined,
            bg: c.trailSoftBg,
            fg: c.trailSoftFg,
            title: l10n.changelogUpdateTitle,
            body: l10n.changelogUpdateBody(latest, _appVersion))
        : _Banner(
            icon: Icons.check_circle_outline,
            bg: c.forestBg,
            fg: c.forestFg,
            title: l10n.changelogOnLatestTitle(
                _appVersion.isEmpty ? latest : _appVersion),
            body: l10n.changelogOnLatestBody);
  }
}

class _Banner extends StatelessWidget {
  final IconData icon;
  final Color bg;
  final Color fg;
  final String title;
  final String? body;
  const _Banner(
      {required this.icon,
      required this.bg,
      required this.fg,
      required this.title,
      this.body});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          Icon(icon, size: 22, color: fg),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(
                    text: title,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                if (body != null) TextSpan(text: '\n$body'),
              ]),
              style: TextStyle(fontSize: 14, height: 1.4, color: fg),
            ),
          ),
        ]),
      );
}

class _ReleaseCard extends StatelessWidget {
  final ReleaseNote release;
  final bool latest;
  final bool open;
  final ReleaseChangeType? filter;
  final VoidCallback onToggle;
  const _ReleaseCard({
    required this.release,
    required this.latest,
    required this.open,
    required this.filter,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    final changes = [
      for (final ch in release.items)
        if (filter == null || ch.type == filter) ch
    ];
    final platforms = [
      for (final p in release.platforms)
        switch (p.platform) {
          'ANDROID' => l10n.releasePlatformAndroid,
          'WEB' => l10n.releasePlatformWeb,
          _ => p.platform,
        }
    ];
    final meta = [
      releaseDate(context, release.releaseDateOn(currentPlatform)),
      ...platforms,
    ].where((s) => s.isNotEmpty).join(' · ');
    return Container(
      decoration: WandererTheme.cardDecoration(context),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              expanded: open,
              child: InkWell(
                onTap: onToggle,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 68),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Text(release.version,
                                style:
                                    WandererTheme.display(18, color: c.text)),
                            if (latest) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                    color: c.trailSoftBg,
                                    borderRadius: BorderRadius.circular(999)),
                                child: Text(l10n.changelogLatest,
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: c.trailSoftFg)),
                              ),
                            ],
                          ]),
                          if (meta.isNotEmpty)
                            Text(meta,
                                style: TextStyle(
                                    fontSize: 13, color: c.textMuted)),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: open ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(Icons.expand_more, color: c.textMuted),
                    ),
                  ]),
                ),
              ),
            ),
            if (open)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                child: changes.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(l10n.changelogEmptyFilter,
                            style: TextStyle(fontSize: 13, color: c.textMuted)),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final ch in changes) ReleaseChangeTile(ch)
                        ],
                      ),
              ),
          ],
        ),
      ),
    );
  }
}
