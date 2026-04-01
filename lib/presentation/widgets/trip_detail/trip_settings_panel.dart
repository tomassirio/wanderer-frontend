import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wanderer_frontend/core/constants/enums.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/presentation/helpers/ui_helpers.dart';
import 'package:wanderer_frontend/presentation/widgets/trip_detail/base_panel.dart';

/// Minimum allowed update interval in minutes (Android WorkManager limitation)
const int _settingsMinIntervalMinutes = 15;

/// Maximum allowed update interval in minutes
const int _settingsMaxIntervalMinutes = 9999;

/// Collapsible settings panel shown as a cog-icon bubble when collapsed.
/// Contains: Show Planned Route toggle (all users, all platforms),
/// Trip Type selector (owner + created/in-progress, all platforms), and
/// Automatic Updates settings (owner + created/in-progress + mobile only).
/// Visible when the trip has a planned route OR the current user is the owner
/// and the trip is created or in progress.
class TripSettingsPanel extends StatefulWidget {
  final bool isCollapsed;
  final VoidCallback onToggleCollapse;

  /// Whether the current user owns this trip
  final bool isOwner;

  /// Whether this trip was created from a plan (has planned waypoints)
  final bool tripHasPlannedRoute;

  /// Current state of the planned-route overlay on the map
  final bool showPlannedWaypoints;

  /// Toggled when the user flips the "Show Planned Route" switch
  final VoidCallback? onTogglePlannedWaypoints;

  // --- Automatic-update settings (owner + in-progress only) ---
  final bool automaticUpdates;
  final int? updateRefresh; // in seconds
  final TripModality? tripModality;
  final bool isLoading;
  final Function(bool automaticUpdates, int? updateRefresh,
      TripModality? tripModality)? onSettingsChange;
  final TripStatus tripStatus;
  final String? tripId;
  final VoidCallback? onTestBackgroundUpdate;

  /// Override for tests — defaults to [kIsWeb]
  final bool? isWeb;

  /// Callback to delete the trip (owner only)
  final VoidCallback? onDeleteTrip;

  const TripSettingsPanel({
    super.key,
    required this.isCollapsed,
    required this.onToggleCollapse,
    required this.isOwner,
    required this.tripHasPlannedRoute,
    required this.showPlannedWaypoints,
    this.onTogglePlannedWaypoints,
    required this.automaticUpdates,
    this.updateRefresh,
    this.tripModality,
    required this.isLoading,
    this.onSettingsChange,
    required this.tripStatus,
    this.tripId,
    this.onTestBackgroundUpdate,
    this.isWeb,
    this.onDeleteTrip,
  });

  @override
  State<TripSettingsPanel> createState() => _TripSettingsPanelState();
}

class _TripSettingsPanelState extends State<TripSettingsPanel> {
  late bool _automaticUpdates;
  late TextEditingController _intervalController;
  TripModality? _tripModality;

  /// The saved interval text — used to detect whether the user actually
  /// changed the value so the Save button can be grayed-out when nothing
  /// has been modified.
  late String _savedIntervalText;

  /// Converts seconds to clamped minutes for display in the interval field.
  int _secondsToMinutes(int? seconds) {
    if (seconds == null) return _settingsMinIntervalMinutes;
    return (seconds / 60)
        .round()
        .clamp(_settingsMinIntervalMinutes, _settingsMaxIntervalMinutes);
  }

  @override
  void initState() {
    super.initState();
    _automaticUpdates = widget.automaticUpdates;
    _tripModality = widget.tripModality;
    _intervalController = TextEditingController(
      text: _secondsToMinutes(widget.updateRefresh).toString(),
    );
    _savedIntervalText = _intervalController.text;
    _intervalController.addListener(_onIntervalChanged);
  }

