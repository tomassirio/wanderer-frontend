import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/presentation/helpers/ui_helpers.dart';
import 'package:wanderer_frontend/presentation/widgets/common/toasts.dart';
import 'package:wanderer_frontend/presentation/widgets/common/wanderer_sheet.dart';
import 'package:wanderer_frontend/presentation/widgets/trip_plans/web_plan_editor_layout.dart'
    show PlanPlacementMode;

export 'package:wanderer_frontend/presentation/widgets/trip_plans/web_plan_editor_layout.dart'
    show PlanPlacementMode;

const _shadow = [
  BoxShadow(color: Color(0x261B1A17), blurRadius: 12, offset: Offset(0, 4))
];

/// Success / error feedback: floating notification on web (unchanged),
/// canvas toast on Android.
void planNotify(BuildContext context, String message, {bool error = false}) {
  if (kIsWeb) {
    error
        ? UiHelpers.showErrorMessage(context, message)
        : UiHelpers.showSuccessMessage(context, message);
    return;
  }
  Toasts.show(ToastData(
      kind: error ? ToastKind.error : ToastKind.success, title: message));
}

/// Android delete-plan confirmation sheet; true when confirmed.
Future<bool> confirmPlanDelete(BuildContext context, String planName) async {
  final l10n = context.l10n;
  final c = WandererTheme.of(context);
  final error = Theme.of(context).colorScheme.error;
  final ok = await showWandererSheet<bool>(
    context,
    title: l10n.tripPlansDeleteTitle,
    builder: (sheet) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(l10n.tripPlansDeleteMessage(planName),
            style: TextStyle(fontSize: 15, color: c.textMuted)),
        const SizedBox(height: 20),
        SizedBox(
          height: 56,
          child: FilledButton(
            onPressed: () => Navigator.pop(sheet, true),
            style: FilledButton.styleFrom(
              backgroundColor: error,
              foregroundColor: Theme.of(context).colorScheme.onError,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: Text(l10n.tripPlansDeleteAction),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 48,
          child: TextButton(
            onPressed: () => Navigator.pop(sheet, false),
            style: TextButton.styleFrom(foregroundColor: c.text),
            child: Text(l10n.tripPlansKeepPlan),
          ),
        ),
      ],
    ),
  );
  return ok == true;
}

/// "Fri 3 Apr – Thu 21 May 2026 · 49 days", or null without dates.
String? planDateRange(BuildContext context, DateTime? start, DateTime? end) {
  if (start == null || end == null) return null;
  final locale = Localizations.localeOf(context).toString();
  final days =
      DateUtils.dateOnly(end).difference(DateUtils.dateOnly(start)).inDays + 1;
  return '${DateFormat('EEE d MMM', locale).format(start)} – '
      '${DateFormat('EEE d MMM yyyy', locale).format(end)} · '
      '${context.l10n.daysCount(days)}';
}

/// Floating white round map control (48dp).
class PlanMapButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final Color? color;
  final double radius;
  const PlanMapButton(
      {super.key,
      required this.icon,
      required this.tooltip,
      this.onTap,
      this.color,
      this.radius = 999});

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(radius),
            boxShadow: _shadow),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(radius),
            onTap: onTap,
            child: Icon(icon,
                size: 22, color: onTap == null ? c.label : (color ?? c.text)),
          ),
        ),
      ),
    );
  }
}

