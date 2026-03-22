import 'package:flutter/material.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/presentation/widgets/create_trip/date_picker_card.dart';

/// Date range selector with start and end date pickers
class DateRangeSelector extends StatelessWidget {
  final DateTime? startDate;
  final DateTime? endDate;
  final VoidCallback onSelectStartDate;
  final VoidCallback onSelectEndDate;
  final VoidCallback onClearStartDate;
  final VoidCallback onClearEndDate;

  const DateRangeSelector({
    super.key,
    this.startDate,
    this.endDate,
    required this.onSelectStartDate,
    required this.onSelectEndDate,
    required this.onClearStartDate,
    required this.onClearEndDate,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.datesOptional,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        DatePickerCard(
          label: l10n.startDate,
          icon: Icons.calendar_today,
          selectedDate: startDate,
          onTap: onSelectStartDate,
          onClear: onClearStartDate,
        ),
        const SizedBox(height: 8),
        DatePickerCard(
          label: l10n.endDate,
          icon: Icons.event,
          selectedDate: endDate,
          onTap: onSelectEndDate,
          onClear: onClearEndDate,
        ),
      ],
    );
  }
}
