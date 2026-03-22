import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wanderer_frontend/core/constants/enums.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/presentation/helpers/ui_helpers.dart';

/// Minimum allowed update interval in minutes (Android WorkManager limitation)
const int _minIntervalMinutes = 15;

/// Widget for controlling trip automatic update settings
/// Only shown on mobile (not web), only for trip owners, and only when trip is created or in progress
class TripSettingsControl extends StatefulWidget {
  final bool automaticUpdates;
  final int? updateRefresh; // in seconds
  final TripModality? tripModality;
  final bool isOwner;
  final bool isLoading;
  final Function(
          bool automaticUpdates, int? updateRefresh, TripModality? tripModality)
      onSettingsChange;

  /// Current trip status - settings only shown when trip is created or in progress
  final TripStatus tripStatus;

  /// Trip ID for triggering test background updates
  final String? tripId;

  /// Callback to trigger a test background update immediately
  final VoidCallback? onTestBackgroundUpdate;

  /// Whether running on web platform. Defaults to [kIsWeb].
  /// Can be overridden for testing purposes.
  final bool? isWeb;

  const TripSettingsControl({
    super.key,
    required this.automaticUpdates,
    this.updateRefresh,
    this.tripModality,
    required this.isOwner,
    required this.isLoading,
    required this.onSettingsChange,
    required this.tripStatus,
    this.tripId,
    this.onTestBackgroundUpdate,
    this.isWeb,
  });

  @override
  State<TripSettingsControl> createState() => _TripSettingsControlState();
}

class _TripSettingsControlState extends State<TripSettingsControl> {
  late bool _automaticUpdates;
  late TextEditingController _intervalController;
  TripModality? _tripModality;

  /// The saved interval text — used to detect whether the user actually
  /// changed the value so the Save button can be grayed-out when nothing
  /// has been modified.
  late String _savedIntervalText;

  @override
  void initState() {
    super.initState();
    _automaticUpdates = widget.automaticUpdates;
    _tripModality = widget.tripModality;
    // Convert seconds to minutes for display, enforce minimum
    final minutes = widget.updateRefresh != null
        ? (widget.updateRefresh! / 60).round().clamp(_minIntervalMinutes, 9999)
        : _minIntervalMinutes;
    _intervalController = TextEditingController(
      text: minutes.toString(),
    );
    _savedIntervalText = _intervalController.text;
    _intervalController.addListener(_onIntervalChanged);
  }

