import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter/services.dart';
import 'package:wanderer_frontend/core/constants/enums.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/data/repositories/create_trip_repository.dart';
import 'package:wanderer_frontend/data/services/trip_plan_service.dart';
import 'package:wanderer_frontend/data/services/trip_service.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/presentation/helpers/ui_helpers.dart';
import 'package:wanderer_frontend/presentation/screens/trip_detail_screen.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/presentation/widgets/trip_plans/trip_from_plan_dialog.dart';

/// Screen for creating a new trip with a clean, modern design
class CreateTripScreen extends StatefulWidget {
  const CreateTripScreen({super.key});

  @override
  State<CreateTripScreen> createState() => _CreateTripScreenState();
}

class _CreateTripScreenState extends State<CreateTripScreen> {
  final CreateTripRepository _repository = CreateTripRepository();
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  Visibility _selectedVisibility = Visibility.public;
  TripModality _selectedModality = TripModality.simple;
  bool _isLoading = false;
  TripPlan? _selectedTripPlan;
  List<TripPlan> _tripPlans = [];
  bool _createFromPlan = false;
  bool _automaticUpdates = false;
  final _intervalController = TextEditingController(text: '15');
  static const int _minIntervalMinutes = 15;
  late final TripPlanService _tripPlanService;
  late final TripService _tripService;

  @override
  void initState() {
    super.initState();
    _tripPlanService = TripPlanService();
    _tripService = TripService();
    _loadTripPlans();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _intervalController.dispose();
    super.dispose();
  }

  Future<void> _loadTripPlans() async {
    try {
      final plans = await _tripPlanService.getUserTripPlans();
      setState(() {
        _tripPlans = plans;
      });
    } catch (e) {
      debugPrint('Failed to load trip plans: $e');
    }
  }

