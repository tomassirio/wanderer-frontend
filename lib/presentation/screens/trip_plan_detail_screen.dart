import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:wanderer_frontend/core/providers/app_providers.dart';
import 'package:wanderer_frontend/data/client/google_directions_api_client.dart';
import 'package:wanderer_frontend/data/client/polyline_codec.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/data/repositories/home_repository.dart';
import 'package:wanderer_frontend/data/services/trip_plan_service.dart';
import 'package:wanderer_frontend/data/services/trip_service.dart';
import 'package:wanderer_frontend/presentation/helpers/auth_navigation_helper.dart';
import 'package:wanderer_frontend/presentation/helpers/dashed_polyline_helper.dart';
import 'package:wanderer_frontend/presentation/helpers/dialog_helper.dart';
import 'package:wanderer_frontend/presentation/helpers/trip_plan_map_helper.dart';
import 'package:wanderer_frontend/presentation/helpers/page_transitions.dart';
import 'package:wanderer_frontend/presentation/screens/auth_screen.dart';
import 'package:wanderer_frontend/presentation/screens/settings_screen.dart';
import 'package:wanderer_frontend/presentation/screens/trip_detail_screen.dart';
import 'package:wanderer_frontend/presentation/widgets/common/wanderer_app_bar.dart';
import 'package:wanderer_frontend/presentation/screens/android/plan_detail_view.dart';
import 'package:wanderer_frontend/presentation/widgets/android/android_ui.dart';
import 'package:wanderer_frontend/presentation/widgets/android/plan_editor_layout.dart';
import 'package:wanderer_frontend/presentation/widgets/android/plan_map_style.dart';
import 'package:wanderer_frontend/presentation/widgets/common/app_sidebar.dart';
import 'package:wanderer_frontend/presentation/widgets/common/wanderer_sheet.dart';
import 'package:wanderer_frontend/presentation/widgets/trip_plans/trip_from_plan_dialog.dart';
import 'package:wanderer_frontend/presentation/widgets/trip_plans/web_plan_detail_layout.dart';
import 'package:wanderer_frontend/presentation/widgets/trip_plans/web_plan_editor_layout.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/presentation/widgets/common/wanderer_scaffold.dart';
import 'package:wanderer_frontend/presentation/screens/initial_screen.dart';
import 'package:wanderer_frontend/presentation/helpers/map_style_helper.dart';
import 'package:wanderer_frontend/presentation/widgets/common/wanderer_dialog.dart';
import 'package:wanderer_frontend/presentation/helpers/adaptive_layout.dart';

/// The type of point the user wants to place next on the map in edit mode
enum _EditPlacementMode { start, end, waypoint }

/// Screen for viewing and editing a trip plan
class TripPlanDetailScreen extends ConsumerStatefulWidget {
  final TripPlan tripPlan;

  /// Android: open straight into the editor (Plans tab "Edit").
  final bool startInEdit;

  const TripPlanDetailScreen(
      {super.key, required this.tripPlan, this.startInEdit = false});

  @override
  ConsumerState<TripPlanDetailScreen> createState() =>
      _TripPlanDetailScreenState();
}

class _TripPlanDetailScreenState extends ConsumerState<TripPlanDetailScreen> {
  late final TripPlanService _tripPlanService;
  late final TripService _tripService;
  late final HomeRepository _homeRepository;
  late final GoogleDirectionsApiClient _directionsClient;
  late TripPlan _tripPlan;
  bool _isEditing = false;
  bool _isLoading = false;

  // User state for WandererAppBar & AppSidebar
  String? _username;
  String? _userId;
  String? _displayName;
  String? _avatarUrl;
  bool _isLoggedIn = false;
  bool _isAdmin = false;

  late TextEditingController _nameController;
  late String _selectedPlanType;
  DateTime? _startDate;
  DateTime? _endDate;

  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  // Edit mode map state
  List<LatLng> _editWaypoints = [];
  LatLng? _editStartLocation;
  LatLng? _editEndLocation;
  bool _showEditWaypointsList = false;

  /// Placement mode for adding/moving points in edit mode
  _EditPlacementMode _editPlacementMode = _EditPlacementMode.waypoint;

  /// Polylines computed for edit mode (road-snapped or fallback)
  final Set<Polyline> _editPolylines = {};

  /// The computed encoded polyline for saving
  String? _editEncodedPolyline;

  /// Whether a route computation is in progress
  bool _isEditComputingRoute = false;

  /// Flag to ignore the next map tap on web
  bool _editIgnoreNextMapTap = false;

  /// True while a date picker dialog is open — gates map tap handling so
  /// tapping a date inside the dialog does not also drop a waypoint.
  bool _isPickerOpen = false;

