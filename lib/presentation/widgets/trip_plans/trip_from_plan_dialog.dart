import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter/services.dart';
import 'package:wanderer_frontend/core/constants/enums.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';

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
    return AlertDialog(
      title: Text(l10n.createTripFromPlan),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Create a trip from "${widget.planName}"'),
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
                        _automaticUpdates
                            ? 'Location shared automatically'
                            : 'You can enable this later',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
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
                  labelText: 'Interval (min $_minIntervalMinutes min)',
                  hintText: 'e.g., 15',
                  suffixText: 'min',
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
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: Text(l10n.cancel),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: Text(l10n.create),
        ),
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