  @override
  void didUpdateWidget(TripSettingsControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.automaticUpdates != widget.automaticUpdates) {
      _automaticUpdates = widget.automaticUpdates;
    }
    if (oldWidget.tripModality != widget.tripModality) {
      _tripModality = widget.tripModality;
    }
    if (oldWidget.updateRefresh != widget.updateRefresh) {
      // Convert seconds to minutes for display, enforce minimum
      final minutes = widget.updateRefresh != null
          ? (widget.updateRefresh! / 60)
              .round()
              .clamp(_minIntervalMinutes, 9999)
          : _minIntervalMinutes;
      _intervalController.text = minutes.toString();
      _savedIntervalText = _intervalController.text;
    }
  }

  @override
  void dispose() {
    _intervalController.removeListener(_onIntervalChanged);
    _intervalController.dispose();
    super.dispose();
  }

  /// Triggers a rebuild so the Save button reacts to interval text changes.
  void _onIntervalChanged() {
    setState(() {});
  }

  /// Whether the interval has been modified from the last-saved value.
  bool get _isIntervalDirty => _intervalController.text != _savedIntervalText;

  /// Validates the interval field when the user finishes editing.
  /// If the value is empty or below the minimum, resets to the minimum
  /// and shows a snackbar informing the user.
  void _validateAndClampInterval() {
    final text = _intervalController.text.trim();
    final parsed = int.tryParse(text);
    if (text.isEmpty || parsed == null || parsed < _minIntervalMinutes) {
      setState(() {
        _intervalController.text = _minIntervalMinutes.toString();
        _intervalController.selection = TextSelection.collapsed(
          offset: _intervalController.text.length,
        );
      });
      if (mounted) {
        UiHelpers.showErrorMessage(
          context,
          'Minimum interval is $_minIntervalMinutes minutes',
        );
      }
    }
  }

  void _handleSave() {
    _validateAndClampInterval();
    final minutes = int.tryParse(_intervalController.text);
    if (_automaticUpdates &&
        (minutes == null || minutes < _minIntervalMinutes)) {
      UiHelpers.showErrorMessage(
        context,
        'Minimum interval is $_minIntervalMinutes minutes',
      );
      // Reset to minimum if invalid
      if (minutes != null && minutes < _minIntervalMinutes) {
        setState(() {
          _intervalController.text = _minIntervalMinutes.toString();
        });
      }
      return;
    }
    // Convert minutes to seconds for the backend
    final seconds = minutes != null ? minutes * 60 : null;
    widget.onSettingsChange(_automaticUpdates, seconds, _tripModality);
    // After a successful save, update the saved baseline so the button
    // grays out again until the next edit.
    setState(() {
      _savedIntervalText = _intervalController.text;
    });
  }

  @override
  Widget build(BuildContext context) {
    final effectiveIsWeb = widget.isWeb ?? kIsWeb;

    // Only show on mobile (not web)
    if (effectiveIsWeb) {
      return const SizedBox.shrink();
    }

    // Only show for trip owners
    if (!widget.isOwner) {
      return const SizedBox.shrink();
    }

    // Only show when trip is created or in progress
    if (widget.tripStatus != TripStatus.inProgress &&
        widget.tripStatus != TripStatus.created) {
      return const SizedBox.shrink();
    }

    final l10n = context.l10n;
    final bool isTripInProgress = widget.tripStatus == TripStatus.inProgress;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: WandererTheme.glassBackgroundFor(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: WandererTheme.glassBorderColorFor(context),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Trip Modality selector - hidden when already multi-day (irreversible)
          if (widget.tripModality != TripModality.multiDay) ...[
            Row(
              children: [
                Icon(
                  Icons.route,
                  size: 16,
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.tripType,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildModalityButton(
                    label: l10n.simple,
                    modality: TripModality.simple,
                    disabled: false,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildModalityButton(
                    label: l10n.multiDay,
                    modality: TripModality.multiDay,
                    disabled: false,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          Row(
            children: [
              Icon(
                Icons.settings,
                size: 16,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
              const SizedBox(width: 8),
              Text(
                l10n.automaticUpdates,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              Switch(
                value: _automaticUpdates,
                onChanged: widget.isLoading || !isTripInProgress
                    ? null
                    : (value) {
                        setState(() {
                          _automaticUpdates = value;
                        });
                        // Auto-save immediately on toggle so the backend is
                        // always in sync. Previously only toggling OFF was
                        // auto-saved, which meant enabling updates was never
                        // persisted until the user also changed the interval.
                        final minutes = int.tryParse(_intervalController.text);
                        final seconds = minutes != null ? minutes * 60 : null;
                        widget.onSettingsChange(value, seconds, _tripModality);
                      },
                activeColor: WandererTheme.primaryOrange,
              ),
            ],
          ),
          if (!isTripInProgress && _automaticUpdates) ...[
            const SizedBox(height: 4),
            Text(
              l10n.willActivateWhenStarted,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          if (_automaticUpdates && isTripInProgress) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _intervalController,
                    enabled: !widget.isLoading,
                    keyboardType: TextInputType.number,
                    textCapitalization: TextCapitalization.none,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    decoration: InputDecoration(
                      labelText:
                          'Update Interval (min $_minIntervalMinutes min)',
                      hintText: 'e.g., 15',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      isDense: true,
                      suffixText: 'min',
                    ),
                    style: const TextStyle(fontSize: 13),
                    onEditingComplete: _validateAndClampInterval,
                    onTapOutside: (_) {
                      _validateAndClampInterval();
                      FocusScope.of(context).unfocus();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: (widget.isLoading || !_isIntervalDirty)
                      ? null
                      : _handleSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: WandererTheme.primaryOrange,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        WandererTheme.primaryOrange.withOpacity(0.4),
                    disabledForegroundColor: Colors.white70,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    minimumSize: const Size(0, 32),
                  ),
                  child: widget.isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          l10n.save,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l10n.locationInterval,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
          // Debug-only: Test background update button
          if (kDebugMode && widget.onTestBackgroundUpdate != null) ...[
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed:
                    widget.isLoading ? null : widget.onTestBackgroundUpdate,
                icon: const Icon(Icons.bug_report, size: 16),
                label: Text(
                  l10n.testBackgroundUpdate,
                  style: const TextStyle(fontSize: 12),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.deepOrange,
                  side: const BorderSide(color: Colors.deepOrange),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              ),
            ),
            Text(
              l10n.firesWorkManagerTask,
              style: TextStyle(
                fontSize: 10,
                color:
                    Theme.of(context).colorScheme.onSurface.withOpacity(0.45),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildModalityButton({
    required String label,
    required TripModality modality,
    required bool disabled,
  }) {
    final isSelected = _tripModality == modality;
    return OutlinedButton(
      onPressed: (widget.isLoading || disabled)
          ? null
          : () {
              setState(() {
                _tripModality = modality;
              });
            },
      style: OutlinedButton.styleFrom(
        backgroundColor: isSelected ? WandererTheme.primaryOrange : null,
        foregroundColor: isSelected ? Colors.white : null,
        side: BorderSide(
          color: isSelected
              ? WandererTheme.primaryOrange
              : WandererTheme.glassBorderColorFor(context),
        ),
        padding: const EdgeInsets.symmetric(vertical: 8),
        minimumSize: const Size(0, 32),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
