import 'package:flutter/material.dart' hide Visibility;
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/constants/enums.dart';
import 'package:wanderer_frontend/presentation/widgets/create_trip/create_trip_button.dart';
import 'package:wanderer_frontend/presentation/widgets/create_trip/date_range_selector.dart';
import 'package:wanderer_frontend/presentation/widgets/create_trip/trip_description_field.dart';
import 'package:wanderer_frontend/presentation/widgets/create_trip/trip_title_field.dart';
import 'package:wanderer_frontend/presentation/widgets/create_trip/visibility_selector.dart';

/// Main form widget for creating a trip
class CreateTripForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final Visibility selectedVisibility;
  final TripModality? selectedModality;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isLoading;
  final ValueChanged<Visibility> onVisibilityChanged;
  final ValueChanged<TripModality?> onModalityChanged;
  final VoidCallback onSelectStartDate;
  final VoidCallback onSelectEndDate;
  final VoidCallback onClearStartDate;
  final VoidCallback onClearEndDate;
  final VoidCallback onSubmit;

  const CreateTripForm({
    super.key,
    required this.formKey,
    required this.titleController,
    required this.descriptionController,
    required this.selectedVisibility,
    this.selectedModality,
    this.startDate,
    this.endDate,
    required this.isLoading,
    required this.onVisibilityChanged,
    required this.onModalityChanged,
    required this.onSelectStartDate,
    required this.onSelectEndDate,
    required this.onClearStartDate,
    required this.onClearEndDate,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TripTitleField(controller: titleController),
          const SizedBox(height: 16),
          TripDescriptionField(controller: descriptionController),
          const SizedBox(height: 24),
          VisibilitySelector(
            selectedVisibility: selectedVisibility,
            onVisibilityChanged: onVisibilityChanged,
          ),
          const SizedBox(height: 24),
          _buildModalitySelector(context),
          const SizedBox(height: 24),
          DateRangeSelector(
            startDate: startDate,
            endDate: endDate,
            onSelectStartDate: onSelectStartDate,
            onSelectEndDate: onSelectEndDate,
            onClearStartDate: onClearStartDate,
            onClearEndDate: onClearEndDate,
          ),
          const SizedBox(height: 32),
          CreateTripButton(isLoading: isLoading, onPressed: onSubmit),
        ],
      ),
    );
  }

  Widget _buildModalitySelector(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.tripType,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildModalityOption(
                context: context,
                label: l10n.simple,
                subtitle: l10n.singleDayTrip,
                modality: TripModality.simple,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildModalityOption(
                context: context,
                label: l10n.multiDay,
                subtitle: l10n.multiDayJourney,
                modality: TripModality.multiDay,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildModalityOption({
    required BuildContext context,
    required String label,
    required String subtitle,
    required TripModality modality,
  }) {
    final isSelected = selectedModality == modality;
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: isLoading
          ? null
          : () => onModalityChanged(isSelected ? null : modality),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? colorScheme.primary : colorScheme.outline,
            width: isSelected ? 2 : 1,
          ),
          color: isSelected
              ? colorScheme.primary.withOpacity(0.08)
              : Colors.transparent,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? colorScheme.primary : null,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
