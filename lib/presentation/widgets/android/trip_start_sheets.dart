import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' hide Visibility;
import 'package:wanderer_frontend/core/constants/enums.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/presentation/widgets/android/plan_editor_layout.dart';
import 'package:wanderer_frontend/presentation/widgets/common/wanderer_sheet.dart';

/// Sheets of the "Ready to start" trip screen (canvas Proposal B and D).
/// The controls are the ones the old New trip form had, moved here.

/// B · One sheet for who sees it, auto check-in + interval and length.
/// [lengthFixed] hides the length choice (a plan's type decides it).
/// Returns the new settings, or null when dismissed.
Future<TripStartSettings?> showTripStartSettings(
  BuildContext context, {
  required TripStartSettings settings,
  bool fromLastTrip = false,
  bool lengthFixed = false,
}) =>
    showWandererSheet<TripStartSettings>(
      context,
      title: context.l10n.tripSettings,
      builder: (_) => _TripStartSettingsSheet(
          initial: settings,
          fromLastTrip: fromLastTrip,
          lengthFixed: lengthFixed),
    );

class _TripStartSettingsSheet extends StatefulWidget {
  final TripStartSettings initial;
  final bool fromLastTrip;
  final bool lengthFixed;
  const _TripStartSettingsSheet(
      {required this.initial,
      required this.fromLastTrip,
      required this.lengthFixed});

  @override
  State<_TripStartSettingsSheet> createState() =>
      _TripStartSettingsSheetState();
}