/// White bottom sheet panel over a map: 28dp top corners and a handle.
class PlanSheet extends StatelessWidget {
  final List<Widget> children;
  const PlanSheet({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x1F1B1A17), blurRadius: 30, offset: Offset(0, -8))
        ],
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                      color: c.line, borderRadius: BorderRadius.circular(999)),
                ),
              ),
              for (final (i, w) in children.indexed) ...[
                if (i > 0) const SizedBox(height: 14),
                w,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Android plan editor (canvas "New plan" / "Edit plan"): full-screen map,
/// floating close / title / undo, Start · Stop · Finish chips, a
/// my-location button and the form in a bottom sheet.
class PlanEditorLayout extends StatelessWidget {
  final Widget map;
  final String title;
  final String closeTooltip;
  final VoidCallback onClose;
  final VoidCallback? onUndo;
  final VoidCallback? onMyLocation;
  final PlanPlacementMode mode;
  final ValueChanged<PlanPlacementMode> onModeChanged;
  final int stopCount;
  final String? mapHint;
  final List<Widget> sheet;

  const PlanEditorLayout({
    super.key,
    required this.map,
    required this.title,
    required this.closeTooltip,
    required this.onClose,
    required this.onUndo,
    required this.mode,
    required this.onModeChanged,
    required this.stopCount,
    required this.sheet,
    this.onMyLocation,
    this.mapHint,
  });

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: c.mapGround,
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(child: map),
                Positioned(
                  left: 16,
                  right: 16,
                  top: 0,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              PlanMapButton(
                                  icon: Icons.close,
                                  tooltip: closeTooltip,
                                  onTap: onClose),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Container(
                                  height: 48,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  alignment: Alignment.centerLeft,
                                  decoration: BoxDecoration(
                                      color: c.surface,
                                      borderRadius: BorderRadius.circular(999),
                                      boxShadow: _shadow),
                                  child: Text(title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: c.text)),
                                ),
                              ),
                              const SizedBox(width: 10),
                              PlanMapButton(
                                  icon: Icons.undo,
                                  tooltip: l10n.planEditorUndo,
                                  onTap: onUndo),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            clipBehavior: Clip.none,
                            child: Row(
                              children: [
                                _ModeChip(
                                    mode: PlanPlacementMode.start,
                                    label: l10n.planEditorStart,
                                    selected: mode == PlanPlacementMode.start,
                                    onTap: onModeChanged),
                                const SizedBox(width: 8),
                                _ModeChip(
                                    mode: PlanPlacementMode.stop,
                                    label: stopCount > 0
                                        ? '${l10n.planEditorAddStop} · $stopCount'
                                        : l10n.planEditorStop,
                                    selected: mode == PlanPlacementMode.stop,
                                    onTap: onModeChanged),
                                const SizedBox(width: 8),
                                _ModeChip(
                                    mode: PlanPlacementMode.finish,
                                    label: l10n.planEditorFinish,
                                    selected: mode == PlanPlacementMode.finish,
                                    onTap: onModeChanged),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (mapHint != null)
                  Positioned(
                    left: 24,
                    right: 24,
                    bottom: 16,
                    child: IgnorePointer(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                            color: const Color(0xD11B1A17),
                            borderRadius: BorderRadius.circular(12)),
                        child: Text(mapHint!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 13, color: Colors.white)),
                      ),
                    ),
                  ),
                if (onMyLocation != null)
                  Positioned(
                    right: 16,
                    bottom: mapHint != null ? 76 : 16,
                    child: PlanMapButton(
                        icon: Icons.my_location,
                        tooltip: l10n.planMyLocation,
                        color: c.skyFg,
                        radius: 14,
                        onTap: onMyLocation),
                  ),
              ],
            ),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.55),
            child: PlanSheet(children: sheet),
          ),
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  final PlanPlacementMode mode;
  final String label;
  final bool selected;
  final ValueChanged<PlanPlacementMode> onTap;
  const _ModeChip(
      {required this.mode,
      required this.label,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    final dot = switch (mode) {
      PlanPlacementMode.start => BoxDecoration(
          color: selected ? c.forestFg : WandererTheme.forest,
          shape: BoxShape.circle),
      PlanPlacementMode.stop => BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: WandererTheme.trail, width: 2)),
      PlanPlacementMode.finish =>
        const BoxDecoration(color: WandererTheme.trail, shape: BoxShape.circle),
    };
    return Semantics(
      selected: selected,
      button: true,
      child: GestureDetector(
        onTap: () => onTap(mode),
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
              color: selected ? c.neutralButtonBg : c.surface,
              borderRadius: BorderRadius.circular(10),
              boxShadow: _shadow),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 10, height: 10, decoration: dot),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                      color: selected ? c.neutralButtonFg : c.textMuted)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Green numbered "what to do next" hint at the top of the editor sheet.
class PlanStepHint extends StatelessWidget {
  final int step;
  final String text;
  const PlanStepHint({super.key, required this.step, required this.text});

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
          color: c.forestBg, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
                color: WandererTheme.forest, shape: BoxShape.circle),
            child: Text('$step',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style: TextStyle(fontSize: 14, height: 1.4, color: c.text)),
          ),
        ],
      ),
    );
  }
}

/// Single day / Multi-day segmented control.
class PlanTypeToggle extends StatelessWidget {
  final bool multiDay;
  final ValueChanged<bool> onChanged;
  const PlanTypeToggle(
      {super.key, required this.multiDay, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    Widget seg(String label, bool value) {
      final on = multiDay == value;
      return Expanded(
        child: Semantics(
          selected: on,
          button: true,
          child: GestureDetector(
            onTap: () => onChanged(value),
            child: Container(
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: on ? c.surface : Colors.transparent,
                borderRadius: BorderRadius.circular(9),
                boxShadow: on
                    ? const [
                        BoxShadow(
                            color: Color(0x141B1A17),
                            blurRadius: 3,
                            offset: Offset(0, 1))
                      ]
                    : null,
              ),
              child: Text(label,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: on ? FontWeight.w700 : FontWeight.w600,
                      color: on ? c.text : c.textMuted)),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
          color: c.ground, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        seg(l10n.newTripSingleDay, false),
        const SizedBox(width: 4),
        seg(l10n.newTripMultiDay, true),
      ]),
    );
  }
}

/// Leave / Arrive date tiles; both open the range picker.
class PlanDateTiles extends StatelessWidget {
  final DateTime? start;
  final DateTime? end;
  final VoidCallback onPick;
  const PlanDateTiles(
      {super.key,
      required this.start,
      required this.end,
      required this.onPick});

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    final fmt = DateFormat(
        'EEE d MMM yyyy', Localizations.localeOf(context).toString());
    Widget tile(String label, DateTime? d) => Expanded(
          child: Material(
            color: c.surface,
            shape: RoundedRectangleBorder(
                side: BorderSide(color: c.line),
                borderRadius: BorderRadius.circular(14)),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onPick,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: TextStyle(fontSize: 12, color: c.caption)),
                    Text(d == null ? l10n.planEditorPickDate : fmt.format(d),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: d == null ? c.label : c.text)),
                  ],
                ),
              ),
            ),
          ),
        );
    return Row(children: [
      tile(l10n.planEditorLeave, start),
      const SizedBox(width: 10),
      tile(l10n.planEditorArrive, end),
    ]);
  }
}

/// 56dp primary (orange) sheet button; greyed when [onPressed] is null.
class PlanPrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;
  const PlanPrimaryButton(
      {super.key,
      required this.label,
      this.icon,
      this.onPressed,
      this.loading = false});

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    return SizedBox(
      height: 56,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: WandererTheme.trail,
          foregroundColor: Colors.white,
          disabledBackgroundColor: c.raised,
          disabledForegroundColor: c.label,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: Colors.white))
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
                ],
              ),
      ),
    );
  }
}