  @override
  void didUpdateWidget(TripSettingsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.automaticUpdates != widget.automaticUpdates) {
      _automaticUpdates = widget.automaticUpdates;
    }
    if (oldWidget.tripModality != widget.tripModality) {
      _tripModality = widget.tripModality;
    }
    if (oldWidget.updateRefresh != widget.updateRefresh) {
      _intervalController.text =
          _secondsToMinutes(widget.updateRefresh).toString();
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

  /// Returns true when there is at least one section to display.
  bool get _hasContent {
    return widget.tripHasPlannedRoute || (widget.isOwner && _isEditableStatus);
  }

  /// Whether the trip status allows editing settings (created or in-progress).
  bool get _isEditableStatus =>
      widget.tripStatus == TripStatus.created ||
      widget.tripStatus == TripStatus.inProgress;

  /// Whether the trip is currently in progress (controls are fully interactive).
  bool get _isTripInProgress => widget.tripStatus == TripStatus.inProgress;

  /// Whether the trip is already multi-day (locked, shown grayed out).
  bool get _isMultiDay => widget.tripModality == TripModality.multiDay;

  void _validateAndClampInterval() {
    final text = _intervalController.text.trim();
    final parsed = int.tryParse(text);
    if (text.isEmpty ||
        parsed == null ||
        parsed < _settingsMinIntervalMinutes) {
      setState(() {
        _intervalController.text = _settingsMinIntervalMinutes.toString();
        _intervalController.selection = TextSelection.collapsed(
          offset: _intervalController.text.length,
        );
      });
      if (mounted) {
        UiHelpers.showErrorMessage(
          context,
          'Minimum interval is $_settingsMinIntervalMinutes minutes',
        );
      }
    }
  }

  void _handleSave() {
    _validateAndClampInterval();
    // After clamping, the value is guaranteed to be valid.
    final minutes = int.tryParse(_intervalController.text);
    final seconds = minutes != null ? minutes * 60 : null;
    widget.onSettingsChange?.call(_automaticUpdates, seconds, _tripModality);
    // After a successful save, update the saved baseline so the button
    // grays out again until the next edit.
    setState(() {
      _savedIntervalText = _intervalController.text;
    });
  }

  /// Prompts the user to confirm switching to multi-day, then auto-saves.
  Future<void> _confirmAndSwitchToMultiDay() async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.switchToMultiDay),
        content: Text(l10n.multiDayConvertConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: WandererTheme.primaryOrange,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() {
        _tripModality = TripModality.multiDay;
      });
      // Auto-save immediately after confirmation
      _handleSave();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasContent) return const SizedBox.shrink();

    final effectiveIsWeb = widget.isWeb ?? kIsWeb;

    return BasePanel(
      isCollapsed: widget.isCollapsed,
      collapsedMargin: const EdgeInsets.only(top: 16, right: 16, bottom: 8),
      collapsedChild: CollapsedBubble(
        icon: Icons.settings,
        onTap: widget.onToggleCollapse,
        margin: const EdgeInsets.only(top: 16, right: 16, bottom: 8),
      ),
      expandedChild: ExpandedCard(
        child: _buildContent(context, effectiveIsWeb),
      ),
    );
  }

  Widget _buildContent(BuildContext context, bool effectiveIsWeb) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        PanelHeader(
          icon: Icons.settings,
          title: l10n.tripSettings,
          onMinimize: widget.onToggleCollapse,
        ),
        const SizedBox(height: 12),

        // Show Planned Route toggle — available to ALL users on ALL platforms
        // when the trip was created from a plan.
        if (widget.tripHasPlannedRoute &&
            widget.onTogglePlannedWaypoints != null) ...[
          _buildPlannedRouteToggle(context, l10n),
          if (widget.isOwner && _isEditableStatus) const SizedBox(height: 12),
        ],

        // Owner-only settings — when trip is created or in progress
        if (widget.isOwner && _isEditableStatus) ...[
          // Trip Type selector — available on all platforms when not
          // already multi-day (irreversible once set).
          _buildSectionLabel(context, Icons.route, l10n.tripType),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildModalityButton(
                  context: context,
                  label: l10n.simple,
                  modality: TripModality.simple,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildModalityButton(
                  context: context,
                  label: l10n.multiDay,
                  modality: TripModality.multiDay,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Automatic Updates — mobile only (WorkManager / background
          // location is an Android concept; not applicable on web).
          if (!effectiveIsWeb) ...[
            Row(
              children: [
                Icon(
                  Icons.update,
                  size: 16,
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
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
                  onChanged: widget.isLoading || !_isTripInProgress
                      ? null
                      : (value) {
                          setState(() {
                            _automaticUpdates = value;
                          });
                          // Auto-save immediately on toggle so the
                          // backend is always in sync. Previously only
                          // toggling OFF was auto-saved, which meant
                          // enabling updates was never persisted until
                          // the user also changed the interval.
                          final minutes =
                              int.tryParse(_intervalController.text);
                          final seconds = minutes != null ? minutes * 60 : null;
                          widget.onSettingsChange
                              ?.call(value, seconds, _tripModality);
                        },
                  activeColor: WandererTheme.primaryOrange,
                ),
              ],
            ),
            if (!_isTripInProgress && _automaticUpdates) ...[
              const SizedBox(height: 4),
              Text(
                l10n.willActivateWhenStarted,
                style: TextStyle(
                  fontSize: 11,
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            if (_automaticUpdates && _isTripInProgress) ...[
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
                            'Update Interval (min $_settingsMinIntervalMinutes min)',
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
                  _buildSaveButton(),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                l10n.locationInterval,
                style: TextStyle(
                  fontSize: 11,
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ] else if (!_automaticUpdates) ...[
              const SizedBox(height: 8),
            ],

            // Debug-only test button
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
        ],

        // Delete Trip — owner only, all statuses except finished
        if (widget.onDeleteTrip != null && _isEditableStatus) ...[
          const Divider(),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: widget.isLoading ? null : widget.onDeleteTrip,
              icon: const Icon(Icons.delete_forever, size: 16),
              label: Text(
                l10n.deleteTrip,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPlannedRouteToggle(BuildContext context, AppLocalizations l10n) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.purple.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.purple.withOpacity(0.2),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.route,
            size: 16,
            color: Colors.purple.shade600,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.showPlannedRoute,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ),
          SizedBox(
            height: 24,
            child: Switch(
              value: widget.showPlannedWaypoints,
              onChanged: (_) => widget.onTogglePlannedWaypoints?.call(),
              activeColor: Colors.purple.shade600,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(BuildContext context, IconData icon, String label) {
    return Row(
      children: [
        Icon(icon,
            size: 16,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildModalityButton({
    required BuildContext context,
    required String label,
    required TripModality modality,
  }) {
    final isSelected = _tripModality == modality;
    final isDisabled = _isMultiDay || widget.isLoading;
    return OutlinedButton(
      onPressed: isDisabled
          ? null
          : () {
              if (modality == TripModality.multiDay) {
                // Confirm before switching to multi-day
                _confirmAndSwitchToMultiDay();
              } else {
                setState(() {
                  _tripModality = modality;
                });
              }
            },
      style: OutlinedButton.styleFrom(
        backgroundColor: isSelected
            ? (_isMultiDay
                ? WandererTheme.primaryOrange.withOpacity(0.4)
                : WandererTheme.primaryOrange)
            : null,
        foregroundColor: isSelected
            ? Colors.white.withOpacity(_isMultiDay ? 0.7 : 1.0)
            : null,
        disabledBackgroundColor:
            isSelected ? WandererTheme.primaryOrange.withOpacity(0.4) : null,
        disabledForegroundColor: isSelected
            ? Colors.white.withOpacity(0.7)
            : Theme.of(context).colorScheme.onSurface.withOpacity(0.45),
        side: BorderSide(
          color: isSelected
              ? WandererTheme.primaryOrange.withOpacity(_isMultiDay ? 0.4 : 1.0)
              : WandererTheme.glassBorderColorFor(context),
        ),
        padding: const EdgeInsets.symmetric(vertical: 8),
        minimumSize: const Size(0, 32),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildSaveButton({bool fullWidth = false}) {
    final button = ElevatedButton(
      onPressed: (widget.isLoading || !_isIntervalDirty) ? null : _handleSave,
      style: ElevatedButton.styleFrom(
        backgroundColor: WandererTheme.primaryOrange,
        foregroundColor: Colors.white,
        disabledBackgroundColor: WandererTheme.primaryOrange.withOpacity(0.4),
        disabledForegroundColor: Colors.white70,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        minimumSize: const Size(0, 32),
      ),
      child: widget.isLoading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Text(
              context.l10n.save,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
    );
    if (fullWidth) {
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
  }
}
