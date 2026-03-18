import 'package:flutter/material.dart' hide Visibility;
import 'package:wanderer_frontend/core/constants/enums.dart';
import 'package:wanderer_frontend/data/models/admin_models.dart';
import 'package:wanderer_frontend/data/models/responses/page_response.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/data/services/admin_service.dart';
import 'package:wanderer_frontend/data/services/trip_service.dart';
import 'package:wanderer_frontend/data/repositories/home_repository.dart';
import 'package:wanderer_frontend/presentation/helpers/auth_navigation_helper.dart';
import 'package:wanderer_frontend/presentation/helpers/ui_helpers.dart';
import 'package:wanderer_frontend/presentation/screens/home_screen.dart';
import 'package:wanderer_frontend/presentation/screens/settings_screen.dart';
import 'package:wanderer_frontend/presentation/screens/trip_detail_screen.dart';
import 'package:wanderer_frontend/presentation/widgets/common/wanderer_app_bar.dart';
import 'package:wanderer_frontend/presentation/widgets/common/app_sidebar.dart';

/// Admin screen for managing trip data maintenance (polyline and geocoding recomputation).
/// Allows admins to view statistics and trigger backend recomputation of encoded polylines
/// and geocoding (city/country) for trip updates.
class TripMaintenanceScreen extends StatefulWidget {
  const TripMaintenanceScreen({super.key});

  @override
  State<TripMaintenanceScreen> createState() => _TripMaintenanceScreenState();
}

class _TripMaintenanceScreenState extends State<TripMaintenanceScreen> {
  final AdminService _adminService = AdminService();
  final TripService _tripService = TripService();
  final HomeRepository _homeRepository = HomeRepository();
  final TextEditingController _searchController = TextEditingController();

  List<Trip> _allTrips = [];
  List<Trip> _filteredTrips = [];
  TripMaintenanceStats? _stats;
  bool _isLoading = false;
  bool _isLoadingMoreTrips = false;
  bool _hasMoreTrips = false;
  int _currentTripsPage = 0;
  static const int _tripsPageSize = 20;
  String? _error;
  String? _userId;
  String? _username;
  String? _displayName;
  String? _avatarUrl;
  bool _isLoggedIn = false;
  bool _isAdmin = false;
  final int _selectedSidebarIndex = 7; // Trip maintenance index

  /// Set of trip IDs currently being recomputed (for loading indicators)
  final Set<String> _recomputingTrips = {};

  /// Set of trip IDs that have been successfully recomputed in this session
  final Set<String> _recomputedTrips = {};

  /// Set of trip IDs currently having geocoding recomputed
  final Set<String> _recomputingGeocoding = {};

