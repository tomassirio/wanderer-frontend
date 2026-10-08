import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/providers/app_providers.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/data/models/domain/release_note.dart';
import 'package:wanderer_frontend/presentation/helpers/page_transitions.dart';
import 'package:wanderer_frontend/presentation/widgets/android/android_ui.dart';
import 'package:wanderer_frontend/presentation/widgets/android/explore_widgets.dart';
import 'package:wanderer_frontend/presentation/widgets/android/plan_editor_layout.dart';
import 'package:wanderer_frontend/presentation/widgets/android/release_notes_widgets.dart';
import 'package:wanderer_frontend/presentation/widgets/common/pill.dart';
import 'package:wanderer_frontend/presentation/widgets/common/toasts.dart';
import 'package:wanderer_frontend/presentation/widgets/common/wanderer_sheet.dart';

const releasePlatforms = ['ANDROID', 'WEB'];

final _semver = RegExp(r'^\d+\.\d+\.\d+$');

/// Admin editor for a release (canvas "E · Edit the drafted notes, then
/// publish"). For a new release ([takenVersions] given) the version is
/// editable and must not be one of them. Pops true once published.
class AndroidReleaseNotesEditor extends ConsumerStatefulWidget {
  final ReleaseNote draft;
  final Set<String>? takenVersions;
  const AndroidReleaseNotesEditor(
      {super.key, required this.draft, this.takenVersions});

  @override
  ConsumerState<AndroidReleaseNotesEditor> createState() =>
      _AndroidReleaseNotesEditorState();
}

class _Item {
  ReleaseChange change;
  final TextEditingController title;
  final TextEditingController body;
  final Key key = UniqueKey();
  _Item(this.change)
      : title = TextEditingController(text: change.title),
        body = TextEditingController(text: change.text);

  ReleaseChange get value =>
      change.copyWith(title: title.text.trim(), text: body.text.trim());
}

