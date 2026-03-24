import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:wanderer_frontend/core/constants/api_endpoints.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/data/client/google_directions_api_client.dart';
import 'package:wanderer_frontend/data/client/polyline_codec.dart';
import 'package:wanderer_frontend/data/models/requests/create_trip_plan_backend_request.dart';
import 'package:wanderer_frontend/data/services/trip_plan_service.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/presentation/helpers/dashed_polyline_helper.dart';
import 'package:wanderer_frontend/presentation/helpers/ui_helpers.dart';
import 'package:wanderer_frontend/presentation/helpers/web_marker_generator.dart';

/// Screen for creating a new trip plan with map integration
class CreateTripPlanScreen extends StatefulWidget {
  const CreateTripPlanScreen({super.key});

  @override
  State<CreateTripPlanScreen> createState() => _CreateTripPlanScreenState();
}

/// The type of point the user wants to place next on the map
enum _PlacementMode { start, end, waypoint }

class _CreateTripPlanScreenState extends State<CreateTripPlanScreen> {
  final TripPlanService _tripPlanService = TripPlanService();
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

  /// Controls whether the form sheet is expanded
  bool _formExpanded = false;

  /// Whether the desktop side panel is collapsed
  bool _isPanelCollapsed = false;

  /// Which point type the next map tap will place
  _PlacementMode _placementMode = _PlacementMode.start;

  /// Whether to show the floating waypoints reorder panel
  bool _showWaypointsList = false;

  /// Flag to ignore the next map tap — set when a UI overlay is tapped on web
  /// to prevent the underlying platform view from also firing onTap.
  bool _ignoreNextMapTap = false;

  /// True while a date picker dialog is open — gates map tap handling so
  /// tapping a date inside the dialog does not also drop a waypoint.
  bool _isPickerOpen = false;

  /// Computed number of days between start and end dates
  int? get _daysBetween {
    if (_startDate == null || _endDate == null) return null;
    return _endDate!.difference(_startDate!).inDays + 1;
  }

