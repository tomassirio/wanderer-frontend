import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/data/models/domain/trip_location.dart';
import 'package:wanderer_frontend/presentation/helpers/update_markers.dart';
import 'package:wanderer_frontend/presentation/helpers/weather_helpers.dart';
import 'package:wanderer_frontend/presentation/widgets/android/trip_checkin_sheet.dart';
import 'package:wanderer_frontend/presentation/widgets/common/toasts.dart';

/// Web map point popover (canvas "Map popover"): a 300dp card whose top
/// edge and chip take the marker kind's colour, place and time, distance /
/// weather / battery tiles, the traveler's note and Maps / copy actions.
/// The arrow below points at the marker.
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
    final l10n = context.l10n;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final u = location;
    final kind = updateKind(u);
    final accent = accentOf(kind, dark: dark);
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

    Widget tile(String caption, String value, {Color? valueColor}) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
                color: c.raised, borderRadius: BorderRadius.circular(10)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: c.caption)),
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: valueColor ?? c.text)),
              ],
            ),
          ),
        );

    Widget action(IconData icon, String text, VoidCallback onTap) => Expanded(
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

    return Semantics(
      container: true,
      label: '$label · ${place.isEmpty ? u.displayLocation : place}',
      child: Material(
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 6, 0),
                child: Row(children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: dark
                          ? Colors.white.withValues(alpha: 0.06)
                          : accent.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(kind.icon ?? Icons.place_outlined,
                          size: 15, color: accent),
                      const SizedBox(width: 6),
                      Text(label,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: accent)),
                    ]),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: MaterialLocalizations.of(context).closeButtonLabel,
                    onPressed: onClose,
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.close, size: 16, color: c.caption),
                  ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(place.isEmpty ? u.displayLocation : place,
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: c.text)),
                    const SizedBox(height: 2),
                    Text(time,
                        style: TextStyle(fontSize: 13, color: c.caption)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      tile(
                          l10n.categoryDistance,
                          u.distanceSoFarKm == null
                              ? '—'
                              : l10n.kmValue(
                                  u.distanceSoFarKm!.toStringAsFixed(1))),
                      const SizedBox(width: 6),
                      tile(
                          u.weatherCondition == null
                              ? l10n.tripWeather
                              : WeatherHelpers.getWeatherLabel(
                                  u.weatherCondition!),
                          u.temperatureCelsius == null
                              ? '—'
                              : WeatherHelpers.formatTemperature(
                                  u.temperatureCelsius!)),
                      const SizedBox(width: 6),
                      tile(
                          l10n.tripBattery, battery == null ? '—' : '$battery%',
                          valueColor: battery == null
                              ? null
                              : battery < 20
                                  ? (dark
                                      ? const Color(0xFFF4A39A)
                                      : const Color(0xFFB42318))
                                  : c.forestFg),
                    ],
                  ),
                ),
              ),
              if (note != null)
                Container(
                  margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: c.raised,
                    borderRadius: BorderRadius.circular(10),
                    border: Border(left: BorderSide(color: accent, width: 3)),
                  ),
                  child: Text('“$note”',
                      style:
                          TextStyle(fontSize: 14, height: 1.4, color: c.text)),
                ),
              if (u.hasLocation)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  child: Row(children: [
                    action(
                        Icons.open_in_new,
                        l10n.tripOpenInMaps,
                        () => launchUrl(Uri.parse(mapsUrl),
                            mode: LaunchMode.externalApplication)),
                    const SizedBox(width: 8),
                    action(Icons.copy_outlined, l10n.tripCopyLocation,
                        () async {
                      await Clipboard.setData(ClipboardData(text: mapsUrl));
                      Toasts.show(ToastData(
                          kind: ToastKind.success,
                          title: l10n.tripLocationCopied));
                    }),
                  ]),
                )
              else
                const SizedBox(height: 14),
            ],
          ),
        ),
      ),
    );
  }
}