  String _formatPlanType(String planType) {
    return planType
        .split('_')
        .map((word) => word[0] + word.substring(1).toLowerCase())
        .join(' ');
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  Future<void> _createTrip() async {
    if (_createFromPlan && _selectedTripPlan != null) {
      await _createTripFromPlan();
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final tripId = await _repository.createTrip(
        name: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        visibility: _selectedVisibility,
        tripModality: _selectedModality,
        automaticUpdates: _automaticUpdates ? true : null,
        updateRefresh: _automaticUpdates
            ? (int.tryParse(_intervalController.text) ?? _minIntervalMinutes) *
                60
            : null,
      );

      final trip = await _repository.getTripById(tripId);

      // Apply creation settings that the backend may not have propagated yet
      // into the query model (e.g. automaticUpdates / updateRefresh).
      final effectiveTrip = _automaticUpdates
          ? trip.copyWith(
              automaticUpdates: true,
              updateRefresh: (int.tryParse(_intervalController.text) ??
                      _minIntervalMinutes) *
                  60,
            )
          : trip;

      if (mounted) {
        UiHelpers.showSuccessMessage(context, 'Trip created successfully!');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => TripDetailScreen(trip: effectiveTrip),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        UiHelpers.showErrorMessage(context, 'Error creating trip: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _createTripFromPlan() async {
    if (_selectedTripPlan == null) return;

    final request = await showDialog<TripFromPlanRequest>(
      context: context,
      builder: (context) => TripFromPlanDialog(
          planName: _selectedTripPlan!.name,
          planType: _selectedTripPlan!.planType),
    );

    if (request == null || !mounted) return;

    setState(() => _isLoading = true);

    try {
      final tripId = await _tripService.createTripFromPlan(
        _selectedTripPlan!.id,
        request,
      );
      final trip = await _tripService.getTripById(tripId);

      if (mounted) {
        UiHelpers.showSuccessMessage(
          context,
          'Trip created from plan successfully!',
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => TripDetailScreen(trip: trip),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        UiHelpers.showErrorMessage(context, 'Error creating trip: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(l10n.newTripTitle),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    // Creation mode toggle
                    if (_tripPlans.isNotEmpty) ...[
                      _buildCreationModeToggle(),
                      const SizedBox(height: 24),
                    ],
                    // Content based on mode
                    if (_createFromPlan)
                      _buildFromPlanSection()
                    else
                      _buildManualForm(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            // Bottom button
            _buildBottomButton(),
          ],
        ),
      ),
    );
  }

  /// Toggle between "Create manually" and "From plan"
  Widget _buildCreationModeToggle() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: _buildModeToggleOption(
              label: 'Create Manually',
              icon: Icons.edit_note_rounded,
              isSelected: !_createFromPlan,
              onTap: () => setState(() => _createFromPlan = false),
            ),
          ),
          Expanded(
            child: _buildModeToggleOption(
              label: 'From Plan',
              icon: Icons.map_outlined,
              isSelected: _createFromPlan,
              onTap: () => setState(() => _createFromPlan = true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeToggleOption({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.surface
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected
                  ? WandererTheme.primaryOrange
                  : Theme.of(context).colorScheme.onSurface.withOpacity(0.45),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected
                    ? Theme.of(context).colorScheme.onSurface
                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.45),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Manual trip creation form
  Widget _buildManualForm() {
    final l10n = context.l10n;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title field
          _buildSectionLabel('Trip Title'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _titleController,
            decoration: InputDecoration(
              hintText: l10n.tripTitleHint,
              hintStyle: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
              ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: WandererTheme.primaryOrange,
                  width: 1.5,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a title';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          // Description field
          _buildSectionLabel('Description'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _descriptionController,
            decoration: InputDecoration(
              hintText: l10n.tripDescriptionHint,
              hintStyle: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
              ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: WandererTheme.primaryOrange,
                  width: 1.5,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 24),
          // Trip Type toggle
          _buildSectionLabel(l10n.tripType),
          const SizedBox(height: 10),
          _buildTripTypeToggle(),
          const SizedBox(height: 24),
          // Visibility selector
          _buildSectionLabel(l10n.visibility),
          const SizedBox(height: 10),
          _buildVisibilitySelector(),
          const SizedBox(height: 24),
          // Automatic Updates section
          _buildAutomaticUpdatesSection(),
        ],
      ),
    );
  }

  /// Trip type segmented toggle (Simple / Multi-Day)
  Widget _buildTripTypeToggle() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
        ),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: _buildTypeOption(
              label: 'Simple',
              subtitle: 'Single-day trip',
              icon: Icons.wb_sunny_outlined,
              modality: TripModality.simple,
            ),
          ),
          Expanded(
            child: _buildTypeOption(
              label: 'Multi-Day',
              subtitle: 'Multi-day journey',
              icon: Icons.luggage_outlined,
              modality: TripModality.multiDay,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeOption({
    required String label,
    required String subtitle,
    required IconData icon,
    required TripModality modality,
  }) {
    final isSelected = _selectedModality == modality;
    return GestureDetector(
      onTap: () => setState(() => _selectedModality = modality),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? WandererTheme.primaryOrange.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color:
                isSelected ? WandererTheme.primaryOrange : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected
                  ? WandererTheme.primaryOrange
                  : Theme.of(context).colorScheme.onSurface.withOpacity(0.45),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? WandererTheme.primaryOrange
                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: isSelected
                    ? WandererTheme.primaryOrange.withOpacity(0.7)
                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.45),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Visibility selector with pill buttons
  Widget _buildVisibilitySelector() {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildVisibilityPill(
              icon: Icons.public,
              label: l10n.publicVisibility,
              visibility: Visibility.public,
            ),
            const SizedBox(width: 8),
            _buildVisibilityPill(
              icon: Icons.group,
              label: l10n.protectedVisibility,
              visibility: Visibility.protected,
            ),
            const SizedBox(width: 8),
            _buildVisibilityPill(
              icon: Icons.lock,
              label: l10n.privateVisibility,
              visibility: Visibility.private,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _getVisibilityDescription(_selectedVisibility),
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.45),
          ),
        ),
      ],
    );
  }

  Widget _buildVisibilityPill({
    required IconData icon,
    required String label,
    required Visibility visibility,
  }) {
    final isSelected = _selectedVisibility == visibility;
    return GestureDetector(
      onTap: () => setState(() => _selectedVisibility = visibility),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? WandererTheme.primaryOrange
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected
                ? WandererTheme.primaryOrange
                : Theme.of(context).colorScheme.outline,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? Colors.white
                  : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getVisibilityDescription(Visibility visibility) {
    switch (visibility) {
      case Visibility.private:
        return 'Only you can see this trip';
      case Visibility.protected:
        return 'Followers or users with a shared link can view';
      case Visibility.public:
        return 'Everyone can see this trip';
    }
  }

  /// Automatic updates toggle with optional interval field
  Widget _buildAutomaticUpdatesSection() {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.update,
              size: 16,
              color: _automaticUpdates
                  ? WandererTheme.primaryOrange
                  : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
            const SizedBox(width: 8),
            Text(
              l10n.automaticUpdates,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const Spacer(),
            Switch(
              value: _automaticUpdates,
              onChanged: (value) {
                setState(() {
                  _automaticUpdates = value;
                });
              },
              activeColor: WandererTheme.primaryOrange,
            ),
          ],
        ),
        Text(
          _automaticUpdates
              ? 'Location will be shared automatically at the set interval'
              : 'You can enable this later from trip settings',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.45),
          ),
        ),
        if (_automaticUpdates) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _intervalController,
                  keyboardType: TextInputType.number,
                  textCapitalization: TextCapitalization.none,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  decoration: InputDecoration(
                    labelText: 'Update Interval (min $_minIntervalMinutes min)',
                    hintText: l10n.automaticUpdatesIntervalHint,
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Theme.of(context)
                            .colorScheme
                            .outline
                            .withOpacity(0.3),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Theme.of(context)
                            .colorScheme
                            .outline
                            .withOpacity(0.3),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: WandererTheme.primaryOrange,
                        width: 1.5,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
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
            ],
          ),
        ],
      ],
    );
  }

