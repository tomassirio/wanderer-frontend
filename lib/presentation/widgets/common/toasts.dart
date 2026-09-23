import 'package:flutter/material.dart';
import 'package:wanderer_frontend/core/constants/api_endpoints.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/services/navigation_service.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/presentation/widgets/common/notifications_dropdown.dart';

/// Kinds from the canvas "Live notifications" pattern; the coloured icon
/// chip carries the meaning, never a full-colour background.
enum ToastKind {
  /// Your own action worked (copied, saved, trip started).
  success,

  /// A trip you follow moved or posted, or a neutral info message.
  info,

  /// Comments, reactions, follows; shows the person's initial / avatar.
  social,

  /// A badge was unlocked.
  achievement,

  /// Needs a decision; has buttons and stays until handled.
  request,

  /// Connection lost or something failed; stays until closed.
  error,
}

/// One live notification.
class ToastData {
  final ToastKind kind;
  final String title;
  final String? body;

  /// Social: initial and optional avatar shown in the chip.
  final String? initial;
  final String? avatarUrl;

  /// Optional link line ("Open live map →").
  final String? linkLabel;
  final VoidCallback? onLink;

  /// Request: Accept / Decline buttons.
  final Future<void> Function()? onAccept;
  final Future<void> Function()? onDecline;

  /// Toasts sharing a key within [groupWindow] merge into one; the title
  /// then comes from [groupedTitle] with the running count.
  final String? groupKey;
  final String Function(int count)? groupedTitle;

  /// Info icon override (e.g. a place pin for trip updates).
  final IconData? icon;

  const ToastData({
    required this.kind,
    required this.title,
    this.body,
    this.initial,
    this.avatarUrl,
    this.linkLabel,
    this.onLink,
    this.onAccept,
    this.onDecline,
    this.groupKey,
    this.groupedTitle,
    this.icon,
  });

  /// Requests and problems stay until the person acts or closes them.
  bool get sticky => kind == ToastKind.request || kind == ToastKind.error;
}

class _Entry {
  final int id;
  ToastData data;
  int count = 1;
  final DateTime createdAt = DateTime.now();
  _Entry(this.id, this.data);
}

/// App-wide toast stack (web). Show with `Toasts.show(ToastData(...))`.
///
/// Bottom-right, newest on top, at most 3 visible; older ones collapse
/// into a "+N more" chip that opens the notifications panel. Timed toasts
/// disappear after 5 s (hover pauses). Bursts with the same `groupKey`
/// within a minute merge into one toast.
class Toasts {
  Toasts._();

  static const maxVisible = 3;
  static const duration = Duration(seconds: 5);
  static const groupWindow = Duration(minutes: 1);

  static final ValueNotifier<List<_Entry>> _entries = ValueNotifier([]);
  static int _nextId = 0;

  static void show(ToastData data) {
    final list = [..._entries.value];
    if (data.groupKey != null) {
      final i = list.indexWhere((e) =>
          e.data.groupKey == data.groupKey &&
          DateTime.now().difference(e.createdAt) < groupWindow);
      if (i >= 0) {
        final e = list.removeAt(i)..count += 1;
        e.data = data;
        list.insert(0, e);
        _entries.value = list;
        return;
      }
    }
    list.insert(0, _Entry(_nextId++, data));
    _entries.value = list;
  }

  /// Removes every toast with [groupKey] (e.g. "Live updates paused" once
  /// the connection is back).
  static void dismiss(String groupKey) {
    _entries.value =
        _entries.value.where((e) => e.data.groupKey != groupKey).toList();
  }

  static void _dismiss(int id) {
    _entries.value = _entries.value.where((e) => e.id != id).toList();
  }

  /// Test helper.
  @visibleForTesting
  static void clear() => _entries.value = [];
}

/// Renders the toast stack over the whole app. Place once, above the
/// navigator (MaterialApp.builder), web only.
class ToastHost extends StatelessWidget {
  final Widget child;
  const ToastHost({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        ValueListenableBuilder<List<_Entry>>(
          valueListenable: Toasts._entries,
          builder: (context, entries, _) {
            if (entries.isEmpty) return const SizedBox.shrink();
            final phone = MediaQuery.sizeOf(context).width < 600;
            final visible = entries.take(Toasts.maxVisible).toList();
            final hidden = entries.length - visible.length;
            final column = Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
                  phone ? CrossAxisAlignment.stretch : CrossAxisAlignment.end,
              children: [
                if (hidden > 0) ...[
                  _MoreChip(count: hidden),
                  const SizedBox(height: 12),
                ],
                for (final e in visible) ...[
                  _ToastCard(
                    key: ValueKey(e.id),
                    entry: e,
                    onDismiss: () => Toasts._dismiss(e.id),
                  ),
                  if (e != visible.last) const SizedBox(height: 12),
                ],
              ],
            );
            return Positioned(
              right: phone ? 12 : 24,
              left: phone ? 12 : null,
              top: phone ? MediaQuery.paddingOf(context).top + 12 : null,
              bottom: phone ? null : 24,
              child: Semantics(
                liveRegion: true,
                child: Material(type: MaterialType.transparency, child: column),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _MoreChip extends StatelessWidget {
  final int count;
  const _MoreChip({required this.count});

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    return Material(
      color: c.surface,
      shape: StadiumBorder(side: BorderSide(color: c.line)),
      elevation: 0,
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: () {
          final ctx = NavigationService().navigatorKey.currentContext;
          if (ctx == null) return;
          final size = MediaQuery.sizeOf(ctx);
          Toasts.clear();
          showNotificationsDropdown(
            context: ctx,
            position: RelativeRect.fromLTRB(size.width - 420, 72, 24, 0),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            context.l10n.toastMoreInNotifications(count),
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: c.neutralFg),
          ),
        ),
      ),
    );
  }
}

class _ToastCard extends StatefulWidget {
  final _Entry entry;
  final VoidCallback onDismiss;
  const _ToastCard({super.key, required this.entry, required this.onDismiss});

  @override
  State<_ToastCard> createState() => _ToastCardState();
}

class _ToastCardState extends State<_ToastCard> with TickerProviderStateMixin {
  late final AnimationController _timer =
      AnimationController(vsync: this, duration: Toasts.duration);
  late final AnimationController _enter = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 220))
    ..forward();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (!widget.entry.data.sticky) {
      _timer.addStatusListener((s) {
        if (s == AnimationStatus.completed) widget.onDismiss();
      });
      _timer.forward();
    }
  }

