import 'dart:async';
import 'dart:math';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:wanderer_frontend/core/constants/enums.dart';
import 'package:wanderer_frontend/core/errors/app_exception.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/providers/app_providers.dart';
import 'package:wanderer_frontend/core/services/background_update_manager.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/data/client/polyline_codec.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/presentation/helpers/location_permission_disclosure.dart';
import 'package:wanderer_frontend/presentation/helpers/page_transitions.dart';
import 'package:wanderer_frontend/presentation/screens/android/android_shell.dart';
import 'package:wanderer_frontend/presentation/screens/android/android_trips_tab.dart';
import 'package:wanderer_frontend/presentation/screens/create_trip_plan_screen.dart';
import 'package:wanderer_frontend/presentation/screens/trip_detail_screen.dart';
import 'package:wanderer_frontend/presentation/widgets/android/plan_editor_layout.dart';
import 'package:wanderer_frontend/presentation/widgets/android/plan_map_style.dart';
import 'package:wanderer_frontend/presentation/widgets/android/trip_start_sheets.dart';
import 'package:wanderer_frontend/presentation/widgets/common/pill.dart';
import 'package:wanderer_frontend/presentation/widgets/common/toasts.dart';
import 'package:wanderer_frontend/presentation/widgets/trip_detail/trip_map_view.dart';

/// New trip = the trip screen itself, "Ready to start" (canvas Proposal A–E):
/// map + sheet with a prefilled name and three setting tiles. Nothing is
/// saved until Start, which creates the trip live in one call and turns
/// this screen into the trip's Live view in place. Closing asks "Not
/// leaving yet?". With [plan] it starts that plan (its route on the map).
class ReadyTripScreen extends ConsumerStatefulWidget {
  final TripPlan? plan;

  /// Tests swap the Google map and the live trip screen for stand-ins.
  @visibleForTesting
  final Widget? testMap;
  @visibleForTesting
  final Widget Function(Trip trip)? testLive;

  const ReadyTripScreen({super.key, this.plan, this.testMap, this.testLive});

  @override
  ConsumerState<ReadyTripScreen> createState() => _ReadyTripScreenState();
}

class _ReadyTripScreenState extends ConsumerState<ReadyTripScreen> {
  final _name = TextEditingController();
  bool _nameEdited = false;

  TripPlan? _plan;
  List<TripPlan> _plans = const [];
  TripStartSettings _settings = const TripStartSettings();
  bool _fromLastTrip = false;

  LatLng? _here;
  String? _place;
  bool _locationOff = false;
  bool _starting = false;
  Trip? _started;
  GoogleMapController? _map;

  /// One key for every Start retry from this screen (contract: generated
  /// when the ready screen opens), so a lost response never makes a
  /// second trip.
  final String _idempotencyKey = newIdempotencyKey();

  String get _source => _plan == null ? 'SCRATCH' : 'PLAN';
  bool get _autoAvailable => !kIsWeb;

