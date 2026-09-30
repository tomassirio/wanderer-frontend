import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter/services.dart';
import 'package:wanderer_frontend/core/constants/enums.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/presentation/widgets/android/plan_editor_layout.dart';
import 'package:wanderer_frontend/presentation/widgets/common/wanderer_dialog.dart';
import 'package:wanderer_frontend/presentation/widgets/common/wanderer_sheet.dart';

/// Dialog that collects all parameters needed to create a trip from a plan.
/// The trip modality is inherited from the plan's type.
/// Returns a [TripFromPlanRequest] or null if cancelled.
class TripFromPlanDialog extends StatefulWidget {
  final String planName;
  final String planType;

  const TripFromPlanDialog({
    super.key,
    required this.planName,
    required this.planType,
  });

  /// Shows the dialog: canvas form popup on web, AlertDialog on mobile.
  static Future<TripFromPlanRequest?> show(
    BuildContext context, {
    required String planName,
    required String planType,
  }) {
    Widget builder(BuildContext context) =>
        TripFromPlanDialog(planName: planName, planType: planType);
    return kIsWeb
        ? WandererDialog.show<TripFromPlanRequest>(context,
            width: WandererDialog.formWidth, builder: builder)
        : showWandererSheet<TripFromPlanRequest>(context,
            title: context.l10n.planDetailStartTrip,
            builder: (_) =>
                _AndroidStartPlanSheet(planName: planName, planType: planType));
  }

  @override
  State<TripFromPlanDialog> createState() => _TripFromPlanDialogState();
}

class _TripFromPlanDialogState extends State<TripFromPlanDialog> {
  Visibility _visibility = Visibility.public;
  late final TripModality _modality;
  bool _automaticUpdates = false;
  final _intervalController = TextEditingController(text: '15');
  static const int _minIntervalMinutes = 15;

  @override
  void initState() {
    super.initState();
    _modality = TripModality.fromJson(widget.planType);
  }

  @override
  void dispose() {
    _intervalController.dispose();
    super.dispose();
  }

