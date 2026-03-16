import 'package:flutter/material.dart' hide Visibility;
import 'package:wanderer_frontend/core/constants/enums.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
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

/// Trip Promotion Management screen for admins
class TripPromotionScreen extends StatefulWidget {
  const TripPromotionScreen({super.key});

  @override
  State<TripPromotionScreen> createState() => _TripPromotionScreenState();
}

class _TripPromotionScreenState extends State<TripPromotionScreen> {
  final AdminService _adminService = AdminService();
  final HomeRepository _homeRepository = HomeRepository();
  final TripService _tripService = TripService();
  final TextEditingController _searchController = TextEditingController();

  List<Trip> _allTrips = [];
  List<PromotedTrip> _promotedTrips = [];
  List<Trip> _filteredTrips = [];
  bool _isLoading = false;
  bool _isLoadingMoreTrips = false;
  bool _hasMoreTrips = false;
  int _currentTripsPage = 0;
  static const int _tripsPageSize = 20;
  bool _isLoadingPromoted = false;
  String? _error;
  String? _userId;
  String? _username;
  String? _displayName;
  String? _avatarUrl;
  bool _isLoggedIn = false;
  bool _isAdmin = false;
  final int _selectedSidebarIndex = 5; // Admin panel index

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _loadTrips();
    _loadPromotedTrips();
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
      // Get all trips (admin only, first page)
      final page =
          await _adminService.getAllTrips(page: 0, size: _tripsPageSize);

      final promotableTrips = _filterPromotable(page.content);

      setState(() {
        _allTrips = promotableTrips;
        _filteredTrips = promotableTrips;
        _hasMoreTrips = !page.last;
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
      final page = await _adminService.getAllTrips(
          page: nextPage, size: _tripsPageSize);

      final more = _filterPromotable(page.content);

      setState(() {
        _allTrips = [..._allTrips, ...more];
        _currentTripsPage = nextPage;
        _hasMoreTrips = !page.last;
        _isLoadingMoreTrips = false;
        final query = _searchController.text.toLowerCase();
        _filteredTrips = query.isEmpty
            ? _allTrips
            : _allTrips.where((t) {
                return t.name.toLowerCase().contains(query) ||
                    t.username.toLowerCase().contains(query);
              }).toList();
      });
    } catch (e) {
      setState(() => _isLoadingMoreTrips = false);
      if (mounted) {
        UiHelpers.showErrorMessage(context, 'Error loading more trips: $e');
      }
    }
  }

  List<Trip> _filterPromotable(List<Trip> trips) {
    return trips.where((trip) {
      return trip.visibility == Visibility.public &&
          (trip.status == TripStatus.created ||
              trip.status == TripStatus.inProgress ||
              trip.status == TripStatus.paused);
    }).toList();
  }

  Future<void> _loadPromotedTrips() async {
    setState(() {
      _isLoadingPromoted = true;
    });

    try {
      final promoted = await _adminService.getPromotedTrips();
      setState(() {
        _promotedTrips = promoted;
        _isLoadingPromoted = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingPromoted = false;
      });
      if (mounted) {
        debugPrint('Failed to load promoted trips: $e');
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
              trip.username.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  Future<void> _promoteTrip(Trip trip) async {
    final donationLinkController = TextEditingController();
    bool isPreAnnounced = false;
    DateTime? countdownStartDate;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isMobile = MediaQuery.of(context).size.width < 600;

            return AlertDialog(
              title: const Text('Promote Trip'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Trip: ${trip.name}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'By: ${trip.username}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: donationLinkController,
                      decoration: const InputDecoration(
                        labelText: 'Donation Link (optional)',
                        hintText: 'https://...',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      maxLength: 500,
                      maxLines: isMobile ? 2 : 1,
                      keyboardType: TextInputType.url,
                      textCapitalization: TextCapitalization.none,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(
                          Icons.campaign,
                          size: 16,
                          color: WandererTheme.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Pre-Announce',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: WandererTheme.textPrimary,
                                ),
                              ),
                              Text(
                                'Show countdown before trip starts',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: WandererTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: isPreAnnounced,
                          onChanged: (value) {
                            setDialogState(() {
                              isPreAnnounced = value;
                              if (!isPreAnnounced) countdownStartDate = null;
                            });
                          },
                          activeColor: WandererTheme.primaryOrange,
                        ),
                      ],
                    ),
                    if (isPreAnnounced) ...[
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: countdownStartDate ??
                                DateTime.now().add(
                                  const Duration(days: 1),
                                ),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365 * 5),
                            ),
                            helpText: 'Select Trip Start Date',
                          );
                          if (picked != null) {
                            setDialogState(() => countdownStartDate = picked);
                          }
                        },
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text(
                          countdownStartDate == null
                              ? 'Pick Start Date *'
                              : '${countdownStartDate!.day}/${countdownStartDate!.month}/${countdownStartDate!.year}',
                        ),
                      ),
                      if (countdownStartDate == null)
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text(
                            'Start date is required for pre-announcements',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 11,
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isPreAnnounced && countdownStartDate == null
                      ? null
                      : () => Navigator.pop(context, true),
                  child: const Text('Promote'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true && mounted) {
      try {
        final donationLink = donationLinkController.text.trim();
        await _adminService.promoteTrip(
          trip.id,
          donationLink: donationLink.isEmpty ? null : donationLink,
          isPreAnnounced: isPreAnnounced,
          countdownStartDate: countdownStartDate,
        );

        if (mounted) {
          UiHelpers.showSuccessMessage(context, 'Trip promoted successfully!');
          await _loadPromotedTrips();
        }
      } catch (e) {
        if (mounted) {
          UiHelpers.showErrorMessage(context, 'Failed to promote trip: $e');
        }
      }
    }
  }