  @override
  void initState() {
    super.initState();
    _tripPlanService = ref.read(tripPlanServiceProvider);
    _tripService = ref.read(tripServiceProvider);
    _homeRepository = ref.read(homeRepositoryProvider);
    _directionsClient = ref.read(googleDirectionsApiClientProvider);
    _tripPlan = widget.tripPlan;
    _nameController = TextEditingController(text: _tripPlan.name);
    _selectedPlanType = _tripPlan.planType;
    _startDate = _tripPlan.startDate;
    _endDate = _tripPlan.endDate;
    _initEditLocations();
    _updateMapData();
    _loadUserInfo();
    if (widget.startInEdit) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _enterEditMode();
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadUserInfo() async {
    final username = await _homeRepository.getCurrentUsername();
    final userId = await _homeRepository.getCurrentUserId();
    final isLoggedIn = await _homeRepository.isLoggedIn();
    final isAdmin = await _homeRepository.isAdmin();

    if (isLoggedIn) {
      await _homeRepository.refreshUserDetails();
    }

    final displayName = await _homeRepository.getCurrentDisplayName();
    final avatarUrl = await _homeRepository.getCurrentAvatarUrl();

    if (mounted) {
      setState(() {
        _username = username;
        _userId = userId;
        _displayName = displayName;
        _avatarUrl = avatarUrl;
        _isLoggedIn = isLoggedIn;
        _isAdmin = isAdmin;
      });
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await DialogHelper.showLogoutConfirmation(context);

    if (confirm) {
      await _homeRepository.logout();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          PageTransitions.fade(const InitialScreen()),
          (route) => false,
        );
      }
    }
  }

  void _handleSettings() {
    Navigator.push(
      context,
      PageTransitions.slideFromBottom(const SettingsScreen()),
    );
  }

  Future<void> _navigateToAuth() async {
    final result = await Navigator.push(
      context,
      PageTransitions.fade(const AuthScreen()),
    );

    if (result == true && mounted) {
      await _loadUserInfo();
    }
  }

  /// Updates map data using backend polyline or straight-line fallback
  void _updateMapData() {
    try {
      final mapData = TripPlanMapHelper.createMapDataWithDirections(
        _tripPlan,
        onWaypointTap: _showWaypointOptions,
      );
      setState(() {
        _markers = mapData.markers;
        _polylines = mapData.polylines;
      });
    } catch (e) {
      // Fallback to straight lines if decoding fails
      final mapData = TripPlanMapHelper.createMapData(
        _tripPlan,
        onWaypointTap: _showWaypointOptions,
      );
      setState(() {
        _markers = mapData.markers;
        _polylines = mapData.polylines;
      });
    }
  }

  /// Populates the editable location fields from the current trip plan
  void _initEditLocations() {
    _editWaypoints =
        _tripPlan.waypoints.map((w) => LatLng(w.lat, w.lon)).toList();
    _editStartLocation = _tripPlan.startLocation != null
        ? LatLng(_tripPlan.startLocation!.lat, _tripPlan.startLocation!.lon)
        : null;
    _editEndLocation = _tripPlan.endLocation != null
        ? LatLng(_tripPlan.endLocation!.lat, _tripPlan.endLocation!.lon)
        : null;
    _editPlacementMode = _EditPlacementMode.waypoint;
    _editEncodedPolyline =
        _tripPlan.plannedPolyline ?? _tripPlan.encodedPolyline;
  }

  /// Builds ordered points for the edit mode polyline: start → waypoints → end.
  List<LatLng> _buildEditOrderedPoints() {
    final points = <LatLng>[];
    if (_editStartLocation != null) points.add(_editStartLocation!);
    points.addAll(_editWaypoints);
    if (_editEndLocation != null) points.add(_editEndLocation!);
    return points;
  }

  /// Computes a road-snapped polyline via the Directions API for edit mode.
  /// Falls back to a straight-line polyline if the API call fails.
  Future<void> _computeEditRoutePolyline() async {
    final points = _buildEditOrderedPoints();

    if (points.length < 2) {
      setState(() {
        _editPolylines.clear();
        _editEncodedPolyline = null;
      });
      return;
    }

    // Show straight-line fallback immediately while loading
    setState(() {
      _editPolylines.clear();
      _editPolylines.addAll(
        DashedPolylineHelper.createDashedPolylines(
          polylineIdPrefix: 'edit_route',
          points: points,
          color: Colors.blue.withOpacity(0.5),
          width: 3,
        ),
      );
      _isEditComputingRoute = true;
    });

    try {
      final result = await _directionsClient.getRouteWithPoints(points);

      if (!mounted) return;

      if (result != null) {
        setState(() {
          _editPolylines.clear();
          _editPolylines.add(
            Polyline(
              polylineId: const PolylineId('edit_route'),
              points: result.routePoints,
              color: Colors.blue,
              width: 5,
              geodesic: false,
              startCap: Cap.roundCap,
              endCap: Cap.roundCap,
              jointType: JointType.round,
            ),
          );
          _editEncodedPolyline = result.encodedPolyline;
          _isEditComputingRoute = false;
        });
      } else {
        setState(() {
          _editEncodedPolyline = PolylineCodec.encode(points);
          _isEditComputingRoute = false;
        });
      }
    } catch (e) {
      debugPrint('TripPlanDetailScreen: Edit route computation failed: $e');
      if (!mounted) return;
      setState(() {
        _editEncodedPolyline = PolylineCodec.encode(points);
        _isEditComputingRoute = false;
      });
    }
  }

