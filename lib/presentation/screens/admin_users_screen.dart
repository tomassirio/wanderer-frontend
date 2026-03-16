import 'package:flutter/material.dart';
import 'package:wanderer_frontend/data/models/responses/page_response.dart';
import 'package:wanderer_frontend/data/models/user_models.dart';
import 'package:wanderer_frontend/data/services/admin_service.dart';
import 'package:wanderer_frontend/data/repositories/home_repository.dart';
import 'package:wanderer_frontend/presentation/helpers/auth_navigation_helper.dart';
import 'package:wanderer_frontend/presentation/helpers/ui_helpers.dart';
import 'package:wanderer_frontend/presentation/screens/home_screen.dart';
import 'package:wanderer_frontend/presentation/screens/settings_screen.dart';
import 'package:wanderer_frontend/presentation/widgets/common/wanderer_app_bar.dart';
import 'package:wanderer_frontend/presentation/widgets/common/app_sidebar.dart';

/// Admin User Management screen for viewing all users with pagination
class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final AdminService _adminService = AdminService();
  final HomeRepository _homeRepository = HomeRepository();
  final TextEditingController _searchController = TextEditingController();

  List<UserProfile> _users = [];
  List<UserProfile> _filteredUsers = [];
  bool _isLoading = false;
  String? _error;
  String? _userId;
  String? _username;
  String? _displayName;
  String? _avatarUrl;
  bool _isLoggedIn = false;
  bool _isAdmin = false;
  final int _selectedSidebarIndex = 6; // Admin users index

  // Pagination state
  int _currentPage = 0;
  int _totalPages = 0;
  int _totalElements = 0;
  final int _pageSize = 20;

  // Sorting state
  String _sortField = 'username';
  String _sortDirection = 'asc';

  // Tracks which users have ADMIN role (userId -> isAdmin)
  final Map<String, bool> _userAdminStatus = {};

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _loadUsers();
    _searchController.addListener(_filterUsers);
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

  Future<void> _loadUsers({int page = 0}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final PageResponse<UserProfile> pageResponse =
          await _adminService.getAllUsers(
        page: page,
        size: _pageSize,
        sort: _sortField,
        direction: _sortDirection,
      );

      setState(() {
        _users = pageResponse.content;
        _filteredUsers = pageResponse.content;
        _currentPage = pageResponse.number;
        _totalPages = pageResponse.totalPages;
        _totalElements = pageResponse.totalElements;
        _isLoading = false;
      });

      // Load admin status for each user
      await _loadUserRoles(pageResponse.content);

      // Re-apply search filter if active
      if (_searchController.text.isNotEmpty) {
        _filterUsers();
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _filterUsers() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredUsers = _users;
      } else {
        _filteredUsers = _users.where((user) {
          return user.username.toLowerCase().contains(query) ||
              user.email.toLowerCase().contains(query) ||
              (user.displayName?.toLowerCase().contains(query) ?? false);
        }).toList();
      }
    });
  }

  void _changeSortField(String field) {
    setState(() {
      if (_sortField == field) {
        // Toggle direction if same field
        _sortDirection = _sortDirection == 'asc' ? 'desc' : 'asc';
      } else {
        _sortField = field;
        _sortDirection = 'asc';
      }
    });
    _loadUsers();
  }

  void _goToPage(int page) {
    if (page >= 0 && page < _totalPages) {
      _searchController.clear();
      _loadUsers(page: page);
    }
  }

  void _navigateToUserProfile(String userId) {
    AuthNavigationHelper.navigateToUserProfile(context, userId);
  }

  Future<void> _loadUserRoles(List<UserProfile> users) async {
    for (final user in users) {
      try {
        final roles = await _adminService.getUserRoles(user.id);
        if (mounted) {
          setState(() {
            _userAdminStatus[user.id] =
                roles.any((r) => r.toUpperCase() == 'ADMIN');
          });
        }
      } catch (e) {
        // Silently fail for individual role checks
        debugPrint('Failed to load roles for ${user.username}: $e');
      }
    }
  }

  Future<void> _promoteUser(UserProfile user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Promote to Admin'),
        content: Text(
            'Are you sure you want to promote "${user.username}" to admin?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Promote'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _adminService.promoteUserToAdmin(user.id);
        if (mounted) {
          UiHelpers.showSuccessMessage(
              context, '${user.username} promoted to admin!');
          await _loadUsers(page: _currentPage);
        }
      } catch (e) {
        if (mounted) {
          UiHelpers.showErrorMessage(context, 'Failed to promote user: $e');
        }
      }
    }
  }

  Future<void> _demoteUser(UserProfile user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Demote from Admin'),
        content: Text(
            'Are you sure you want to remove admin role from "${user.username}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: const Text('Demote'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _adminService.demoteUserFromAdmin(user.id);
        if (mounted) {
          UiHelpers.showSuccessMessage(
              context, '${user.username} demoted from admin!');
          await _loadUsers(page: _currentPage);
        }
      } catch (e) {
        if (mounted) {
          UiHelpers.showErrorMessage(context, 'Failed to demote user: $e');
        }
      }
    }
  }

  Future<void> _deleteUser(UserProfile user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Are you sure you want to permanently delete "${user.username}"?'),
            const SizedBox(height: 8),
            const Text(
              'This action cannot be undone. All user data will be removed.',
              style: TextStyle(color: Colors.red, fontSize: 13),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _adminService.deleteUser(user.id);
        if (mounted) {
          UiHelpers.showSuccessMessage(
              context, '${user.username} deleted successfully!');
          await _loadUsers(page: _currentPage);
        }
      } catch (e) {
        if (mounted) {
          UiHelpers.showErrorMessage(context, 'Failed to delete user: $e');
        }
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
              onPressed: () => _loadUsers(),
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
          onRefresh: () => _loadUsers(page: _currentPage),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(horizontalPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(isMobile),
                const SizedBox(height: 16),
                _buildSortBar(isMobile),
                const SizedBox(height: 16),
                _buildUsersTable(isMobile),
                const SizedBox(height: 16),
                _buildPaginationControls(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(bool isMobile) {
    final cardPadding = isMobile ? 12.0 : 16.0;
    final titleFontSize = isMobile ? 18.0 : 20.0;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(cardPadding),
        child: Row(
          children: [
            Icon(Icons.people, size: isMobile ? 24 : 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'User Management',
                    style: TextStyle(
                      fontSize: titleFontSize,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$_totalElements total users',
                    style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.6),
                      fontSize: isMobile ? 12 : 14,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => _loadUsers(page: _currentPage),
              tooltip: 'Refresh',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSortBar(bool isMobile) {
    final cardPadding = isMobile ? 12.0 : 16.0;

    if (isMobile) {
      // Mobile layout: Stack vertically
      return Card(
        child: Padding(
          padding: EdgeInsets.all(cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sort chips
              Row(
                children: [
                  const Text(
                    'Sort by: ',
                    style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                  ),
                  const SizedBox(width: 8),
                  _buildSortChip('Username', 'username'),
                  const SizedBox(width: 8),
                  _buildSortChip('Created', 'createdAt'),
                ],
              ),
              const SizedBox(height: 12),
              // Search filter
              TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Filter results...',
                  prefixIcon: Icon(Icons.filter_list, size: 20),
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                textCapitalization: TextCapitalization.none,
              ),
            ],
          ),
        ),
      );
    }

    // Desktop layout: Horizontal row
    return Card(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: cardPadding, vertical: 8),
        child: Row(
          children: [
            const Text(
              'Sort by: ',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 8),
            _buildSortChip('Username', 'username'),
            const SizedBox(width: 8),
            _buildSortChip('Created', 'createdAt'),
            const Spacer(),
            // Local search filter
            SizedBox(
              width: 200,
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Filter results...',
                  prefixIcon: Icon(Icons.filter_list, size: 20),
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                textCapitalization: TextCapitalization.none,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSortChip(String label, String field) {
    final isActive = _sortField == field;
    return ActionChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (isActive) ...[
            const SizedBox(width: 4),
            Icon(
              _sortDirection == 'asc'
                  ? Icons.arrow_upward
                  : Icons.arrow_downward,
              size: 16,
            ),
          ],
        ],
      ),
      backgroundColor:
          isActive ? Theme.of(context).colorScheme.primaryContainer : null,
      onPressed: () => _changeSortField(field),
    );
  }

  Widget _buildUsersTable(bool isMobile) {
    if (_filteredUsers.isEmpty) {
      return Card(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              'No users found',
              style: TextStyle(
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
            ),
          ),
        ),
      );
    }

    // On mobile, each user is its own card, so no wrapper needed
    if (isMobile) {
      return ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _filteredUsers.length,
        itemBuilder: (context, index) {
          final user = _filteredUsers[index];
          return _buildUserTile(user, isMobile);
        },
      );
    }

    // Desktop keeps the card wrapper
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _filteredUsers.length,
          separatorBuilder: (context, index) => const Divider(),
          itemBuilder: (context, index) {
            final user = _filteredUsers[index];
            return _buildUserTile(user, isMobile);
          },
        ),
      ),
    );
  }

  Widget _buildUserTile(UserProfile user, bool isMobile) {
    final isUserAdmin = _userAdminStatus[user.id] ?? false;
    final isSelf = user.id == _userId;

    if (isMobile) {
      return _buildMobileUserTile(user, isUserAdmin, isSelf);
    }
    return _buildDesktopUserTile(user, isUserAdmin, isSelf);
  }

  Widget _buildMobileUserTile(UserProfile user, bool isUserAdmin, bool isSelf) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      child: InkWell(
        onTap: () => _navigateToUserProfile(user.id),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with avatar and primary info
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor:
                        Theme.of(context).colorScheme.primaryContainer,
                    backgroundImage: user.avatarUrl != null
                        ? NetworkImage(user.avatarUrl!)
                        : null,
                    child: user.avatarUrl == null
                        ? Text(
                            user.username.isNotEmpty
                                ? user.username[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Username with admin badge
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                user.displayName ?? user.username,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isUserAdmin) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                  border:
                                      Border.all(color: Colors.amber.shade700),
                                ),
                                child: Text(
                                  'ADMIN',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (user.displayName != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            '@${user.username}',
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.6),
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Email
              Row(
                children: [
                  Icon(Icons.email_outlined,
                      size: 14,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.6)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      user.email,
                      style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.7)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Stats row in a subtle container
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildCompactStat(Icons.map, '${user.tripsCount}', 'Trips'),
                    Container(
                        width: 1,
                        height: 24,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.12)),
                    _buildCompactStat(
                        Icons.people, '${user.followersCount}', 'Followers'),
                    Container(
                        width: 1,
                        height: 24,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.12)),
                    _buildCompactStat(
                        Icons.handshake, '${user.friendsCount}', 'Friends'),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Join date
              Row(
                children: [
                  Icon(Icons.calendar_today,
                      size: 12,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.5)),
                  const SizedBox(width: 4),
                  Text(
                    'Joined ${_formatDate(user.createdAt)}',
                    style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.5)),
                  ),
                ],
              ),

              // Action buttons
              if (!isSelf) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: isUserAdmin
                          ? OutlinedButton.icon(
                              onPressed: () => _demoteUser(user),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.orange.shade700,
                                side: BorderSide(color: Colors.orange.shade400),
                              ),
                              icon: const Icon(Icons.arrow_downward, size: 16),
                              label: const Text(
                                'Unpromote',
                                style: TextStyle(fontSize: 12),
                              ),
                            )
                          : ElevatedButton.icon(
                              onPressed: () => _promoteUser(user),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    Theme.of(context).colorScheme.primary,
                              ),
                              icon: const Icon(Icons.arrow_upward, size: 16),
                              label: const Text(
                                'Promote',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: OutlinedButton.icon(
                        onPressed: () => _deleteUser(user),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red.shade700,
                          side: BorderSide(color: Colors.red.shade400),
                        ),
                        icon: const Icon(Icons.delete_outline, size: 16),
                        label: const Text(
                          'Delete',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.open_in_new, size: 20),
                      onPressed: () => _navigateToUserProfile(user.id),
                      tooltip: 'View Profile',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ] else ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _navigateToUserProfile(user.id),
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: const Text(
                        'View Profile',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactStat(IconData icon, String value, String label) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: onSurface.withOpacity(0.7)),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: onSurface.withOpacity(0.8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: onSurface.withOpacity(0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopUserTile(
      UserProfile user, bool isUserAdmin, bool isSelf) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        backgroundImage:
            user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
        child: user.avatarUrl == null
            ? Text(
                user.username.isNotEmpty ? user.username[0].toUpperCase() : '?',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              )
            : null,
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              user.displayName ?? user.username,
              style: const TextStyle(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (user.displayName != null) ...[
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                '@${user.username}',
                style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.6),
                    fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          if (isUserAdmin) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.amber.shade400),
              ),
              child: Text(
                'ADMIN',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade700),
              ),
            ),
          ],
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(user.email),
          const SizedBox(height: 4),
          Row(
            children: [
              _buildStatBadge(Icons.map, '${user.tripsCount}'),
              const SizedBox(width: 12),
              _buildStatBadge(Icons.people, '${user.followersCount}'),
              const SizedBox(width: 12),
              _buildStatBadge(Icons.handshake, '${user.friendsCount}'),
              const SizedBox(width: 12),
              Text(
                'Joined ${_formatDate(user.createdAt)}',
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.5)),
              ),
            ],
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Promote/Unpromote button
          if (!isSelf)
            isUserAdmin
                ? SizedBox(
                    width: 110,
                    child: ElevatedButton.icon(
                      onPressed: () => _demoteUser(user),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade400,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      icon: const Icon(Icons.arrow_downward, size: 16),
                      label: const Text('Unpromote',
                          style: TextStyle(fontSize: 12)),
                    ),
                  )
                : SizedBox(
                    width: 110,
                    child: ElevatedButton.icon(
                      onPressed: () => _promoteUser(user),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      icon: const Icon(Icons.arrow_upward, size: 16),
                      label:
                          const Text('Promote', style: TextStyle(fontSize: 12)),
                    ),
                  ),
          const SizedBox(width: 8),
          // Delete button (cannot delete self)
          if (!isSelf)
            IconButton(
              icon: const Icon(Icons.delete_forever, color: Colors.red),
              onPressed: () => _deleteUser(user),
              tooltip: 'Delete User',
            ),
          // View profile button
          IconButton(
            icon: const Icon(Icons.open_in_new),
            onPressed: () => _navigateToUserProfile(user.id),
            tooltip: 'View Profile',
          ),
        ],
      ),
      onTap: () => _navigateToUserProfile(user.id),
    );
  }

  Widget _buildStatBadge(IconData icon, String value) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: onSurface.withOpacity(0.6)),
        const SizedBox(width: 2),
        Text(
          value,
          style: TextStyle(fontSize: 12, color: onSurface.withOpacity(0.6)),
        ),
      ],
    );
  }

  Widget _buildPaginationControls() {
    if (_totalPages <= 1) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.first_page),
              onPressed: _currentPage > 0 ? () => _goToPage(0) : null,
              tooltip: 'First page',
            ),
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed:
                  _currentPage > 0 ? () => _goToPage(_currentPage - 1) : null,
              tooltip: 'Previous page',
            ),
            const SizedBox(width: 16),
            Text(
              'Page ${_currentPage + 1} of $_totalPages',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 16),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: _currentPage < _totalPages - 1
                  ? () => _goToPage(_currentPage + 1)
                  : null,
              tooltip: 'Next page',
            ),
            IconButton(
              icon: const Icon(Icons.last_page),
              onPressed: _currentPage < _totalPages - 1
                  ? () => _goToPage(_totalPages - 1)
                  : null,
              tooltip: 'Last page',
            ),
          ],
        ),
      ),
    );
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
      'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