  @override
  void didUpdateWidget(covariant _ToastCard old) {
    super.didUpdateWidget(old);
    // A grouped burst refreshes the timer.
    if (!widget.entry.data.sticky) _timer.forward(from: 0);
  }

  @override
  void dispose() {
    _timer.dispose();
    _enter.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function()? action) async {
    if (action == null || _busy) return;
    setState(() => _busy = true);
    try {
      await action();
      widget.onDismiss();
    } catch (e) {
      // Keep the toast so the person can retry; the action reports errors.
      debugPrint('Toast action failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  (Color, Color) _chip(WandererColors c, bool dark) =>
      switch (widget.entry.data.kind) {
        ToastKind.success => (c.forestBg, c.forestFg),
        ToastKind.info => (c.skyBg, c.skyFg),
        ToastKind.social || ToastKind.request => (c.trailSoftBg, c.trailSoftFg),
        ToastKind.achievement => (
            c.goldBg,
            dark ? c.goldFg : WandererTheme.goldIcon
          ),
        ToastKind.error => dark
            ? (const Color(0xFF4A2320), const Color(0xFFF4A39A))
            : (const Color(0xFFFDECEA), const Color(0xFFB42318)),
      };

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final d = widget.entry.data;
    final (chipBg, chipFg) = _chip(c, dark);
    final title = widget.entry.count > 1 && d.groupedTitle != null
        ? d.groupedTitle!(widget.entry.count)
        : d.title;
    final phone = MediaQuery.sizeOf(context).width < 600;

    final Widget chipChild = switch (d.kind) {
      ToastKind.success => Icon(Icons.check, size: 18, color: chipFg),
      ToastKind.info =>
        Icon(d.icon ?? Icons.info_outline, size: 18, color: chipFg),
      ToastKind.social => d.avatarUrl != null && d.avatarUrl!.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                ApiEndpoints.resolveThumbnailUrl(d.avatarUrl),
                width: 36,
                height: 36,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _initial(d, chipFg),
              ),
            )
          : _initial(d, chipFg),
      ToastKind.achievement =>
        Icon(Icons.emoji_events_outlined, size: 18, color: chipFg),
      ToastKind.request =>
        Icon(Icons.person_add_alt_1_outlined, size: 18, color: chipFg),
      ToastKind.error =>
        Icon(Icons.warning_amber_rounded, size: 18, color: chipFg),
    };

    final card = Container(
      width: phone ? null : 380,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.line),
        boxShadow: [
          BoxShadow(
            color: dark ? const Color(0x59000000) : const Color(0x243C2814),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 12, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: chipBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: chipChild,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: c.text)),
                      if (d.body != null && d.body!.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(d.body!,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 13,
                                height: 1.45,
                                color: c.textMuted)),
                      ],
                      if (d.linkLabel != null && d.onLink != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: InkWell(
                            onTap: () {
                              d.onLink!();
                              widget.onDismiss();
                            },
                            child: Text('${d.linkLabel} →',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: c.accentText)),
                          ),
                        ),
                      if (d.kind == ToastKind.request &&
                          (d.onAccept != null || d.onDecline != null))
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Wrap(spacing: 8, children: [
                            if (d.onAccept != null)
                              FilledButton(
                                onPressed:
                                    _busy ? null : () => _run(d.onAccept),
                                style: FilledButton.styleFrom(
                                  backgroundColor: c.neutralButtonBg,
                                  foregroundColor: c.neutralButtonFg,
                                  minimumSize: const Size(0, 34),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                  textStyle: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700),
                                ),
                                child: Text(l10n.acceptRequest),
                              ),
                            if (d.onDecline != null)
                              OutlinedButton(
                                onPressed:
                                    _busy ? null : () => _run(d.onDecline),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(0, 34),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                  textStyle: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700),
                                ),
                                child: Text(l10n.toastDecline),
                              ),
                          ]),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                SizedBox(
                  width: 32,
                  height: 32,
                  // No IconButton tooltip: the host sits above the
                  // navigator's Overlay, which tooltips need.
                  child: Semantics(
                    label: l10n.toastDismiss,
                    button: true,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: widget.onDismiss,
                      child: Icon(Icons.close, size: 14, color: c.textMuted),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (!d.sticky)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AnimatedBuilder(
                animation: _timer,
                builder: (context, _) => Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: 1 - _timer.value,
                    child: Container(height: 3, color: chipFg.withOpacity(0.6)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    return MouseRegion(
      onEnter: (_) {
        if (!d.sticky) _timer.stop();
      },
      onExit: (_) {
        if (!d.sticky) _timer.forward();
      },
      child: FadeTransition(
        opacity: _enter,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.15), end: Offset.zero)
              .animate(CurvedAnimation(parent: _enter, curve: Curves.easeOut)),
          child: card,
        ),
      ),
    );
  }

  Widget _initial(ToastData d, Color fg) => Text(
        (d.initial ?? '?').characters.first.toUpperCase(),
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: fg),
      );
}
