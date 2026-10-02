import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/data/models/domain/trip_location.dart';
import 'package:wanderer_frontend/presentation/helpers/battery_helpers.dart';
import 'package:wanderer_frontend/presentation/helpers/update_markers.dart';
import 'package:wanderer_frontend/presentation/helpers/weather_helpers.dart';
import 'package:wanderer_frontend/presentation/widgets/android/trip_checkin_sheet.dart';
import 'package:wanderer_frontend/presentation/widgets/android/trip_state_controls.dart';
import 'package:wanderer_frontend/presentation/widgets/common/toasts.dart';

/// Web map point popover (canvas "Map popover"): [UpdateDetails] in a
/// 300dp card whose top edge takes the marker kind's colour. The arrow
/// below it (drawn by the map) points at the marker.
class CustomInfoWindow extends StatelessWidget {
  final TripLocation location;
  final VoidCallback onClose;

  const CustomInfoWindow({
    super.key,
    required this.location,
    required this.onClose,
  });

  static const width = 300.0;

  /// Kind colour, lightened in dark mode so the chip text stays readable.
  static Color accentOf(UpdateKind kind, {required bool dark}) =>
      switch (kind) {
        UpdateKind.tripFinished =>
          dark ? const Color(0xFFF4A39A) : const Color(0xFFB42318),
        UpdateKind.tripStarted =>
          dark ? const Color(0xFF8FD6B0) : const Color(0xFF2F6B4F),
        UpdateKind.dayStarted =>
          dark ? const Color(0xFFF7CF7A) : const Color(0xFFA16207),
        UpdateKind.dayEnded =>
          dark ? const Color(0xFFB9AEE0) : const Color(0xFF5B4B8A),
        UpdateKind.checkIn ||
        UpdateKind.autoCheckIn =>
          dark ? const Color(0xFFA8CCF2) : const Color(0xFF2F5C8A),
      };

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = accentOf(updateKind(location), dark: dark);
    return Material(
      color: c.surface,
      elevation: 10,
      shadowColor: Colors.black.withValues(alpha: dark ? 0.6 : 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: c.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Container(
        width: width,
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: accent, width: 4)),
        ),
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 14),
        child: UpdateDetails(location: location, onClose: onClose),
      ),
    );
  }
}

/// What a trip update says, shared by the web popover and the Android /
/// mobile web check-in sheet: a type chip in the kind's colour, place and
/// time, distance / weather / battery tiles, the traveler's note and
/// Maps / copy actions. [large] is the sheet's size.
class UpdateDetails extends StatelessWidget {
  final TripLocation location;
  final VoidCallback? onClose;
  final bool large;

  const UpdateDetails(
      {super.key, required this.location, this.onClose, this.large = false});

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final u = location;
    final kind = updateKind(u);
    final accent = CustomInfoWindow.accentOf(kind, dark: dark);
    final locale = Localizations.localeOf(context).toString();
    final when = u.timestamp.toLocal();
    final time = '${DateFormat('EEE d MMM y', locale).format(when)} · '
        '${DateFormat.Hm(locale).format(when)}';
    // Day events carry their own wording ("Day 3 started").
    final label =
        (kind == UpdateKind.dayStarted || kind == UpdateKind.dayEnded) &&
                (u.message?.trim().isNotEmpty ?? false)
            ? u.message!.trim()
            : tripCheckInKind(l10n, u);
    final place = tripCheckInPlace(u);
    final note = tripCheckInMessage(u);
    final mapsUrl =
        'https://www.google.com/maps/search/?api=1&query=${u.latitude},${u.longitude}';
    final battery = u.battery;
    final weather = u.weatherCondition;
    // Content lines up with the tiles; the popover's ✕ sits in its padding.
    final right = onClose == null ? 0.0 : 8.0;

