import 'package:flutter/material.dart' hide Visibility;
import 'package:wanderer_frontend/core/constants/enums.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/data/services/admin_service.dart';
import 'package:wanderer_frontend/data/services/trip_service.dart';
import 'package:wanderer_frontend/data/repositories/home_repository.dart';
import 'package:wanderer_frontend/presentation/helpers/auth_navigation_helper.dart';
import 'package:wanderer_frontend/presentation/helpers/ui_helpers.dart';
import 'package:wanderer_frontend/presentation/helpers/page_transitions.dart';
import 'package:wanderer_frontend/presentation/screens/home_screen.dart';
import 'package:wanderer_frontend/presentation/screens/settings_screen.dart';
import 'package:wanderer_frontend/presentation/screens/trip_detail_screen.dart';
import 'package:wanderer_frontend/presentation/widgets/common/wanderer_app_bar.dart';
import 'package:wanderer_frontend/presentation/widgets/common/app_sidebar.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';

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
      final page =
          await _adminService.getAllTrips(page: nextPage, size: _tripsPageSize);

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
    final l10n = context.l10n;
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
              title: Text(l10n.promoteTripTitle),
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
                      decoration: InputDecoration(
                        labelText: l10n.donationLink,
                        hintText: 'https://...',
                        border: const OutlineInputBorder(),
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
                            children: [
                              Text(
                                l10n.preAnnounce,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: WandererTheme.textPrimary,
                                ),
                              ),
                              Text(
                                l10n.showCountdown,
                                style: const TextStyle(
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
                          // Pick date first
                          final pickedDate = await showDatePicker(
                            context: context,
                            initialDate: countdownStartDate ??
                                DateTime.now().add(
                                  const Duration(days: 1),
                                ),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365 * 5),
                            ),
                            helpText: 'Select Countdown Start Date',
                          );

                          if (pickedDate != null) {
                            // Pick time
                            final pickedTime = await showTimePicker(
                              context: context,
                              initialTime: countdownStartDate != null
                                  ? TimeOfDay.fromDateTime(countdownStartDate!)
                                  : const TimeOfDay(hour: 0, minute: 0),
                              helpText: 'Select Start Time (UTC)',
                            );

                            if (pickedTime != null) {
                              // Combine date and time in UTC
                              final combined = DateTime.utc(
                                pickedDate.year,
                                pickedDate.month,
                                pickedDate.day,
                                pickedTime.hour,
                                pickedTime.minute,
                              );
                              setDialogState(
                                  () => countdownStartDate = combined);
                            }
                          }
                        },
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text(
                          countdownStartDate == null
                              ? 'Pick Start Date & Time *'
                              : _formatDateTimeWithTimezone(
                                  countdownStartDate!),
                        ),
                      ),
                      if (countdownStartDate != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Local: ${_formatLocalTime(countdownStartDate!)}',
                            style: const TextStyle(
                              color: WandererTheme.textSecondary,
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      if (countdownStartDate == null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            l10n.startDateRequired,
                            style: const TextStyle(
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
                  child: Text(l10n.cancel),
                ),
                ElevatedButton(
                  onPressed: isPreAnnounced && countdownStartDate == null
                      ? null
                      : () => Navigator.pop(context, true),
                  child: Text(l10n.promote),
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
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.unpromoteTripTitle),
        content: Text(l10n.unpromoteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: Text(l10n.unpromote),
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
          PageTransitions.slideFromRight(TripDetailScreen(trip: trip)),
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
        PageTransitions.fade(const HomeScreen()),
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
    final l10n = context.l10n;
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
              child: Text(l10n.retry),
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
    final l10n = context.l10n;
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
                    l10n.currentlyPromotedTrips,
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
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    l10n.noPromotedTrips,
                    style: const TextStyle(color: Colors.grey),
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
    final l10n = context.l10n;
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
              tooltip: l10n.unpromote,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromotableTripsSection(bool isMobile) {
    final l10n = context.l10n;
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
                    l10n.promotableTrips,
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
              l10n.publicTripsNote,
              style: TextStyle(
                color: Colors.grey,
                fontSize: isMobile ? 12 : 14,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: l10n.searchTrips,
                hintText: l10n.searchTripsByNameOrUser,
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),
            if (_filteredTrips.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    l10n.noPromotableTripsFound,
                    style: const TextStyle(color: Colors.grey),
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
                          label: Text(
                            l10n.loadMoreTrips,
                            style: const TextStyle(
                                color: WandererTheme.primaryOrange),
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
    final l10n = context.l10n;
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
                  child: Text(l10n.unpromote),
                )
              : ElevatedButton(
                  onPressed: () => _promoteTrip(trip),
                  child: Text(l10n.promote),
                ),
        ),
      ],
    );
  }

  Widget _buildDesktopTripItem(Trip trip, bool isPromoted) {
    final l10n = context.l10n;
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
                  child: Text(
                    l10n.unpromote,
                    textAlign: TextAlign.center,
                  ),
                )
              : ElevatedButton(
                  onPressed: () => _promoteTrip(trip),
                  child: Text(
                    l10n.promote,
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

  String _formatDateTimeWithTimezone(DateTime dateTime) {
    // Format: "Apr 3, 2026 00:00 UTC"
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
      'Dec'
    ];
    final month = months[dateTime.month - 1];
    final day = dateTime.day;
    final year = dateTime.year;
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');

    return '$month $day, $year $hour:$minute UTC';
  }

  String _formatLocalTime(DateTime utcDateTime) {
    // Convert UTC to local time and format
    final localTime = utcDateTime.toLocal();
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
      'Dec'
    ];
    final month = months[localTime.month - 1];
    final day = localTime.day;
    final year = localTime.year;
    final hour = localTime.hour.toString().padLeft(2, '0');
    final minute = localTime.minute.toString().padLeft(2, '0');

    // Get timezone offset
    final offset = localTime.timeZoneOffset;
    final offsetHours = offset.inHours;
    final offsetMinutes = (offset.inMinutes % 60).abs();
    final offsetSign = offsetHours >= 0 ? '+' : '-';
    final offsetStr =
        '$offsetSign${offsetHours.abs().toString().padLeft(2, '0')}:${offsetMinutes.toString().padLeft(2, '0')}';

    return '$month $day, $year $hour:$minute (UTC$offsetStr)';
  }
}
