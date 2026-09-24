import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/presentation/widgets/common/web_page_header.dart';

/// What the next map click places.
enum PlanPlacementMode { start, stop, finish }

/// Web trip plan editor (canvas "New trip plan" / "Edit trip plan"):
/// breadcrumb + title with Cancel / Save, a 400px form panel (name, single /
/// multi-day, dates, route summary, optional description) and the map card
/// with a floating placement-mode picker and zoom / undo controls.
///
/// Purely presentational: the owning screen keeps all state and passes the
/// map widget in. Used by `CreateTripPlanScreen` (create) and
/// `TripPlanDetailScreen` (edit mode).
class WebPlanEditorLayout extends StatelessWidget {
  final String breadcrumbCurrent;
  final VoidCallback onBreadcrumbTap;
  final String title;
  final String saveLabel;
  final VoidCallback onCancel;
  final VoidCallback? onSave;
  final bool isSaving;

  final TextEditingController nameController;
  final TextEditingController? descriptionController;
  final bool multiDay;
  final ValueChanged<bool> onMultiDayChanged;
  final DateTime? startDate;
  final DateTime? endDate;
  final VoidCallback onPickStartDate;
  final VoidCallback onPickEndDate;

  /// Label for each route point; null means "not placed yet".
  final String? startLabel;
  final String? finishLabel;
  final int stopCount;

  /// e.g. "124 km planned"; null shows "Nothing placed yet" when empty.
  final String? routeMeta;

  final PlanPlacementMode placementMode;
  final ValueChanged<PlanPlacementMode> onPlacementModeChanged;
  final VoidCallback? onZoomIn;
  final VoidCallback? onZoomOut;
  final VoidCallback? onUndo;

  final Widget map;

  /// Create mode: card over the map asking where the trip starts.
  final bool showStartHint;

  /// Optional extra content under the form (e.g. errors).
  final Widget? footer;

  /// Called when a pointer goes down on a floating map control. On Flutter
  /// Web the click also reaches the map platform view underneath, so the
  /// screen should ignore the map tap that follows.
  final VoidCallback? onOverlayPointerDown;

  const WebPlanEditorLayout({
    super.key,
    required this.breadcrumbCurrent,
    required this.onBreadcrumbTap,
    required this.title,
    required this.saveLabel,
    required this.onCancel,
    required this.onSave,
    this.isSaving = false,
    required this.nameController,
    this.descriptionController,
    required this.multiDay,
    required this.onMultiDayChanged,
    required this.startDate,
    required this.endDate,
    required this.onPickStartDate,
    required this.onPickEndDate,
    required this.startLabel,
    required this.finishLabel,
    required this.stopCount,
    this.routeMeta,
    required this.placementMode,
    required this.onPlacementModeChanged,
    this.onZoomIn,
    this.onZoomOut,
    this.onUndo,
    required this.map,
    this.showStartHint = false,
    this.footer,
    this.onOverlayPointerDown,
  });

