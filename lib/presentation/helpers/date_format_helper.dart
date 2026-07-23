import 'package:intl/intl.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';

/// Helper for formatting dates as human-relative strings across trip cards.
class DateFormatHelper {
  /// Formats [date] relative to now: "just now", "5 minutes ago", "3 days
  /// ago", etc., falling back to an absolute "MMM d, yyyy" date once
  /// [date] is over a year old.
  static String formatRelativeDate(AppLocalizations l10n, DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return l10n.justNow;
        }
        return difference.inMinutes == 1
            ? l10n.minuteAgo
            : l10n.minutesAgo(difference.inMinutes);
      }
      return difference.inHours == 1
          ? l10n.hourAgo
          : l10n.hoursAgo(difference.inHours);
    } else if (difference.inDays < 7) {
      return difference.inDays == 1
          ? l10n.dayAgo
          : l10n.daysAgo(difference.inDays);
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return weeks == 1 ? l10n.weekAgo : l10n.weeksAgo(weeks);
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return months == 1 ? l10n.monthAgo : l10n.monthsAgo(months);
    } else {
      return DateFormat('MMM d, yyyy').format(date);
    }
  }
}