  @override
  void initState() {
    super.initState();
    _plan = widget.plan;
    final trips = ref.read(tripServiceProvider);
    trips.trackStartFunnel('READY_SCREEN_VIEWED', source: _source);
    _loadDefaults();
    if (_plan == null) _loadPlans();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_plan != null) _usePlan(_plan!);
      _suggestName();
      _locate();
    });
  }

  Future<void> _loadDefaults() async {
    try {
      final (defaults, fromLastTrip) =
          await ref.read(tripServiceProvider).getStartDefaults();
      if (!mounted) return;
      setState(() {
        // A plan's type decides the length.
        _settings = _plan == null
            ? defaults
            : defaults.copyWith(modality: _settings.modality);
        _fromLastTrip = fromLastTrip;
      });
    } catch (e) {
      // Brand-new defaults stay; the person can still change them.
      debugPrint('Start defaults: $e');
    }
  }

  Future<void> _loadPlans() async {
    try {
      final plans = await ref.read(tripPlanServiceProvider).getUserTripPlans();
      if (mounted) setState(() => _plans = plans);
    } catch (e) {
      debugPrint('Plans: $e');
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String get _locale => Localizations.localeOf(context).toString();

  /// "Amsterdam · Tue 6 Oct", or just the date when the place is unknown.
  void _suggestName() {
    if (_nameEdited || _plan != null) return;
    _name.text = readyTripName(_place, DateTime.now(), _locale);
  }

  void _usePlan(TripPlan plan) {
    setState(() {
      _plan = plan;
      _name.text = plan.name;
      _settings =
          _settings.copyWith(modality: TripModality.fromJson(plan.planType));
    });
    _fitMap();
  }

  // ---------------------------------------------------------------------------
  // Location
  // ---------------------------------------------------------------------------

  /// Finds where the person is. Asks for permission (with the disclosure)
  /// only when [interactive] or when it was never asked; never sends them
  /// to settings on its own.
  Future<LatLng?> _locate({bool interactive = false}) async {
    try {
      if (!interactive) {
        final permission = await Geolocator.checkPermission();
        if (!await Geolocator.isLocationServiceEnabled() ||
            permission == LocationPermission.deniedForever) {
          if (mounted) setState(() => _locationOff = true);
          return null;
        }
      }
      if (!mounted) return null;
      final access = await ensureLocationAccess(context);
      if (access != LocationAccess.granted) {
        if (mounted) setState(() => _locationOff = true);
        if (access == LocationAccess.serviceOff && interactive) {
          await Geolocator.openLocationSettings();
        }
        return null;
      }
      final p = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
      final here = LatLng(p.latitude, p.longitude);
      if (!mounted) return here;
      setState(() {
        _here = here;
        _locationOff = false;
      });
      _fitMap();
      _lookUpPlace(here);
      return here;
    } catch (e) {
      debugPrint('Ready screen location: $e');
      return null;
    }
  }

  Future<void> _lookUpPlace(LatLng here) async {
    final place = await ref.read(googleGeocodingApiClientProvider).placeName(
        here.latitude, here.longitude,
        language: Localizations.localeOf(context).languageCode);
    if (!mounted || place == null) return;
    setState(() => _place = place);
    _suggestName();
  }

  // ---------------------------------------------------------------------------
  // Map
  // ---------------------------------------------------------------------------

  List<LatLng> get _route {
    final plan = _plan;
    if (plan == null) return const [];
    final encoded = plan.plannedPolyline ?? plan.encodedPolyline;
    if (encoded != null && encoded.isNotEmpty) {
      try {
        return PolylineCodec.decode(encoded);
      } catch (_) {}
    }
    return [
      if (plan.startLocation case final s?) LatLng(s.lat, s.lon),
      for (final w in plan.waypoints) LatLng(w.lat, w.lon),
      if (plan.endLocation case final e?) LatLng(e.lat, e.lon),
    ];
  }

  void _fitMap() {
    final map = _map;
    if (map == null) return;
    final points = [..._route, if (_here case final h?) h];
    if (points.isEmpty) return;
    if (points.length == 1) {
      map.animateCamera(CameraUpdate.newLatLngZoom(points.first, 15));
      return;
    }
    final lats = points.map((p) => p.latitude);
    final lons = points.map((p) => p.longitude);
    map.animateCamera(CameraUpdate.newLatLngBounds(
        LatLngBounds(
            southwest: LatLng(lats.reduce(min), lons.reduce(min)),
            northeast: LatLng(lats.reduce(max), lons.reduce(max))),
        48));
  }

  // ---------------------------------------------------------------------------
  // Start / close
  // ---------------------------------------------------------------------------

  Future<void> _openSettings() async {
    final s = await showTripStartSettings(context,
        settings: _settings,
        fromLastTrip: _fromLastTrip,
        lengthFixed: _plan != null);
    if (s != null && mounted) setState(() => _settings = s);
  }

  Future<void> _pickPlan() async {
    final plan = await showReadyPlanPicker(context, _plans);
    if (plan != null && mounted) _usePlan(plan);
  }

  void _toast(ToastKind kind, String title, {String? body}) =>
      Toasts.show(ToastData(kind: kind, title: title, body: body));

  Future<void> _start() async {
    if (_starting) return;
    final l10n = context.l10n;
    final auto = _settings.automaticUpdates && _autoAvailable;
    setState(() => _starting = true);
    try {
      final access =
          await ensureLocationAccess(context, requireBackground: auto);
      if (!mounted) return;
      if (access != LocationAccess.granted) {
        if (access == LocationAccess.serviceOff) {
          setState(() => _locationOff = true);
        }
        if (access != LocationAccess.dismissed) {
          _toast(
              ToastKind.error,
              access == LocationAccess.backgroundDenied ||
                      access == LocationAccess.backgroundNotAlways
                  ? l10n.readyBackgroundNeeded
                  : l10n.readyLocationNeeded);
        }
        return;
      }
      final here = await _locate() ?? _here;
      if (!mounted) return;
      if (here == null) {
        _toast(ToastKind.error, l10n.readyNoFix);
        return;
      }
      int? battery;
      try {
        // Optional; never hold the start up for it.
        battery =
            await Battery().batteryLevel.timeout(const Duration(seconds: 2));
      } catch (_) {}
      final typed = _name.text.trim();
      final trips = ref.read(tripServiceProvider);
      final result = await trips.startTrip(
        StartTripRequest(
          name: typed.length >= 3
              ? typed
              : readyTripName(_place, DateTime.now(), _locale),
          visibility: _settings.visibility,
          tripModality: _settings.modality,
          automaticUpdates: auto,
          updateRefresh: auto ? _settings.intervalMinutes * 60 : null,
          lat: here.latitude,
          lon: here.longitude,
          battery: battery,
          tripPlanId: _plan?.id,
        ),
        idempotencyKey: _idempotencyKey,
      );
      final trip = await trips.getTripById(result.tripId);
      if (auto && trip.status == TripStatus.inProgress) {
        await BackgroundUpdateManager()
            .startAutoUpdates(trip.id, trip.name, trip.effectiveUpdateRefresh);
      }
      if (!mounted) return;
      _toast(ToastKind.success, l10n.tripToastStarted,
          body: _place != null
              ? l10n.readyStartedBody(_place!)
              : l10n.tripToastStartedBody);
      setState(() => _started = trip);
    } catch (e) {
      if (mounted) _toast(ToastKind.error, readyStartError(l10n, e));
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _close() async {
    final trips = ref.read(tripServiceProvider);
    // A plan is already saved: going back creates or loses nothing.
    if (_plan != null) {
      trips.trackStartFunnel('CLOSED_WITHOUT_STARTING', source: _source);
      Navigator.of(context).pop();
      return;
    }
    switch (await showReadyCloseSheet(context)) {
      case ReadyCloseChoice.saveAsPlan:
        await _saveAsPlan();
      case ReadyCloseChoice.startNow:
        await _start();
      case ReadyCloseChoice.discard:
        trips.trackStartFunnel('CLOSED_WITHOUT_STARTING', source: _source);
        if (mounted) Navigator.of(context).pop();
      case null:
        break;
    }
  }

  /// Plans need a start and finish: here, today. Without a location the
  /// plan editor opens instead so they can be picked on the map.
  Future<void> _saveAsPlan() async {
    final l10n = context.l10n;
    final here = _here ?? await _locate(interactive: true);
    if (!mounted) return;
    if (here == null) {
      Navigator.of(context).pushReplacement(
          PageTransitions.slideFromRight(const CreateTripPlanScreen()));
      return;
    }
    final at = GeoLocation(lat: here.latitude, lon: here.longitude);
    final today = DateUtils.dateOnly(DateTime.now());
    final typed = _name.text.trim();
    try {
      await ref.read(tripPlanServiceProvider).createTripPlanBackend(
            CreateTripPlanBackendRequest(
              name: typed.length >= 3
                  ? typed
                  : readyTripName(_place, today, _locale),
              planType: _settings.modality.toJson(),
              startDate: today,
              endDate: today,
              startLocation: at,
              endLocation: at,
              metadata: {'visibility': _settings.visibility.toJson()},
            ),
          );
      ref
          .read(tripServiceProvider)
          .trackStartFunnel('SAVED_AS_PLAN', source: _source);
      if (!mounted) return;
      _toast(ToastKind.success, l10n.readySavedAsPlan);
      if (AndroidShell.selectTab(context, AndroidTab.trips)) {
        AndroidTripsTab.showPlans();
      } else {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        _toast(ToastKind.error,
            readyIsOffline(e) ? l10n.readyOffline : l10n.readySaveFailed);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // C · Started: the same screen is now the trip's Live view.
    if (_started case final trip?) {
      return widget.testLive?.call(trip) ??
          TripDetailScreen(key: ValueKey(trip.id), trip: trip);
    }
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    final top = MediaQuery.paddingOf(context).top + 8;
    final route = _route;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_starting) _close();
      },
      child: Scaffold(
        backgroundColor: c.mapGround,
        body: Stack(
          children: [
            Positioned.fill(
              child: widget.testMap ??
                  FutureBuilder(
                    future: PlanMapStyle.ensureLoaded(),
                    builder: (context, _) => TripMapView(
                      initialLocation: route.isNotEmpty
                          ? route.first
                          : _here ?? const LatLng(52.3676, 4.9041),
                      initialZoom: _here == null && route.isEmpty ? 4 : 14,
                      markers: route.isEmpty
                          ? const {}
                          : PlanMapStyle.markers(
                              start: route.first,
                              stops: [
                                for (final w in _plan!.waypoints)
                                  LatLng(w.lat, w.lon)
                              ],
                              finish: route.last),
                      polylines: PlanMapStyle.route(route),
                      // The native blue "you are here" dot.
                      isOwner: !kIsWeb,
                      onMapCreated: (m) {
                        _map = m;
                        _fitMap();
                      },
                      padding: EdgeInsets.only(top: top + 56, bottom: 400),
                    ),
                  ),
            ),
            Positioned(
              top: top,
              left: 16,
              child: PointerInterceptor(
                child: PlanMapButton(
                  key: const Key('ready_close'),
                  icon: _plan != null && widget.plan != null
                      ? Icons.arrow_back
                      : Icons.close,
                  tooltip: _plan != null && widget.plan != null
                      ? MaterialLocalizations.of(context).backButtonTooltip
                      : MaterialLocalizations.of(context).closeButtonTooltip,
                  onTap: _starting ? null : _close,
                ),
              ),
            ),
            if (_place != null && _plan == null)
              Positioned(
                top: top + 64,
                left: 0,
                right: 0,
                child: Center(
                  child: Pill(l10n.readyYouAreHere(_place!),
                      tone: PillTone.onImage),
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: PointerInterceptor(child: _sheet(context)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sheet(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    final plan = _plan;
    final caption = plan != null
        ? (plan.waypoints.isEmpty
            ? l10n.readyFromPlan
            : l10n.readyFromPlanStops(plan.waypoints.length))
        : _place != null
            ? l10n.readyNamedFromPlace
            : l10n.readyRenameAnytime;
    return Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x241B1A17), blurRadius: 30, offset: Offset(0, -8)),
        ],
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            20, 0, 20, 16 + MediaQuery.paddingOf(context).bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Center(
                child: Container(
                  width: 40,
                  height: 5,
                  margin: const EdgeInsets.symmetric(vertical: 11.5),
                  decoration: BoxDecoration(
                      color: c.line, borderRadius: BorderRadius.circular(999)),
                ),
              ),
            ),
            Wrap(spacing: 6, runSpacing: 6, children: [
              Pill(l10n.readyToStart, tone: PillTone.promoted),
              if (plan != null)
                Pill(TripModality.fromJson(plan.planType) ==
                        TripModality.multiDay
                    ? l10n.planDetailMultiDayPlan
                    : l10n.planDetailSimplePlan),
            ]),
            const SizedBox(height: 12),
            _nameField(context, editable: plan == null),
            const SizedBox(height: 6),
            Text(caption, style: TextStyle(fontSize: 13, color: c.caption)),
            const SizedBox(height: 14),
            _tiles(context),
            const SizedBox(height: 14),
            _hint(context),
            const SizedBox(height: 14),
            PlanPrimaryButton(
              key: const Key('ready_start'),
              label: l10n.tripStartAction,
              icon: Icons.play_arrow_rounded,
              loading: _starting,
              onPressed: _start,
            ),
            if (plan == null && _plans.isNotEmpty)
              SizedBox(
                height: 48,
                child: TextButton.icon(
                  key: const Key('ready_pick_plan'),
                  onPressed: _starting ? null : _pickPlan,
                  iconAlignment: IconAlignment.end,
                  icon: const Icon(Icons.chevron_right, size: 18),
                  label: Text(l10n.readyOrPlans),
                  style: TextButton.styleFrom(
                    foregroundColor: c.accentText,
                    textStyle: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _nameField(BuildContext context, {required bool editable}) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    final style = WandererTheme.display(23, color: c.text);
    if (!editable) {
      return Semantics(
          header: true, child: Text(_name.text, style: style, maxLines: 2));
    }
    return TextField(
      key: const Key('ready_name'),
      controller: _name,
      style: style,
      maxLines: 1,
      textInputAction: TextInputAction.done,
      inputFormatters: [LengthLimitingTextInputFormatter(100)],
      onChanged: (_) => _nameEdited = true,
      decoration: InputDecoration(
        labelText: null,
        hintText: l10n.newTripName,
        semanticCounterText: '',
        isDense: true,
        contentPadding: const EdgeInsets.only(bottom: 6),
        filled: false,
        suffixIcon: Icon(Icons.edit_outlined, size: 18, color: c.caption),
        suffixIconConstraints:
            const BoxConstraints(minWidth: 24, minHeight: 24),
        enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: c.line, width: 1.5)),
        focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: WandererTheme.trail, width: 1.5)),
      ),
    );
  }

  Widget _tiles(BuildContext context) {
    final l10n = context.l10n;
    final plan = _plan;
    final days = plan?.startDate == null || plan?.endDate == null
        ? null
        : DateUtils.dateOnly(plan!.endDate!)
                .difference(DateUtils.dateOnly(plan.startDate!))
                .inDays +
            1;
    final tiles = [
      (
        'ready_tile_visibility',
        l10n.readyTileWho,
        visibilityName(l10n, _settings.visibility)
      ),
      if (_autoAvailable)
        (
          'ready_tile_auto',
          l10n.newTripAutoCheckIn,
          _settings.automaticUpdates
              ? l10n.newTripMinutes(_settings.intervalMinutes)
              : l10n.newTripOff
        ),
      (
        'ready_tile_length',
        l10n.newTripLength,
        days != null && days > 1
            ? l10n.daysCount(days)
            : _settings.modality == TripModality.multiDay
                ? l10n.newTripMultiDay
                : l10n.readyOneDay
      ),
    ];
    return Row(children: [
      for (final (i, (key, label, value)) in tiles.indexed) ...[
        if (i > 0) const SizedBox(width: 8),
        Expanded(
            child: _SettingTile(
                key: Key(key),
                label: label,
                value: value,
                onTap: _starting ? null : _openSettings)),
      ],
    ]);
  }

  /// Green "checks you in right here", or how to turn location on.
  Widget _hint(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    final off = _locationOff && _here == null;
    final (bg, fg) = off ? (c.goldBg, c.goldFg) : (c.forestBg, c.forestFg);
    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding:
          EdgeInsets.fromLTRB(12, off ? 4 : 10, off ? 4 : 12, off ? 4 : 10),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Icon(off ? Icons.location_off_outlined : Icons.place_outlined,
            size: 16, color: fg),
        const SizedBox(width: 10),
        Expanded(
          child: Text(off ? l10n.readyLocationOff : l10n.readyCheckInHere,
              style: TextStyle(fontSize: 13, color: fg)),
        ),
        if (off)
          SizedBox(
            height: 48,
            child: TextButton(
              key: const Key('ready_turn_on_location'),
              onPressed: () => _locate(interactive: true),
              style: TextButton.styleFrom(
                foregroundColor: fg,
                textStyle:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              child: Text(l10n.readyTurnOn),
            ),
          ),
      ]),
    );
  }
}

/// Stat-tile look, but a button with a chevron (opens the settings sheet).
class _SettingTile extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onTap;
  const _SettingTile(
      {super.key, required this.label, required this.value, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    return Semantics(
      button: true,
      label: '$label: $value',
      hint: context.l10n.tripChange,
      excludeSemantics: true,
      child: Material(
        color: c.raised,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: c.caption)),
                  Row(children: [
                    Expanded(
                      child: Text(value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: c.text)),
                    ),
                    Icon(Icons.chevron_right, size: 16, color: c.label),
                  ]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Amsterdam · Tue 6 Oct"; date only when [place] is unknown.
@visibleForTesting
String readyTripName(String? place, DateTime date, String locale) {
  final day = DateFormat('EEE d MMM', locale).format(date);
  return place == null || place.isEmpty ? day : '$place · $day';
}

/// Random v4-style UUID for the Start Idempotency-Key.
@visibleForTesting
String newIdempotencyKey() {
  final r = Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
      '${h.substring(16, 20)}-${h.substring(20)}';
}

/// No connection (or no answer in time).
bool readyIsOffline(Object e) =>
    e is http.ClientException || e is TimeoutException;

/// Plain-words message for a failed Start (no error codes).
String readyStartError(AppLocalizations l10n, Object e) => switch (e) {
      ApiException(statusCode: 409) => l10n.readyAlreadyLive,
      _ when readyIsOffline(e) => l10n.readyOffline,
      _ => l10n.readyStartFailed,
    };