  Future<void> _unpromoteTrip(String tripId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unpromote Trip'),
        content: const Text('Are you sure you want to unpromote this trip?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Unpromote'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _adminService.unpromoteTrip(tripId);

        if (mounted) {
          UiHelpers.showSuccessMessage(
            context,
            'Trip unpromoted successfully!',
          );
          await _loadPromotedTrips();
        }
      } catch (e) {
        if (mounted) {
          UiHelpers.showErrorMessage(context, 'Failed to unpromote trip: $e');
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
        searchController: _searchController,
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
          onRefresh: () async {
            await _loadTrips();
            await _loadPromotedTrips();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(horizontalPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPromotedTripsSection(isMobile),
                const SizedBox(height: 24),
                _buildPromotableTripsSection(isMobile),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPromotedTripsSection(bool isMobile) {
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
                const Icon(Icons.star, color: Colors.amber),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Currently Promoted Trips',
                    style: TextStyle(
                      fontSize: titleFontSize,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoadingPromoted)
              const Center(child: CircularProgressIndicator())
            else if (_promotedTrips.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'No promoted trips',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _promotedTrips.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final promoted = _promotedTrips[index];
                  return _buildPromotedTripItem(promoted, isMobile);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromotedTripItem(PromotedTrip promoted, bool isMobile) {
    return InkWell(
      onTap: () => _navigateToTrip(promoted.tripId),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.star, color: Colors.amber, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    promoted.tripName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Owner: ${promoted.tripOwnerUsername}',
                    style: const TextStyle(fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Promoted by: ${promoted.promotedByUsername}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (promoted.donationLink != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Donation: ${promoted.donationLink}',
                      style: const TextStyle(fontSize: 12, color: Colors.blue),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.remove_circle, color: Colors.red),
              onPressed: () => _unpromoteTrip(promoted.tripId),
              tooltip: 'Unpromote',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromotableTripsSection(bool isMobile) {
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
                const Icon(Icons.public),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Promotable Trips',
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
              'Public trips that are created, in progress, or paused',
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
                hintText: 'Search by trip name or username',
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
                    'No promotable trips found',
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
                  final isPromoted = _promotedTrips
                      .any((promoted) => promoted.tripId == trip.id);
                  return _buildPromotableTripItem(trip, isPromoted, isMobile);
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
                          child: CircularProgressIndicator(
                            color: WandererTheme.primaryOrange,
                            strokeWidth: 2,
                          ),
                        )
                      : TextButton.icon(
                          onPressed: _loadMoreTrips,
                          icon: const Icon(
                            Icons.expand_more,
                            color: WandererTheme.primaryOrange,
                          ),
                          label: const Text(
                            'Load more trips',
                            style:
                                TextStyle(color: WandererTheme.primaryOrange),
                          ),
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromotableTripItem(Trip trip, bool isPromoted, bool isMobile) {
    return InkWell(
      onTap: () => _navigateToTrip(trip.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: isMobile
            ? _buildMobileTripItem(trip, isPromoted)
            : _buildDesktopTripItem(trip, isPromoted),
      ),
    );
  }

  Widget _buildMobileTripItem(Trip trip, bool isPromoted) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              _getStatusIcon(trip.status),
              color: _getStatusColor(trip.status),
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trip.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
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
                  Text(
                    'Status: ${_getStatusLabel(trip.status)}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: isPromoted
              ? ElevatedButton(
                  onPressed: () => _unpromoteTrip(trip.id),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade400,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Unpromote'),
                )
              : ElevatedButton(
                  onPressed: () => _promoteTrip(trip),
                  child: const Text('Promote'),
                ),
        ),
      ],
    );
  }

  Widget _buildDesktopTripItem(Trip trip, bool isPromoted) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          _getStatusIcon(trip.status),
          color: _getStatusColor(trip.status),
          size: 24,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                trip.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
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
              Text(
                'Status: ${_getStatusLabel(trip.status)}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 120,
          child: isPromoted
              ? ElevatedButton(
                  onPressed: () => _unpromoteTrip(trip.id),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade400,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text(
                    'Unpromote',
                    textAlign: TextAlign.center,
                  ),
                )
              : ElevatedButton(
                  onPressed: () => _promoteTrip(trip),
                  child: const Text(
                    'Promote',
                    textAlign: TextAlign.center,
                  ),
                ),
        ),
      ],
    );
  }

  IconData _getStatusIcon(TripStatus status) {
    switch (status) {
      case TripStatus.created:
        return Icons.fiber_new;
      case TripStatus.inProgress:
        return Icons.directions_run;
      case TripStatus.paused:
        return Icons.pause_circle;
      case TripStatus.finished:
        return Icons.check_circle;
      case TripStatus.resting:
        return Icons.nightlight_round;
    }
  }

  Color _getStatusColor(TripStatus status) {
    switch (status) {
      case TripStatus.created:
        return Colors.blue;
      case TripStatus.inProgress:
        return Colors.green;
      case TripStatus.paused:
        return Colors.orange;
      case TripStatus.finished:
        return Colors.grey;
      case TripStatus.resting:
        return WandererTheme.statusResting;
    }
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