  Widget _guard(Widget child) => Listener(
        onPointerDown: (_) => onOverlayPointerDown?.call(),
        child: child,
      );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = WandererTheme.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 1100;

    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Breadcrumb(
          parent: l10n.tripPlansTitle,
          current: breadcrumbCurrent,
          onParentTap: onBreadcrumbTap,
        ),
        const SizedBox(height: 8),
        WebPageHeader(
          title: title,
          actions: [
            OutlinedButton(onPressed: onCancel, child: Text(l10n.cancel)),
          ],
          primaryAction: ElevatedButton.icon(
            onPressed: isSaving ? null : onSave,
            icon: isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.check, size: 16),
            label: Text(saveLabel),
          ),
        ),
      ],
    );

    final form = Container(
      decoration: WandererTheme.cardDecoration(context),
      padding: const EdgeInsets.all(22),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Label(l10n.planEditorName),
            const SizedBox(height: 8),
            TextField(
              controller: nameController,
              decoration: InputDecoration(hintText: l10n.planEditorNameHint),
            ),
            const SizedBox(height: 18),
            _Label(l10n.newTripHowLong),
            const SizedBox(height: 8),
            _Segmented(
              labels: [l10n.newTripSingleDay, l10n.newTripMultiDay],
              selected: multiDay ? 1 : 0,
              onSelected: (i) => onMultiDayChanged(i == 1),
            ),
            const SizedBox(height: 18),
            _Label(l10n.planEditorDates),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _DateBox(
                    label: l10n.planEditorLeave,
                    date: startDate,
                    onTap: onPickStartDate,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DateBox(
                    label: l10n.planEditorArrive,
                    date: endDate,
                    onTap: onPickEndDate,
                  ),
                ),
              ],
            ),
            if (startDate != null && endDate != null) ...[
              const SizedBox(height: 8),
              Text(
                l10n.planEditorDaysOnRoad(
                    endDate!.difference(startDate!).inDays + 1),
                style: TextStyle(fontSize: 13, color: c.textMuted),
              ),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(child: _Label(l10n.planEditorRoute)),
                Text(
                  routeMeta ??
                      (startLabel == null && finishLabel == null
                          ? l10n.planEditorNothingPlaced
                          : ''),
                  style: TextStyle(fontSize: 12, color: c.caption),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _RouteSummary(
              startLabel: startLabel,
              finishLabel: finishLabel,
              stopCount: stopCount,
              onPick: onPlacementModeChanged,
            ),
            if (descriptionController != null) ...[
              const SizedBox(height: 14),
              Theme(
                data: Theme.of(context)
                    .copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: EdgeInsets.zero,
                  initiallyExpanded:
                      descriptionController!.text.trim().isNotEmpty,
                  title: Text(
                    l10n.planEditorAddDescription,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: c.textMuted),
                  ),
                  children: [
                    TextField(
                      controller: descriptionController,
                      minLines: 3,
                      maxLines: 5,
                    ),
                  ],
                ),
              ),
            ],
            if (footer != null) ...[const SizedBox(height: 12), footer!],
          ],
        ),
      ),
    );

    final mapCard = Container(
      clipBehavior: Clip.antiAlias,
      decoration:
          WandererTheme.cardDecoration(context).copyWith(color: c.mapGround),
      child: Stack(
        fit: StackFit.expand,
        children: [
          map,
          Positioned(
            top: 16,
            left: 16,
            child: _guard(_PlacementPicker(
              mode: placementMode,
              onChanged: onPlacementModeChanged,
            )),
          ),
          Positioned(
            top: 16,
            right: 16,
            child: _guard(_MapControls(
              onZoomIn: onZoomIn,
              onZoomOut: onZoomOut,
              onUndo: onUndo,
            )),
          ),
          if (showStartHint)
            Center(
              child: IgnorePointer(
                child: Container(
                  width: 360,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius:
                        BorderRadius.circular(WandererTheme.radiusPanel),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0x261B1A17),
                          blurRadius: 40,
                          offset: Offset(0, 16)),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                            color: c.forestBg, shape: BoxShape.circle),
                        child: Icon(Icons.place_outlined,
                            color: c.forestFg, size: 24),
                      ),
                      const SizedBox(height: 10),
                      Text(l10n.planEditorWhereStart,
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: c.text)),
                      const SizedBox(height: 6),
                      Text(
                        l10n.planEditorWhereStartHint,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 14, height: 1.5, color: c.textMuted),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(wide ? 40 : 16, 24, wide ? 40 : 16, 28),
      child: wide
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header,
                const SizedBox(height: 20),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(width: 400, child: form),
                      const SizedBox(width: 20),
                      Expanded(child: mapCard),
                    ],
                  ),
                ),
              ],
            )
          : ListView(
              children: [
                header,
                const SizedBox(height: 20),
                SizedBox(height: 420, child: mapCard),
                const SizedBox(height: 20),
                form,
              ],
            ),
    );
  }
}

class _Breadcrumb extends StatelessWidget {
  final String parent;
  final String current;
  final VoidCallback onParentTap;
  const _Breadcrumb(
      {required this.parent, required this.current, required this.onParentTap});

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    final style = TextStyle(
        fontSize: 13, fontWeight: FontWeight.w600, color: c.textMuted);
    return Semantics(
      label: 'Breadcrumb',
      child: Wrap(
        spacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          InkWell(
            onTap: onParentTap,
            borderRadius: BorderRadius.circular(6),
            child: Text(parent, style: style),
          ),
          Text('/', style: style.copyWith(color: c.caption)),
          Text(current, style: style.copyWith(color: c.text)),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: WandererTheme.of(context).text));
}