class _AndroidReleaseNotesEditorState
    extends ConsumerState<AndroidReleaseNotesEditor> {
  late final _version = TextEditingController(text: widget.draft.version);
  late final _headline = TextEditingController(text: widget.draft.headline);
  late final List<_Item> _items = [
    for (final c in widget.draft.items) _Item(c)
  ];
  late Set<String> _platforms = {
    for (final p in widget.draft.platforms) p.platform
  };
  late bool _popup = widget.draft.showPopup;
  bool _publishing = false;

  @override
  void dispose() {
    _version.dispose();
    _headline.dispose();
    for (final i in _items) {
      i.title.dispose();
      i.body.dispose();
    }
    super.dispose();
  }

  /// Release dates already set are kept; a newly added platform has none
  /// yet (it goes live there once a date is set).
  ReleaseNote get _note => ReleaseNote(
        id: widget.draft.id,
        version: _version.text.trim(),
        draft: widget.draft.draft,
        headline: _headline.text.trim(),
        showPopup: _popup,
        platforms: [
          for (final p in releasePlatforms)
            if (_platforms.contains(p))
              ReleasePlatform(p, widget.draft.releaseDateOn(p))
        ],
        items: [for (final i in _items) i.value],
      );

  bool get _isNew => widget.takenVersions != null;

  bool get _valid =>
      _semver.hasMatch(_version.text.trim()) &&
      !(widget.takenVersions?.contains(_version.text.trim()) ?? false) &&
      _headline.text.trim().isNotEmpty &&
      _platforms.isNotEmpty &&
      _items.isNotEmpty &&
      _items.every((i) => i.title.text.trim().isNotEmpty);

  void _move(int i, int by) => setState(() {
        final item = _items.removeAt(i);
        _items.insert(i + by, item);
      });

  Future<void> _publish() async {
    final l10n = context.l10n;
    setState(() => _publishing = true);
    try {
      await ref.read(releaseNotesServiceProvider).publish(_note);
      Toasts.show(ToastData(
          kind: ToastKind.success, title: l10n.releaseNotesPublished));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      debugPrint('AndroidReleaseNotesEditor: publish failed: $e');
      Toasts.show(ToastData(
          kind: ToastKind.error, title: l10n.releaseNotesPublishFailed));
      if (mounted) setState(() => _publishing = false);
    }
  }

  void _preview() => showWandererSheet<void>(
        context,
        builder: (ctx) => WhatsNewContent(
          note: _note,
          onGotIt: () => Navigator.pop(ctx),
          onSeeAll: () => Navigator.pop(ctx),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    final version = _version.text.trim();
    final drafted = widget.draft.items.any((i) => i.prNumber != null);
    return Scaffold(
      backgroundColor: c.ground,
      appBar: AndroidTopBar(
        title: l10n.releaseNotesTitle,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
                child: Pill(widget.draft.draft
                    ? l10n.releaseNotesDraft
                    : l10n.releaseNotesLive)),
          ),
        ],
      ),
      body: _Narrow(ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          if (_isNew)
            LabeledField(
              label: l10n.releaseNotesVersion,
              controller: _version,
              helper: l10n.releaseNotesVersionHelp,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
            )
          else
            _Field(label: l10n.releaseNotesVersion, value: version),
          const SizedBox(height: 12),
          Text(l10n.releaseNotesPlatforms,
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700, color: c.text)),
          const SizedBox(height: 6),
          Row(children: [
            for (final p in releasePlatforms) ...[
              ExploreChip(
                label: p == 'ANDROID'
                    ? l10n.releasePlatformAndroid
                    : l10n.releasePlatformWeb,
                selected: _platforms.contains(p),
                onTap: () => setState(() => _platforms = _platforms.contains(p)
                    ? (_platforms.toSet()..remove(p))
                    : {..._platforms, p}),
              ),
              const SizedBox(width: 8),
            ],
          ]),
          if (drafted) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                  color: c.skyBg, borderRadius: BorderRadius.circular(12)),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.auto_awesome_outlined, size: 18, color: c.skyFg),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(l10n.releaseNotesDraftedHint,
                      style:
                          TextStyle(fontSize: 13, height: 1.4, color: c.skyFg)),
                ),
              ]),
            ),
          ],
          const SizedBox(height: 12),
          LabeledField(
            label: l10n.releaseNotesHeadline,
            controller: _headline,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: Text(l10n.releaseNotesChanges(_items.length),
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: c.text)),
            ),
            SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _items.add(_Item(
                    const ReleaseChange(
                        type: ReleaseChangeType.newFeature, title: '')))),
                icon: const Icon(Icons.add, size: 18),
                label: Text(l10n.releaseNotesAddChange),
                style: OutlinedButton.styleFrom(
                  foregroundColor: c.text,
                  side: BorderSide(color: c.line),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ]),
          for (final (i, item) in _items.indexed) ...[
            const SizedBox(height: 10),
            _ChangeCard(
              key: item.key,
              item: item,
              onType: (t) =>
                  setState(() => item.change = item.change.copyWith(type: t)),
              onUp: i == 0 ? null : () => _move(i, -1),
              onDown: i == _items.length - 1 ? null : () => _move(i, 1),
              onRemove: () => setState(() => _items.removeAt(i)),
              onChanged: () => setState(() {}),
            ),
          ],
          const SizedBox(height: 12),
          Container(
            decoration: WandererTheme.cardDecoration(context, radius: 16),
            child: SwitchListTile(
              value: _popup,
              onChanged: (v) => setState(() => _popup = v),
              activeTrackColor: WandererTheme.trail,
              title: Text(l10n.releaseNotesPopup,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: c.text)),
              subtitle: Text(l10n.releaseNotesPopupCaption,
                  style: TextStyle(fontSize: 13, color: c.textMuted)),
            ),
          ),
        ],
      )),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(
              color: c.ground, border: Border(top: BorderSide(color: c.line))),
          child: _Narrow(Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: OutlinedButton(
                    onPressed: _preview,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: c.text,
                      backgroundColor: c.surface,
                      side: BorderSide(color: c.line),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      textStyle: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    child: Text(l10n.releaseNotesPreview),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: PlanPrimaryButton(
                  label: l10n.releaseNotesPublish(version),
                  loading: _publishing,
                  onPressed: _valid ? _publish : null,
                ),
              ),
            ]),
            const SizedBox(height: 8),
            Text(l10n.releaseNotesPublishCaption(version),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: c.caption)),
          ])),
        ),
      ),
    );
  }
}

