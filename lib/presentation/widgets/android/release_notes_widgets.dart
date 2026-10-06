import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/data/models/domain/release_note.dart';
import 'package:wanderer_frontend/presentation/widgets/common/pill.dart';

/// Release notes building blocks (canvas "2 · Changelog: What's new").

/// New / Improved / Fixed pill.
class ReleaseTypePill extends StatelessWidget {
  final ReleaseChangeType type;
  const ReleaseTypePill(this.type, {super.key});

  static PillTone tone(ReleaseChangeType t) => switch (t) {
        ReleaseChangeType.newFeature => PillTone.promoted,
        ReleaseChangeType.improved => PillTone.progress,
        ReleaseChangeType.fixed => PillTone.completed,
      };

  static String label(BuildContext context, ReleaseChangeType t) => switch (t) {
        ReleaseChangeType.newFeature => context.l10n.releaseTypeNew,
        ReleaseChangeType.improved => context.l10n.releaseTypeImproved,
        ReleaseChangeType.fixed => context.l10n.releaseTypeFixed,
      };

  @override
  Widget build(BuildContext context) =>
      Pill(label(context, type), tone: tone(type));
}

/// One change: pill + bold title, then a muted sentence.
class ReleaseChangeTile extends StatelessWidget {
  final ReleaseChange change;
  const ReleaseChangeTile(this.change, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration:
          BoxDecoration(border: Border(top: BorderSide(color: c.lineSoft))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            ReleaseTypePill(change.type),
            const SizedBox(width: 8),
            Expanded(
              child: Text(change.title,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: c.text)),
            ),
          ]),
          if (change.text.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(change.text,
                style:
                    TextStyle(fontSize: 13, height: 1.45, color: c.textMuted)),
          ],
        ],
      ),
    );
  }
}

/// Platform key used by the release notes API.
String get currentPlatform => kIsWeb ? 'WEB' : 'ANDROID';

/// "Tue 6 Oct 2026" in the app's locale.
String releaseDate(BuildContext context, DateTime? d) => d == null
    ? ''
    : DateFormat('EEE d MMM y', Localizations.localeOf(context).toString())
        .format(d.toLocal());

/// Body of the What's new sheet (A). Shared with the editor's Preview.
class WhatsNewContent extends StatelessWidget {
  final ReleaseNote note;
  final VoidCallback onGotIt;
  final VoidCallback onSeeAll;
  const WhatsNewContent(
      {super.key,
      required this.note,
      required this.onGotIt,
      required this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
                color: c.neutralButtonBg,
                borderRadius: BorderRadius.circular(999)),
            child: Text(l10n.whatsNewPill(note.version),
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: c.neutralButtonFg)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
                releaseDate(context, note.releaseDateOn(currentPlatform)),
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: c.caption)),
          ),
        ]),
        const SizedBox(height: 14),
        Semantics(
          header: true,
          child: Text(note.headline,
              style: WandererTheme.display(26, color: c.text)),
        ),
        const SizedBox(height: 14),
        for (final ch in note.items) ReleaseChangeTile(ch),
        const SizedBox(height: 16),
        SizedBox(
          height: 56,
          child: FilledButton(
            onPressed: onGotIt,
            style: FilledButton.styleFrom(
              backgroundColor: c.neutralButtonBg,
              foregroundColor: c.neutralButtonFg,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              textStyle:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            child: Text(l10n.whatsNewGotIt),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 48,
          child: TextButton(
            onPressed: onSeeAll,
            style: TextButton.styleFrom(
              foregroundColor: c.accentText,
              textStyle:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            child: Text(l10n.whatsNewSeeAll),
          ),
        ),
      ],
    );
  }
}

/// What's new sheet (A). Resolves to true for "See every change", false for
/// "Got it", null when dismissed by dragging or tapping outside.
Future<bool?> showWhatsNewSheet(BuildContext context, ReleaseNote note) {
  final c = WandererTheme.of(context);
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: c.surface,
    barrierColor: const Color(0x731B1A17),
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (ctx) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Center(
          child: Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
                color: c.line, borderRadius: BorderRadius.circular(999)),
          ),
        ),
        WhatsNewContent(
          note: note,
          onGotIt: () => Navigator.pop(ctx, false),
          onSeeAll: () => Navigator.pop(ctx, true),
        ),
      ]),
    ),
  );
}

/// Small trail dot marking unread release notes.
class UnreadDot extends StatelessWidget {
  const UnreadDot({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
        label: context.l10n.whatsNewUnread,
        child: Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
              color: WandererTheme.trail, shape: BoxShape.circle),
        ),
      );
}