  /// Set of trip IDs that have had geocoding successfully recomputed in this session
  final Set<String> _recomputedGeocoding = {};

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _loadTrips();
    _searchController.addListener(_filterTrips);
  }

  @override
  void dispose() {
    _searchController.dispose();
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

    setState(() {
      _username = username;
      _userId = userId;
      _displayName = displayName;
      _avatarUrl = avatarUrl;
      _isLoggedIn = isLoggedIn;
      _isAdmin = isAdmin;
    });
  }

  Future<void> _loadTrips() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _currentTripsPage = 0;
    });

    try {
      // Load both trips (first page) and stats in parallel
      final results = await Future.wait([
        _adminService.getAllTrips(page: 0, size: _tripsPageSize),
        _adminService.getTripStats(),
      ]);

      final tripPage = results[0] as PageResponse<Trip>;
      setState(() {
        _allTrips = tripPage.content;
        _filteredTrips = tripPage.content;
        _hasMoreTrips = !tripPage.last;
        _stats = results[1] as TripMaintenanceStats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreTrips() async {
    if (_isLoadingMoreTrips || !_hasMoreTrips) return;

    setState(() => _isLoadingMoreTrips = true);

    try {
      final nextPage = _currentTripsPage + 1;
      final page =
          await _adminService.getAllTrips(page: nextPage, size: _tripsPageSize);

      setState(() {
        _allTrips = [..._allTrips, ...page.content];
        _currentTripsPage = nextPage;
        _hasMoreTrips = !page.last;
        _isLoadingMoreTrips = false;
        final query = _searchController.text.toLowerCase();
        _filteredTrips = query.isEmpty
            ? _allTrips
            : _allTrips.where((trip) {
                return trip.name.toLowerCase().contains(query) ||
                    trip.username.toLowerCase().contains(query) ||
                    trip.id.toLowerCase().contains(query);
              }).toList();
      });
    } catch (e) {
      setState(() => _isLoadingMoreTrips = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading more trips: $e')),
        );
      }
    }
  }

  void _filterTrips() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredTrips = _allTrips;
      } else {
        _filteredTrips = _allTrips.where((trip) {
          return trip.name.toLowerCase().contains(query) ||
              trip.username.toLowerCase().contains(query) ||
              trip.id.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  Future<void> _recomputePolyline(Trip trip) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recompute Polyline'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Trip: ${trip.name}',
              style: const TextStyle(fontWeight: FontWeight.bold),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text('By: ${trip.username}'),
            const SizedBox(height: 12),
            Text(
              'This will fully recompute the encoded polyline from all '
              'trip updates using the Google Routes API on the backend.',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            const SizedBox(height: 8),
            Text(
              'Locations: ${trip.locations?.length ?? 0}',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            Text(
              'Has polyline: ${trip.encodedPolyline != null ? "Yes" : "No"}',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Recompute'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() {
        _recomputingTrips.add(trip.id);
      });

      try {
        await _adminService.recomputePolyline(trip.id);

        if (mounted) {
          setState(() {
            _recomputingTrips.remove(trip.id);
            _recomputedTrips.add(trip.id);
          });
          UiHelpers.showSuccessMessage(
            context,
            'Polyline recomputed for "${trip.name}"',
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _recomputingTrips.remove(trip.id);
          });
          UiHelpers.showErrorMessage(
            context,
            'Failed to recompute polyline: $e',
          );
        }
      }
    }
  }

  Future<void> _recomputeGeocoding(Trip trip) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recompute Geocoding'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Trip: ${trip.name}',
              style: const TextStyle(fontWeight: FontWeight.bold),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text('By: ${trip.username}'),
            const SizedBox(height: 12),
            Text(
              'This will recompute city and country for all '
              'trip updates using reverse geocoding on the backend.',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            const SizedBox(height: 8),
            Text(
              'Locations: ${trip.locations?.length ?? 0}',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Recompute'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() {
        _recomputingGeocoding.add(trip.id);
      });

      try {
        await _adminService.recomputeGeocoding(trip.id);

        if (mounted) {
          setState(() {
            _recomputingGeocoding.remove(trip.id);
            _recomputedGeocoding.add(trip.id);
          });
          UiHelpers.showSuccessMessage(
            context,
            'Geocoding recomputed for "${trip.name}"',
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _recomputingGeocoding.remove(trip.id);
          });
          UiHelpers.showErrorMessage(
            context,
            'Failed to recompute geocoding: $e',
          );
        }
      }
    }
  }

  Future<void> _recomputeAll() async {
    final tripsWithLocations = _allTrips
        .where((t) => t.locations != null && t.locations!.length >= 2)
        .toList();

    if (tripsWithLocations.isEmpty) {
      UiHelpers.showErrorMessage(context, 'No trips with 2+ locations found');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recompute All Polylines'),
        content: Text(
          'This will recompute polylines for ${tripsWithLocations.length} '
          'trips with 2 or more locations.\n\n'
          'This may take a while and will use Google Routes API calls '
          'on the backend.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Recompute All'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      int successes = 0;
      int failures = 0;

      for (final trip in tripsWithLocations) {
        if (!mounted) break;

        setState(() {
          _recomputingTrips.add(trip.id);
        });

        try {
          await _adminService.recomputePolyline(trip.id);
          successes++;
          if (mounted) {
            setState(() {
              _recomputingTrips.remove(trip.id);
              _recomputedTrips.add(trip.id);
            });
          }
        } catch (e) {
          failures++;
          if (mounted) {
            setState(() {
              _recomputingTrips.remove(trip.id);
            });
          }
        }
      }

      if (mounted) {
        if (failures == 0) {
          UiHelpers.showSuccessMessage(
            context,
            'All $successes polylines recomputed successfully!',
          );
        } else {
          UiHelpers.showErrorMessage(
            context,
            'Recomputed $successes, failed $failures',
          );
        }
      }
    }
  }

  Future<void> _navigateToTrip(String tripId) async {
    try {
      final trip = await _tripService.getTripById(tripId);
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => TripDetailScreen(trip: trip)),
        );
      }
    } catch (e) {
      if (mounted) {
        UiHelpers.showErrorMessage(context, 'Failed to load trip: $e');
      }
    }
  }

  Future<void> _handleLogout() async {
    await _homeRepository.logout();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
        (route) => false,
      );
    }
  }

  void _handleSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: WandererAppBar(
        isLoggedIn: _isLoggedIn,
        username: _username,
        userId: _userId,
        displayName: _displayName,
        avatarUrl: _avatarUrl,
        onLogout: _handleLogout,
        onSettings: _handleSettings,
        onProfile: () => AuthNavigationHelper.navigateToOwnProfile(context),
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
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Error: $_error',
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadTrips,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final horizontalPadding = isMobile ? 8.0 : 16.0;

        return RefreshIndicator(
          onRefresh: _loadTrips,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(horizontalPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatsCard(isMobile),
                const SizedBox(height: 24),
                _buildTripsSection(isMobile),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatsCard(bool isMobile) {
    final cardPadding = isMobile ? 12.0 : 16.0;

    // Use server stats if available, otherwise calculate from loaded trips
    final totalTrips = _stats?.totalTrips ?? _allTrips.length;
    final tripsWithPolyline = _stats?.tripsWithPolyline ??
        _allTrips.where((t) => t.encodedPolyline != null).length;
    final tripsWithLocations = _stats?.tripsWithMultipleLocations ??
        _allTrips
            .where((t) => t.locations != null && t.locations!.length >= 2)
            .length;
    final tripsNeedingPolyline = _stats?.tripsMissingPolyline ??
        _allTrips
            .where((t) =>
                t.encodedPolyline == null &&
                t.locations != null &&
                t.locations!.length >= 2)
            .length;

    final totalUpdates = _stats?.totalUpdates ?? 0;
    final updatesWithGeocoding = _stats?.updatesWithGeocoding ?? 0;
    final updatesMissingGeocoding = _stats?.updatesMissingGeocoding ?? 0;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.analytics, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Trip Data Overview',
                  style: TextStyle(
                    fontSize: isMobile ? 18 : 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Polyline stats
            Text(
              'Polyline Statistics',
              style: TextStyle(
                fontSize: isMobile ? 14 : 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            // Row layout to fit all 4 chips in one line (all screen sizes)
            Row(
              children: [
                Expanded(
                  child: _buildStatChip(
                    'Total Trips',
                    totalTrips.toString(),
                    Colors.grey,
                    isMobile,
                  ),
                ),
                SizedBox(width: isMobile ? 6 : 12),
                Expanded(
                  child: _buildStatChip(
                    'With Polyline',
                    tripsWithPolyline.toString(),
                    Colors.green,
                    isMobile,
                  ),
                ),
                SizedBox(width: isMobile ? 6 : 12),
                Expanded(
                  child: _buildStatChip(
                    '2+ Locations',
                    tripsWithLocations.toString(),
                    Colors.blue,
                    isMobile,
                  ),
                ),
                SizedBox(width: isMobile ? 6 : 12),
                Expanded(
                  child: _buildStatChip(
                    'Missing Polyline',
                    tripsNeedingPolyline.toString(),
                    tripsNeedingPolyline > 0 ? Colors.orange : Colors.green,
                    isMobile,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            // Geocoding stats
            Text(
              'Geocoding Statistics',
              style: TextStyle(
                fontSize: isMobile ? 14 : 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: isMobile ? 12 : 24,
              runSpacing: 12,
              children: [
                _buildStatChip(
                  'Total Updates',
                  totalUpdates.toString(),
                  Colors.grey,
                  isMobile,
                ),
                _buildStatChip(
                  'With Geocoding',
                  updatesWithGeocoding.toString(),
                  Colors.green,
                  isMobile,
                ),
                _buildStatChip(
                  'Missing Geocoding',
                  updatesMissingGeocoding.toString(),
                  updatesMissingGeocoding > 0 ? Colors.orange : Colors.green,
                  isMobile,
                ),
              ],
            ),
            if (tripsNeedingPolyline > 0) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _recomputeAll,
                  icon: const Icon(Icons.refresh),
                  label: Text(
                    'Recompute All Missing Polylines ($tripsNeedingPolyline)',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(
      String label, String value, Color color, bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 6 : 12,
        vertical: isMobile ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: isMobile ? 16 : 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isMobile ? 9 : 11,
              color: color.withValues(alpha: 0.8),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildTripsSection(bool isMobile) {
    final cardPadding = isMobile ? 12.0 : 16.0;
    final titleFontSize = isMobile ? 18.0 : 20.0;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.route),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'All Trips',
                    style: TextStyle(
                      fontSize: titleFontSize,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Tap a trip to view details, or recompute its polyline/geocoding',
              style: TextStyle(
                color: Colors.grey,
                fontSize: isMobile ? 12 : 14,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search trips',
                hintText: 'Search by name, username, or trip ID',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),
            if (_filteredTrips.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'No trips found',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _filteredTrips.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final trip = _filteredTrips[index];
                  return _buildTripItem(trip, isMobile);
                },
              ),
            if (_hasMoreTrips)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: _isLoadingMoreTrips
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : TextButton.icon(
                          onPressed: _loadMoreTrips,
                          icon: const Icon(Icons.expand_more),
                          label: const Text('Load more trips'),
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTripItem(Trip trip, bool isMobile) {
    final isRecomputing = _recomputingTrips.contains(trip.id);
    final wasRecomputed = _recomputedTrips.contains(trip.id);
    final isRecomputingGeo = _recomputingGeocoding.contains(trip.id);
    final wasRecomputedGeo = _recomputedGeocoding.contains(trip.id);
    final hasPolyline = trip.encodedPolyline != null;
    // Check if trip has geocoding data (any location with city and country)
    final hasGeocoding =
        trip.locations?.any((loc) => loc.city != null && loc.country != null) ??
            false;
    // Polyline recomputation requires 2+ locations (for routing between points)
    // Geocoding recomputation only requires 1+ locations (each can be geocoded independently)
    final hasEnoughLocations =
        trip.locations != null && trip.locations!.length >= 2;
    final locationCount = trip.locations?.length ?? 0;

    return InkWell(
      onTap: () => _navigateToTrip(trip.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: isMobile
            ? _buildMobileTripItem(
                trip,
                isRecomputing,
                wasRecomputed,
                isRecomputingGeo,
                wasRecomputedGeo,
                hasPolyline,
                hasGeocoding,
                hasEnoughLocations,
                locationCount,
              )
            : _buildDesktopTripItem(
                trip,
                isRecomputing,
                wasRecomputed,
                isRecomputingGeo,
                wasRecomputedGeo,
                hasPolyline,
                hasGeocoding,
                hasEnoughLocations,
                locationCount,
              ),
      ),
    );
  }

  Widget _buildMobileTripItem(
    Trip trip,
    bool isRecomputing,
    bool wasRecomputed,
    bool isRecomputingGeo,
    bool wasRecomputedGeo,
    bool hasPolyline,
    bool hasGeocoding,
    bool hasEnoughLocations,
    int locationCount,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPolylineStatusIcon(hasPolyline, wasRecomputed),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTripInfo(
                  trip, locationCount, hasPolyline, hasGeocoding),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildRecomputeButton(
                trip,
                isRecomputing,
                wasRecomputed,
                hasEnoughLocations,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildRecomputeGeocodingButton(
                trip,
                isRecomputingGeo,
                wasRecomputedGeo,
                locationCount,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDesktopTripItem(
    Trip trip,
    bool isRecomputing,
    bool wasRecomputed,
    bool isRecomputingGeo,
    bool wasRecomputedGeo,
    bool hasPolyline,
    bool hasGeocoding,
    bool hasEnoughLocations,
    int locationCount,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPolylineStatusIcon(hasPolyline, wasRecomputed),
        const SizedBox(width: 12),
        Expanded(
          child: _buildTripInfo(trip, locationCount, hasPolyline, hasGeocoding),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 140,
          child: _buildRecomputeButton(
            trip,
            isRecomputing,
            wasRecomputed,
            hasEnoughLocations,
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 140,
          child: _buildRecomputeGeocodingButton(
            trip,
            isRecomputingGeo,
            wasRecomputedGeo,
            locationCount,
          ),
        ),
      ],
    );
  }

  Widget _buildPolylineStatusIcon(bool hasPolyline, bool wasRecomputed) {
    if (wasRecomputed) {
      return const Icon(Icons.check_circle, color: Colors.green, size: 24);
    }
    if (hasPolyline) {
      return const Icon(Icons.route, color: Colors.blue, size: 24);
    }
    return const Icon(Icons.route, color: Colors.grey, size: 24);
  }

  Widget _buildTripInfo(
      Trip trip, int locationCount, bool hasPolyline, bool hasGeocoding) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          trip.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          'By: ${trip.username}',
          style: const TextStyle(fontSize: 14),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Row(
          children: [
            Text(
              '${_getStatusLabel(trip.status)} · $locationCount locations',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: hasPolyline
                    ? Colors.green.withValues(alpha: 0.1)
                    : Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                hasPolyline ? 'Has polyline' : 'No polyline',
                style: TextStyle(
                  fontSize: 10,
                  color: hasPolyline ? Colors.green : Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: hasGeocoding
                    ? Colors.green.withValues(alpha: 0.1)
                    : Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                hasGeocoding ? 'Has geocoding' : 'No geocoding',
                style: TextStyle(
                  fontSize: 10,
                  color: hasGeocoding ? Colors.green : Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecomputeButton(
    Trip trip,
    bool isRecomputing,
    bool wasRecomputed,
    bool hasEnoughLocations,
  ) {
    if (isRecomputing) {
      return const ElevatedButton(
        onPressed: null,
        child: SizedBox(
          height: 16,
          width: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (wasRecomputed) {
      return ElevatedButton.icon(
        onPressed: () => _recomputePolyline(trip),
        icon: const Icon(Icons.check, size: 16),
        label: const Text('Done'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
        ),
      );
    }

    if (!hasEnoughLocations) {
      return ElevatedButton(
        onPressed: null,
        child: Text(
          'Needs 2+ locations',
          style: TextStyle(fontSize: 12, color: Colors.grey[400]),
          textAlign: TextAlign.center,
        ),
      );
    }

    return ElevatedButton(
      onPressed: () => _recomputePolyline(trip),
      child: const Text(
        'Polyline',
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildRecomputeGeocodingButton(
    Trip trip,
    bool isRecomputing,
    bool wasRecomputed,
    int locationCount,
  ) {
    if (isRecomputing) {
      return const ElevatedButton(
        onPressed: null,
        child: SizedBox(
          height: 16,
          width: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (wasRecomputed) {
      return ElevatedButton.icon(
        onPressed: () => _recomputeGeocoding(trip),
        icon: const Icon(Icons.check, size: 16),
        label: const Text('Done'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
        ),
      );
    }

    // Geocoding doesn't require multiple locations - each update can be geocoded independently
    if (locationCount == 0) {
      return ElevatedButton(
        onPressed: null,
        child: Text(
          'Needs 1+ location',
          style: TextStyle(fontSize: 12, color: Colors.grey[400]),
          textAlign: TextAlign.center,
        ),
      );
    }

    return ElevatedButton(
      onPressed: () => _recomputeGeocoding(trip),
      child: const Text(
        'Geocoding',
        textAlign: TextAlign.center,
      ),
    );
  }

  String _getStatusLabel(TripStatus status) {
    switch (status) {
      case TripStatus.created:
        return 'Created';
      case TripStatus.inProgress:
        return 'In Progress';
      case TripStatus.paused:
        return 'Paused';
      case TripStatus.finished:
        return 'Finished';
      case TripStatus.resting:
        return 'Resting';
    }
  }
}