class _TripStartSettingsSheetState extends State<_TripStartSettingsSheet> {
  static const _intervals = [15, 20, 30, 60];
  late TripStartSettings _s = widget.initial;

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    final label =
        TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Transform.translate(
          offset: const Offset(0, -12),
          child: Text(
              widget.fromLastTrip
                  ? l10n.readySettingsFromLastTrip
                  : l10n.readySettingsChangeLater,
              style: TextStyle(fontSize: 13, color: c.caption)),
        ),
        Text(l10n.newTripWhoCanSee, style: label),
        const SizedBox(height: 8),
        TripStartRadioList(rows: [
          for (final v in [
            Visibility.public,
            Visibility.protected,
            Visibility.private
          ])
            (
              v == _s.visibility,
              () => setState(() => _s = _s.copyWith(visibility: v)),
              visibilityName(l10n, v),
              _visibilityCaption(l10n, v),
            ),
        ]),
        // Browsers can't check in on a schedule; tracking lives in the app.
        if (!kIsWeb) ...[
          const SizedBox(height: 16),
          _autoCheckIn(context),
        ],
        if (!widget.lengthFixed) ...[
          const SizedBox(height: 16),
          Text(l10n.newTripHowLong, style: label),
          const SizedBox(height: 8),
          _Segmented(
            labels: [l10n.newTripSingleDay, l10n.newTripMultiDay],
            selected: _s.modality == TripModality.multiDay ? 1 : 0,
            onSelect: (i) => setState(() => _s = _s.copyWith(
                modality:
                    i == 1 ? TripModality.multiDay : TripModality.simple)),
          ),
        ],
        // Native only: the phone records the route.
        if (!kIsWeb &&
            (_s.automaticUpdates || _s.modality == TripModality.simple)) ...[
          const SizedBox(height: 16),
          Text(l10n.recordingTitle, style: label),
          const SizedBox(height: 8),
          RecordingProfilePicker(
            selected:
                _s.recordingProfile ?? RecordingProfile.defaultFor(_s.modality),
            checkInMinutes: _s.automaticUpdates ? _s.intervalMinutes : null,
            onSelect: (p) =>
                setState(() => _s = _s.copyWith(recordingProfile: p)),
          ),
        ],
        const SizedBox(height: 20),
        SizedBox(
          height: 56,
          child: FilledButton(
            key: const Key('ready_settings_done'),
            onPressed: () => Navigator.pop(context, _s),
            style: FilledButton.styleFrom(
              backgroundColor: c.neutralButtonBg,
              foregroundColor: c.neutralButtonFg,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              textStyle:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            child: Text(l10n.done),
          ),
        ),
      ],
    );
  }

  Widget _autoCheckIn(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MergeSemantics(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.newTripAutoCheckIn,
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: c.text)),
                      Text(l10n.newTripAutoCheckInCaption,
                          style: TextStyle(fontSize: 13, color: c.textMuted)),
                    ],
                  ),
                ),
                Switch(
                  key: const Key('ready_auto_switch'),
                  value: _s.automaticUpdates,
                  onChanged: (v) =>
                      setState(() => _s = _s.copyWith(automaticUpdates: v)),
                  activeColor: Colors.white,
                  activeTrackColor: WandererTheme.trail,
                ),
              ],
            ),
          ),
          if (_s.automaticUpdates) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                for (final m in _intervals) ...[
                  if (m != _intervals.first) const SizedBox(width: 8),
                  Expanded(child: _intervalChip(context, m)),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _intervalChip(BuildContext context, int minutes) {
    final c = WandererTheme.of(context);
    final on = minutes == _s.intervalMinutes;
    return Semantics(
      selected: on,
      button: true,
      child: Material(
        color: on ? c.neutralButtonBg : c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: on ? c.neutralButtonBg : c.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () =>
              setState(() => _s = _s.copyWith(intervalMinutes: minutes)),
          child: SizedBox(
            height: 48,
            child: Center(
              child: Text(
                intervalLabel(context.l10n, minutes),
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: on ? c.neutralButtonFg : c.textMuted),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "15 min" / "1 h".
String intervalLabel(AppLocalizations l10n, int minutes) => minutes < 60
    ? l10n.newTripMinutes(minutes)
    : l10n.newTripHours(minutes ~/ 60);

String visibilityName(AppLocalizations l10n, Visibility v) => switch (v) {
      Visibility.public => l10n.newTripPublic,
      Visibility.protected => l10n.newTripFriends,
      Visibility.private => l10n.newTripPrivate,
    };

String _visibilityCaption(AppLocalizations l10n, Visibility v) => switch (v) {
      Visibility.public => l10n.newTripPublicCaption,
      Visibility.protected => l10n.newTripFriendsCaption,
      Visibility.private => l10n.newTripPrivateCaption,
    };

/// Live / Battery saver radio rows with what each costs and gives.
/// [checkInMinutes] is the automatic check-in interval, null when off.
class RecordingProfilePicker extends StatelessWidget {
  final RecordingProfile selected;
  final int? checkInMinutes;
  final ValueChanged<RecordingProfile> onSelect;
  const RecordingProfilePicker(
      {super.key,
      required this.selected,
      required this.checkInMinutes,
      required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return TripStartRadioList(rows: [
      for (final p in RecordingProfile.values)
        (
          p == selected,
          () => onSelect(p),
          recordingProfileName(l10n, p),
          switch (p) {
            RecordingProfile.live => l10n.recordingLiveCaption,
            RecordingProfile.saver => checkInMinutes == null
                ? l10n.recordingSaverCaption
                : l10n.recordingSaverCheckIns(
                    intervalLabel(l10n, checkInMinutes!)),
          },
        ),
    ]);
  }
}

String recordingProfileName(AppLocalizations l10n, RecordingProfile p) =>
    switch (p) {
      RecordingProfile.live => l10n.recordingLive,
      RecordingProfile.saver => l10n.recordingSaver,
    };

/// White card of radio rows: (selected, onTap, title, caption).
class TripStartRadioList extends StatelessWidget {
  final List<(bool, VoidCallback, String, String)> rows;
  const TripStartRadioList({super.key, required this.rows});

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) Divider(height: 1, color: c.lineSoft),
            Semantics(
              inMutuallyExclusiveGroup: true,
              checked: rows[i].$1,
              button: true,
              child: InkWell(
                onTap: rows[i].$2,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 60),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(rows[i].$3,
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: c.text)),
                              Text(rows[i].$4,
                                  style: TextStyle(
                                      fontSize: 13, color: c.textMuted)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: rows[i].$1
                                ? Border.all(
                                    color: WandererTheme.trail, width: 7)
                                : Border.all(color: c.caption, width: 2),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Two-way segmented control on a raised track.
class _Segmented extends StatelessWidget {
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;

  const _Segmented(
      {required this.labels, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
          color: c.raised, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Semantics(
                selected: i == selected,
                button: true,
                child: Material(
                  color: i == selected ? c.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(11),
                    onTap: () => onSelect(i),
                    child: SizedBox(
                      height: 48,
                      child: Center(
                        child: Text(labels[i],
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: i == selected
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                color: i == selected ? c.text : c.textMuted)),
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

/// D · What the person picked when closing a trip that never started.
enum ReadyCloseChoice { saveAsPlan, startNow, discard }

/// "Not leaving yet?": Save as a plan, Actually start it now, Discard.
/// Null when the sheet is dismissed (stay on the ready screen).
Future<ReadyCloseChoice?> showReadyCloseSheet(BuildContext context) {
  final c = WandererTheme.of(context);
  final l10n = context.l10n;
  return showWandererSheet<ReadyCloseChoice>(
    context,
    title: l10n.readyCloseTitle,
    builder: (sheet) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Transform.translate(
          offset: const Offset(0, -10),
          child: Text(l10n.readyCloseBody,
              style: TextStyle(fontSize: 14, height: 1.5, color: c.textMuted)),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 56,
          child: FilledButton.icon(
            key: const Key('ready_save_plan'),
            onPressed: () => Navigator.pop(sheet, ReadyCloseChoice.saveAsPlan),
            icon: const Icon(Icons.calendar_month_outlined, size: 18),
            label: Text(l10n.readySaveAsPlan),
            style: FilledButton.styleFrom(
              backgroundColor: c.neutralButtonBg,
              foregroundColor: c.neutralButtonFg,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              textStyle:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(height: 12),
        PlanPrimaryButton(
          key: const Key('ready_start_now'),
          label: l10n.readyStartNow,
          icon: Icons.play_arrow_rounded,
          onPressed: () => Navigator.pop(sheet, ReadyCloseChoice.startNow),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 48,
          child: TextButton(
            key: const Key('ready_discard'),
            onPressed: () => Navigator.pop(sheet, ReadyCloseChoice.discard),
            style: TextButton.styleFrom(
                foregroundColor: c.text,
                textStyle:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            child: Text(l10n.readyDiscard),
          ),
        ),
      ],
    ),
  );
}

/// "Or start one of your plans": pick one; null when dismissed.
Future<TripPlan?> showReadyPlanPicker(
    BuildContext context, List<TripPlan> plans) {
  final l10n = context.l10n;
  return showWandererSheet<TripPlan>(
    context,
    title: l10n.newTripPickPlan,
    builder: (sheet) => TripStartRadioList(rows: [
      for (final p in plans)
        (
          false,
          () => Navigator.pop(sheet, p),
          p.name,
          TripModality.fromJson(p.planType) == TripModality.multiDay
              ? l10n.newTripMultiDay
              : l10n.newTripSingleDay,
        ),
    ]),
  );
}