  @override
  void initState() {
    super.initState();
    _directionsClient =
        GoogleDirectionsApiClient(ApiEndpoints.googleMapsApiKey);
    _getCurrentLocation();
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
    _directionsClient.dispose();
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
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Row(
                children: [
                  Icon(
                    _iconForMarkerId(markerId),
                    color: _colorForMarkerId(markerId),
                    size: 20,
                  ),
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
            ListTile(
              leading: Icon(
                Icons.my_location_rounded,
                color: WandererTheme.primaryOrange,
              ),
              title: Text(context.l10n.rePlaceOnMap),
              subtitle: Text(
                context.l10n.tapMapToSetPosition,
                style: TextStyle(
                  fontSize: 12,
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.45),
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  if (markerId == 'start') {
                    _placementMode = _PlacementMode.start;
                  } else if (markerId == 'end') {
                    _placementMode = _PlacementMode.end;
                  } else {
                    _placementMode = _PlacementMode.waypoint;
                  }
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: Text(
                context.l10n.remove,
                style: const TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(context);
                _deleteMarker(markerId);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
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
    // Auto-close panel when no waypoints left
    if (_waypoints.isEmpty) {
      _showWaypointsList = false;
    }
  }

  /// Reorders waypoints when the user drags items in the list
  void _onReorderWaypoints(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final item = _waypoints.removeAt(oldIndex);
      _waypoints.insert(newIndex, item);
      _rebuildWaypointMarkers();
    });
    _computeRoutePolyline();
  }

  IconData _iconForMarkerId(String id) {
    if (id == 'start') return Icons.trip_origin;
    if (id == 'end') return Icons.place;
    return Icons.more_horiz;
  }

  Color _colorForMarkerId(String id) {
    if (id == 'start') return Colors.green;
    if (id == 'end') return Colors.red;
    return Colors.blue;
  }

  void _clearAllMarkers() {
    setState(() {
      _markers.clear();
      _polylines.clear();
      _waypoints.clear();
      _startLocation = null;
      _endLocation = null;
      _encodedPolyline = null;
      _placementMode = _PlacementMode.start;
      _showWaypointsList = false;
    });
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
    DateTimeRange? picked;
    try {
      picked = await showDateRangePicker(
        context: context,
        initialDateRange: _startDate != null
            ? DateTimeRange(
                start: _startDate!,
                end: _endDate ?? _startDate!,
              )
            : null,
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      );
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
    if (picked != null && mounted) {
      setState(() {
        _startDate = picked!.start;
        _endDate = picked.end;
      });
    }
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Future<void> _createTripPlan() async {
    if (!_formKey.currentState!.validate()) return;

    if (_startLocation == null || _endLocation == null) {
      UiHelpers.showErrorMessage(
        context,
        'Please select start and end locations on the map',
      );
      return;
    }

    if (_startDate == null || _endDate == null) {
      UiHelpers.showErrorMessage(context, 'Please select start and end dates');
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

      await _tripPlanService.createTripPlanBackend(request);

      if (mounted) {
        UiHelpers.showSuccessMessage(
          context,
          'Trip plan created successfully!',
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        UiHelpers.showErrorMessage(context, 'Error creating trip plan: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 600;
        if (isWide) {
          return _buildDesktopLayout();
        }
        return _buildMobileLayout();
      },
    );
  }

  /// Desktop/Web layout with floating glass side panel on the left
  Widget _buildDesktopLayout() {
    const double panelWidth = 400.0;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(context.l10n.newTripPlan),
        backgroundColor: WandererTheme.primaryOrange.withOpacity(0.9),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_markers.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.undo_rounded),
              tooltip: context.l10n.removeLastMarker,
              onPressed: _removeLastWaypoint,
            ),
          if (_markers.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.layers_clear_rounded),
              tooltip: context.l10n.clearAllMarkers,
              onPressed: _clearAllMarkers,
            ),
        ],
      ),
      body: Stack(
        children: [
          // Full-screen map
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _initialCameraLocation,
                zoom: 12,
              ),
              markers: _markers,
              polylines: _polylines,
              onMapCreated: _onMapCreated,
              onTap: _onMapTapped,
              myLocationButtonEnabled: true,
              myLocationEnabled: true,
              zoomControlsEnabled: true,
              mapToolbarEnabled: false,
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + kToolbarHeight,
                left: _isPanelCollapsed ? 88 : panelWidth,
              ),
            ),
          ),
          // Location status chips (offset to right of panel)
          Positioned(
            top: MediaQuery.of(context).padding.top + kToolbarHeight + 8,
            left: (_isPanelCollapsed ? 88 : panelWidth) + 16,
            right: 16,
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (_) => _ignoreNextMapTap = true,
              child: _buildLocationChips(),
            ),
          ),
          // Loading indicator for location
          if (_isLoadingLocation)
            Positioned(
              top: MediaQuery.of(context).padding.top + kToolbarHeight + 44,
              left: (_isPanelCollapsed ? 88 : panelWidth) + 16,
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (_) => _ignoreNextMapTap = true,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: WandererTheme.primaryOrange,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        context.l10n.gettingLocation,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // Route computing indicator
          if (_isComputingRoute)
            Positioned(
              top: MediaQuery.of(context).padding.top + kToolbarHeight + 44,
              right: 16,
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (_) => _ignoreNextMapTap = true,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        context.l10n.computingRoute,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // Floating waypoints reorder panel (to the right of side panel)
          if (_showWaypointsList && _waypoints.isNotEmpty)
            Positioned(
              top: MediaQuery.of(context).padding.top + kToolbarHeight + 44,
              left: (_isPanelCollapsed ? 88 : panelWidth) + 12,
              right: 12,
              bottom: 16,
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (_) => _ignoreNextMapTap = true,
                child: _buildWaypointsPanel(),
              ),
            ),
          // Floating glass side panel
          Positioned(
            left: 0,
            top: 0,
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (_) => _ignoreNextMapTap = true,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                width: _isPanelCollapsed ? 88 : panelWidth,
                child: _isPanelCollapsed
                    ? _buildCollapsedPanelBubble()
                    : _buildExpandedSidePanel(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Collapsed panel bubble (matching edit trip plan style)
  Widget _buildCollapsedPanelBubble() {
    return Align(
      alignment: Alignment.bottomLeft,
      child: Container(
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
              color: WandererTheme.glassBackground,
              shape: CircleBorder(
                side: BorderSide(
                  color: WandererTheme.glassBorderColor,
                  width: 1,
                ),
              ),
              child: InkWell(
                onTap: () => setState(() => _isPanelCollapsed = false),
                customBorder: const CircleBorder(),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(shape: BoxShape.circle),
                  child: Icon(
                    Icons.add_location_alt_outlined,
                    size: 24,
                    color: WandererTheme.primaryOrange,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Expanded glass side panel with the create form
  Widget _buildExpandedSidePanel() {
    final screenHeight = MediaQuery.of(context).size.height;
    // topOffset = statusBar + appBar + panel top margin (8) + panel bottom margin (16)
    final topOffset =
        MediaQuery.of(context).padding.top + kToolbarHeight + 8 + 16;
    final maxPanelHeight = screenHeight - topOffset - 16;
    return Container(
      margin: EdgeInsets.only(
        left: 16,
        top: MediaQuery.of(context).padding.top + kToolbarHeight + 8,
        bottom: 16,
      ),
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
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxPanelHeight),
            child: Container(
              decoration: BoxDecoration(
                color: WandererTheme.glassBackground,
                borderRadius: BorderRadius.circular(WandererTheme.glassRadius),
                border: Border.all(
                  color: WandererTheme.glassBorderColor,
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surface
                          .withOpacity(0.4),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(WandererTheme.glassRadius),
                        topRight: Radius.circular(WandererTheme.glassRadius),
                      ),
                      border: Border(
                        bottom: BorderSide(
                          color: WandererTheme.glassBorderColor,
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.add_location_alt_outlined,
                          size: 18,
                          color: WandererTheme.primaryOrange,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            context.l10n.newTripPlan,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surface
                                .withOpacity(0.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: IconButton(
                            icon: Icon(
                              Icons.remove,
                              size: 18,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.6),
                            ),
                            onPressed: () =>
                                setState(() => _isPanelCollapsed = true),
                            tooltip: context.l10n.minimize,
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Scrollable form content
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Plan Name
                            _buildSectionLabel('Plan Name'),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _nameController,
                              decoration: _inputDecoration(
                                'e.g., Weekend Hiking Adventure',
                              ),
                              textCapitalization: TextCapitalization.words,
                              textInputAction: TextInputAction.next,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter a plan name';
                                }
                                if (value.trim().length < 3) {
                                  return 'Plan name must be at least 3 characters';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            // Description
                            _buildSectionLabel('Description'),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _descriptionController,
                              decoration: _inputDecoration(
                                'Tell us about this plan... (optional)',
                              ),
                              maxLines: 2,
                              textCapitalization: TextCapitalization.sentences,
                            ),
                            const SizedBox(height: 20),
                            // Plan Type
                            _buildSectionLabel('Plan Type'),
                            const SizedBox(height: 10),
                            _buildPlanTypeSelector(),
                            const SizedBox(height: 20),
                            // Dates
                            _buildSectionLabel('Dates'),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildDateButton(
                                    label: 'Start',
                                    date: _startDate,
                                    onTap: _selectDateRange,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _buildDateButton(
                                    label: 'End',
                                    date: _endDate,
                                    onTap: _selectDateRange,
                                  ),
                                ),
                              ],
                            ),
                            if (_daysBetween != null) ...[
                              const SizedBox(height: 10),
                              _buildDaysInfoBadge(),
                            ],
                            const SizedBox(height: 24),
                            // Create button
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _createTripPlan,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: WandererTheme.primaryOrange,
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withOpacity(0.12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  elevation: 0,
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        'Create Plan',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Mobile layout with bottom sheet form (original behavior)
  Widget _buildMobileLayout() {
    final expandedHeight = MediaQuery.of(context).size.height -
        MediaQuery.of(context).padding.top -
        kToolbarHeight;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text(context.l10n.newTripPlan),
        backgroundColor: WandererTheme.primaryOrange.withOpacity(0.9),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_markers.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.undo_rounded),
              tooltip: context.l10n.removeLastMarker,
              onPressed: _removeLastWaypoint,
            ),
          if (_markers.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.layers_clear_rounded),
              tooltip: context.l10n.clearAllMarkers,
              onPressed: _clearAllMarkers,
            ),
        ],
      ),
      body: Stack(
        children: [
          // Full-screen map (disabled when form sheet is fully expanded)
          Positioned.fill(
            child: AbsorbPointer(
              absorbing: _formExpanded,
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _initialCameraLocation,
                  zoom: 12,
                ),
                markers: _markers,
                polylines: _polylines,
                onMapCreated: _onMapCreated,
                onTap: _onMapTapped,
                myLocationButtonEnabled: true,
                myLocationEnabled: true,
                zoomControlsEnabled: false,
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 56,
                  bottom: _formExpanded ? expandedHeight : 180,
                ),
              ),
            ),
          ),
          // Location status chips (floating over map)
          Positioned(
            top: MediaQuery.of(context).padding.top + 64,
            left: 16,
            right: 16,
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (_) => _ignoreNextMapTap = true,
              child: _buildLocationChips(),
            ),
          ),
          // Loading indicator for location
          if (_isLoadingLocation)
            Positioned(
              top: MediaQuery.of(context).padding.top + 110,
              left: 16,
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (_) => _ignoreNextMapTap = true,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: WandererTheme.primaryOrange,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        context.l10n.gettingLocation,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // Floating waypoints reorder panel
          if (_showWaypointsList && _waypoints.isNotEmpty)
            Positioned(
              top: MediaQuery.of(context).padding.top + 100,
              left: 12,
              right: 12,
              bottom: _formExpanded ? expandedHeight + 10 : 210,
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (_) => _ignoreNextMapTap = true,
                child: _buildWaypointsPanel(),
              ),
            ),
          // Route computing indicator
          if (_isComputingRoute)
            Positioned(
              top: MediaQuery.of(context).padding.top + 110,
              right: 16,
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (_) => _ignoreNextMapTap = true,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        context.l10n.computingRoute,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // Bottom draggable form sheet
          _buildFormSheet(),
        ],
      ),
    );
  }

  /// Compact location status chips floating on the map — tappable to select
  /// which point type to place next
  Widget _buildLocationChips() {
    return Row(
      children: [
        _buildStatusChip(
          label: 'Start',
          isSet: _startLocation != null,
          isActive: _placementMode == _PlacementMode.start,
          color: Colors.green,
          icon: Icons.trip_origin,
          onTap: () => setState(() => _placementMode = _PlacementMode.start),
        ),
        const SizedBox(width: 6),
        _buildStatusChip(
          label: 'End',
          isSet: _endLocation != null,
          isActive: _placementMode == _PlacementMode.end,
          color: Colors.red,
          icon: Icons.place,
          onTap: () => setState(() => _placementMode = _PlacementMode.end),
        ),
        const SizedBox(width: 6),
        _buildStatusChip(
          label: _waypoints.isEmpty
              ? 'Waypoints'
              : 'Waypoints (${_waypoints.length})',
          isSet: _waypoints.isNotEmpty,
          isActive: _placementMode == _PlacementMode.waypoint,
          color: Colors.blue,
          icon: Icons.more_horiz,
          onTap: () {
            setState(() {
              _placementMode = _PlacementMode.waypoint;
              if (_waypoints.isNotEmpty) {
                _showWaypointsList = !_showWaypointsList;
              }
            });
          },
        ),
      ],
    );
  }

  Widget _buildStatusChip({
    required String label,
    required bool isSet,
    required bool isActive,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? color.withOpacity(0.25)
              : isSet
                  ? color.withOpacity(0.15)
                  : Theme.of(context).colorScheme.surface.withOpacity(0.9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive
                ? color
                : isSet
                    ? color.withOpacity(0.4)
                    : Theme.of(context).colorScheme.outline,
            width: isActive ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSet ? Icons.check_circle : icon,
              size: 14,
              color: isActive || isSet
                  ? color
                  : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive || isSet
                    ? color
                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Floating panel showing waypoints in a reorderable list
  Widget _buildWaypointsPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
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
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
            child: Row(
              children: [
                const Icon(Icons.reorder_rounded, size: 18, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Waypoints (${_waypoints.length})',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                Text(
                  context.l10n.dragToReorder,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.45),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.45),
                  ),
                  onPressed: () => setState(() => _showWaypointsList = false),
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Reorderable list
          Flexible(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(16),
              ),
              child: ReorderableListView.builder(
                shrinkWrap: true,
                itemCount: _waypoints.length,
                proxyDecorator: (child, index, animation) {
                  return Material(
                    elevation: 4,
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    child: child,
                  );
                },
                onReorder: _onReorderWaypoints,
                itemBuilder: (context, index) {
                  final waypoint = _waypoints[index];
                  return _buildWaypointTile(index, waypoint);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaypointTile(int index, LatLng waypoint) {
    final key =
        ValueKey('wp_${waypoint.latitude}_${waypoint.longitude}_$index');
    return Container(
      key: key,
      color: Theme.of(context).colorScheme.surface,
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
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
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          '${waypoint.latitude.toStringAsFixed(4)}, ${waypoint.longitude.toStringAsFixed(4)}',
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.45),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () {
                setState(() {
                  _waypoints.removeAt(index);
                  _rebuildWaypointMarkers();
                });
              },
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
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.45),
            ),
          ],
        ),
        onTap: () {
          // Center map on this waypoint
          _mapController?.animateCamera(
            CameraUpdate.newLatLng(waypoint),
          );
        },
      ),
    );
  }

  /// The bottom form sheet that slides up
  Widget _buildFormSheet() {
    final expandedHeight = MediaQuery.of(context).size.height -
        MediaQuery.of(context).padding.top -
        kToolbarHeight;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) => _ignoreNextMapTap = true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragUpdate: (details) {
            if (details.primaryDelta! < -4) {
              setState(() => _formExpanded = true);
            } else if (details.primaryDelta! > 4) {
              setState(() => _formExpanded = false);
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            height: _formExpanded ? expandedHeight : 200,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Drag handle
                GestureDetector(
                  onTap: () => setState(() => _formExpanded = !_formExpanded),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.only(top: 12, bottom: 8),
                    child: Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.outline,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ),
                // Form content
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      0,
                      20,
                      MediaQuery.of(context).viewInsets.bottom,
                    ),
                    physics: _formExpanded
                        ? const BouncingScrollPhysics()
                        : const NeverScrollableScrollPhysics(),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Plan Name
                          _buildSectionLabel('Plan Name'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _nameController,
                            decoration: _inputDecoration(
                              'e.g., Weekend Hiking Adventure',
                            ),
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            onTap: () {
                              if (!_formExpanded) {
                                setState(() => _formExpanded = true);
                              }
                            },
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter a plan name';
                              }
                              if (value.trim().length < 3) {
                                return 'Plan name must be at least 3 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          // Description
                          _buildSectionLabel('Description'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _descriptionController,
                            decoration: _inputDecoration(
                              'Tell us about this plan... (optional)',
                            ),
                            maxLines: 2,
                            textCapitalization: TextCapitalization.sentences,
                            onTap: () {
                              if (!_formExpanded) {
                                setState(() => _formExpanded = true);
                              }
                            },
                          ),
                          const SizedBox(height: 20),
                          // Plan Type toggle
                          _buildSectionLabel('Plan Type'),
                          const SizedBox(height: 10),
                          _buildPlanTypeSelector(),
                          const SizedBox(height: 20),
                          // Dates
                          _buildSectionLabel('Dates'),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _buildDateButton(
                                  label: 'Start',
                                  date: _startDate,
                                  onTap: _selectDateRange,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildDateButton(
                                  label: 'End',
                                  date: _endDate,
                                  onTap: _selectDateRange,
                                ),
                              ),
                            ],
                          ),
                          if (_daysBetween != null) ...[
                            const SizedBox(height: 10),
                            _buildDaysInfoBadge(),
                          ],
                          const SizedBox(height: 24),
                          // Create button
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _createTripPlan,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: WandererTheme.primaryOrange,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 0,
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Create Plan',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Segmented plan type selector
  Widget _buildPlanTypeSelector() {
    final types = [
      {'value': 'SIMPLE', 'label': 'Simple', 'icon': Icons.wb_sunny_outlined},
      {
        'value': 'MULTI_DAY',
        'label': 'Multi-Day',
        'icon': Icons.luggage_outlined,
      },
    ];

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
        ),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: types.map((type) {
          final isSelected = _planType == type['value'];
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _planType = type['value'] as String),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? WandererTheme.primaryOrange.withOpacity(0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? WandererTheme.primaryOrange
                        : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      type['icon'] as IconData,
                      size: 20,
                      color: isSelected
                          ? WandererTheme.primaryOrange
                          : Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.45),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      type['label'] as String,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? WandererTheme.primaryOrange
                            : Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.6),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Date button styled as a card
  Widget _buildDateButton({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    final hasDate = date != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasDate
                ? WandererTheme.primaryOrange.withOpacity(0.5)
                : Theme.of(context).colorScheme.outline.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: 18,
              color: hasDate
                  ? WandererTheme.primaryOrange
                  : Theme.of(context).colorScheme.onSurface.withOpacity(0.45),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.45),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasDate ? _formatDate(date) : 'Select',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: hasDate ? FontWeight.w600 : FontWeight.w400,
                      color: hasDate
                          ? Theme.of(context).colorScheme.onSurface
                          : Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.45),
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

  /// Info badge showing the auto-calculated number of days between dates
  Widget _buildDaysInfoBadge() {
    final days = _daysBetween!;
    final isMultiDay = _planType == 'MULTI_DAY';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isMultiDay
            ? WandererTheme.primaryOrange.withOpacity(0.06)
            : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isMultiDay
              ? WandererTheme.primaryOrange.withOpacity(0.2)
              : Theme.of(context).colorScheme.outline.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.date_range_rounded,
            size: 16,
            color: isMultiDay
                ? WandererTheme.primaryOrange
                : Theme.of(context).colorScheme.onSurface.withOpacity(0.45),
          ),
          const SizedBox(width: 8),
          Text(
            days == 1 ? '1 day' : '$days days',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isMultiDay
                  ? WandererTheme.primaryOrange
                  : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          if (isMultiDay && days > 1) ...[
            const SizedBox(width: 6),
            Text(
              context.l10n.multiDayTrip,
              style: TextStyle(
                fontSize: 12,
                color: WandererTheme.primaryOrange.withOpacity(0.7),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
      ),
      filled: true,
      fillColor: Theme.of(context).colorScheme.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: WandererTheme.primaryOrange,
          width: 1.5,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
    );
  }
}