  /// Validates the interval field, clamping to minimum if needed
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

  /// "From Plan" section
  Widget _buildFromPlanSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('Select a Trip Plan'),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
            ),
          ),
          child: Column(
            children: [
              for (int i = 0; i < _tripPlans.length; i++) ...[
                _buildPlanOption(_tripPlans[i]),
                if (i < _tripPlans.length - 1)
                  Divider(
                    height: 1,
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    indent: 16,
                    endIndent: 16,
                  ),
              ],
            ],
          ),
        ),
        if (_selectedTripPlan != null) ...[
          const SizedBox(height: 16),
          _buildSelectedPlanDetails(),
        ],
      ],
    );
  }

  Widget _buildPlanOption(TripPlan plan) {
    final isSelected = _selectedTripPlan?.id == plan.id;
    return InkWell(
      onTap: () => setState(() => _selectedTripPlan = plan),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected
                    ? WandererTheme.primaryOrange.withOpacity(0.1)
                    : Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.map_rounded,
                size: 20,
                color: isSelected
                    ? WandererTheme.primaryOrange
                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.45),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected
                          ? Theme.of(context).colorScheme.onSurface
                          : Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatPlanType(plan.planType),
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.45),
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: WandererTheme.primaryOrange,
                size: 22,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedPlanDetails() {
    final l10n = context.l10n;
    final plan = _selectedTripPlan!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: WandererTheme.primaryOrange.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: WandererTheme.primaryOrange.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 16,
                color: WandererTheme.primaryOrange,
              ),
              const SizedBox(width: 6),
              Text(
                l10n.planDetails,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: WandererTheme.primaryOrange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Type: ${_formatPlanType(plan.planType)}',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          if (plan.startDate != null && plan.endDate != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Dates: ${_formatDate(plan.startDate!)} \u2013 ${_formatDate(plan.endDate!)}',
                style: TextStyle(
                  fontSize: 13,
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }

  /// Sticky bottom create button
  Widget _buildBottomButton() {
    final canCreate = _createFromPlan ? _selectedTripPlan != null : true;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
          ),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: _isLoading || !canCreate ? null : _createTrip,
          style: ElevatedButton.styleFrom(
            backgroundColor: WandererTheme.primaryOrange,
            foregroundColor: Colors.white,
            disabledBackgroundColor:
                Theme.of(context).colorScheme.onSurface.withOpacity(0.12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 0,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : Text(
                  _createFromPlan ? 'Create from Plan' : 'Create Trip',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
    );
  }
}
