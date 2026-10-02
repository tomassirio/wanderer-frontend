import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' hide Visibility;
import 'package:wanderer_frontend/core/constants/enums.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/presentation/widgets/android/android_ui.dart';
import 'package:wanderer_frontend/presentation/widgets/create_trip/web_create_trip_layout.dart';

/// Android "New trip" body from the canvas (AndroidNewTrip): source toggle,
/// labelled fields, trip length cards, visibility radio list, auto check-in
/// card and one sticky orange button. State lives in CreateTripScreen.
class NewTripForm extends StatelessWidget {
  static const intervals = [15, 20, 30, 60];

  final GlobalKey<FormState> formKey;
  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final TripModality modality;
  final ValueChanged<TripModality> onModalityChanged;
  final Visibility visibility;
  final ValueChanged<Visibility> onVisibilityChanged;
  final bool automaticUpdates;
  final ValueChanged<bool> onAutomaticUpdatesChanged;
  final int intervalMinutes;
  final ValueChanged<int> onIntervalChanged;

  /// Empty hides the "From scratch / From a plan" toggle.
  final List<TripPlan> plans;
  final bool fromPlan;
  final ValueChanged<bool> onFromPlanChanged;
  final TripPlan? selectedPlan;
  final ValueChanged<TripPlan> onPlanSelected;

  final bool isLoading;
  final VoidCallback onCreate;

  // Coach-mark targets (see CreateTripScreen tutorial).
  final Key? titleKey;
  final Key? tripTypeKey;
  final Key? visibilityKey;
  final Key? autoUpdatesKey;
  final Key? createButtonKey;

  const NewTripForm({
    super.key,
    required this.formKey,
    required this.titleController,
    required this.descriptionController,
    required this.modality,
    required this.onModalityChanged,
    required this.visibility,
    required this.onVisibilityChanged,
    required this.automaticUpdates,
    required this.onAutomaticUpdatesChanged,
    required this.intervalMinutes,
    required this.onIntervalChanged,
    required this.plans,
    required this.fromPlan,
    required this.onFromPlanChanged,
    required this.selectedPlan,
    required this.onPlanSelected,
    required this.isLoading,
    required this.onCreate,
    this.titleKey,
    this.tripTypeKey,
    this.visibilityKey,
    this.autoUpdatesKey,
    this.createButtonKey,
  });

