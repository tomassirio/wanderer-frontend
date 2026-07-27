import 'dart:ui';
import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:wanderer_frontend/core/providers/app_providers.dart';
import 'package:wanderer_frontend/data/client/google_directions_api_client.dart';
import 'package:wanderer_frontend/data/client/polyline_codec.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/data/services/trip_plan_service.dart';
import 'package:wanderer_frontend/data/services/trip_service.dart';
import 'package:wanderer_frontend/presentation/helpers/auth_navigation_helper.dart';
import 'package:wanderer_frontend/presentation/helpers/dialog_helper.dart';
import 'package:wanderer_frontend/presentation/helpers/ui_helpers.dart';
import 'package:wanderer_frontend/presentation/helpers/trip_plan_map_helper.dart';
import 'package:wanderer_frontend/presentation/helpers/page_transitions.dart';
import 'package:wanderer_frontend/presentation/screens/auth_screen.dart';
import 'package:wanderer_frontend/presentation/screens/home_screen.dart';
import 'package:wanderer_frontend/presentation/screens/settings_screen.dart';
import 'package:wanderer_frontend/presentation/screens/trip_detail_screen.dart';
import 'package:wanderer_frontend/presentation/state/trip_plan_detail/trip_plan_detail_notifier.dart';
import 'package:wanderer_frontend/presentation/state/trip_plan_detail/trip_plan_detail_state.dart';
import 'package:wanderer_frontend/presentation/state/user_chrome/user_chrome_notifier.dart';
import 'package:wanderer_frontend/presentation/state/user_chrome/user_chrome_state.dart';
import 'package:wanderer_frontend/presentation/widgets/common/wanderer_app_bar.dart';
import 'package:wanderer_frontend/presentation/widgets/common/app_sidebar.dart';
import 'package:wanderer_frontend/presentation/widgets/trip_plans/trip_from_plan_dialog.dart';
import 'package:wanderer_frontend/presentation/widgets/trip_plans/trip_plan_info_card.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';

/// Screen for viewing and editing a trip plan
class TripPlanDetailScreen extends ConsumerStatefulWidget {
  final TripPlan tripPlan;

  const TripPlanDetailScreen({super.key, required this.tripPlan});

  @override
  ConsumerState<TripPlanDetailScreen> createState() =>
      _TripPlanDetailScreenState();
}

class _TripPlanDetailScreenState extends ConsumerState<TripPlanDetailScreen> {
  late final TripPlanService _tripPlanService;
  late final TripService _tripService;
  late final GoogleDirectionsApiClient _directionsClient;
  TripPlan get _tripPlan =>
      ref.watch(tripPlanDetailNotifierProvider(widget.tripPlan.id)).tripPlan;
  bool _isEditing = false;
  bool _isLoading = false;

  final int _selectedSidebarIndex = -1; // Not a sidebar item

  UserChromeState get _userChrome => ref.watch(userChromeNotifierProvider);
  String? get _username => _userChrome.username;
  String? get _userId => _userChrome.userId;
  String? get _displayName => _userChrome.displayName;
  String? get _avatarUrl => _userChrome.avatarUrl;
  bool get _isLoggedIn => _userChrome.isLoggedIn;
  bool get _isAdmin => _userChrome.isAdmin;

  late TextEditingController _nameController;
  late String _selectedPlanType;
  DateTime? _startDate;
  DateTime? _endDate;

  GoogleMapController? _mapController;
  Set<Marker> get _markers => ref
      .watch(tripPlanDetailNotifierProvider(widget.tripPlan.id))
      .viewMap
      .markers;
  Set<Polyline> get _polylines => ref
      .watch(tripPlanDetailNotifierProvider(widget.tripPlan.id))
      .viewMap
      .polylines;

  // Collapsible panel state
  bool get _isInfoCollapsed => ref
      .watch(tripPlanDetailNotifierProvider(widget.tripPlan.id))
      .viewMap
      .isInfoCollapsed;

