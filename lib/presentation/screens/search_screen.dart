import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/constants/api_endpoints.dart';
import '../../data/models/domain/search_result.dart';
import '../../data/services/search_service.dart';
import 'profile_screen.dart';

/// Search screen for finding users and trips
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final SearchService _searchService = SearchService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounceTimer;
  SearchResultsResponse? _results;
  bool _isLoading = false;
  bool _isLoadingMoreUsers = false;
  bool _isLoadingMoreTrips = false;
  String? _error;
  int _currentUserPage = 0;
  int _currentTripPage = 0;
  static const int _pageSize = 10;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();

    if (query.trim().isEmpty) {
      setState(() {
        _results = null;
        _error = null;
        _currentUserPage = 0;
        _currentTripPage = 0;
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _performSearch(query.trim());
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() {
      _isLoading = true;
      _error = null;
      _currentUserPage = 0;
      _currentTripPage = 0;
    });

    try {
      final results = await _searchService.search(
        query,
        userPage: 0,
        userSize: _pageSize,
        tripPage: 0,
        tripSize: _pageSize,
      );
      if (mounted) {
        setState(() {
          _results = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to search. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMoreUsers() async {
    if (_isLoadingMoreUsers || _results == null || _results!.users.last) return;

    setState(() {
      _isLoadingMoreUsers = true;
    });

    try {
      final nextPage = _currentUserPage + 1;
      final moreResults = await _searchService.search(
        _searchController.text.trim(),
        userPage: nextPage,
        userSize: _pageSize,
        tripPage: _currentTripPage,
        tripSize: _pageSize,
      );

      if (mounted) {
        setState(() {
          _currentUserPage = nextPage;
          _results = SearchResultsResponse(
            users: PageResponse(
              content: [..._results!.users.content, ...moreResults.users.content],
              totalElements: moreResults.users.totalElements,
              totalPages: moreResults.users.totalPages,
              number: moreResults.users.number,
              size: moreResults.users.size,
              first: _results!.users.first,
              last: moreResults.users.last,
              empty: moreResults.users.empty,
              numberOfElements: _results!.users.content.length + moreResults.users.content.length,
            ),
            trips: _results!.trips,
          );
          _isLoadingMoreUsers = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMoreUsers = false;
        });
      }
    }
  }

  Future<void> _loadMoreTrips() async {
    if (_isLoadingMoreTrips || _results == null || _results!.trips.last) return;

    setState(() {
      _isLoadingMoreTrips = true;
    });

    try {
      final nextPage = _currentTripPage + 1;
      final moreResults = await _searchService.search(
        _searchController.text.trim(),
        userPage: _currentUserPage,
        userSize: _pageSize,
        tripPage: nextPage,
        tripSize: _pageSize,
      );

      if (mounted) {
        setState(() {
          _currentTripPage = nextPage;
          _results = SearchResultsResponse(
            users: _results!.users,
            trips: PageResponse(
              content: [..._results!.trips.content, ...moreResults.trips.content],
              totalElements: moreResults.trips.totalElements,
              totalPages: moreResults.trips.totalPages,
              number: moreResults.trips.number,
              size: moreResults.trips.size,
              first: _results!.trips.first,
              last: moreResults.trips.last,
              empty: moreResults.trips.empty,
              numberOfElements: _results!.trips.content.length + moreResults.trips.content.length,
            ),
          );
          _isLoadingMoreTrips = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMoreTrips = false;
        });
      }
    }
  }

  void _navigateToUserProfile(String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ProfileScreen(userId: userId)),
    );
  }

  void _navigateToTripDetail(TripSummary tripSummary) {
    // For now, navigate to the trip detail by constructing minimal Trip object
    // The TripDetailScreen will fetch the full details
    Navigator.pushNamed(
      context,
      '/trip/${tripSummary.id}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
        backgroundColor: theme.colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search users and trips...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: isDarkMode
                    ? theme.colorScheme.surface
                    : Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: theme.colorScheme.primary,
                    width: 2,
                  ),
                ),
              ),
            ),
          ),

          // Results
          Expanded(
            child: _buildResultsBody(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsBody(ThemeData theme) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(
                color: theme.colorScheme.error,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    if (_results == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 64,
              color: theme.colorScheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Search for users and trips',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    if (_results!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: theme.colorScheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No results found for "${_searchController.text}"',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        // Users Section
        if (_results!.users.content.isNotEmpty) ...[
          _buildSectionHeader(
            'USERS',
            _results!.users.totalElements,
            theme,
          ),
          const SizedBox(height: 8),
          ..._results!.users.content.map((user) => _buildUserCard(user, theme)),
          
          // Load more users button
          if (_results!.users.hasNext)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: _isLoadingMoreUsers
                  ? const Center(child: CircularProgressIndicator())
                  : OutlinedButton(
                      onPressed: _loadMoreUsers,
                      child: Text(
                        'Load more users (${_results!.users.content.length} of ${_results!.users.totalElements})',
                      ),
                    ),
            ),
          const SizedBox(height: 16),
        ],

        // Divider
        if (_results!.users.content.isNotEmpty && _results!.trips.content.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Divider(
              thickness: 1,
              color: theme.colorScheme.onSurface.withOpacity(0.1),
            ),
          ),

        // Trips Section
        if (_results!.trips.content.isNotEmpty) ...[
          _buildSectionHeader(
            'TRIPS',
            _results!.trips.totalElements,
            theme,
          ),
          const SizedBox(height: 8),
          ..._results!.trips.content.map((trip) => _buildTripCard(trip, theme)),
          
          // Load more trips button
          if (_results!.trips.hasNext)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: _isLoadingMoreTrips
                  ? const Center(child: CircularProgressIndicator())
                  : OutlinedButton(
                      onPressed: _loadMoreTrips,
                      child: Text(
                        'Load more trips (${_results!.trips.content.length} of ${_results!.trips.totalElements})',
                      ),
                    ),
            ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title, int count, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        '$title ($count)',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.onSurface.withOpacity(0.6),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildUserCard(UserSearchResult user, ThemeData theme) {
    final isDarkMode = theme.brightness == Brightness.dark;
    final resolvedAvatarUrl = ApiEndpoints.resolveThumbnailUrl(user.avatarUrl);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: isDarkMode ? 2 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _navigateToUserProfile(user.id),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 24,
                backgroundImage: resolvedAvatarUrl.isNotEmpty
                    ? NetworkImage(resolvedAvatarUrl)
                    : null,
                child: resolvedAvatarUrl.isEmpty
                    ? const Icon(Icons.person)
                    : null,
              ),
              const SizedBox(width: 12),

              // User info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.username,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (user.displayName.isNotEmpty)
                      Text(
                        user.displayName,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                          fontSize: 14,
                        ),
                      ),
                  ],
                ),
              ),

              // Arrow icon
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurface.withOpacity(0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTripCard(TripSummary trip, ThemeData theme) {
    final isDarkMode = theme.brightness == Brightness.dark;
    final resolvedThumbnailUrl =
        ApiEndpoints.resolveThumbnailUrl(trip.thumbnailUrl);
    final statusText = _formatStatus(trip.status);
    final statusColor = _getStatusColor(trip.status, theme);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: isDarkMode ? 2 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _navigateToTripDetail(trip),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 60,
                  height: 60,
                  color: theme.colorScheme.surfaceVariant,
                  child: resolvedThumbnailUrl.isNotEmpty
                      ? Image.network(
                          resolvedThumbnailUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.map),
                        )
                      : const Icon(Icons.map),
                ),
              ),
              const SizedBox(width: 12),

              // Trip info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Trip name with promoted badge
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            trip.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (trip.isPromoted) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.star,
                                  size: 12,
                                  color: Colors.amber,
                                ),
                                SizedBox(width: 2),
                                Text(
                                  'Featured',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Username
                    Text(
                      'by @${trip.username}',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Status and day
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                          ),
                        ),
                        if (trip.currentDay != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            'Day ${trip.currentDay}',
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  theme.colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Arrow icon
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurface.withOpacity(0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatStatus(String status) {
    switch (status) {
      case 'IN_PROGRESS':
        return 'In Progress';
      case 'PAUSED':
        return 'Paused';
      case 'RESTING':
        return 'Resting';
      case 'FINISHED':
        return 'Finished';
      case 'CREATED':
        return 'Planning';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status, ThemeData theme) {
    switch (status) {
      case 'IN_PROGRESS':
        return Colors.green;
      case 'PAUSED':
        return Colors.orange;
      case 'RESTING':
        return Colors.blue;
      case 'FINISHED':
        return Colors.grey;
      case 'CREATED':
        return Colors.purple;
      default:
        return theme.colorScheme.primary;
    }
  }
}