  void _submit() {
    final interval =
        int.tryParse(_intervalController.text) ?? _minIntervalMinutes;
    final clampedInterval =
        interval < _minIntervalMinutes ? _minIntervalMinutes : interval;

    final request = TripFromPlanRequest(
      visibility: _visibility,
      tripModality: _modality,
      automaticUpdates: _automaticUpdates ? true : null,
      updateRefresh: _automaticUpdates ? clampedInterval : null,
    );
    Navigator.pop(context, request);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = WandererTheme.of(context);
    final body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(kIsWeb
            ? l10n.dialogsFromPlanIntro(widget.planName)
            : 'Create a trip from "${widget.planName}"'),
        const SizedBox(height: 16),

        // Visibility
        Text(
          l10n.visibility,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        _buildVisibilityOption(
          icon: Icons.public,
          title: l10n.publicVisibility,
          subtitle: l10n.visibleToEveryone,
          value: Visibility.public,
        ),
        _buildVisibilityOption(
          icon: Icons.group,
          title: l10n.protectedVisibility,
          subtitle: l10n.visibleToFriendsOnly,
          value: Visibility.protected,
        ),
        _buildVisibilityOption(
          icon: Icons.lock,
          title: l10n.privateVisibility,
          subtitle: l10n.onlyVisibleToYou,
          value: Visibility.private,
        ),
        const Divider(height: 24),

        // Automatic updates
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.automaticUpdates,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    kIsWeb
                        ? (_automaticUpdates
                            ? l10n.dialogsFromPlanAutoOn
                            : l10n.dialogsFromPlanAutoOff)
                        : (_automaticUpdates
                            ? 'Location shared automatically'
                            : 'You can enable this later'),
                    style: TextStyle(
                      fontSize: 12,
                      color: kIsWeb ? c.textMuted : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: _automaticUpdates,
              onChanged: (v) => setState(() => _automaticUpdates = v),
            ),
          ],
        ),
        if (_automaticUpdates) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _intervalController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: kIsWeb
                  ? l10n.dialogsFromPlanInterval(_minIntervalMinutes)
                  : 'Interval (min $_minIntervalMinutes min)',
              hintText: kIsWeb ? l10n.automaticUpdatesIntervalHint : 'e.g., 15',
              suffixText: kIsWeb ? l10n.dialogsMinutesSuffix : 'min',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
          ),
        ],
      ],
    );
    final createButton = ElevatedButton(
      onPressed: _submit,
      child: Text(l10n.create),
    );
    if (kIsWeb) {
      return WandererFormDialog(
        title: l10n.createTripFromPlan,
        body: body,
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context, null),
            child: Text(l10n.cancel),
          ),
          createButton,
        ],
      );
    }
    return AlertDialog(
      title: Text(l10n.createTripFromPlan),
      content: SingleChildScrollView(child: body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: Text(l10n.cancel),
        ),
        createButton,
      ],
    );
  }

  Widget _buildVisibilityOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Visibility value,
  }) {
    return RadioListTile<Visibility>(
      value: value,
      groupValue: _visibility,
      onChanged: (v) => setState(() => _visibility = v!),
      title: Text(title, style: const TextStyle(fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      secondary: Icon(icon, size: 20),
      dense: true,
      contentPadding: EdgeInsets.zero,
    );
  }
}

/// Android "Start this trip" sheet (canvas AndroidStartPlan): who can see
/// it, auto check-in with interval chips, Start trip now / Not yet.
class _AndroidStartPlanSheet extends StatefulWidget {
  final String planName;
  final String planType;
  const _AndroidStartPlanSheet(
      {required this.planName, required this.planType});

  @override
  State<_AndroidStartPlanSheet> createState() => _AndroidStartPlanSheetState();
}

class _AndroidStartPlanSheetState extends State<_AndroidStartPlanSheet> {
  static const _intervals = [15, 20, 30, 60];
  Visibility _visibility = Visibility.public;
  bool _auto = false;
  int _every = 20;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = WandererTheme.of(context);
    final options = [
      (Visibility.public, l10n.newTripPublic, l10n.newTripPublicCaption),
      (Visibility.protected, l10n.newTripFriends, l10n.newTripFriendsCaption),
      (Visibility.private, l10n.newTripPrivate, l10n.newTripPrivateCaption),
    ];
    final border = BorderSide(color: c.line);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Transform.translate(
          offset: const Offset(0, -12),
          child: Text(l10n.planStartFromPlan(widget.planName),
              style: TextStyle(fontSize: 14, color: c.textMuted)),
        ),
        Text(l10n.newTripWhoCanSee,
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700, color: c.text)),
        const SizedBox(height: 8),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
              border: Border.fromBorderSide(border),
              borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: [
              for (final (i, (value, name, desc)) in options.indexed)
                Material(
                  color: c.surface,
                  child: InkWell(
                    onTap: () => setState(() => _visibility = value),
                    child: Semantics(
                      selected: _visibility == value,
                      inMutuallyExclusiveGroup: true,
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 58),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                            border: i < options.length - 1
                                ? Border(bottom: BorderSide(color: c.lineSoft))
                                : null),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name,
                                      style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: c.text)),
                                  Text(desc,
                                      style: TextStyle(
                                          fontSize: 13, color: c.caption)),
                                ],
                              ),
                            ),
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: _visibility == value
                                    ? Border.all(
                                        color: WandererTheme.trail, width: 7)
                                    : Border.all(color: c.label, width: 2),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          decoration: BoxDecoration(
              border: Border.fromBorderSide(border),
              borderRadius: BorderRadius.circular(16)),
          child: Column(
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
                        Text(l10n.planAutoCheckInCaption,
                            style: TextStyle(fontSize: 13, color: c.caption)),
                      ],
                    ),
                  ),
                  Switch(
                    value: _auto,
                    activeTrackColor: WandererTheme.trail,
                    onChanged: (v) => setState(() => _auto = v),
                  ),
                ],
              ),
              if (_auto) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    for (final (i, m) in _intervals.indexed) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(
                        child: _IntervalChip(
                          label: m < 60
                              ? l10n.newTripMinutes(m)
                              : l10n.newTripHours(m ~/ 60),
                          selected: _every == m,
                          onTap: () => setState(() => _every = m),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        PlanPrimaryButton(
          label: l10n.planStartNow,
          icon: Icons.play_arrow_rounded,
          onPressed: () => Navigator.pop(
            context,
            TripFromPlanRequest(
              visibility: _visibility,
              tripModality: TripModality.fromJson(widget.planType),
              automaticUpdates: _auto ? true : null,
              updateRefresh: _auto ? _every : null,
            ),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 48,
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
                foregroundColor: c.text,
                textStyle:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            child: Text(l10n.planNotYet),
          ),
        ),
      ],
    );
  }
}

class _IntervalChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _IntervalChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    return Material(
      color: selected ? c.neutralButtonBg : c.surface,
      shape: RoundedRectangleBorder(
          side: BorderSide(color: selected ? c.neutralButtonBg : c.line),
          borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: SizedBox(
          height: 44,
          child: Center(
            child: Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: selected ? c.neutralButtonFg : c.textMuted)),
          ),
        ),
      ),
    );
  }
}
