import 'package:flutter/material.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/data/models/achievement_models.dart';
import 'package:wanderer_frontend/data/services/achievement_service.dart';
import 'package:wanderer_frontend/data/services/auth_service.dart';
import 'package:wanderer_frontend/presentation/helpers/dialog_helper.dart';
import 'package:wanderer_frontend/presentation/helpers/auth_navigation_helper.dart';
import 'package:wanderer_frontend/presentation/widgets/common/wanderer_app_bar.dart';
import 'package:wanderer_frontend/presentation/widgets/common/app_sidebar.dart';
import 'auth_screen.dart';
import 'home_screen.dart';
import 'settings_screen.dart';

/// Screen displaying all achievements and user's unlocked achievements
class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  final AchievementService _achievementService = AchievementService();
  final AuthService _authService = AuthService();

  List<Achievement> _allAchievements = [];
  List<UserAchievement> _myAchievements = [];
  bool _isLoading = false;
  String? _error;
  bool _isLoggedIn = false;
  bool _isAdmin = false;
  String? _username;
  String? _userId;
  String? _displayName;
  String? _avatarUrl;
  final int _selectedSidebarIndex = 3; // Achievements is index 3

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final isAdmin = await _authService.isAdmin();
      final userId = await _authService.getCurrentUserId();
      final username = await _authService.getCurrentUsername();
      final isLoggedIn = userId != null && userId.isNotEmpty;

      if (isLoggedIn) {
        await _authService.refreshUserDetails();
      }

      final displayName = await _authService.getCurrentDisplayName();
      final avatarUrl = await _authService.getCurrentAvatarUrl();

      setState(() {
        _isAdmin = isAdmin;
        _userId = userId;
        _username = username;
        _displayName = displayName;
        _avatarUrl = avatarUrl;
        _isLoggedIn = isLoggedIn;
      });

      // Load all available achievements
      final allAchievements = await _achievementService.getAllAchievements();

      setState(() {
        _allAchievements = allAchievements;
      });

      // Load user's achievements if logged in
      if (isLoggedIn) {
        try {
          final myAchievements = await _achievementService.getMyAchievements();
          setState(() {
            _myAchievements = myAchievements;
          });
        } catch (e) {
          // Silently fail for user achievements - still show all available
        }
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _navigateToAuth() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AuthScreen()),
    );

    if (result == true && mounted) {
      await _loadData();
    }
  }

  void _navigateToProfile() {
    AuthNavigationHelper.navigateToOwnProfile(context);
  }

  void _handleSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
  }

  Future<void> _handleLogout() async {
    final confirm = await DialogHelper.showLogoutConfirmation(context);

    if (confirm) {
      await AuthService().logout();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      }
    }
  }

  /// Check if an achievement is unlocked by the current user
  bool _isUnlocked(Achievement achievement) {
    return _myAchievements.any((ua) => ua.achievement.id == achievement.id);
  }

  /// Get the UserAchievement for a given achievement, if unlocked
  UserAchievement? _getUnlockedAchievement(Achievement achievement) {
    try {
      return _myAchievements
          .firstWhere((ua) => ua.achievement.id == achievement.id);
    } catch (_) {
      return null;
    }
  }

  /// Group achievements by category
  Map<String, List<Achievement>> _groupByCategory() {
    final groups = <String, List<Achievement>>{};
    for (final achievement in _allAchievements) {
      final category = achievement.type.category;
      groups.putIfAbsent(category, () => []);
      groups[category]!.add(achievement);
    }
    return groups;
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Distance':
        return Icons.directions_walk;
      case 'Updates':
        return Icons.edit_note;
      case 'Duration':
        return Icons.timer;
      case 'Social':
        return Icons.people;
      default:
        return Icons.emoji_events;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Distance':
        return Colors.blue;
      case 'Updates':
        return Colors.green;
      case 'Duration':
        return Colors.orange;
      case 'Social':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _localizeCategory(BuildContext context, String category) {
    final l10n = context.l10n;
    switch (category) {
      case 'Distance':
        return l10n.categoryDistance;
      case 'Updates':
        return l10n.categoryUpdates;
      case 'Duration':
        return l10n.categoryDuration;
      case 'Social':
        return l10n.categorySocial;
      default:
        return l10n.categoryOther;
    }
  }

  String _formatValue(
      BuildContext context, Achievement achievement, double value) {
    final l10n = context.l10n;
    final type = achievement.type.toJson();
    final cappedValue = value > achievement.thresholdValue
        ? achievement.thresholdValue.toDouble()
        : value;
    if (type.startsWith('DISTANCE_')) {
      return l10n.achievementKm(cappedValue);
    }
    if (type.startsWith('DURATION_')) {
      return l10n.achievementDays(cappedValue.toInt());
    }
    if (type.startsWith('UPDATES_')) {
      return l10n.achievementUpdatesCount(cappedValue.toInt());
    }
    if (type.startsWith('FOLLOWERS_')) {
      return l10n.achievementFollowers(cappedValue.toInt());
    }
    if (type.startsWith('FRIENDS_')) {
      return l10n.achievementFriends(cappedValue.toInt());
    }
    return cappedValue.toInt().toString();
  }

  String _formatThreshold(BuildContext context, Achievement achievement) {
    final l10n = context.l10n;
    final type = achievement.type.toJson();
    if (type.startsWith('DISTANCE_')) {
      return l10n.achievementKm(achievement.thresholdValue.toDouble());
    }
    if (type.startsWith('DURATION_')) {
      return l10n.achievementDays(achievement.thresholdValue.toInt());
    }
    if (type.startsWith('UPDATES_')) {
      return l10n.achievementUpdatesCount(achievement.thresholdValue.toInt());
    }
    if (type.startsWith('FOLLOWERS_')) {
      return l10n.achievementFollowers(achievement.thresholdValue.toInt());
    }
    if (type.startsWith('FRIENDS_')) {
      return l10n.achievementFriends(achievement.thresholdValue.toInt());
    }
    return '${achievement.thresholdValue}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: WandererAppBar(
        isLoggedIn: _isLoggedIn,
        onLoginPressed: _navigateToAuth,
        username: _username,
        userId: _userId,
        displayName: _displayName,
        avatarUrl: _avatarUrl,
        onProfile: _navigateToProfile,
        onSettings: _handleSettings,
        onLogout: _handleLogout,
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
            Text(
              _error!,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadData,
              child: Text(l10n.retry),
            ),
          ],
        ),
      );
    }

    if (_allAchievements.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.emoji_events_outlined,
                size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              l10n.noAchievementsYet,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    final unlockedCount = _myAchievements.length;
    final totalCount = _allAchievements.length;
    final groups = _groupByCategory();

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // Summary header
          if (_isLoggedIn) _buildSummaryCard(unlockedCount, totalCount),
          if (_isLoggedIn) const SizedBox(height: 16),

          // Achievement categories as grids
          ...groups.entries.map((entry) => _buildCategorySection(
                entry.key,
                entry.value,
              )),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(int unlocked, int total) {
    final l10n = context.l10n;
    final progress = total > 0 ? unlocked / total : 0.0;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.emoji_events, color: Colors.amber, size: 28),
                const SizedBox(width: 12),
                Text(
                  l10n.achievementsProgress(unlocked, total),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySection(
    String category,
    List<Achievement> achievements,
  ) {
    final categoryColor = _getCategoryColor(category);
    final categoryIcon = _getCategoryIcon(category);
    final unlockedInCategory = achievements.where((a) => _isUnlocked(a)).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(categoryIcon, color: categoryColor, size: 24),
              const SizedBox(width: 8),
              Text(
                _localizeCategory(context, category),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: categoryColor,
                ),
              ),
              if (_isLoggedIn) ...[
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: categoryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$unlockedInCategory/${achievements.length}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: categoryColor,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        LayoutBuilder(builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 600;
          final crossAxisCount = isMobile ? 4 : 7;
          final aspectRatio = isMobile ? 0.75 : 0.85;
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
              childAspectRatio: aspectRatio,
            ),
            itemCount: achievements.length,
            itemBuilder: (context, index) =>
                _buildAchievementTile(context, achievements[index]),
          );
        }),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildAchievementTile(BuildContext context, Achievement achievement) {
    final unlocked = _isUnlocked(achievement);
    final userAchievement = _getUnlockedAchievement(achievement);
    final categoryColor = _getCategoryColor(achievement.type.category);
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => _showAchievementDetail(achievement, userAchievement),
      child: Container(
        decoration: BoxDecoration(
          color: unlocked
              ? categoryColor.withOpacity(0.1)
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                unlocked ? categoryColor : colorScheme.outline.withOpacity(0.5),
            width: unlocked ? 2 : 1,
          ),
        ),
        padding: const EdgeInsets.all(4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Trophy icon
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: unlocked
                    ? categoryColor
                    : colorScheme.outline.withOpacity(0.4),
                shape: BoxShape.circle,
              ),
              child: Icon(
                unlocked ? Icons.emoji_events : Icons.lock_outline,
                color: unlocked
                    ? Colors.white
                    : colorScheme.onSurface.withOpacity(0.4),
                size: 18,
              ),
            ),
            const SizedBox(height: 3),
            // Achievement name
            Flexible(
              child: Text(
                context.l10n.achievementNameFor(achievement.type.toJson()),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: unlocked
                      ? categoryColor
                      : colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ),
            const SizedBox(height: 1),
            // Threshold or achieved value
            Text(
              unlocked && userAchievement != null
                  ? _formatValue(context, achievement, userAchievement.valueAchieved)
                  : _formatThreshold(context, achievement),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 8,
                color: unlocked
                    ? categoryColor
                    : colorScheme.onSurface.withOpacity(0.45),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAchievementDetail(
    Achievement achievement,
    UserAchievement? userAchievement,
  ) {
    final unlocked = userAchievement != null;
    final categoryColor = _getCategoryColor(achievement.type.category);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final l10n = context.l10n;
        final colorScheme = Theme.of(context).colorScheme;
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: unlocked
                      ? categoryColor
                      : colorScheme.outline.withOpacity(0.4),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  unlocked ? Icons.emoji_events : Icons.lock_outline,
                  color: unlocked
                      ? Colors.white
                      : colorScheme.onSurface.withOpacity(0.4),
                  size: 36,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.achievementNameFor(achievement.type.toJson()),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: unlocked
                      ? categoryColor
                      : colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.achievementDescriptionFor(achievement.type.toJson()),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color:
                      unlocked ? null : colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
              const SizedBox(height: 12),
              if (userAchievement != null) ...[
                Text(
                  l10n.achievedValue(
                      _formatValue(context, achievement, userAchievement.valueAchieved)),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: categoryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.unlockedOn(_formatDate(userAchievement.unlockedAt)),
                  style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurface.withOpacity(0.6)),
                ),
              ] else ...[
                Text(
                  l10n.goalValue(_formatThreshold(context, achievement)),
                  style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.onSurface.withOpacity(0.5)),
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }
}
