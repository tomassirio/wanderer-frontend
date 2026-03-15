// filepath: /Users/tomassirio/Workspace/wanderer_frontend/lib/presentation/widgets/trip_plans/trip_plan_info_card.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';

/// Widget displaying trip plan information card with glassmorphism design
/// Supports collapsible state that shows as a floating bubble
class TripPlanInfoCard extends StatelessWidget {
  final TripPlan tripPlan;
  final bool isCollapsed;
  final VoidCallback onToggleCollapse;
  final bool isEditing;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const TripPlanInfoCard({
    super.key,
    required this.tripPlan,
    required this.isCollapsed,
    required this.onToggleCollapse,
    this.isEditing = false,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedCrossFade(
      duration: const Duration(milliseconds: 300),
      firstCurve: Curves.easeInOut,
      secondCurve: Curves.easeInOut,
      sizeCurve: Curves.easeInOut,
      alignment: Alignment.bottomLeft,
      crossFadeState:
          isCollapsed ? CrossFadeState.showFirst : CrossFadeState.showSecond,
      firstChild: _buildCollapsedBubble(context),
      secondChild: _buildExpandedCard(context),
    );
  }

  /// Collapsed state - floating bubble with info icon
  Widget _buildCollapsedBubble(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: WandererTheme.floatingShadow,
      ),
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: WandererTheme.glassBlurSigma,
            sigmaY: WandererTheme.glassBlurSigma,
          ),
          child: Material(
            color: WandererTheme.glassBackgroundFor(context),
            shape: CircleBorder(
              side: BorderSide(
                color: WandererTheme.glassBorderColorFor(context),
                width: 1,
              ),
            ),
            child: InkWell(
              onTap: onToggleCollapse,
              customBorder: const CircleBorder(),
              child: Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.info_outline,
                  size: 24,
                  color: WandererTheme.primaryOrange,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Expanded state - full info card
  Widget _buildExpandedCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      constraints: const BoxConstraints(maxWidth: 400),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(WandererTheme.glassRadius),
        boxShadow: WandererTheme.floatingShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(WandererTheme.glassRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: WandererTheme.glassBlurSigma,
            sigmaY: WandererTheme.glassBlurSigma,
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: WandererTheme.glassBackgroundFor(context),
              borderRadius: BorderRadius.circular(WandererTheme.glassRadius),
              border: Border.all(
                color: WandererTheme.glassBorderColorFor(context),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title row with collapse button
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        tripPlan.name,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Collapse button
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.remove,
                          size: 18,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        ),
                        onPressed: onToggleCollapse,
                        tooltip: 'Minimize',
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Plan type
                _buildInfoRow(
                  context,
                  _getPlanTypeIcon(tripPlan.planType),
                  _formatPlanType(tripPlan.planType),
                ),
                const SizedBox(height: 8),
                // Dates
                if (tripPlan.startDate != null || tripPlan.endDate != null)
                  _buildInfoRow(
                    context,
                    Icons.calendar_today,
                    _formatDateRange(),
                  ),
                const SizedBox(height: 12),
                // Route summary
                _buildRouteSection(context),
                // Action buttons when not editing
                if (!isEditing && (onEdit != null || onDelete != null)) ...[
                  const SizedBox(height: 16),
                  _buildActionButtons(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, IconData icon, String text) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: WandererTheme.primaryOrange,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRouteSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: WandererTheme.glassBorderColorFor(context),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Route',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.45),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          _buildLocationItem(
            context,
            'Start',
            tripPlan.startLocation,
            WandererTheme.statusCreated,
          ),
          if (tripPlan.waypoints.isNotEmpty) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 20),
              child: Text(
                '${tripPlan.waypoints.length} waypoint(s)',
                style: TextStyle(
                  fontSize: 13,
                  color: WandererTheme.primaryOrangeLight,
                ),
              ),
            ),
          ],
          const SizedBox(height: 4),
          _buildLocationItem(
            context,
            'End',
            tripPlan.endLocation,
            WandererTheme.statusCancelled,
          ),
        ],
      ),
    );
  }

  Widget _buildLocationItem(BuildContext context, String label, PlanLocation? location, Color color) {
    final hasLocation =
        location != null && location.lat != 0 && location.lon != 0;

    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: hasLocation ? color : Colors.grey.shade400,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        Expanded(
          child: Text(
            hasLocation
                ? '${location.lat.toStringAsFixed(4)}, ${location.lon.toStringAsFixed(4)}'
                : 'Not set',
            style: TextStyle(
              fontSize: 13,
              color: hasLocation
                  ? Theme.of(context).colorScheme.onSurface.withOpacity(0.6)
                  : Theme.of(context).colorScheme.onSurface.withOpacity(0.45),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        if (onEdit != null)
          Expanded(
            child: _buildGlassButton(
              icon: Icons.edit_outlined,
              label: 'Edit',
              onTap: onEdit!,
            ),
          ),
        if (onEdit != null && onDelete != null) const SizedBox(width: 8),
        if (onDelete != null)
          Expanded(
            child: _buildGlassButton(
              icon: Icons.delete_outline,
              label: 'Delete',
              onTap: onDelete!,
              isDestructive: true,
            ),
          ),
      ],
    );
  }

  Widget _buildGlassButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final color = isDestructive
        ? WandererTheme.statusCancelled
        : WandererTheme.primaryOrange;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: color.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getPlanTypeIcon(String planType) {
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

  String _formatPlanType(String planType) {
    return planType
        .split('_')
        .map((word) => word[0] + word.substring(1).toLowerCase())
        .join(' ');
  }

  String _formatDateRange() {
    if (tripPlan.startDate != null && tripPlan.endDate != null) {
      return '${_formatDate(tripPlan.startDate!)} - ${_formatDate(tripPlan.endDate!)}';
    } else if (tripPlan.startDate != null) {
      return 'Starting ${_formatDate(tripPlan.startDate!)}';
    } else if (tripPlan.endDate != null) {
      return 'Until ${_formatDate(tripPlan.endDate!)}';
    }
    return 'No dates set';
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }
}