  /// Initializes edit polylines — uses existing encoded polyline if locations
  /// haven't changed, otherwise computes a new one.
  void _initEditPolylines() {
    if (_editLocationsMatchTripPlan()) {
      final polylineStr =
          _tripPlan.plannedPolyline ?? _tripPlan.encodedPolyline;
      if (polylineStr != null && polylineStr.isNotEmpty) {
        try {
          final routePoints = PolylineCodec.decode(polylineStr);
          setState(() {
            _editPolylines.clear();
            _editPolylines.add(
              Polyline(
                polylineId: const PolylineId('edit_route'),
                points: routePoints,
                color: Colors.blue,
                width: 5,
                geodesic: false,
                startCap: Cap.roundCap,
                endCap: Cap.roundCap,
                jointType: JointType.round,
              ),
            );
            _editEncodedPolyline = polylineStr;
          });
          return;
        } catch (_) {
          // Fall through to compute
        }
      }
    }
    _computeEditRoutePolyline();
  }

  /// Called when the user taps on the map in edit mode
  void _onEditMapTapped(LatLng location) {
    if (_editIgnoreNextMapTap) {
      _editIgnoreNextMapTap = false;
      return;
    }
    // Ignore map taps while a date picker dialog is open (Flutter Web platform
    // view receives the click independently of the dialog overlay).
    if (_isPickerOpen) return;

    setState(() {
      switch (_editPlacementMode) {
        case _EditPlacementMode.start:
          _editStartLocation = location;
          if (_editEndLocation == null) {
            _editPlacementMode = _EditPlacementMode.end;
          } else {
            _editPlacementMode = _EditPlacementMode.waypoint;
          }
          break;
        case _EditPlacementMode.end:
          _editEndLocation = location;
          _editPlacementMode = _EditPlacementMode.waypoint;
          break;
        case _EditPlacementMode.waypoint:
          _editWaypoints.add(location);
          break;
      }
    });
    _computeEditRoutePolyline();
  }

