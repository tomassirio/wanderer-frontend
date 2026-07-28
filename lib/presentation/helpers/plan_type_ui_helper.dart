import 'package:flutter/material.dart';

/// One selectable plan-type option shown in the interactive type-picker UI
/// (TripPlanDetailScreen's edit form and CreateTripPlanScreen's create form).
class PlanTypeOption {
  final String value;
  final String label;
  final IconData icon;

  const PlanTypeOption({
    required this.value,
    required this.label,
    required this.icon,
  });
}

/// Shared plan-type icon/label lookups, consolidating what was previously
/// triplicated across TripPlanDetailScreen's and CreateTripPlanScreen's
/// inline selector widgets, and TripPlanInfoCard's private helpers.
class PlanTypeUiHelper {
  /// The 2 selectable plan types shown in the edit/create UI's type picker.
  /// Byte-identical to what both screens' inline `types` lists already
  /// defined — same value/label/icon per option, just no longer duplicated.
  static const List<PlanTypeOption> selectableTypes = [
    PlanTypeOption(
      value: 'SIMPLE',
      label: 'Simple',
      icon: Icons.wb_sunny_outlined,
    ),
    PlanTypeOption(
      value: 'MULTI_DAY',
      label: 'Multi-Day',
      icon: Icons.luggage_outlined,
    ),
  ];

  /// Icon for a plan type in compact/badge display contexts (e.g.
  /// TripPlanInfoCard). Deliberately a different visual language than
  /// [selectableTypes]' icons — a different UI context, not an
  /// inconsistency to merge.
  static IconData getIcon(String planType) {
    switch (planType) {
      case 'SIMPLE':
        return Icons.place;
      case 'MULTI_DAY':
        return Icons.date_range;
      case 'ROAD_TRIP':
        return Icons.directions_car;
      default:
        return Icons.map;
    }
  }

  /// Formats a raw backend plan-type string ('MULTI_DAY') into a
  /// human-readable label ('Multi Day').
  static String formatLabel(String planType) {
    return planType
        .split('_')
        .map((word) => word[0] + word.substring(1).toLowerCase())
        .join(' ');
  }
}