  static TextStyle _label(WandererColors c) =>
      TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.text);

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    final canCreate = !fromPlan || selectedPlan != null;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (plans.isNotEmpty) ...[
                  _SourceToggle(
                    labels: [l10n.newTripFromScratch, l10n.newTripFromPlan],
                    selected: fromPlan ? 1 : 0,
                    onSelect: (i) => onFromPlanChanged(i == 1),
                  ),
                  const SizedBox(height: 18),
                ],
                if (fromPlan) _planList(context) else _form(context),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: BoxDecoration(
            color: c.ground,
            border: Border(top: BorderSide(color: c.line)),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 56,
              child: FilledButton(
                key: createButtonKey,
                onPressed: isLoading || !canCreate ? null : onCreate,
                style: FilledButton.styleFrom(
                  backgroundColor: WandererTheme.trail,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  textStyle: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white),
                      )
                    : Text(fromPlan
                        ? l10n.newTripCreateFromPlan
                        : l10n.newTripCreate),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _form(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KeyedSubtree(
            key: titleKey,
            child: LabeledField(
              label: l10n.newTripName,
              hint: l10n.newTripNameHint,
              controller: titleController,
              textInputAction: TextInputAction.next,
              validator: (v) => v == null || v.trim().isEmpty
                  ? l10n.newTripNameRequired
                  : null,
            ),
          ),
          const SizedBox(height: 18),
          LabeledField(
            label: '${l10n.newTripDescription} ${l10n.newTripOptional}',
            hint: l10n.newTripDescriptionHint,
            controller: descriptionController,
            maxLines: 3,
          ),
          const SizedBox(height: 18),
          Text(l10n.newTripHowLong, style: _label(c)),
          const SizedBox(height: 8),
          KeyedSubtree(
            key: tripTypeKey,
            child: Row(
              children: [
                for (final (m, name, desc) in [
                  (
                    TripModality.simple,
                    l10n.newTripSingleDay,
                    l10n.newTripSingleDayCaption
                  ),
                  (
                    TripModality.multiDay,
                    l10n.newTripMultiDay,
                    l10n.newTripMultiDayCaption
                  ),
                ]) ...[
                  if (m == TripModality.multiDay) const SizedBox(width: 10),
                  Expanded(
                    child: _choiceCard(context,
                        selected: modality == m,
                        onTap: () => onModalityChanged(m),
                        name: name,
                        desc: desc),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(l10n.newTripWhoCanSee, style: _label(c)),
          const SizedBox(height: 8),
          KeyedSubtree(
            key: visibilityKey,
            child: _radioList(context, [
              for (final v in Visibility.values)
                (
                  v == visibility,
                  () => onVisibilityChanged(v),
                  _visibilityName(l10n, v),
                  _visibilityCaption(l10n, v),
                ),
            ]),
          ),
          if (!kIsWeb) ...[
            const SizedBox(height: 18),
            KeyedSubtree(key: autoUpdatesKey, child: _autoCheckIn(context)),
          ],
        ],
      ),
    );
  }

  Widget _choiceCard(BuildContext context,
      {required bool selected,
      required VoidCallback onTap,
      required String name,
      required String desc}) {
    final c = WandererTheme.of(context);
    return Material(
      color: selected ? c.trailSoftBg : c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: selected
            ? const BorderSide(color: WandererTheme.trail, width: 2)
            : BorderSide(color: c.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: c.text)),
              const SizedBox(height: 4),
              Text(desc,
                  style: TextStyle(fontSize: 13, color: c.textMuted),
                  maxLines: 2),
            ],
          ),
        ),
      ),
    );
  }

  /// White card of radio rows: (selected, onTap, title, caption).
  Widget _radioList(
      BuildContext context, List<(bool, VoidCallback, String, String)> rows) {
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
          Row(
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
                value: automaticUpdates,
                onChanged: onAutomaticUpdatesChanged,
                activeColor: Colors.white,
                activeTrackColor: WandererTheme.trail,
              ),
            ],
          ),
          if (automaticUpdates) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                for (final m in intervals) ...[
                  if (m != intervals.first) const SizedBox(width: 8),
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
    final on = minutes == intervalMinutes;
    return Material(
      color: on ? c.neutralButtonBg : c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: on ? c.neutralButtonBg : c.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onIntervalChanged(minutes),
        child: SizedBox(
          height: 48,
          child: Center(
            child: Text(
              WebCreateTripLayout.intervalLabel(context.l10n, minutes),
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: on ? c.neutralButtonFg : c.textMuted),
            ),
          ),
        ),
      ),
    );
  }

  Widget _planList(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.newTripPickPlan, style: _label(c)),
        const SizedBox(height: 8),
        _radioList(context, [
          for (final p in plans)
            (
              p.id == selectedPlan?.id,
              () => onPlanSelected(p),
              p.name,
              TripModality.fromJson(p.planType) == TripModality.multiDay
                  ? l10n.newTripMultiDay
                  : l10n.newTripSingleDay,
            ),
        ]),
      ],
    );
  }

  static String _visibilityName(AppLocalizations l10n, Visibility v) =>
      switch (v) {
        Visibility.public => l10n.newTripPublic,
        Visibility.protected => l10n.newTripFriends,
        Visibility.private => l10n.newTripPrivate,
      };

  static String _visibilityCaption(AppLocalizations l10n, Visibility v) =>
      switch (v) {
        Visibility.public => l10n.newTripPublicCaption,
        Visibility.protected => l10n.newTripFriendsCaption,
        Visibility.private => l10n.newTripPrivateCaption,
      };
}

/// "From scratch / From a plan" segmented control on a raised track.
class _SourceToggle extends StatelessWidget {
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;

  const _SourceToggle(
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
              child: Material(
                color: i == selected ? c.surface : Colors.transparent,
                borderRadius: BorderRadius.circular(11),
                child: InkWell(
                  borderRadius: BorderRadius.circular(11),
                  onTap: () => onSelect(i),
                  child: SizedBox(
                    height: 44,
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
        ],
      ),
    );
  }
}