class _Segmented extends StatelessWidget {
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;
  const _Segmented(
      {required this.labels, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.neutralBg,
        borderRadius: BorderRadius.circular(WandererTheme.radiusControl),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Material(
                color: i == selected ? c.surface : Colors.transparent,
                borderRadius: BorderRadius.circular(9),
                child: InkWell(
                  borderRadius: BorderRadius.circular(9),
                  onTap: () => onSelected(i),
                  child: SizedBox(
                    height: 40,
                    child: Center(
                      child: Text(
                        labels[i],
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              i == selected ? FontWeight.w700 : FontWeight.w600,
                          color: i == selected ? c.text : c.textMuted,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DateBox extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  const _DateBox(
      {required this.label, required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    final locale = Localizations.localeOf(context).toString();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(WandererTheme.radiusControl),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(WandererTheme.radiusControl),
          border: Border.all(color: c.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: c.caption)),
            const SizedBox(height: 2),
            Text(
              date == null
                  ? context.l10n.planEditorPickDate
                  : DateFormat('EEE d MMM yyyy', locale).format(date!),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: date == null ? c.label : c.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteSummary extends StatelessWidget {
  final String? startLabel;
  final String? finishLabel;
  final int stopCount;
  final ValueChanged<PlanPlacementMode> onPick;
  const _RouteSummary({
    required this.startLabel,
    required this.finishLabel,
    required this.stopCount,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = WandererTheme.of(context);
    Widget row(
        String caps, Color capsColor, String value, bool set, Widget action) {
      return Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(caps,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: capsColor)),
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: set ? c.text : c.label)),
              ],
            ),
          ),
          action,
        ],
      );
    }

    IconButton edit(PlanPlacementMode m, String tooltip) => IconButton(
          tooltip: tooltip,
          visualDensity: VisualDensity.compact,
          iconSize: 16,
          color: c.textMuted,
          onPressed: () => onPick(m),
          icon: const Icon(Icons.edit_outlined),
        );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.raised,
        borderRadius: BorderRadius.circular(WandererTheme.radiusCard),
      ),
      child: Column(
        children: [
          row(
            l10n.planEditorStartCaps,
            c.forestFg,
            startLabel ?? l10n.planEditorClickMap,
            startLabel != null,
            edit(PlanPlacementMode.start, l10n.planEditorEditStart),
          ),
          const SizedBox(height: 14),
          row(
            l10n.planEditorStopsCaps,
            c.accentText,
            stopCount == 0
                ? l10n.planEditorOptional
                : l10n.planEditorStopsCount(stopCount),
            stopCount > 0,
            OutlinedButton(
              onPressed: () => onPick(PlanPlacementMode.stop),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 32),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                textStyle:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              child: Text(l10n.planEditorAddStop),
            ),
          ),
          const SizedBox(height: 14),
          row(
            l10n.planEditorFinishCaps,
            WandererTheme.trail,
            finishLabel ?? l10n.planEditorNotSet,
            finishLabel != null,
            edit(PlanPlacementMode.finish, l10n.planEditorEditFinish),
          ),
        ],
      ),
    );
  }
}

class _PlacementPicker extends StatelessWidget {
  final PlanPlacementMode mode;
  final ValueChanged<PlanPlacementMode> onChanged;
  const _PlacementPicker({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = WandererTheme.of(context);
    Widget dot(PlanPlacementMode m) => switch (m) {
          PlanPlacementMode.start => Container(
              width: 9,
              height: 9,
              decoration:
                  BoxDecoration(color: c.forestFg, shape: BoxShape.circle)),
          PlanPlacementMode.stop => Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                  color: c.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: WandererTheme.trail, width: 2))),
          PlanPlacementMode.finish => Container(
              width: 9,
              height: 9,
              decoration: const BoxDecoration(
                  color: WandererTheme.trail, shape: BoxShape.circle)),
        };
    final labels = {
      PlanPlacementMode.start: l10n.planEditorStart,
      PlanPlacementMode.stop: l10n.planEditorStop,
      PlanPlacementMode.finish: l10n.planEditorFinish,
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(WandererTheme.radiusCard),
        boxShadow: const [
          BoxShadow(
              color: Color(0x1A1B1A17), blurRadius: 16, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.planEditorClickToPlace,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: c.textMuted)),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: c.neutralBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final m in PlanPlacementMode.values)
                  Material(
                    color: m == mode ? c.surface : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => onChanged(m),
                      child: Container(
                        height: 34,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            dot(m),
                            const SizedBox(width: 6),
                            Text(
                              labels[m]!,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: m == mode
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                color: m == mode ? c.text : c.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MapControls extends StatelessWidget {
  final VoidCallback? onZoomIn;
  final VoidCallback? onZoomOut;
  final VoidCallback? onUndo;
  const _MapControls({this.onZoomIn, this.onZoomOut, this.onUndo});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = WandererTheme.of(context);
    final buttons = [
      if (onZoomIn != null) (Icons.add, l10n.planEditorZoomIn, onZoomIn!),
      if (onZoomOut != null) (Icons.remove, l10n.planEditorZoomOut, onZoomOut!),
      if (onUndo != null) (Icons.undo, l10n.planEditorUndo, onUndo!),
    ];
    if (buttons.isEmpty) return const SizedBox.shrink();
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(WandererTheme.radiusControl),
        boxShadow: const [
          BoxShadow(
              color: Color(0x141B1A17), blurRadius: 16, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < buttons.length; i++) ...[
            if (i > 0) Container(width: 44, height: 1, color: c.lineSoft),
            SizedBox(
              width: 44,
              height: 44,
              child: IconButton(
                tooltip: buttons[i].$2,
                onPressed: buttons[i].$3,
                color: c.text,
                iconSize: 18,
                icon: Icon(buttons[i].$1),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