  /// Shows info for a waypoint in view mode (no delete)
  void _showWaypointOptions(int waypointIndex) {
    final l10n = context.l10n;
    final waypoint = _tripPlan.waypoints[waypointIndex];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: WandererTheme.backgroundLight,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Row(
                children: [
                  const Icon(Icons.more_horiz, color: Colors.blue, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    'Waypoint ${waypointIndex + 1}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(Icons.location_on, color: Colors.blue.shade300),
              title: Text(
                '${waypoint.lat.toStringAsFixed(4)}, ${waypoint.lon.toStringAsFixed(4)}',
              ),
              subtitle: Text(
                l10n.tapEditToModify,
                style: TextStyle(
                  fontSize: 12,
                  color: WandererTheme.textTertiary,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDateRange() async {
    setState(() => _isPickerOpen = true);
    ({DateTime start, DateTime end, bool multiDay})? picked;
    try {
      picked = await pickPlanDates(context,
          multiDay: _selectedPlanType == 'MULTI_DAY',
          start: _startDate,
          end: _endDate);
    } finally {
      if (mounted) {
        setState(() {
          _isPickerOpen = false;
          // Absorb the trailing map tap that the platform view fires
          // after the dialog dismisses (Save / Cancel / X click).
          _editIgnoreNextMapTap = true;
        });
      }
    }
    if (picked case final p? when mounted) {
      setState(() {
        _startDate = p.start;
        _endDate = p.end;
        _selectedPlanType = p.multiDay ? 'MULTI_DAY' : 'SIMPLE';
      });
    }
  }

  /// Single-day plans end the day they start.
  void _setMultiDay(bool multi) => setState(() {
        _selectedPlanType = multi ? 'MULTI_DAY' : 'SIMPLE';
        if (!multi && _startDate != null) _endDate = _startDate;
      });

  Future<void> _saveChanges() async {
    if (_nameController.text.trim().isEmpty) {
      planNotify(context, error: true, 'Name is required');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Use the already-computed encoded polyline, or compute a fallback
      String? encodedPolyline = _editEncodedPolyline;
      if (encodedPolyline == null) {
        final points = _buildEditOrderedPoints();
        if (points.length >= 2) {
          final result = await _directionsClient.getRoutePolyline(points);
          encodedPolyline = result ?? PolylineCodec.encode(points);
        }
      }

      final request = UpdateTripPlanRequest(
        name: _nameController.text.trim(),
        planType: _selectedPlanType,
        startDate: _startDate,
        endDate: _endDate,
        startLocation: _editStartLocation != null
            ? PlanLocation(
                lat: _editStartLocation!.latitude,
                lon: _editStartLocation!.longitude,
              )
            : _tripPlan.startLocation,
        endLocation: _editEndLocation != null
            ? PlanLocation(
                lat: _editEndLocation!.latitude,
                lon: _editEndLocation!.longitude,
              )
            : _tripPlan.endLocation,
        waypoints: _editWaypoints
            .map((w) => PlanLocation(lat: w.latitude, lon: w.longitude))
            .toList(),
        plannedPolyline: encodedPolyline,
      );

      final planId = await _tripPlanService.updateTripPlan(
        _tripPlan.id,
        request,
      );

      // Fetch the updated plan to get full details
      final updatedPlan = await _tripPlanService.getTripPlanById(planId);

      if (mounted) {
        setState(() {
          _tripPlan = updatedPlan;
          _isEditing = false;
          _isLoading = false;
        });
        _initEditLocations();
        _updateMapData();
        planNotify(
            context,
            AdaptiveLayout.usesDesktopLayout(context)
                ? 'Trip plan updated successfully'
                : context.l10n.planUpdated);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        planNotify(context, error: true, 'Error updating trip plan: $e');
      }
    }
  }

  Future<void> _deleteTripPlan() async {
    final l10n = context.l10n;
    final confirm = AdaptiveLayout.usesDesktopLayout(context)
        ? await WandererDialog.confirm(
            context,
            title: l10n.tripPlansDeleteTitle,
            message: l10n.tripPlansDeleteMessage(_tripPlan.name),
            confirmLabel: l10n.tripPlansDeleteAction,
            cancelLabel: l10n.tripPlansKeepPlan,
            icon: Icons.delete_outline,
            destructive: true,
          )
        : await confirmPlanDelete(context, _tripPlan.name);

    if (confirm != true || !mounted) return;

    setState(() => _isLoading = true);

    try {
      await _tripPlanService.deleteTripPlan(_tripPlan.id);
      if (mounted) {
        planNotify(
            context,
            AdaptiveLayout.usesDesktopLayout(context)
                ? 'Trip plan deleted'
                : l10n.planDeleted);
        Navigator.pop(context, true); // Return true to indicate deletion
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        planNotify(context, error: true, 'Error deleting trip plan: $e');
      }
    }
  }

  Future<void> _createTripFromPlan() async {
    final request = await TripFromPlanDialog.show(context,
        planName: _tripPlan.name, planType: _tripPlan.planType);

    if (request == null || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final tripId =
          await _tripService.createTripFromPlan(_tripPlan.id, request);
      final trip = await _tripService.getTripById(tripId);

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        planNotify(
          context,
          'Trip created successfully from plan!',
        );
        Navigator.push(
          context,
          PageTransitions.slideFromRight(TripDetailScreen(trip: trip)),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        planNotify(context, error: true, 'Error creating trip: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // When editing, show the edit form
    if (_isEditing) {
      return AdaptiveLayout.usesDesktopLayout(context)
          ? _buildEditScreenWeb()
          : _buildEditScreenAndroid();
    }

    if (AdaptiveLayout.usesDesktopLayout(context)) return _buildWebView();

    return _buildAndroidView();
  }

  // ---------------------------------------------------------------------------
  // Android layouts (canvas AndroidPlanDetail / AndroidEditPlan)
  // ---------------------------------------------------------------------------

  static List<LatLng> _pointsOf(Set<Polyline> lines) =>
      [for (final l in lines) ...l.points];

  Widget _buildAndroidView() {
    final route = _pointsOf(_polylines);
    return AndroidPlanDetailView(
      mobileWeb: AdaptiveLayout.isMobileWeb(context),
      plan: _tripPlan,
      route: route,
      onBack: () => Navigator.pop(context),
      onDelete: _deleteTripPlan,
      onEdit: _enterEditMode,
      onStart: _createTripFromPlan,
      onFocusStop: (p) =>
          _mapController?.animateCamera(CameraUpdate.newLatLngZoom(p, 13)),
      map: FutureBuilder(
        future: PlanMapStyle.ensureLoaded(),
        builder: (context, _) => GoogleMap(
          key: kIsWeb ? ValueKey(Theme.of(context).brightness) : null,
          style: MapStyleHelper.of(context),
          initialCameraPosition: CameraPosition(
            target: TripPlanMapHelper.getInitialLocation(_tripPlan),
            zoom: 10,
          ),
          markers: PlanMapStyle.markers(
            start: _editStartLocation,
            stops: [
              for (final w in _tripPlan.waypoints) LatLng(w.lat, w.lon),
            ],
            finish: _editEndLocation,
          ),
          polylines: PlanMapStyle.route(route),
          padding: const EdgeInsets.only(top: 64),
          onMapCreated: (controller) {
            _mapController = controller;
            if (_markers.length >= 2) {
              Future.delayed(const Duration(milliseconds: 300), _fitBounds);
            }
          },
          myLocationEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
        ),
      ),
    );
  }

  void _showAndroidMarkerSheet(String id) {
    final l10n = context.l10n;
    final c = WandererTheme.of(context);
    final error = Theme.of(context).colorScheme.error;
    final index = int.tryParse(id.split('_').last);
    showWandererSheet<void>(
      context,
      title: id == 'start'
          ? l10n.planEditorStart
          : id == 'end'
              ? l10n.planEditorFinish
              : '${l10n.planEditorStop} $index',
      builder: (sheet) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.my_location_rounded, color: c.accentText),
            title: Text(l10n.rePlaceOnMap),
            subtitle: Text(l10n.longPressToDrag,
                style: TextStyle(fontSize: 12, color: c.caption)),
            onTap: () {
              Navigator.pop(sheet);
              setState(() => _editPlacementMode = id == 'start'
                  ? _EditPlacementMode.start
                  : id == 'end'
                      ? _EditPlacementMode.end
                      : _EditPlacementMode.waypoint);
            },
          ),
          if (index != null && index > 0 && index <= _editWaypoints.length)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.delete_outline, color: error),
              title: Text(l10n.remove, style: TextStyle(color: error)),
              onTap: () {
                Navigator.pop(sheet);
                setState(() => _editWaypoints.removeAt(index - 1));
                _computeEditRoutePolyline();
              },
            ),
        ],
      ),
    );
  }

  Widget _buildEditScreenAndroid() {
    final l10n = context.l10n;
    final route = _pointsOf(_editPolylines);
    final days = _startDate == null || _endDate == null
        ? null
        : DateUtils.dateOnly(_endDate!)
                .difference(DateUtils.dateOnly(_startDate!))
                .inDays +
            1;
    final summary = [
      if (days != null) l10n.daysCount(days),
      l10n.planStopsShort(_editWaypoints.length),
      if (route.length >= 2)
        l10n.planKmPlanned(PlanMapStyle.distanceKm(route).round()),
      if (_isEditComputingRoute) l10n.computingRoute,
    ].join(' · ');
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancelEditing();
      },
      child: PlanEditorLayout(
        title: l10n.planDetailEditPlan,
        closeTooltip: l10n.planDiscardChanges,
        onClose: _cancelEditing,
        onUndo: _editWaypoints.isEmpty
            ? null
            : () {
                setState(() => _editWaypoints.removeLast());
                _computeEditRoutePolyline();
              },
        mapHint: l10n.planEditMapHint,
        stopCount: _editWaypoints.length,
        mode: _toWebPlacement[_editPlacementMode]!,
        onModeChanged: (mode) => setState(() => _editPlacementMode =
            _toWebPlacement.entries.firstWhere((e) => e.value == mode).key),
        map: FutureBuilder(
          future: PlanMapStyle.ensureLoaded(),
          builder: (context, _) => GoogleMap(
            key: kIsWeb ? ValueKey(Theme.of(context).brightness) : null,
            style: MapStyleHelper.of(context),
            initialCameraPosition: CameraPosition(
              target: _editStartLocation ??
                  TripPlanMapHelper.getInitialLocation(_tripPlan),
              zoom: 10,
            ),
            markers: PlanMapStyle.markers(
              start: _editStartLocation,
              stops: _editWaypoints,
              finish: _editEndLocation,
              draggable: true,
              onTap: _showAndroidMarkerSheet,
              onDragEnd: (id, pos) {
                setState(() {
                  if (id == 'start') {
                    _editStartLocation = pos;
                  } else if (id == 'end') {
                    _editEndLocation = pos;
                  } else {
                    final i = int.parse(id.split('_').last) - 1;
                    _editWaypoints[i] = pos;
                  }
                });
                _computeEditRoutePolyline();
              },
            ),
            polylines: PlanMapStyle.route(route),
            padding: const EdgeInsets.only(top: 110, bottom: 60),
            onMapCreated: (controller) {
              _mapController = controller;
              Future.delayed(const Duration(milliseconds: 300), _fitEditBounds);
            },
            onTap: _onEditMapTapped,
            myLocationEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),
        ),
        sheet: [
          LabeledField(
            label: l10n.planEditorName,
            hint: l10n.planEditorNameHint,
            controller: _nameController,
            textInputAction: TextInputAction.done,
          ),
          PlanTypeToggle(
            multiDay: _selectedPlanType == 'MULTI_DAY',
            onChanged: _setMultiDay,
          ),
          PlanDateTiles(
              start: _startDate,
              end: _endDate,
              singleDay: _selectedPlanType != 'MULTI_DAY',
              onPick: _selectDateRange),
          Text(summary,
              style: TextStyle(
                  fontSize: 13, color: WandererTheme.of(context).textMuted)),
          PlanPrimaryButton(
            label: l10n.planDetailSaveChanges,
            loading: _isLoading,
            onPressed: _saveChanges,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Web (redesign) layouts
  // ---------------------------------------------------------------------------

  void _enterEditMode() {
    _initEditLocations();
    _initEditPolylines();
    setState(() {
      _isEditing = true;
      _showEditWaypointsList = false;
    });
  }

  WandererAppBar _webAppBar(VoidCallback onBack) => WandererAppBar(
        isLoggedIn: _isLoggedIn,
        onLoginPressed: _navigateToAuth,
        username: _username,
        userId: _userId,
        displayName: _displayName,
        avatarUrl: _avatarUrl,
        onProfile: () => AuthNavigationHelper.navigateToOwnProfile(context),
        onSettings: _handleSettings,
        onLogout: _handleLogout,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: onBack,
        ),
      );

  AppSidebar _webSidebar() => AppSidebar(
        username: _username,
        userId: _userId,
        displayName: _displayName,
        avatarUrl: _avatarUrl,
        selectedIndex: 1, // Trip plans
        onLogout: _handleLogout,
        onSettings: _handleSettings,
        isAdmin: _isAdmin,
      );

  void _zoomIn() => _mapController?.animateCamera(CameraUpdate.zoomIn());
  void _zoomOut() => _mapController?.animateCamera(CameraUpdate.zoomOut());

  /// Web view mode: header + map card + route / dates column.
  Widget _buildWebView() {
    final c = WandererTheme.of(context);
    final hasMapData = _markers.isNotEmpty;
    return WandererScaffold(
      hideAppBarWithSidebar: true,
      appBar: _webAppBar(() => Navigator.pop(context)),
      drawer: _webSidebar(),
      body: WebPlanDetailLayout(
        plan: _tripPlan,
        onBack: () => Navigator.pop(context),
        onDelete: _deleteTripPlan,
        onEdit: _enterEditMode,
        onStartTrip: _createTripFromPlan,
        onZoomIn: hasMapData ? _zoomIn : null,
        onZoomOut: hasMapData ? _zoomOut : null,
        onFitRoute: _markers.length >= 2 ? _fitBounds : null,
        map: hasMapData
            ? GoogleMap(
                key: kIsWeb ? ValueKey(Theme.of(context).brightness) : null,
                style: MapStyleHelper.of(context),
                initialCameraPosition: CameraPosition(
                  target: TripPlanMapHelper.getInitialLocation(_tripPlan),
                  zoom: 10,
                ),
                markers: _markers,
                polylines: _polylines,
                onMapCreated: (controller) {
                  _mapController = controller;
                  if (_markers.length >= 2) _fitBounds();
                },
                myLocationEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
              )
            : Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.map_outlined, size: 48, color: c.caption),
                    const SizedBox(height: 12),
                    Text(context.l10n.noLocationData,
                        style: TextStyle(color: c.caption, fontSize: 15)),
                  ],
                ),
              ),
      ),
    );
  }

  static const _toWebPlacement = {
    _EditPlacementMode.start: PlanPlacementMode.start,
    _EditPlacementMode.waypoint: PlanPlacementMode.stop,
    _EditPlacementMode.end: PlanPlacementMode.finish,
  };

  static String _coords(LatLng p) =>
      '${p.latitude.toStringAsFixed(4)}, ${p.longitude.toStringAsFixed(4)}';

  /// Web edit mode: shared plan editor layout around the editing map.
  Widget _buildEditScreenWeb() {
    final l10n = context.l10n;
    final c = WandererTheme.of(context);
    // Swallow the map click that follows a click on our floating overlays.
    Widget guard(Widget child) => Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (_) => _editIgnoreNextMapTap = true,
          child: child,
        );
    return WandererScaffold(
      hideAppBarWithSidebar: true,
      appBar: _webAppBar(_cancelEditing),
      drawer: _webSidebar(),
      body: WebPlanEditorLayout(
        breadcrumbCurrent: _tripPlan.name,
        onBreadcrumbTap: () => Navigator.pop(context),
        onOverlayPointerDown: () {
          _editIgnoreNextMapTap = true;
          // ponytail: time-boxed so an unused guard can't swallow a later
          // real map click.
          Future.delayed(const Duration(milliseconds: 300),
              () => _editIgnoreNextMapTap = false);
        },
        title: l10n.planDetailEditPlan,
        saveLabel: l10n.planDetailSaveChanges,
        onCancel: _cancelEditing,
        onSave: _saveChanges,
        isSaving: _isLoading,
        nameController: _nameController,
        multiDay: _selectedPlanType == 'MULTI_DAY',
        onMultiDayChanged: _setMultiDay,
        startDate: _startDate,
        endDate: _endDate,
        onPickStartDate: _selectDateRange,
        onPickEndDate: _selectDateRange,
        startLabel:
            _editStartLocation == null ? null : _coords(_editStartLocation!),
        finishLabel:
            _editEndLocation == null ? null : _coords(_editEndLocation!),
        stopCount: _editWaypoints.length,
        placementMode: _toWebPlacement[_editPlacementMode]!,
        onPlacementModeChanged: (mode) => setState(() => _editPlacementMode =
            _toWebPlacement.entries.firstWhere((e) => e.value == mode).key),
        onZoomIn: _zoomIn,
        onZoomOut: _zoomOut,
        onUndo: _editWaypoints.isEmpty
            ? null
            : () {
                setState(() => _editWaypoints.removeLast());
                _computeEditRoutePolyline();
              },
        map: Stack(
          fit: StackFit.expand,
          children: [
            GoogleMap(
              key: kIsWeb ? ValueKey(Theme.of(context).brightness) : null,
              style: MapStyleHelper.of(context),
              initialCameraPosition: CameraPosition(
                target: _editStartLocation ?? const LatLng(40.7128, -74.0060),
                zoom: 10,
              ),
              markers: _buildEditMarkers(),
              polylines: _editPolylines,
              onMapCreated: (controller) {
                _mapController = controller;
                if (_editStartLocation != null) {
                  Future.delayed(const Duration(milliseconds: 300), () {
                    _fitEditBounds();
                  });
                }
              },
              onTap: _onEditMapTapped,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
            ),
            if (_showEditWaypointsList && _editWaypoints.isNotEmpty)
              Positioned(
                left: 16,
                bottom: 68,
                width: 340,
                child: guard(ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 360),
                  child: _buildEditWaypointsPanel(),
                )),
              ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Row(
                children: [
                  if (_editWaypoints.isNotEmpty)
                    guard(FilledButton.icon(
                      onPressed: () => setState(() =>
                          _showEditWaypointsList = !_showEditWaypointsList),
                      style: FilledButton.styleFrom(
                        backgroundColor: c.surface,
                        foregroundColor: c.text,
                      ),
                      icon: const Icon(Icons.reorder_rounded, size: 16),
                      label:
                          Text(l10n.planDetailWaypoints(_editWaypoints.length)),
                    )),
                  const Spacer(),
                  if (_isEditComputingRoute)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius:
                            BorderRadius.circular(WandererTheme.radiusControl),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 8),
                          Text(l10n.computingRoute,
                              style: TextStyle(fontSize: 12, color: c.text)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Cancels editing and restores state
  void _cancelEditing() {
    setState(() {
      _isEditing = false;
      _nameController.text = _tripPlan.name;
      _selectedPlanType = _tripPlan.planType;
      _startDate = _tripPlan.startDate;
      _endDate = _tripPlan.endDate;
      _editWaypoints =
          _tripPlan.waypoints.map((w) => LatLng(w.lat, w.lon)).toList();
      _editStartLocation = _tripPlan.startLocation != null
          ? LatLng(
              _tripPlan.startLocation!.lat,
              _tripPlan.startLocation!.lon,
            )
          : null;
      _editEndLocation = _tripPlan.endLocation != null
          ? LatLng(
              _tripPlan.endLocation!.lat,
              _tripPlan.endLocation!.lon,
            )
          : null;
      _showEditWaypointsList = false;
      _editPolylines.clear();
      _editEncodedPolyline = null;
      _editPlacementMode = _EditPlacementMode.waypoint;
      _isEditComputingRoute = false;
    });
  }

  Set<Marker> _buildEditMarkers() {
    final markers = <Marker>{};
    if (_editStartLocation != null) {
      markers.add(Marker(
        markerId: const MarkerId('start'),
        position: _editStartLocation!,
        infoWindow: const InfoWindow(title: 'Start Location'),
        icon: BitmapDescriptor.defaultMarkerWithHue(120.0), // Green
        draggable: true,
        onDragEnd: (pos) {
          setState(() => _editStartLocation = pos);
          _computeEditRoutePolyline();
        },
        onTap: () => _showEditMarkerOptions('start', 'Start Location'),
      ));
    }
    if (_editEndLocation != null) {
      markers.add(Marker(
        markerId: const MarkerId('end'),
        position: _editEndLocation!,
        infoWindow: const InfoWindow(title: 'End Location'),
        icon: BitmapDescriptor.defaultMarkerWithHue(0.0), // Red
        draggable: true,
        onDragEnd: (pos) {
          setState(() => _editEndLocation = pos);
          _computeEditRoutePolyline();
        },
        onTap: () => _showEditMarkerOptions('end', 'End Location'),
      ));
    }
    for (int i = 0; i < _editWaypoints.length; i++) {
      markers.add(Marker(
        markerId: MarkerId('waypoint_${i + 1}'),
        position: _editWaypoints[i],
        infoWindow: InfoWindow(title: 'Waypoint ${i + 1}'),
        icon: BitmapDescriptor.defaultMarkerWithHue(240.0), // Blue
        draggable: true,
        onDragEnd: (pos) {
          setState(() => _editWaypoints[i] = pos);
          _computeEditRoutePolyline();
        },
        onTap: () => _showEditMarkerOptions(
          'waypoint_${i + 1}',
          'Waypoint ${i + 1}',
        ),
      ));
    }
    return markers;
  }

  /// Checks whether the edit locations still match the original trip plan
  bool _editLocationsMatchTripPlan() {
    // Check start location
    if (_tripPlan.startLocation != null && _editStartLocation != null) {
      if (_editStartLocation!.latitude != _tripPlan.startLocation!.lat ||
          _editStartLocation!.longitude != _tripPlan.startLocation!.lon) {
        return false;
      }
    } else if (_tripPlan.startLocation != null || _editStartLocation != null) {
      return false;
    }

    // Check end location
    if (_tripPlan.endLocation != null && _editEndLocation != null) {
      if (_editEndLocation!.latitude != _tripPlan.endLocation!.lat ||
          _editEndLocation!.longitude != _tripPlan.endLocation!.lon) {
        return false;
      }
    } else if (_tripPlan.endLocation != null || _editEndLocation != null) {
      return false;
    }

    // Check waypoints
    if (_editWaypoints.length != _tripPlan.waypoints.length) return false;
    for (int i = 0; i < _editWaypoints.length; i++) {
      if (_editWaypoints[i].latitude != _tripPlan.waypoints[i].lat ||
          _editWaypoints[i].longitude != _tripPlan.waypoints[i].lon) {
        return false;
      }
    }

    return true;
  }

  void _showEditMarkerOptions(String markerId, String title) {
    final l10n = context.l10n;
    final color = markerId == 'start'
        ? Colors.green
        : markerId == 'end'
            ? Colors.red
            : Colors.blue;
    final icon = markerId == 'start'
        ? Icons.trip_origin
        : markerId == 'end'
            ? Icons.place
            : Icons.more_horiz;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: WandererTheme.backgroundLight,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Row(
                children: [
                  Icon(icon, color: color, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            if (markerId.startsWith('waypoint_'))
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: Text(
                  l10n.remove,
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  final index = int.tryParse(markerId.split('_').last);
                  if (index != null &&
                      index > 0 &&
                      index <= _editWaypoints.length) {
                    setState(() => _editWaypoints.removeAt(index - 1));
                  }
                },
              ),
            ListTile(
              leading: Icon(Icons.drag_indicator_rounded,
                  color: WandererTheme.textTertiary),
              title: Text(l10n.dragMarkerOnMap),
              subtitle: Text(
                l10n.longPressToDrag,
                style: TextStyle(
                  fontSize: 12,
                  color: WandererTheme.textTertiary,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildEditWaypointsPanel() {
    final l10n = context.l10n;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
            child: Row(
              children: [
                const Icon(Icons.reorder_rounded, size: 18, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Waypoints (${_editWaypoints.length})',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: WandererTheme.textPrimary,
                  ),
                ),
                const Spacer(),
                Text(
                  l10n.dragToReorder,
                  style: TextStyle(
                    fontSize: 11,
                    color: WandererTheme.textTertiary,
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(Icons.close_rounded,
                      size: 20, color: WandererTheme.textTertiary),
                  onPressed: () =>
                      setState(() => _showEditWaypointsList = false),
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(16),
              ),
              child: ReorderableListView.builder(
                shrinkWrap: true,
                itemCount: _editWaypoints.length,
                proxyDecorator: (child, index, animation) {
                  return Material(
                    elevation: 4,
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    child: child,
                  );
                },
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex--;
                    final item = _editWaypoints.removeAt(oldIndex);
                    _editWaypoints.insert(newIndex, item);
                  });
                },
                itemBuilder: (context, index) {
                  final wp = _editWaypoints[index];
                  return Container(
                    key: ValueKey(
                      'ewp_${wp.latitude}_${wp.longitude}_$index',
                    ),
                    color: Colors.white,
                    child: ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                      ),
                      leading: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                      title: Text(
                        'Waypoint ${index + 1}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        '${wp.latitude.toStringAsFixed(4)}, ${wp.longitude.toStringAsFixed(4)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: WandererTheme.textTertiary,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: () =>
                                setState(() => _editWaypoints.removeAt(index)),
                            child: Icon(
                              Icons.remove_circle_outline,
                              size: 18,
                              color: Colors.red.shade300,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.drag_handle_rounded,
                            size: 20,
                            color: WandererTheme.textTertiary,
                          ),
                        ],
                      ),
                      onTap: () {
                        _mapController?.animateCamera(
                          CameraUpdate.newLatLng(wp),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _fitEditBounds() {
    final allPoints = <LatLng>[
      if (_editStartLocation != null) _editStartLocation!,
      if (_editEndLocation != null) _editEndLocation!,
      ..._editWaypoints,
    ];
    if (allPoints.length < 2 || _mapController == null) return;

    double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;
    for (final p in allPoints) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        50,
      ),
    );
  }

  void _fitBounds() {
    if (_markers.isEmpty || _mapController == null) return;

    double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;

    for (final marker in _markers) {
      if (marker.position.latitude < minLat) minLat = marker.position.latitude;
      if (marker.position.latitude > maxLat) maxLat = marker.position.latitude;
      if (marker.position.longitude < minLng) {
        minLng = marker.position.longitude;
      }
      if (marker.position.longitude > maxLng) {
        maxLng = marker.position.longitude;
      }
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 50),
    );
  }
}