/// Keeps admin pages phone-width on desktop.
class _Narrow extends StatelessWidget {
  final Widget child;
  const _Narrow(this.child);

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        heightFactor: 1,
        child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720), child: child),
      );
}

class _Field extends StatelessWidget {
  final String label;
  final String value;
  const _Field({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: WandererTheme.cardDecoration(context, radius: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 12, color: c.textMuted)),
        Text(value,
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700, color: c.text)),
      ]),
    );
  }
}

class _ChangeCard extends StatelessWidget {
  final _Item item;
  final ValueChanged<ReleaseChangeType> onType;
  final VoidCallback? onUp;
  final VoidCallback? onDown;
  final VoidCallback onRemove;
  final VoidCallback onChanged;
  const _ChangeCard({
    super.key,
    required this.item,
    required this.onType,
    required this.onUp,
    required this.onDown,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    final ch = item.change;
    InputDecoration deco(String hint) => InputDecoration(
          hintText: hint,
          isDense: true,
          filled: true,
          fillColor: c.surface,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: c.line)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: c.line)),
        );
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: WandererTheme.cardDecoration(context, radius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            PopupMenuButton<ReleaseChangeType>(
              tooltip: l10n.releaseNotesChangeType,
              onSelected: onType,
              itemBuilder: (_) => [
                for (final t in ReleaseChangeType.values)
                  PopupMenuItem(
                      value: t, child: Text(ReleaseTypePill.label(context, t))),
              ],
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  ReleaseTypePill(ch.type),
                  Icon(Icons.expand_more, size: 18, color: c.textMuted),
                ]),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                ch.prNumber == null
                    ? ''
                    : l10n.releaseNotesFromPr(ch.prNumber!),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: c.textMuted),
              ),
            ),
            IconButton(
              tooltip: l10n.releaseNotesMoveUp,
              onPressed: onUp,
              icon: const Icon(Icons.arrow_upward, size: 18),
            ),
            IconButton(
              tooltip: l10n.releaseNotesMoveDown,
              onPressed: onDown,
              icon: const Icon(Icons.arrow_downward, size: 18),
            ),
            IconButton(
              tooltip: l10n.releaseNotesRemoveChange,
              onPressed: onRemove,
              icon: const Icon(Icons.close, size: 18),
            ),
          ]),
          const SizedBox(height: 8),
          Semantics(
            label: l10n.releaseNotesChangeTitle,
            child: TextField(
              controller: item.title,
              onChanged: (_) => onChanged(),
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700, color: c.text),
              decoration: deco(l10n.releaseNotesChangeTitle),
            ),
          ),
          const SizedBox(height: 8),
          Semantics(
            label: l10n.releaseNotesChangeDescription,
            child: TextField(
              controller: item.body,
              minLines: 2,
              maxLines: 4,
              style: TextStyle(fontSize: 13, height: 1.4, color: c.text),
              decoration: deco(l10n.releaseNotesChangeDescription),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Release notes" row at the top of Admin tools (canvas "D"), with a
/// draft-count pill. Opens [ReleaseNotesAdminScreen].
class ReleaseNotesAdminRow extends ConsumerStatefulWidget {
  const ReleaseNotesAdminRow({super.key});

  @override
  ConsumerState<ReleaseNotesAdminRow> createState() =>
      _ReleaseNotesAdminRowState();
}

class _ReleaseNotesAdminRowState extends ConsumerState<ReleaseNotesAdminRow> {
  List<ReleaseNote> _drafts = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final all =
          await ref.read(releaseNotesServiceProvider).getAdminReleases();
      if (mounted) setState(() => _drafts = all.where((r) => r.draft).toList());
    } catch (e) {
      debugPrint('ReleaseNotesAdminRow: load failed: $e');
    }
  }

  Future<void> _open() async {
    await Navigator.of(context)
        .push(PageTransitions.slideFromRight(const ReleaseNotesAdminScreen()));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    return InkWell(
      onTap: _open,
      child: Container(
        constraints: const BoxConstraints(minHeight: 76),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: c.lineSoft))),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: c.forestBg, borderRadius: BorderRadius.circular(12)),
            child:
                Icon(Icons.description_outlined, size: 20, color: c.forestFg),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(l10n.releaseNotesTitle,
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: c.text)),
                      if (_drafts.isNotEmpty)
                        Pill(l10n.releaseNotesDrafts(_drafts.length),
                            tone: PillTone.promoted),
                    ]),
                const SizedBox(height: 2),
                Text(l10n.releaseNotesSub,
                    style:
                        TextStyle(fontSize: 13, height: 1.4, color: c.caption)),
              ],
            ),
          ),
          Icon(Icons.chevron_right, size: 18, color: c.label),
        ]),
      ),
    );
  }
}