    Widget tile(String caption, String value,
            {Color? valueColor,
            IconData? icon,
            Color? iconColor,
            String? sub}) =>
        Expanded(
          child: Tooltip(
            message: sub ?? '',
            child: Container(
              padding: EdgeInsets.symmetric(
                  horizontal: large ? 12 : 10, vertical: large ? 10 : 8),
              decoration: BoxDecoration(
                  color: c.raised,
                  borderRadius: BorderRadius.circular(large ? 14 : 10)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: large ? 12 : 11, color: c.caption)),
                  Row(children: [
                    if (icon != null) ...[
                      Icon(icon, size: large ? 17 : 15, color: iconColor),
                      const SizedBox(width: 4),
                    ],
                    Flexible(
                      child: Text(value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: large ? 16 : 14,
                              fontWeight: FontWeight.w700,
                              color: valueColor ?? c.text)),
                    ),
                  ]),
                  // Long conditions ("Partly cloudy") wrap on their own line
                  // instead of being cut off in the caption.
                  if (sub != null)
                    Text(sub,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: large ? 12 : 11,
                            height: 1.25,
                            color: c.caption)),
                ],
              ),
            ),
          ),
        );

    Future<void> copy() async {
      await Clipboard.setData(ClipboardData(text: mapsUrl));
      Toasts.show(
          ToastData(kind: ToastKind.success, title: l10n.tripLocationCopied));
    }

    void open() =>
        launchUrl(Uri.parse(mapsUrl), mode: LaunchMode.externalApplication);

    Widget smallAction(IconData icon, String text, VoidCallback onTap) =>
        Expanded(
          child: SizedBox(
            height: 38,
            child: OutlinedButton.icon(
              onPressed: onTap,
              icon: Icon(icon, size: 14),
              label: Text(text, overflow: TextOverflow.ellipsis),
              style: OutlinedButton.styleFrom(
                foregroundColor: c.text,
                side: BorderSide(color: c.line),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                textStyle:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        );

    final batteryColor = battery == null
        ? null
        : battery < 20
            ? (dark ? const Color(0xFFF4A39A) : const Color(0xFFB42318))
            : c.forestFg;

    return Semantics(
      container: true,
      label: '$label · ${place.isEmpty ? u.displayLocation : place}',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Flexible(
              child: Container(
                padding: EdgeInsets.symmetric(
                    horizontal: large ? 12 : 10, vertical: large ? 5 : 4),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: dark ? 0.16 : 0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(kind.icon ?? Icons.place_outlined,
                      size: large ? 17 : 15, color: accent),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: large ? 13 : 12,
                            fontWeight: FontWeight.w700,
                            color: accent)),
                  ),
                ]),
              ),
            ),
            const Spacer(),
            if (onClose != null)
              IconButton(
                tooltip: MaterialLocalizations.of(context).closeButtonLabel,
                onPressed: onClose,
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.close, size: 16, color: c.caption),
              ),
          ]),
          SizedBox(height: large ? 10 : 4),
          Padding(
            padding: EdgeInsets.only(right: right),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(place.isEmpty ? u.displayLocation : place,
                    style: large
                        ? WandererTheme.display(22, color: c.text)
                        : TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: c.text)),
                const SizedBox(height: 2),
                Text(time,
                    style:
                        TextStyle(fontSize: large ? 14 : 13, color: c.caption)),
                SizedBox(height: large ? 16 : 12),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      tile(
                          l10n.categoryDistance,
                          u.distanceSoFarKm == null
                              ? '—'
                              : l10n.kmValue(
                                  u.distanceSoFarKm!.toStringAsFixed(1))),
                      SizedBox(width: large ? 8 : 6),
                      tile(
                        l10n.tripWeather,
                        u.temperatureCelsius == null
                            ? '—'
                            : WeatherHelpers.formatTemperature(
                                u.temperatureCelsius!),
                        icon: weather == null
                            ? null
                            : WeatherHelpers.getWeatherIcon(weather),
                        iconColor: weather == null
                            ? null
                            : WeatherHelpers.getWeatherColor(weather),
                        sub: weather == null
                            ? null
                            : WeatherHelpers.getWeatherLabel(weather),
                      ),
                      SizedBox(width: large ? 8 : 6),
                      tile(
                          l10n.tripBattery, battery == null ? '—' : '$battery%',
                          valueColor: batteryColor,
                          icon: battery == null
                              ? null
                              : BatteryHelpers.getBatteryIcon(battery),
                          iconColor: battery == null
                              ? null
                              : BatteryHelpers.getBatteryColor(battery)),
                    ],
                  ),
                ),
                if (note != null)
                  Container(
                    margin: EdgeInsets.only(top: large ? 12 : 10),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: c.raised,
                      borderRadius: BorderRadius.circular(10),
                      border: Border(left: BorderSide(color: accent, width: 3)),
                    ),
                    child: Text('“$note”',
                        style: TextStyle(
                            fontSize: large ? 15 : 14,
                            height: 1.4,
                            color: c.text)),
                  ),
                if (u.hasLocation) ...[
                  SizedBox(height: large ? 16 : 12),
                  if (large)
                    Row(children: [
                      Expanded(
                        child: TripSheetButton(
                          label: l10n.tripCopyLocation,
                          icon: Icons.copy_outlined,
                          background: c.surface,
                          foreground: c.text,
                          border: c.line,
                          onPressed: copy,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TripSheetButton(
                          label: l10n.tripOpenInMaps,
                          icon: Icons.open_in_new,
                          background: c.neutralButtonBg,
                          foreground: c.neutralButtonFg,
                          onPressed: open,
                        ),
                      ),
                    ])
                  else
                    Row(children: [
                      smallAction(Icons.open_in_new, l10n.tripOpenInMaps, open),
                      const SizedBox(width: 8),
                      smallAction(
                          Icons.copy_outlined, l10n.tripCopyLocation, copy),
                    ]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
