import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:wanderer_frontend/presentation/helpers/adaptive_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:wanderer_frontend/core/providers/app_providers.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/data/client/google_directions_api_client.dart';
import 'package:wanderer_frontend/data/client/polyline_codec.dart';
import 'package:wanderer_frontend/data/models/requests/create_trip_plan_backend_request.dart';
import 'package:wanderer_frontend/data/models/domain/trip_plan.dart';
import 'package:wanderer_frontend/data/services/trip_plan_service.dart';
import 'package:wanderer_frontend/presentation/screens/trip_plan_detail_screen.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/presentation/helpers/dashed_polyline_helper.dart';
import 'package:wanderer_frontend/presentation/helpers/location_permission_disclosure.dart';
import 'package:wanderer_frontend/presentation/helpers/web_marker_generator.dart';
import 'package:wanderer_frontend/presentation/helpers/map_style_helper.dart';
import 'package:wanderer_frontend/presentation/helpers/dialog_helper.dart';
import 'package:wanderer_frontend/presentation/helpers/page_transitions.dart';
import 'package:wanderer_frontend/presentation/screens/initial_screen.dart';
import 'package:wanderer_frontend/presentation/screens/settings_screen.dart';
import 'package:wanderer_frontend/presentation/widgets/android/android_ui.dart';
import 'package:wanderer_frontend/presentation/widgets/android/plan_editor_layout.dart';
import 'package:wanderer_frontend/presentation/widgets/android/plan_map_style.dart';
import 'package:wanderer_frontend/presentation/widgets/common/app_sidebar.dart';
import 'package:wanderer_frontend/presentation/widgets/common/wanderer_sheet.dart';
import 'package:wanderer_frontend/presentation/widgets/common/wanderer_dialog.dart';
import 'package:wanderer_frontend/presentation/widgets/common/wanderer_scaffold.dart';
import 'package:wanderer_frontend/presentation/widgets/trip_plans/web_plan_editor_layout.dart';

/// Screen for creating a new trip plan with map integration
class CreateTripPlanScreen extends ConsumerStatefulWidget {
  const CreateTripPlanScreen({super.key});

  @override
  ConsumerState<CreateTripPlanScreen> createState() =>
      _CreateTripPlanScreenState();
}

/// The type of point the user wants to place next on the map
enum _PlacementMode { start, end, waypoint }

class _CreateTripPlanScreenState extends ConsumerState<CreateTripPlanScreen> {
  late final TripPlanService _tripPlanService;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  final List<LatLng> _waypoints = [];

  /// Directions API client for computing road-snapped polylines
  late final GoogleDirectionsApiClient _directionsClient;

  /// The computed encoded polyline string to send to the backend
  String? _encodedPolyline;

  /// Whether a polyline computation is in progress
  bool _isComputingRoute = false;

  static const LatLng _defaultLocation = LatLng(40.7128, -74.0060);
  LatLng _initialCameraLocation = _defaultLocation;
  LatLng? _startLocation;
  LatLng? _endLocation;
  bool _isLoadingLocation = true;

  String _planType = 'SIMPLE';
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isLoading = false;

  /// Which point type the next map tap will place
  _PlacementMode _placementMode = _PlacementMode.start;

  /// Route shown on the Android map (road-snapped or straight fallback).
  List<LatLng> _routePoints = const [];

  /// Flag to ignore the next map tap — set when a UI overlay is tapped on web
  /// to prevent the underlying platform view from also firing onTap.
  bool _ignoreNextMapTap = false;

  /// True while a date picker dialog is open — gates map tap handling so
  /// tapping a date inside the dialog does not also drop a waypoint.
  bool _isPickerOpen = false;

  /// Web: set by the map's own Listener so the page-level Listener can tell
  /// a click on the map from a click on an overlay above it.
  bool _pointerOnMap = false;

  // Web sidebar user info
  String? _userId;
  String? _username;
  String? _displayName;
  String? _avatarUrl;
  bool _isAdmin = false;

  /// Computed number of days between start and end dates
  int? get _daysBetween {
    if (_startDate == null || _endDate == null) return null;
    return _endDate!.difference(_startDate!).inDays + 1;
  }

