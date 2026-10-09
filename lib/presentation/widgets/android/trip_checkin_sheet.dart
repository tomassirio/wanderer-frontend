import 'package:flutter/material.dart';
import 'package:wanderer_frontend/core/constants/enums.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/presentation/helpers/update_markers.dart';

export 'package:wanderer_frontend/presentation/helpers/update_markers.dart'
    show isAutoCheckIn;
import 'package:wanderer_frontend/presentation/widgets/android/android_ui.dart';
import 'package:wanderer_frontend/presentation/widgets/trip_detail/custom_info_window.dart';
import 'package:wanderer_frontend/presentation/widgets/android/trip_state_controls.dart';
import 'package:wanderer_frontend/presentation/widgets/common/wanderer_sheet.dart';

/// The user's own message, never the automatic placeholder or event text.
String? tripCheckInMessage(TripLocation u) =>
    u.updateType == TripUpdateType.regular &&
            !isAutoCheckIn(u) &&
            (u.message?.trim().isNotEmpty ?? false)
        ? u.message!.trim()
        : null;

/// [updates] (newest first) with this phone's unsent check-ins on top,
/// newest first. One the backend already has shows from [updates] only.
List<TripLocation> withPendingCheckIns(
    List<TripLocation> updates, List<TripLocation> pending) {
  if (pending.isEmpty) return updates;
  final sent = {for (final u in updates) u.id};
  return [
    ...pending.where((p) => !sent.contains(p.id)).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp)),
    ...updates,
  ];
}

/// Consecutive regular check-ins at the same place, each within [window] of
/// the previous one, folded into one group (a lone check-in is a group of
/// one). Check-ins with a user message and trip events always stand alone.
/// Order is kept.
List<List<TripLocation>> groupCheckIns(List<TripLocation> updates,
    {Duration window = const Duration(minutes: 15)}) {
  bool groupable(TripLocation u) =>
      !u.pending &&
      u.updateType == TripUpdateType.regular &&
      tripCheckInMessage(u) == null &&
      tripCheckInPlace(u).isNotEmpty;
  final groups = <List<TripLocation>>[];
  for (final u in updates) {
    final prev = groups.isEmpty ? null : groups.last.last;
    if (prev != null &&
        groupable(u) &&
        groupable(prev) &&
        tripCheckInPlace(u) == tripCheckInPlace(prev) &&
        prev.timestamp.difference(u.timestamp).abs() <= window) {
      groups.last.add(u);
    } else {
      groups.add([u]);
    }
  }
  return groups;
}

/// Label for a check-in's type (Check-in, Trip started, Day ended, …).
String tripCheckInKind(AppLocalizations l10n, TripLocation u) =>
    switch (u.updateType) {
      TripUpdateType.regular =>
        isAutoCheckIn(u) ? l10n.tripAutoCheckInLabel : l10n.tripCheckInLabel,
      TripUpdateType.tripStarted => l10n.tripEventStarted,
      TripUpdateType.tripEnded => l10n.tripEventFinished,
      TripUpdateType.dayStart => l10n.tripEventDayStart,
      TripUpdateType.dayEnd => l10n.tripEventDayEnd,
    };

/// Place name, falling back to coordinates only when nothing better exists.
String tripCheckInPlace(TripLocation u) => [u.city, u.country]
    .whereType<String>()
    .where((s) => s.isNotEmpty)
    .join(', ');

/// Row / sheet title: the place, or "Trip finished · Santiago" for events.
String tripCheckInTitle(AppLocalizations l10n, TripLocation u) {
  final place = tripCheckInPlace(u);
  if (u.updateType == TripUpdateType.regular) {
    return place.isNotEmpty ? place : u.displayLocation;
  }
  return [tripCheckInKind(l10n, u), if (place.isNotEmpty) place].join(' · ');
}

/// Dot colour per check-in (state colours from the canvas).
Color tripCheckInColor(WandererColors c, TripLocation u) =>
    switch (u.updateType) {
      TripUpdateType.regular => c.skyFg,
      TripUpdateType.tripStarted => c.forestFg,
      TripUpdateType.tripEnded =>
        ThemeData.estimateBrightnessForColor(c.surface) == Brightness.dark
            ? const Color(0xFFF97066)
            : UpdateKind.tripFinished.color,
      TripUpdateType.dayStart => c.goldFg,
      TripUpdateType.dayEnd => c.restingFg,
    };

/// Check-in detail sheet on Android and mobile web: the same contents as
/// the web map popover ([UpdateDetails]), sized for the sheet.
Future<void> showTripCheckInDetail(BuildContext context, TripLocation u) =>
    showWandererSheet<void>(
      context,
      builder: (ctx) => UpdateDetails(location: u, large: true),
    );

/// Check-in composer: optional message, one orange button. Returns null when
/// dismissed, otherwise the (possibly empty) message.
Future<String?> showTripCheckInComposer(BuildContext context) {
  final l10n = context.l10n;
  final controller = TextEditingController();
  return showWandererSheet<String>(
    context,
    title: l10n.tripCheckIn,
    builder: (ctx) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        LabeledField(
          label: l10n.tripMessageOptional,
          controller: controller,
          maxLines: 3,
          textInputAction: TextInputAction.done,
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 56,
          child: TripSheetButton(
            key: const Key('trip_check_in_send'),
            label: l10n.tripCheckIn,
            icon: Icons.add_location_alt_outlined,
            background: WandererTheme.trail,
            foreground: Colors.white,
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
          ),
        ),
      ],
    ),
  );
}