  TripPlanDetailEditMapState get _editMapState =>
      ref.watch(tripPlanDetailNotifierProvider(widget.tripPlan.id)).editMap;
  List<LatLng> get _editWaypoints => _editMapState.waypoints;
  LatLng? get _editStartLocation => _editMapState.startLocation;
  LatLng? get _editEndLocation => _editMapState.endLocation;
  // `_editPlacementMode` intentionally has no widget-side getter: every
  // remaining reference to the placement mode in this file was inside the
  // now-migrated `_onEditMapTapped`/`_initEditLocations`/`_cancelEditing`
  // methods, so nothing on the widget ever reads it directly anymore
  // (unlike `_editWaypoints` etc., which the panel/chips UI below still
  // reads for rendering). Omitted rather than left as dead code that
  // `flutter analyze` would flag as an unused_element.
  Set<Polyline> get _editPolylines => _editMapState.polylines;
  String? get _editEncodedPolyline => _editMapState.encodedPolyline;
  bool get _isEditComputingRoute => _editMapState.isComputingRoute;

  bool _editFormExpanded = false;
  bool _showEditWaypointsList = false;
  bool _isEditPanelCollapsed = false;

  @override
  void initState() {
    super.initState();
    _tripPlanService = ref.read(tripPlanServiceProvider);
    _tripService = ref.read(tripServiceProvider);
    _directionsClient = ref.read(googleDirectionsApiClientProvider);
    ref
        .read(tripPlanDetailNotifierProvider(widget.tripPlan.id).notifier)
        .seedInitialTripPlan(widget.tripPlan);
    _nameController = TextEditingController(text: _tripPlan.name);
    _selectedPlanType = _tripPlan.planType;
    _startDate = _tripPlan.startDate;
    _endDate = _tripPlan.endDate;
    ref
        .read(tripPlanDetailNotifierProvider(widget.tripPlan.id).notifier)
        .initEditLocations();
    ref
        .read(tripPlanDetailNotifierProvider(widget.tripPlan.id).notifier)
        .updateViewMapData(onWaypointTap: _showWaypointOptions);
    ref.read(userChromeNotifierProvider.notifier).loadUserInfo();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _handleLogout() async {
    final confirm = await DialogHelper.showLogoutConfirmation(context);

    if (confirm) {
      await ref.read(userChromeNotifierProvider.notifier).logout();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          PageTransitions.fade(const HomeScreen()),
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
      await ref.read(userChromeNotifierProvider.notifier).loadUserInfo();
    }
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
    final notifier =
        ref.read(tripPlanDetailNotifierProvider(widget.tripPlan.id).notifier);
    notifier.setPickerOpen(true);
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
        notifier.setPickerOpen(false);
        // Absorb the trailing map tap that the platform view fires
        // after the dialog dismisses (Save / Cancel / X click).
        notifier.setIgnoreNextMapTap(true);
      }
    }
    if (picked != null && mounted) {
      setState(() {
        _startDate = picked!.start;
        _endDate = picked.end;
      });
    }
  }

  Future<void> _saveChanges() async {
    if (_nameController.text.trim().isEmpty) {
      UiHelpers.showErrorMessage(context, 'Name is required');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Use the already-computed encoded polyline, or compute a fallback
      String? encodedPolyline = _editEncodedPolyline;
      if (encodedPolyline == null) {
        final points = ref
            .read(tripPlanDetailNotifierProvider(widget.tripPlan.id).notifier)
            .buildEditOrderedPoints();
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
        ref
            .read(tripPlanDetailNotifierProvider(widget.tripPlan.id).notifier)
            .applyTripPlanOverride(updatedPlan);
        setState(() {
          _isEditing = false;
          _isLoading = false;
        });
        ref
            .read(tripPlanDetailNotifierProvider(widget.tripPlan.id).notifier)
            .initEditLocations();
        ref
            .read(tripPlanDetailNotifierProvider(widget.tripPlan.id).notifier)
            .updateViewMapData(onWaypointTap: _showWaypointOptions);
        UiHelpers.showSuccessMessage(context, 'Trip plan updated successfully');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        UiHelpers.showErrorMessage(context, 'Error updating trip plan: $e');
      }
    }
  }

  Future<void> _deleteTripPlan() async {
    final l10n = context.l10n;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteTripPlan),
        content: Text(
          'Are you sure you want to delete "${_tripPlan.name}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isLoading = true);

    try {
      await _tripPlanService.deleteTripPlan(_tripPlan.id);
      if (mounted) {
        UiHelpers.showSuccessMessage(context, 'Trip plan deleted');
        Navigator.pop(context, true); // Return true to indicate deletion
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        UiHelpers.showErrorMessage(context, 'Error deleting trip plan: $e');
      }
    }
  }

  Future<void> _createTripFromPlan() async {
    final request = await showDialog<TripFromPlanRequest>(
      context: context,
      builder: (context) => TripFromPlanDialog(
          planName: _tripPlan.name, planType: _tripPlan.planType),
    );

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
        UiHelpers.showSuccessMessage(
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
        UiHelpers.showErrorMessage(context, 'Error creating trip: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final hasMapData = _markers.isNotEmpty;

    // When editing, show the edit form
    if (_isEditing) {
      return _buildEditScreen();
    }

    // Normal view with fullscreen map and floating info card
    return Scaffold(
      appBar: WandererAppBar(
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
          onPressed: () => Navigator.pop(context),
        ),
      ),
      drawer: AppSidebar(
        username: _username,
        userId: _userId,
        displayName: _displayName,
        avatarUrl: _avatarUrl,
        selectedIndex: _selectedSidebarIndex,
        onLogout: _handleLogout,
        onSettings: _handleSettings,
        isAdmin: _isAdmin,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 600;
          return Stack(
            children: [
              // Fullscreen Map
              Positioned.fill(
                child: hasMapData
                    ? GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target:
                              TripPlanMapHelper.getInitialLocation(_tripPlan),
                          zoom: 10,
                        ),
                        markers: _markers,
                        polylines: _polylines,
                        onMapCreated: (controller) {
                          _mapController = controller;
                          // Fit bounds to show all markers
                          if (_markers.length >= 2) {
                            _fitBounds();
                          }
                        },
                        myLocationEnabled: false,
                        zoomControlsEnabled: true,
                        mapToolbarEnabled: false,
                      )
                    : Container(
                        color: Colors.grey.shade200,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.map_outlined,
                                size: 64,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                l10n.noLocationData,
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
              // Floating Info Card — top-right on desktop, bottom-center on mobile
              if (isDesktop)
                Positioned(
                  left: 0,
                  top: 0,
                  child: TripPlanInfoCard(
                    tripPlan: _tripPlan,
                    isCollapsed: _isInfoCollapsed,
                    onToggleCollapse: () => ref
                        .read(tripPlanDetailNotifierProvider(widget.tripPlan.id)
                            .notifier)
                        .setInfoCollapsed(!_isInfoCollapsed),
                    onEdit: () {
                      final notifier = ref.read(
                          tripPlanDetailNotifierProvider(widget.tripPlan.id)
                              .notifier);
                      notifier.initEditLocations();
                      notifier.initEditPolylines();
                      setState(() {
                        _isEditing = true;
                        _editFormExpanded = false;
                        _showEditWaypointsList = false;
                      });
                    },
                    onDelete: _deleteTripPlan,
                    onCreateTrip: _createTripFromPlan,
                  ),
                )
              else
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: SafeArea(
                    child: Align(
                      alignment: _isInfoCollapsed
                          ? Alignment.bottomLeft
                          : Alignment.bottomCenter,
                      child: TripPlanInfoCard(
                        tripPlan: _tripPlan,
                        isCollapsed: _isInfoCollapsed,
                        onToggleCollapse: () => ref
                            .read(tripPlanDetailNotifierProvider(
                                    widget.tripPlan.id)
                                .notifier)
                            .setInfoCollapsed(!_isInfoCollapsed),
                        onEdit: () {
                          final notifier = ref.read(
                              tripPlanDetailNotifierProvider(widget.tripPlan.id)
                                  .notifier);
                          notifier.initEditLocations();
                          notifier.initEditPolylines();
                          setState(() {
                            _isEditing = true;
                            _editFormExpanded = false;
                            _showEditWaypointsList = false;
                          });
                        },
                        onDelete: _deleteTripPlan,
                        onCreateTrip: _createTripFromPlan,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  /// Cancels editing and restores state
  void _cancelEditing() {
    ref
        .read(tripPlanDetailNotifierProvider(widget.tripPlan.id).notifier)
        .resetEditMapToSavedPlan();
    setState(() {
      _isEditing = false;
      _nameController.text = _tripPlan.name;
      _selectedPlanType = _tripPlan.planType;
      _startDate = _tripPlan.startDate;
      _endDate = _tripPlan.endDate;
      _showEditWaypointsList = false;
      _isEditPanelCollapsed = false;
    });
  }

  /// Builds the edit screen with responsive layout:
  /// - Desktop/Web (>=600px): side glass panel on left + fullscreen map
  /// - Mobile (<600px): fullscreen map + bottom sheet form
  Widget _buildEditScreen() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 600;
        if (isWide) {
          return _buildEditScreenDesktop();
        }
        return _buildEditScreenMobile();
      },
    );
  }

  /// Desktop/Web edit layout with floating side panel
  Widget _buildEditScreenDesktop() {
    final l10n = context.l10n;
    const double panelWidth = 400.0;
    return Scaffold(
      backgroundColor: WandererTheme.backgroundLight,
      appBar: WandererAppBar(
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
          onPressed: _cancelEditing,
        ),
      ),
      drawer: AppSidebar(
        username: _username,
        userId: _userId,
        displayName: _displayName,
        avatarUrl: _avatarUrl,
        selectedIndex: _selectedSidebarIndex,
        onLogout: _handleLogout,
        onSettings: _handleSettings,
        isAdmin: _isAdmin,
      ),
      body: Stack(
        children: [
          // Full-screen map
          Positioned.fill(
            child: GoogleMap(
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
              onTap: (location) => ref
                  .read(tripPlanDetailNotifierProvider(widget.tripPlan.id)
                      .notifier)
                  .onEditMapTapped(location),
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              zoomControlsEnabled: true,
              mapToolbarEnabled: false,
              padding: EdgeInsets.only(
                left: _isEditPanelCollapsed ? 88 : panelWidth,
              ),
            ),
          ),
          // Location chips (offset to right of panel)
          Positioned(
            top: 8,
            left: (_isEditPanelCollapsed ? 88 : panelWidth) + 16,
            right: 16,
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (_) => ref
                  .read(tripPlanDetailNotifierProvider(widget.tripPlan.id)
                      .notifier)
                  .setIgnoreNextMapTap(true),
              child: _buildEditLocationChips(),
            ),
          ),
          // Route computing indicator
          if (_isEditComputingRoute)
            Positioned(
              top: 44,
              right: 16,
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (_) => ref
                    .read(tripPlanDetailNotifierProvider(widget.tripPlan.id)
                        .notifier)
                    .setIgnoreNextMapTap(true),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
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
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.blue,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        l10n.computingRoute,
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // Floating waypoints reorder panel (to the right of side panel)
          if (_showEditWaypointsList && _editWaypoints.isNotEmpty)
            Positioned(
              top: 44,
              left: (_isEditPanelCollapsed ? 88 : panelWidth) + 12,
              right: 12,
              bottom: 16,
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (_) => ref
                    .read(tripPlanDetailNotifierProvider(widget.tripPlan.id)
                        .notifier)
                    .setIgnoreNextMapTap(true),
                child: _buildEditWaypointsPanel(),
              ),
            ),
          // Floating glass side panel
          Positioned(
            left: 0,
            top: 0,
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (_) => ref
                  .read(tripPlanDetailNotifierProvider(widget.tripPlan.id)
                      .notifier)
                  .setIgnoreNextMapTap(true),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                width: _isEditPanelCollapsed ? 88 : panelWidth,
                child: _isEditPanelCollapsed
                    ? _buildCollapsedEditBubble()
                    : _buildExpandedEditPanel(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Collapsed edit bubble (matching trip detail collapsed style)
  Widget _buildCollapsedEditBubble() {
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
                onTap: () => setState(() => _isEditPanelCollapsed = false),
                customBorder: const CircleBorder(),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(shape: BoxShape.circle),
                  child: Icon(
                    Icons.edit_outlined,
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

  /// Expanded glass side panel with edit form
  Widget _buildExpandedEditPanel() {
    final l10n = context.l10n;
    final screenHeight = MediaQuery.of(context).size.height;
    // topOffset = appBar + panel top margin (8) + panel bottom margin (16)
    final topOffset = kToolbarHeight + 8 + 16;
    final maxPanelHeight = screenHeight - topOffset - 16;
    return Container(
      margin: const EdgeInsets.only(
        left: 16,
        top: 8,
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
                      color: Colors.white.withOpacity(0.4),
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
                          Icons.edit_outlined,
                          size: 18,
                          color: WandererTheme.primaryOrange,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.editTripPlan,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: WandererTheme.textPrimary,
                            ),
                          ),
                        ),
                        // Cancel button
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: IconButton(
                            icon: Icon(
                              Icons.close,
                              size: 18,
                              color: Colors.red.shade400,
                            ),
                            onPressed: _cancelEditing,
                            tooltip: l10n.cancel,
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                            padding: EdgeInsets.zero,
                          ),
                        ),
                        const SizedBox(width: 4),
                        // Save button
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: IconButton(
                            icon: _isLoading
                                ? SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: WandererTheme.primaryOrange,
                                    ),
                                  )
                                : Icon(
                                    Icons.check_rounded,
                                    size: 18,
                                    color: WandererTheme.primaryOrange,
                                  ),
                            onPressed: _isLoading ? null : _saveChanges,
                            tooltip: l10n.saveChanges,
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                            padding: EdgeInsets.zero,
                          ),
                        ),
                        const SizedBox(width: 4),
                        // Collapse button
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: IconButton(
                            icon: Icon(
                              Icons.remove,
                              size: 18,
                              color: WandererTheme.textSecondary,
                            ),
                            onPressed: () => setState(
                              () => _isEditPanelCollapsed = true,
                            ),
                            tooltip: l10n.minimize,
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Name
                          _buildEditSectionLabel('Plan Name'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _nameController,
                            decoration: _editInputDecoration(
                              'e.g., Weekend Hiking Adventure',
                            ),
                            textCapitalization: TextCapitalization.words,
                          ),
                          const SizedBox(height: 20),
                          // Plan Type
                          _buildEditSectionLabel('Plan Type'),
                          const SizedBox(height: 10),
                          _buildEditPlanTypeSelector(),
                          const SizedBox(height: 20),
                          // Dates
                          _buildEditSectionLabel('Dates'),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _buildEditDateButton(
                                  label: 'Start',
                                  date: _startDate,
                                  onTap: _selectDateRange,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildEditDateButton(
                                  label: 'End',
                                  date: _endDate,
                                  onTap: _selectDateRange,
                                ),
                              ),
                            ],
                          ),
                          if (_startDate != null && _endDate != null) ...[
                            const SizedBox(height: 10),
                            _buildEditDaysInfo(),
                          ],
                          const SizedBox(height: 24),
                          // Save button
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _saveChanges,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: WandererTheme.primaryOrange,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: Colors.grey.shade300,
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
                                  : Text(
                                      l10n.saveChanges,
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Mobile edit layout with bottom sheet form (original behavior)
  Widget _buildEditScreenMobile() {
    final l10n = context.l10n;
    final expandedHeight = MediaQuery.of(context).size.height -
        MediaQuery.of(context).padding.top -
        kToolbarHeight;
    return Scaffold(
      backgroundColor: WandererTheme.backgroundLight,
      resizeToAvoidBottomInset: false,
      appBar: WandererAppBar(
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
          onPressed: _cancelEditing,
        ),
      ),
      drawer: AppSidebar(
        username: _username,
        userId: _userId,
        displayName: _displayName,
        avatarUrl: _avatarUrl,
        selectedIndex: _selectedSidebarIndex,
        onLogout: _handleLogout,
        onSettings: _handleSettings,
        isAdmin: _isAdmin,
      ),
      body: Stack(
        children: [
          // Full-screen map with draggable markers (disabled when form sheet is fully expanded)
          Positioned.fill(
            child: AbsorbPointer(
              absorbing: _editFormExpanded,
              child: GoogleMap(
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
                onTap: (location) => ref
                    .read(tripPlanDetailNotifierProvider(widget.tripPlan.id)
                        .notifier)
                    .onEditMapTapped(location),
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
                zoomControlsEnabled: false,
                padding: EdgeInsets.only(
                  bottom: _editFormExpanded ? expandedHeight : 200,
                ),
              ),
            ),
          ),
          // Location chips
          Positioned(
            top: 8,
            left: 16,
            right: 16,
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (_) => ref
                  .read(tripPlanDetailNotifierProvider(widget.tripPlan.id)
                      .notifier)
                  .setIgnoreNextMapTap(true),
              child: _buildEditLocationChips(),
            ),
          ),
          // Route computing indicator
          if (_isEditComputingRoute)
            Positioned(
              top: 48,
              right: 16,
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (_) => ref
                    .read(tripPlanDetailNotifierProvider(widget.tripPlan.id)
                        .notifier)
                    .setIgnoreNextMapTap(true),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
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
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.blue,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        l10n.computingRoute,
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // Floating waypoints reorder panel
          if (_showEditWaypointsList && _editWaypoints.isNotEmpty)
            Positioned(
              top: 48,
              left: 12,
              right: 12,
              bottom: _editFormExpanded ? expandedHeight + 10 : 210,
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (_) => ref
                    .read(tripPlanDetailNotifierProvider(widget.tripPlan.id)
                        .notifier)
                    .setIgnoreNextMapTap(true),
                child: _buildEditWaypointsPanel(),
              ),
            ),
          // Bottom form sheet
          _buildEditFormSheet(),
        ],
      ),
    );
  }

  Set<Marker> _buildEditMarkers() {
    final notifier =
        ref.read(tripPlanDetailNotifierProvider(widget.tripPlan.id).notifier);
    final markers = <Marker>{};
    if (_editStartLocation != null) {
      markers.add(Marker(
        markerId: const MarkerId('start'),
        position: _editStartLocation!,
        infoWindow: const InfoWindow(title: 'Start Location'),
        icon: BitmapDescriptor.defaultMarkerWithHue(120.0), // Green
        draggable: true,
        onDragEnd: (pos) => notifier.setStartLocation(pos),
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
        onDragEnd: (pos) => notifier.setEndLocation(pos),
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
        onDragEnd: (pos) => notifier.updateWaypointAt(i, pos),
        onTap: () => _showEditMarkerOptions(
          'waypoint_${i + 1}',
          'Waypoint ${i + 1}',
        ),
      ));
    }
    return markers;
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
                    ref
                        .read(tripPlanDetailNotifierProvider(widget.tripPlan.id)
                            .notifier)
                        .removeWaypointAt(index - 1);
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

  Widget _buildEditLocationChips() {
    return Row(
      children: [
        _buildEditChip(
          label: 'Start',
          isSet: _editStartLocation != null,
          color: Colors.green,
          icon: Icons.trip_origin,
        ),
        const SizedBox(width: 6),
        _buildEditChip(
          label: 'End',
          isSet: _editEndLocation != null,
          color: Colors.red,
          icon: Icons.place,
        ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: () {
            if (_editWaypoints.isNotEmpty) {
              setState(() => _showEditWaypointsList = !_showEditWaypointsList);
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _showEditWaypointsList
                  ? Colors.blue.withOpacity(0.25)
                  : _editWaypoints.isNotEmpty
                      ? Colors.blue.withOpacity(0.15)
                      : Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _showEditWaypointsList
                    ? Colors.blue
                    : _editWaypoints.isNotEmpty
                        ? Colors.blue.withOpacity(0.4)
                        : Colors.grey.shade300,
                width: _showEditWaypointsList ? 2 : 1,
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
                  _editWaypoints.isNotEmpty
                      ? Icons.check_circle
                      : Icons.more_horiz,
                  size: 14,
                  color: _editWaypoints.isNotEmpty
                      ? Colors.blue
                      : Colors.grey.shade500,
                ),
                const SizedBox(width: 4),
                Text(
                  _editWaypoints.isEmpty
                      ? 'Waypoints'
                      : 'Waypoints (${_editWaypoints.length})',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: _showEditWaypointsList
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: _editWaypoints.isNotEmpty
                        ? Colors.blue
                        : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEditChip({
    required String label,
    required bool isSet,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isSet ? color.withOpacity(0.15) : Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSet ? color.withOpacity(0.4) : Colors.grey.shade300,
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
            color: isSet ? color : Colors.grey.shade500,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: isSet ? color : Colors.grey.shade600,
            ),
          ),
        ],
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
                  ref
                      .read(tripPlanDetailNotifierProvider(widget.tripPlan.id)
                          .notifier)
                      .reorderWaypoint(oldIndex, newIndex);
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
                            onTap: () => ref
                                .read(tripPlanDetailNotifierProvider(
                                        widget.tripPlan.id)
                                    .notifier)
                                .removeWaypointAt(index),
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

  Widget _buildEditFormSheet() {
    final l10n = context.l10n;
    final expandedHeight = MediaQuery.of(context).size.height -
        MediaQuery.of(context).padding.top -
        kToolbarHeight;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) => ref
            .read(tripPlanDetailNotifierProvider(widget.tripPlan.id).notifier)
            .setIgnoreNextMapTap(true),
        child: GestureDetector(
          onVerticalDragUpdate: (details) {
            if (details.primaryDelta! < -4) {
              setState(() => _editFormExpanded = true);
            } else if (details.primaryDelta! > 4) {
              setState(() => _editFormExpanded = false);
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            height: _editFormExpanded ? expandedHeight : 200,
            decoration: BoxDecoration(
              color: WandererTheme.backgroundLight,
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
                  onTap: () =>
                      setState(() => _editFormExpanded = !_editFormExpanded),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.only(top: 12, bottom: 8),
                    child: Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      0,
                      20,
                      MediaQuery.of(context).viewInsets.bottom,
                    ),
                    physics: _editFormExpanded
                        ? const BouncingScrollPhysics()
                        : const NeverScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name
                        _buildEditSectionLabel('Plan Name'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _nameController,
                          decoration: _editInputDecoration(
                            'e.g., Weekend Hiking Adventure',
                          ),
                          textCapitalization: TextCapitalization.words,
                          onTap: () {
                            if (!_editFormExpanded) {
                              setState(() => _editFormExpanded = true);
                            }
                          },
                        ),
                        const SizedBox(height: 20),
                        // Plan Type
                        _buildEditSectionLabel('Plan Type'),
                        const SizedBox(height: 10),
                        _buildEditPlanTypeSelector(),
                        const SizedBox(height: 20),
                        // Dates
                        _buildEditSectionLabel('Dates'),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _buildEditDateButton(
                                label: 'Start',
                                date: _startDate,
                                onTap: _selectDateRange,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildEditDateButton(
                                label: 'End',
                                date: _endDate,
                                onTap: _selectDateRange,
                              ),
                            ),
                          ],
                        ),
                        if (_startDate != null && _endDate != null) ...[
                          const SizedBox(height: 10),
                          _buildEditDaysInfo(),
                        ],
                        const SizedBox(height: 24),
                        // Save button
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _saveChanges,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: WandererTheme.primaryOrange,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.grey.shade300,
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
                                : Text(
                                    l10n.saveChanges,
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEditPlanTypeSelector() {
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: types.map((type) {
          final isSelected = _selectedPlanType == type['value'];
          return Expanded(
            child: GestureDetector(
              onTap: () =>
                  setState(() => _selectedPlanType = type['value'] as String),
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
                          : WandererTheme.textTertiary,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      type['label'] as String,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? WandererTheme.primaryOrange
                            : WandererTheme.textSecondary,
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

  Widget _buildEditDateButton({
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasDate
                ? WandererTheme.primaryOrange.withOpacity(0.5)
                : Colors.grey.shade200,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: 18,
              color: hasDate
                  ? WandererTheme.primaryOrange
                  : WandererTheme.textTertiary,
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
                      color: WandererTheme.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasDate ? _formatEditDate(date) : 'Select',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: hasDate ? FontWeight.w600 : FontWeight.w400,
                      color: hasDate
                          ? WandererTheme.textPrimary
                          : WandererTheme.textTertiary,
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

  String _formatEditDate(DateTime date) {
    const months = [
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

  Widget _buildEditDaysInfo() {
    final l10n = context.l10n;
    final days = _endDate!.difference(_startDate!).inDays + 1;
    final isMultiDay = _selectedPlanType == 'MULTI_DAY';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isMultiDay
            ? WandererTheme.primaryOrange.withOpacity(0.06)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isMultiDay
              ? WandererTheme.primaryOrange.withOpacity(0.2)
              : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.date_range_rounded,
            size: 16,
            color: isMultiDay
                ? WandererTheme.primaryOrange
                : WandererTheme.textTertiary,
          ),
          const SizedBox(width: 8),
          Text(
            days == 1 ? '1 day' : '$days days',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isMultiDay
                  ? WandererTheme.primaryOrange
                  : WandererTheme.textSecondary,
            ),
          ),
          if (isMultiDay && days > 1) ...[
            const SizedBox(width: 6),
            Text(
              l10n.multiDayTrip,
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

  Widget _buildEditSectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: WandererTheme.textPrimary,
      ),
    );
  }

  InputDecoration _editInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
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

  void _fitEditBounds() {
    final allPoints = <LatLng>[
      if (_editStartLocation != null) _editStartLocation!,
      if (_editEndLocation != null) _editEndLocation!,
      ..._editWaypoints,
    ];
    if (allPoints.length < 2 || _mapController == null) return;
    final bounds = TripPlanMapHelper.calculateBoundsForPoints(allPoints);
    if (bounds == null) return;
    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 50),
    );
  }

  void _fitBounds() {
    if (_mapController == null) return;
    final bounds = TripPlanMapHelper.calculateBounds(_markers);
    if (bounds == null) return;
    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 50),
    );
  }
}
