import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wanderer_frontend/core/constants/enums.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/presentation/helpers/weather_helpers.dart';
import 'package:wanderer_frontend/presentation/widgets/android/android_ui.dart';
import 'package:wanderer_frontend/presentation/widgets/android/trip_state_controls.dart';
import 'package:wanderer_frontend/presentation/widgets/common/toasts.dart';
import 'package:wanderer_frontend/presentation/widgets/common/wanderer_sheet.dart';

/// Label for a check-in's type (Check-in, Trip started, Day ended, …).
String tripCheckInKind(AppLocalizations l10n, TripLocation u) =>
    switch (u.updateType) {
      TripUpdateType.regular => l10n.tripCheckInLabel,
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
      TripUpdateType.tripEnded => WandererTheme.trail,
      TripUpdateType.dayStart => c.goldFg,
      TripUpdateType.dayEnd => c.restingFg,
    };

/// Check-in detail (canvas AndroidUpdate): place, date, weather, battery,
/// type, message, and copy / open-in-maps actions.
Future<void> showTripCheckInDetail(BuildContext context, TripLocation u) {
  final l10n = context.l10n;
  final c = WandererTheme.of(context);
  final locale = Localizations.localeOf(context).toString();
  final when = u.timestamp.toLocal();
  final date =
      '${DateFormat.MMMEd(locale).add_y().format(when)} · ${DateFormat.Hm(locale).format(when)}';
  final mapsUrl =
      'https://www.google.com/maps/search/?api=1&query=${u.latitude},${u.longitude}';

  Widget tile(String label, String value, String? sub, {Color? valueColor}) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: c.raised, borderRadius: BorderRadius.circular(14)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: c.caption)),
              const SizedBox(height: 2),
              Text(value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: valueColor ?? c.text)),
              if (sub != null)
                Text(sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: c.caption)),
            ],
          ),
        ),
      );

  final tiles = <Widget>[
    if (u.temperatureCelsius != null || u.weatherCondition != null)
      tile(
        l10n.tripWeather,
        u.temperatureCelsius != null
            ? WeatherHelpers.formatTemperature(u.temperatureCelsius!)
            : '—',
        u.weatherCondition != null
            ? WeatherHelpers.getWeatherLabel(u.weatherCondition!)
            : null,
      ),
    if (u.battery != null)
      tile(
        l10n.tripBattery,
        '${u.battery}%',
        u.battery! >= 30 ? l10n.tripBatteryGood : l10n.tripBatteryLow,
        valueColor: u.battery! >= 30 ? c.forestFg : const Color(0xFFB42318),
      ),
    tile(l10n.tripCheckInType, tripCheckInKind(l10n, u), null),
  ];

  return showWandererSheet<void>(
    context,
    builder: (ctx) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                  color: c.skyBg, borderRadius: BorderRadius.circular(14)),
              child: Icon(Icons.place_outlined,
                  color: tripCheckInColor(c, u), size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tripCheckInTitle(l10n, u),
                      style: WandererTheme.display(22, color: c.text)),
                  const SizedBox(height: 2),
                  Text(date,
                      style: TextStyle(fontSize: 14, color: c.textMuted)),
                ],
              ),
            ),
          ],
        ),
        if (u.message != null &&
            u.message!.isNotEmpty &&
            u.updateType == TripUpdateType.regular) ...[
          const SizedBox(height: 16),
          Text(u.message!,
              style: TextStyle(fontSize: 15, height: 1.45, color: c.text)),
        ],
        const SizedBox(height: 16),
        Row(children: [
          for (var i = 0; i < tiles.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            tiles[i],
          ],
        ]),
        if (u.hasLocation) ...[
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: TripSheetButton(
                label: l10n.tripCopyLocation,
                background: c.surface,
                foreground: c.text,
                border: c.line,
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: mapsUrl));
                  Toasts.show(ToastData(
                      kind: ToastKind.success, title: l10n.tripLocationCopied));
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TripSheetButton(
                label: l10n.tripOpenInMaps,
                background: c.neutralButtonBg,
                foreground: c.neutralButtonFg,
                onPressed: () => launchUrl(Uri.parse(mapsUrl),
                    mode: LaunchMode.externalApplication),
              ),
            ),
          ]),
        ],
      ],
    ),
  );
}

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