  @override
  void initState() {
    super.initState();
    _tripPlanService = ref.read(tripPlanServiceProvider);
    _directionsClient = ref.read(googleDirectionsApiClientProvider);
    _getCurrentLocation();
    if (kIsWeb) _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final home = ref.read(homeRepositoryProvider);
    final username = await home.getCurrentUsername();
    final userId = await home.getCurrentUserId();
    final isAdmin = await home.isAdmin();
    final displayName = await home.getCurrentDisplayName();
    final avatarUrl = await home.getCurrentAvatarUrl();
    if (!mounted) return;
    setState(() {
      _username = username;
      _userId = userId;
      _displayName = displayName;
      _avatarUrl = avatarUrl;
      _isAdmin = isAdmin;
    });
  }

  Future<void> _logout() async {
    final confirm = await DialogHelper.showLogoutConfirmation(context);
    if (!confirm) return;
    await ref.read(homeRepositoryProvider).logout();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        PageTransitions.fade(const InitialScreen()),
        (route) => false,
      );
    }
  }

  void _handleSettings() {
    Navigator.push(
      context,
      PageTransitions.slideFromBottom(const SettingsScreen()),
    );
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _isLoadingLocation = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        if (!mounted) return;
        // Play-policy disclosure is Android-only; browsers prompt themselves.
        final consented =
            kIsWeb || await LocationPermissionDisclosure.show(context);
        if (!consented) {
          setState(() => _isLoadingLocation = false);
          return;
        }
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _isLoadingLocation = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() => _isLoadingLocation = false);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 10),
      );

      final userLocation = LatLng(position.latitude, position.longitude);

      setState(() {
        _initialCameraLocation = userLocation;
        _isLoadingLocation = false;
      });

      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(userLocation, 12),
      );
    } catch (e) {
      setState(() => _isLoadingLocation = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  /// Builds the ordered list of plan points: start → waypoints → end.
  List<LatLng> _buildOrderedPoints() {
    final points = <LatLng>[];
    if (_startLocation != null) points.add(_startLocation!);
    points.addAll(_waypoints);
    if (_endLocation != null) points.add(_endLocation!);
    return points;
  }

  /// Computes a road-snapped polyline via the Directions API and shows it
  /// on the map. Falls back to a straight-line polyline if the API call
  /// fails or if start/end are not yet set.
  Future<void> _computeRoutePolyline() async {
    final points = _buildOrderedPoints();

    if (points.length < 2) {
      // Not enough points — clear any existing polyline
      setState(() {
        _polylines.clear();
        _encodedPolyline = null;
        _routePoints = const [];
      });
      return;
    }

    // Show straight-line fallback immediately while loading
    _showStraightLinePolyline(points);

    setState(() => _isComputingRoute = true);

    try {
      final result = await _directionsClient.getRouteWithPoints(points);

      if (!mounted) return;

      if (result != null) {
        setState(() {
          _polylines.clear();
          _polylines.add(
            Polyline(
              polylineId: const PolylineId('planned_route'),
              points: result.routePoints,
              color: Colors.blue,
              width: 5,
              geodesic: false,
              startCap: Cap.roundCap,
              endCap: Cap.roundCap,
              jointType: JointType.round,
            ),
          );
          _encodedPolyline = result.encodedPolyline;
          _routePoints = result.routePoints;
          _isComputingRoute = false;
        });
      } else {
        // API returned no route — keep straight-line fallback and encode it
        setState(() {
          _encodedPolyline = PolylineCodec.encode(points);
          _isComputingRoute = false;
        });
      }
    } catch (e) {
      debugPrint('CreateTripPlanScreen: Route computation failed: $e');
      if (!mounted) return;
      setState(() {
        _encodedPolyline = PolylineCodec.encode(points);
        _isComputingRoute = false;
      });
    }
  }

  /// Shows a dashed straight-line polyline as an immediate visual fallback.
  void _showStraightLinePolyline(List<LatLng> points) {
    setState(() {
      _routePoints = points;
      _polylines.clear();
      _polylines.addAll(
        DashedPolylineHelper.createDashedPolylines(
          polylineIdPrefix: 'planned_route',
          points: points,
          color: Colors.blue.withOpacity(0.5),
          width: 3,
        ),
      );
    });
  }

  void _onMapTapped(LatLng location) {
    // Ignore map taps that originated from UI overlay interactions (web issue)
    if (_ignoreNextMapTap) {
      _ignoreNextMapTap = false;
      return;
    }
    // Ignore map taps while a date picker dialog is open (Flutter Web platform
    // view receives the click independently of the dialog overlay).
    if (_isPickerOpen) return;

    setState(() {
      switch (_placementMode) {
        case _PlacementMode.start:
          // Replace existing start marker if any
          _markers.removeWhere((m) => m.markerId.value == 'start');
          _startLocation = location;
          _addMarker(
            location,
            'start',
            'Start Location',
            WebMarkerGenerator.markerWithHue(120.0), // Green
          );
          // Auto-advance to next unset point
          if (_endLocation == null) {
            _placementMode = _PlacementMode.end;
          } else {
            _placementMode = _PlacementMode.waypoint;
          }
          break;
        case _PlacementMode.end:
          // Replace existing end marker if any
          _markers.removeWhere((m) => m.markerId.value == 'end');
          _endLocation = location;
          _addMarker(
            location,
            'end',
            'End Location',
            WebMarkerGenerator.markerWithHue(0.0), // Red
          );
          // Auto-advance to waypoints
          _placementMode = _PlacementMode.waypoint;
          break;
        case _PlacementMode.waypoint:
          final waypointNumber = _waypoints.length + 1;
          _waypoints.add(location);
          _addMarker(
            location,
            'waypoint_$waypointNumber',
            'Waypoint $waypointNumber',
            WebMarkerGenerator.markerWithHue(240.0), // Blue
          );
          break;
      }
    });
    _computeRoutePolyline();
  }

  void _addMarker(
    LatLng location,
    String id,
    String title,
    BitmapDescriptor icon,
  ) {
    _markers.add(
      Marker(
        markerId: MarkerId(id),
        position: location,
        infoWindow: InfoWindow(title: title),
        icon: icon,
        draggable: true,
        onTap: () => _onMarkerTapped(id, title),
        onDragEnd: (newPosition) => _onMarkerDragEnd(id, newPosition),
      ),
    );
  }

  /// Called when a marker is dragged to a new position on the map
  void _onMarkerDragEnd(String markerId, LatLng newPosition) {
    setState(() {
      if (markerId == 'start') {
        _startLocation = newPosition;
      } else if (markerId == 'end') {
        _endLocation = newPosition;
      } else if (markerId.startsWith('waypoint_')) {
        final index = int.tryParse(markerId.split('_').last);
        if (index != null && index > 0 && index <= _waypoints.length) {
          _waypoints[index - 1] = newPosition;
        }
      }
      // Rebuild the moved marker with updated position
      _markers.removeWhere((m) => m.markerId.value == markerId);
      final icon = markerId == 'start'
          ? WebMarkerGenerator.markerWithHue(120.0) // Green
          : markerId == 'end'
              ? WebMarkerGenerator.markerWithHue(0.0) // Red
              : WebMarkerGenerator.markerWithHue(240.0); // Blue
      final title = markerId == 'start'
          ? 'Start Location'
          : markerId == 'end'
              ? 'End Location'
              : 'Waypoint ${markerId.split('_').last}';
      _addMarker(newPosition, markerId, title, icon);
    });
    _computeRoutePolyline();
  }

  /// Shows a bottom sheet when a marker is tapped, allowing the user to
  /// delete the point or re-place it.
  void _onMarkerTapped(String markerId, String title) {
    if (AdaptiveLayout.usesDesktopLayout(context)) {
      _showWebMarkerDialog(markerId);
      return;
    }
    final l10n = context.l10n;
    final c = WandererTheme.of(context);
    showWandererSheet<void>(
      context,
      title: markerId == 'start'
          ? l10n.planEditorStart
          : markerId == 'end'
              ? l10n.planEditorFinish
              : '${l10n.planEditorStop} ${markerId.split('_').last}',
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.my_location_rounded, color: c.accentText),
            title: Text(l10n.rePlaceOnMap),
            subtitle: Text(l10n.tapMapToSetPosition,
                style: TextStyle(fontSize: 12, color: c.caption)),
            onTap: () {
              Navigator.pop(sheetContext);
              setState(() {
                _placementMode = markerId == 'start'
                    ? _PlacementMode.start
                    : markerId == 'end'
                        ? _PlacementMode.end
                        : _PlacementMode.waypoint;
              });
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.delete_outline,
                color: Theme.of(context).colorScheme.error),
            title: Text(l10n.remove,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
            onTap: () {
              Navigator.pop(sheetContext);
              _deleteMarker(markerId);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showWebMarkerDialog(String markerId) async {
    final l10n = context.l10n;
    final title = markerId == 'start'
        ? l10n.planEditorStart
        : markerId == 'end'
            ? l10n.planEditorFinish
            : '${l10n.planEditorStop} ${markerId.split('_').last}';
    setState(() => _isPickerOpen = true);
    final String? action;
    try {
      action = await WandererDialog.show<String>(
        context,
        width: WandererDialog.infoWidth,
        builder: (context) => WandererFormDialog(
          title: title,
          body: Text(l10n.tapMapToSetPosition),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'remove'),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              child: Text(l10n.remove),
            ),
            OutlinedButton(
              onPressed: () => Navigator.pop(context, 'replace'),
              child: Text(l10n.rePlaceOnMap),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isPickerOpen = false;
          _ignoreNextMapTap = true;
        });
      }
    }
    if (!mounted) return;
    if (action == 'remove') {
      _deleteMarker(markerId);
    } else if (action == 'replace') {
      setState(() {
        _placementMode = markerId == 'start'
            ? _PlacementMode.start
            : markerId == 'end'
                ? _PlacementMode.end
                : _PlacementMode.waypoint;
      });
    }
  }

  void _deleteMarker(String markerId) {
    setState(() {
      _markers.removeWhere((m) => m.markerId.value == markerId);
      if (markerId == 'start') {
        _startLocation = null;
        _placementMode = _PlacementMode.start;
      } else if (markerId == 'end') {
        _endLocation = null;
        _placementMode = _PlacementMode.end;
      } else if (markerId.startsWith('waypoint_')) {
        final index = int.tryParse(markerId.split('_').last);
        if (index != null && index > 0 && index <= _waypoints.length) {
          _waypoints.removeAt(index - 1);
          _rebuildWaypointMarkers();
        }
      }
    });
    _computeRoutePolyline();
  }

  /// Removes all waypoint markers and re-adds them with corrected numbering
  void _rebuildWaypointMarkers() {
    _markers.removeWhere(
      (m) => m.markerId.value.startsWith('waypoint_'),
    );
    for (int i = 0; i < _waypoints.length; i++) {
      _addMarker(
        _waypoints[i],
        'waypoint_${i + 1}',
        'Waypoint ${i + 1}',
        WebMarkerGenerator.markerWithHue(240.0), // Blue
      );
    }
  }

  void _removeLastWaypoint() {
    if (_waypoints.isNotEmpty) {
      setState(() {
        _waypoints.removeLast();
        _markers.removeWhere(
          (marker) =>
              marker.markerId.value == 'waypoint_${_waypoints.length + 1}',
        );
      });
    } else if (_endLocation != null) {
      setState(() {
        _endLocation = null;
        _markers.removeWhere((marker) => marker.markerId.value == 'end');
        _placementMode = _PlacementMode.end;
      });
    } else if (_startLocation != null) {
      setState(() {
        _startLocation = null;
        _markers.removeWhere((marker) => marker.markerId.value == 'start');
        _placementMode = _PlacementMode.start;
      });
    }
    _computeRoutePolyline();
  }

  Future<void> _selectDateRange() async {
    setState(() => _isPickerOpen = true);
    ({DateTime start, DateTime end, bool multiDay})? picked;
    try {
      picked = await pickPlanDates(context,
          multiDay: _planType == 'MULTI_DAY', start: _startDate, end: _endDate);
    } finally {
      if (mounted) {
        setState(() {
          _isPickerOpen = false;
          // Absorb the trailing map tap that the platform view fires
          // after the dialog dismisses (Save / Cancel / X click).
          _ignoreNextMapTap = true;
        });
      }
    }
    if (picked case final p? when mounted) {
      setState(() {
        _startDate = p.start;
        _endDate = p.end;
        _planType = p.multiDay ? 'MULTI_DAY' : 'SIMPLE';
      });
    }
  }

  /// Single-day plans end the day they start.
  void _setMultiDay(bool multi) => setState(() {
        _planType = multi ? 'MULTI_DAY' : 'SIMPLE';
        if (!multi && _startDate != null) _endDate = _startDate;
      });

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return context.l10n.createPlanNameRequired;
    }
    if (value.trim().length < 3) {
      return context.l10n.createPlanNameMinLength;
    }
    return null;
  }

  Future<void> _createTripPlan() async {
    // The web editor has no Form; validate the name directly there.
    if (AdaptiveLayout.usesDesktopLayout(context)) {
      final nameError = _validateName(_nameController.text);
      if (nameError != null) {
        planNotify(context, error: true, nameError);
        return;
      }
    } else if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_startLocation == null || _endLocation == null) {
      planNotify(
        context,
        error: true,
        context.l10n.createPlanSelectLocations,
      );
      return;
    }

    if (_startDate == null || _endDate == null) {
      planNotify(context, error: true, context.l10n.createPlanSelectDates);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final metadata = <String, dynamic>{};
      if (_planType == 'MULTI_DAY' && _daysBetween != null) {
        metadata['multiDayTrip'] = _daysBetween;
      }

      final request = CreateTripPlanBackendRequest(
        name: _nameController.text.trim(),
        planType: _planType,
        startDate: _startDate!,
        endDate: _endDate!,
        startLocation: GeoLocation(
          lat: _startLocation!.latitude,
          lon: _startLocation!.longitude,
        ),
        endLocation: GeoLocation(
          lat: _endLocation!.latitude,
          lon: _endLocation!.longitude,
        ),
        waypoints: _waypoints
            .map((loc) => GeoLocation(lat: loc.latitude, lon: loc.longitude))
            .toList(),
        metadata: metadata.isNotEmpty ? metadata : null,
        plannedPolyline: _encodedPolyline,
      );

      final planId = await _tripPlanService.createTripPlanBackend(request);

      if (mounted) {
        planNotify(
          context,
          context.l10n.createPlanCreated,
        );
      }
      // Open the new plan. Writes return only the id and the read side
      // catches up shortly after, so retry the fetch a few times.
      TripPlan? plan;
      for (var i = 0; i < 4 && plan == null && planId.isNotEmpty; i++) {
        try {
          plan = await _tripPlanService.getTripPlanById(planId);
        } catch (_) {
          await Future.delayed(Duration(milliseconds: 500 * (i + 1)));
        }
      }
      if (!mounted) return;
      if (plan == null) {
        Navigator.pop(context, true);
      } else {
        Navigator.of(context).pushReplacement(
            PageTransitions.slideFromRight(
                TripPlanDetailScreen(tripPlan: plan)),
            result: true);
      }
    } catch (e) {
      if (mounted) {
        planNotify(context, error: true, context.l10n.createPlanError(e));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (AdaptiveLayout.usesDesktopLayout(context)) return _buildWeb();
    return _buildAndroid();
  }

  /// Android: full-screen map, floating controls, form in a bottom sheet
  /// (canvas "New plan").
  Widget _buildAndroid() {
    final l10n = context.l10n;
    final (step, hint) = _startLocation == null
        ? (1, l10n.planStepStart)
        : _endLocation == null
            ? (2, l10n.planStepFinish)
            : (3, l10n.planStepStops);
    final ready = _startLocation != null &&
        _endLocation != null &&
        _startDate != null &&
        _nameController.text.trim().isNotEmpty;
    return PlanEditorLayout(
      title: l10n.tripPlansNewPlan,
      closeTooltip: l10n.close,
      onClose: () => Navigator.maybePop(context),
      onUndo: _startLocation == null ? null : _removeLastWaypoint,
      onMyLocation: _isLoadingLocation ? null : _getCurrentLocation,
      stopCount: _waypoints.length,
      mode: switch (_placementMode) {
        _PlacementMode.start => PlanPlacementMode.start,
        _PlacementMode.end => PlanPlacementMode.finish,
        _PlacementMode.waypoint => PlanPlacementMode.stop,
      },
      onModeChanged: (mode) => setState(() {
        _placementMode = switch (mode) {
          PlanPlacementMode.start => _PlacementMode.start,
          PlanPlacementMode.finish => _PlacementMode.end,
          PlanPlacementMode.stop => _PlacementMode.waypoint,
        };
      }),
      map: FutureBuilder(
        future: PlanMapStyle.ensureLoaded(),
        builder: (context, _) => GoogleMap(
          style: MapStyleHelper.of(context),
          initialCameraPosition:
              CameraPosition(target: _initialCameraLocation, zoom: 12),
          markers: PlanMapStyle.markers(
            start: _startLocation,
            stops: _waypoints,
            finish: _endLocation,
            draggable: true,
            onTap: (id) => _onMarkerTapped(id, id),
            onDragEnd: _onMarkerDragEnd,
          ),
          polylines: PlanMapStyle.route(_routePoints),
          onMapCreated: _onMapCreated,
          onTap: _onMapTapped,
          padding: const EdgeInsets.only(top: 110),
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
        ),
      ),
      sheet: [
        PlanStepHint(step: step, text: hint),
        Form(
          key: _formKey,
          child: LabeledField(
            label: l10n.planEditorName,
            hint: l10n.planEditorNameHint,
            controller: _nameController,
            validator: _validateName,
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {}),
          ),
        ),
        PlanTypeToggle(
          multiDay: _planType == 'MULTI_DAY',
          onChanged: _setMultiDay,
        ),
        PlanDateTiles(
            start: _startDate,
            end: _endDate,
            singleDay: _planType != 'MULTI_DAY',
            onPick: _selectDateRange),
        PlanPrimaryButton(
          label: l10n.createPlanSave,
          loading: _isLoading,
          onPressed: ready ? _createTripPlan : null,
        ),
      ],
    );
  }

  static String _coords(LatLng p) =>
      '${p.latitude.toStringAsFixed(4)}, ${p.longitude.toStringAsFixed(4)}';

  /// Web: sidebar + [WebPlanEditorLayout] (canvas "New trip plan").
  Widget _buildWeb() {
    final l10n = context.l10n;
    return WandererScaffold(
      hideAppBarWithSidebar: true,
      appBar: AppBar(title: Text(l10n.tripPlansNewPlan)),
      drawer: AppSidebar(
        username: _username,
        userId: _userId,
        displayName: _displayName,
        avatarUrl: _avatarUrl,
        selectedIndex: 1,
        onLogout: _logout,
        onSettings: _handleSettings,
        isAdmin: _isAdmin,
      ),
      body: Listener(
        // Flutter Web: clicks on overlays above the map (placement picker,
        // zoom/undo) also reach the map platform view — swallow that tap.
        onPointerDown: (_) {
          if (!_pointerOnMap) {
            _ignoreNextMapTap = true;
            // ponytail: time-boxed so a click elsewhere on the page can't
            // swallow a later real map click.
            Future.delayed(
              const Duration(milliseconds: 300),
              () => _ignoreNextMapTap = false,
            );
          }
          _pointerOnMap = false;
        },
        child: WebPlanEditorLayout(
          breadcrumbCurrent: l10n.tripPlansNewPlan,
          onBreadcrumbTap: () => Navigator.maybePop(context),
          title: l10n.tripPlansPlanNewTrip,
          saveLabel: l10n.createPlanSave,
          onCancel: () => Navigator.maybePop(context),
          onSave: _createTripPlan,
          isSaving: _isLoading,
          nameController: _nameController,
          descriptionController: _descriptionController,
          multiDay: _planType == 'MULTI_DAY',
          onMultiDayChanged: _setMultiDay,
          startDate: _startDate,
          endDate: _endDate,
          onPickStartDate: _selectDateRange,
          onPickEndDate: _selectDateRange,
          startLabel: _startLocation == null ? null : _coords(_startLocation!),
          finishLabel: _endLocation == null ? null : _coords(_endLocation!),
          stopCount: _waypoints.length,
          routeMeta: _isComputingRoute ? l10n.computingRoute : null,
          placementMode: switch (_placementMode) {
            _PlacementMode.start => PlanPlacementMode.start,
            _PlacementMode.end => PlanPlacementMode.finish,
            _PlacementMode.waypoint => PlanPlacementMode.stop,
          },
          onPlacementModeChanged: (mode) => setState(() {
            _placementMode = switch (mode) {
              PlanPlacementMode.start => _PlacementMode.start,
              PlanPlacementMode.finish => _PlacementMode.end,
              PlanPlacementMode.stop => _PlacementMode.waypoint,
            };
          }),
          onZoomIn: () => _mapController?.animateCamera(CameraUpdate.zoomIn()),
          onZoomOut: () =>
              _mapController?.animateCamera(CameraUpdate.zoomOut()),
          onUndo: _markers.isEmpty ? null : _removeLastWaypoint,
          showStartHint: _startLocation == null,
          map: Listener(
            onPointerDown: (_) => _pointerOnMap = true,
            child: _buildWebMap(),
          ),
        ),
      ),
    );
  }

  Widget _buildWebMap() => GoogleMap(
        style: MapStyleHelper.of(context),
        initialCameraPosition: CameraPosition(
          target: _initialCameraLocation,
          zoom: 12,
        ),
        markers: _markers,
        polylines: _polylines,
        onMapCreated: _onMapCreated,
        onTap: _onMapTapped,
        myLocationButtonEnabled: false,
        myLocationEnabled: true,
        zoomControlsEnabled: false,
        mapToolbarEnabled: false,
      );
}
