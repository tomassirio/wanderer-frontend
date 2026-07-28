import 'package:flutter/material.dart' hide Visibility;
import 'package:wanderer_frontend/core/constants/enums.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/presentation/widgets/common/floating_notification.dart';

/// Helper class for UI-related utilities
class UiHelpers {
  /// Gets the appropriate icon for a trip status
  static IconData getStatusIcon(TripStatus status) {
    switch (status) {
      case TripStatus.inProgress:
        return Icons.play_arrow;
      case TripStatus.created:
        return Icons.schedule;
      case TripStatus.paused:
        return Icons.pause;
      case TripStatus.finished:
        return Icons.check;
      case TripStatus.resting:
        return Icons.nightlight_round;
    }
  }

  /// Gets the canonical color for a trip status.
  static Color getStatusColor(TripStatus status) {
    switch (status) {
      case TripStatus.created:
        return const Color(0xFF6C757D);
      case TripStatus.inProgress:
        return const Color(0xFF4CAF50);
      case TripStatus.paused:
        return const Color(0xFFFF9800);
      case TripStatus.finished:
        return WandererTheme.statusCompleted;
      case TripStatus.resting:
        return WandererTheme.statusResting;
    }
  }

  /// Gets the appropriate icon for trip visibility. `protected` returns
  /// `Icons.lock_outline` - this was previously `Icons.group`, disagreeing
  /// with both home_screen.dart's own visibility icon lookup and
  /// VisibilityBadge, which both already rendered lock_outline on screen.
  /// Fixed to match what users actually see today, not the outlier value.
  static IconData getVisibilityIcon(Visibility visibility) {
    switch (visibility) {
      case Visibility.private:
        return Icons.lock;
      case Visibility.protected:
        return Icons.lock_outline;
      case Visibility.public:
        return Icons.public;
    }
  }

  /// Gets the localized label for a trip status.
  static String getStatusLabel(TripStatus status, AppLocalizations l10n) {
    switch (status) {
      case TripStatus.inProgress:
        return l10n.live;
      case TripStatus.paused:
        return l10n.paused;
      case TripStatus.finished:
        return l10n.completed;
      case TripStatus.created:
        return l10n.draft;
      case TripStatus.resting:
        return l10n.resting;
    }
  }

  /// Gets the localized label for trip visibility.
  static String getVisibilityLabel(Visibility visibility, AppLocalizations l10n) {
    switch (visibility) {
      case Visibility.public:
        return l10n.publicVisibility;
      case Visibility.protected:
        return l10n.protectedVisibility;
      case Visibility.private:
        return l10n.privateVisibility;
    }
  }

  /// Shows a success notification
  static void showSuccessMessage(BuildContext context, String message) {
    FloatingNotification.show(
      context,
      message,
      NotificationType.success,
      duration: const Duration(seconds: 2),
    );
  }

  /// Shows an error notification
  static void showErrorMessage(BuildContext context, String message) {
    FloatingNotification.show(
      context,
      message,
      NotificationType.error,
      duration: const Duration(seconds: 3),
    );
  }

  /// Shows an info notification
  static void showInfoMessage(BuildContext context, String message) {
    FloatingNotification.show(
      context,
      message,
      NotificationType.info,
      duration: const Duration(seconds: 2),
    );
  }
}