/// Every release, drafts and published, newest first, plus "New release".
/// Reached from Admin tools (phone) and the web sidebar's Admin group.
class ReleaseNotesAdminScreen extends ConsumerStatefulWidget {
  const ReleaseNotesAdminScreen({super.key});

  @override
  ConsumerState<ReleaseNotesAdminScreen> createState() =>
      _ReleaseNotesAdminScreenState();
}

class _ReleaseNotesAdminScreenState
    extends ConsumerState<ReleaseNotesAdminScreen> {
  List<ReleaseNote>? _releases;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _failed = false);
    try {
      final all = [
        ...await ref.read(releaseNotesServiceProvider).getAdminReleases()
      ]..sort((a, b) => compareVersions(b.version, a.version));
      if (mounted) setState(() => _releases = all);
    } catch (e) {
      debugPrint('ReleaseNotesAdminScreen: load failed: $e');
      if (mounted) setState(() => _failed = true);
    }
  }

  Set<String> get _taken => {for (final r in _releases ?? []) r.version};

  Future<void> _edit(ReleaseNote note, {bool isNew = false}) async {
    final published = await Navigator.of(context).push(
        PageTransitions.slideFromRight(AndroidReleaseNotesEditor(
            draft: note, takenVersions: isNew ? _taken : null)));
    if (published == true) _load();
  }

  /// Prefills the installed version unless it already has notes.
  Future<void> _new() async {
    final v = await ref.read(releaseNotesServiceProvider).appVersion();
    if (!mounted) return;
    await _edit(
        ReleaseNote(
          version: _taken.contains(v) ? '' : v,
          draft: true,
          platforms: [for (final p in releasePlatforms) ReleasePlatform(p)],
        ),
        isNew: true);
  }

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    final releases = _releases;
    return Scaffold(
      backgroundColor: c.ground,
      appBar: AndroidTopBar(title: l10n.releaseNotesTitle),
      body: _Narrow(ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              onPressed: releases == null ? null : _new,
              icon: const Icon(Icons.add, size: 18),
              label: Text(l10n.releaseNotesNew),
              style: OutlinedButton.styleFrom(
                foregroundColor: c.text,
                side: BorderSide(color: c.line),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_failed)
            Center(
              child: OutlinedButton(onPressed: _load, child: Text(l10n.retry)),
            )
          else if (releases == null)
            const Center(child: CircularProgressIndicator())
          else if (releases.isEmpty)
            Text(l10n.releaseNotesEmpty,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: c.textMuted))
          else
            Container(
              decoration: WandererTheme.cardDecoration(context),
              clipBehavior: Clip.antiAlias,
              child: Material(
                type: MaterialType.transparency,
                child: Column(children: [
                  for (final (i, r) in releases.indexed)
                    ListTile(
                      onTap: () => _edit(r),
                      minVerticalPadding: 12,
                      shape: i == 0
                          ? null
                          : Border(top: BorderSide(color: c.lineSoft)),
                      title: Text(r.version,
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: c.text)),
                      subtitle: r.headline.isEmpty
                          ? null
                          : Text(r.headline,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 13, color: c.caption)),
                      trailing: Pill(
                          r.draft
                              ? l10n.releaseNotesDraft
                              : l10n.releaseNotesLive,
                          tone:
                              r.draft ? PillTone.promoted : PillTone.completed),
                    ),
                ]),
              ),
            ),
        ],
      )),
    );
  }
}
