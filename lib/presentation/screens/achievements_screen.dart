import 'package:wanderer_frontend/presentation/helpers/adaptive_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/providers/app_providers.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/data/models/achievement_models.dart';
import 'package:wanderer_frontend/data/services/achievement_service.dart';
import 'package:wanderer_frontend/data/services/auth_service.dart';
import 'package:wanderer_frontend/presentation/helpers/dialog_helper.dart';
import 'package:wanderer_frontend/presentation/helpers/auth_navigation_helper.dart';
import 'package:wanderer_frontend/presentation/helpers/page_transitions.dart';
import 'package:wanderer_frontend/presentation/widgets/achievements/achievement_dialog.dart';
import 'package:wanderer_frontend/presentation/widgets/achievements/web_achievements_layout.dart';
import 'package:wanderer_frontend/presentation/widgets/android/android_ui.dart';
import 'package:wanderer_frontend/presentation/widgets/common/wanderer_sheet.dart';
import 'package:wanderer_frontend/presentation/widgets/common/wanderer_app_bar.dart';
import 'package:wanderer_frontend/presentation/widgets/common/web_page_header.dart';
import 'package:wanderer_frontend/presentation/widgets/common/app_sidebar.dart';
import 'auth_screen.dart';
import 'create_trip_screen.dart';
import 'settings_screen.dart';
import 'package:wanderer_frontend/presentation/widgets/common/wanderer_scaffold.dart';
import 'package:wanderer_frontend/presentation/screens/initial_screen.dart';

/// Screen displaying all achievements and user's unlocked achievements
/// "100 km", "45 days", "10 updates"… for an achievement's threshold.
String achievementThresholdLabel(AppLocalizations l10n, Achievement a) {
  final type = a.type.toJson();
  final v = a.thresholdValue;
  if (type.startsWith('DISTANCE_')) return l10n.achievementKm(v.toDouble());
  if (type.startsWith('DURATION_')) return l10n.achievementDays(v);
  if (type.startsWith('UPDATES_')) return l10n.achievementUpdatesCount(v);
  if (type.startsWith('FOLLOWERS_')) return l10n.achievementFollowers(v);
  if (type.startsWith('FRIENDS_')) return l10n.achievementFriends(v);
  return '$v';
}

class AchievementsScreen extends ConsumerStatefulWidget {
  const AchievementsScreen({super.key});

  @override
  ConsumerState<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends ConsumerState<AchievementsScreen> {
  late final AchievementService _achievementService;
  late final AuthService _authService;

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
    _achievementService = ref.read(achievementServiceProvider);
    _authService = ref.read(authServiceProvider);
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
      PageTransitions.fade(const AuthScreen()),
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
      PageTransitions.slideFromBottom(const SettingsScreen()),
    );
  }

  Future<void> _handleLogout() async {
    final confirm = await DialogHelper.showLogoutConfirmation(context);

    if (confirm) {
      await _authService.logout();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          PageTransitions.fade(const InitialScreen()),
          (route) => false,
        );
      }
    }
  }

  /// Distinct achievements unlocked. [_myAchievements] holds one entry per
  /// unlock, and per-trip achievements are unlocked once per trip.
  int get _unlockedCount => _allAchievements.where(_isUnlocked).length;

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

  /// Fixed display order for achievement categories, regardless of API order
  static const List<String> _categoryOrder = [
    'Getting Started',
    'Distance',
    'Updates',
    'Duration',
    'Social',
    'Other',
  ];

  /// Group achievements by category, ordered per [_categoryOrder]
  Map<String, List<Achievement>> _groupByCategory() {
    final groups = <String, List<Achievement>>{};
    for (final achievement in _allAchievements) {
      final category = achievement.type.category;
      groups.putIfAbsent(category, () => []);
      groups[category]!.add(achievement);
    }
    // AchievementType is declared in display order (sub-group, then magnitude),
    // e.g. Followers before Friends within Social, ascending threshold within each.
    for (final list in groups.values) {
      list.sort((a, b) => a.type.index.compareTo(b.type.index));
    }
    final ordered = <String, List<Achievement>>{};
    for (final category in _categoryOrder) {
      if (groups.containsKey(category)) {
        ordered[category] = groups[category]!;
      }
    }
    for (final entry in groups.entries) {
      ordered.putIfAbsent(entry.key, () => entry.value);
    }
    return ordered;
  }

  String _localizeCategory(BuildContext context, String category) {
    final l10n = context.l10n;
    switch (category) {
      case 'Getting Started':
        return l10n.categoryGettingStarted;
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

  String _formatThreshold(BuildContext context, Achievement achievement) =>
      achievementThresholdLabel(context.l10n, achievement);

  @override
  Widget build(BuildContext context) {
    if (!AdaptiveLayout.usesDesktopLayout(context)) return _buildAndroid();
    return WandererScaffold(
      hideAppBarWithSidebar: true,
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
      body: _buildWebBody(),
    );
  }

  /// Web redesign: page header, summary card and one section per category.
  Widget _buildWebBody() {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    final wide = MediaQuery.sizeOf(context).width >= 720;
    final groups = _groupByCategory();
    Achievement? nextUp;
    for (final list in groups.values) {
      nextUp ??= list.where((a) => !_isUnlocked(a)).firstOrNull;
    }

    final Widget content;
    if (_isLoading) {
      content = const Padding(
        padding: EdgeInsets.all(48),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (_error != null) {
      content = Column(children: [
        Icon(Icons.error_outline, size: 48, color: c.textMuted),
        const SizedBox(height: 12),
        Text(_error!,
            textAlign: TextAlign.center, style: TextStyle(color: c.textMuted)),
        const SizedBox(height: 16),
        OutlinedButton(onPressed: _loadData, child: Text(l10n.retry)),
      ]);
    } else if (_allAchievements.isEmpty) {
      content = Padding(
        padding: const EdgeInsets.all(48),
        child: Center(
          child: Text(l10n.noAchievementsYet,
              style: TextStyle(fontSize: 15, color: c.textMuted)),
        ),
      );
    } else {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_isLoggedIn) ...[
            AchievementsSummaryCard(
              unlocked: _unlockedCount,
              total: _allAchievements.length,
              nextUp: nextUp,
              onStartTrip: () => Navigator.push(
                context,
                PageTransitions.slideUp(const CreateTripScreen()),
              ),
            ),
            const SizedBox(height: 28),
          ],
          for (final entry in groups.entries) ...[
            AchievementCategorySection(
              label: _localizeCategory(context, entry.key),
              color: _webCategoryColor(c, entry.key),
              achievements: entry.value,
              isUnlocked: _isUnlocked,
              hintFor: (a) {
                final ua = _getUnlockedAchievement(a);
                return ua != null
                    ? _formatValue(context, a, ua.valueAchieved)
                    : _formatThreshold(context, a);
              },
              onTap: (a) =>
                  _showAchievementDetail(a, _getUnlockedAchievement(a)),
              showCount: _isLoggedIn,
            ),
            const SizedBox(height: 28),
          ],
        ],
      );
    }

    return Container(
      color: c.ground,
      child: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: wide
              ? const EdgeInsets.fromLTRB(40, 28, 40, 40)
              : const EdgeInsets.all(16),
          children: [
            WebPageHeader(
              title: l10n.achievements,
              userId: _userId,
              isLoggedIn: _isLoggedIn,
            ),
            const SizedBox(height: 28),
            content,
          ],
        ),
      ),
    );
  }

  Color _webCategoryColor(WandererColors c, String category) {
    switch (category) {
      case 'Getting Started':
        return c.forestFg;
      case 'Distance':
        return c.skyFg;
      case 'Updates':
        return c.accentText;
      case 'Duration':
        return c.goldFg;
      default:
        return c.neutralFg;
    }
  }

  /// Android category tint (bg, fg) from the canvas.
  (Color, Color) _androidCategoryColors(WandererColors c, String category) {
    switch (category) {
      case 'Getting Started':
        return (c.forestBg, c.forestFg);
      case 'Distance':
        return (c.skyBg, c.skyFg);
      case 'Updates':
        return (c.trailSoftBg, c.accentText);
      case 'Duration':
        return (c.goldBg, c.goldFg);
      case 'Social':
        return (c.restingBg, c.restingFg);
      default:
        return (c.neutralBg, c.neutralFg);
    }
  }

  /// Android (canvas "AndroidAchievements"): progress card with the next
  /// goal, then a 3-column grid per category tinted in its colour.
  Widget _buildAndroid() {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    final groups = _groupByCategory();
    Achievement? nextUp;
    for (final list in groups.values) {
      nextUp ??= list.where((a) => !_isUnlocked(a)).firstOrNull;
    }
    final total = _allAchievements.length;
    final unlocked = _unlockedCount;

    final Widget body;
    if (_isLoading && _allAchievements.isEmpty) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null || _allAchievements.isEmpty) {
      body = Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.emoji_events_outlined, size: 48, color: c.caption),
          const SizedBox(height: 12),
          Text(_error ?? l10n.noAchievementsYet,
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textMuted)),
          if (_error != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _loadData, child: Text(l10n.retry)),
          ],
        ]),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            if (_isLoggedIn) ...[
              Container(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                decoration: WandererTheme.cardDecoration(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(l10n.achievementsCountOf(unlocked, total),
                            style: WandererTheme.display(24, color: c.text)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text.rich(
                            nextUp == null
                                ? TextSpan(text: l10n.achievementsAllUnlocked)
                                : TextSpan(children: [
                                    TextSpan(
                                        text: '${l10n.achievementsNextUp} '),
                                    TextSpan(
                                      text: _formatThreshold(context, nextUp),
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: c.text),
                                    ),
                                  ]),
                            textAlign: TextAlign.end,
                            maxLines: 2,
                            style: TextStyle(fontSize: 13, color: c.textMuted),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: total > 0 ? unlocked / total : 0,
                        minHeight: 10,
                        backgroundColor: c.lineSoft,
                        valueColor:
                            const AlwaysStoppedAnimation(WandererTheme.trail),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
            for (final entry in groups.entries) ...[
              _androidSection(c, entry.key, entry.value),
              const SizedBox(height: 20),
            ],
          ],
        ),
      );
    }
    return Scaffold(
      backgroundColor: c.ground,
      appBar: AndroidTopBar(title: l10n.achievements),
      body: body,
    );
  }

  Widget _androidSection(
      WandererColors c, String category, List<Achievement> achievements) {
    final (bg, fg) = _androidCategoryColors(c, category);
    final done = achievements.where(_isUnlocked).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(children: [
            Expanded(
              child: Text(_localizeCategory(context, category),
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: c.text)),
            ),
            if (_isLoggedIn)
              Text('$done / ${achievements.length}',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: c.textMuted)),
          ]),
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.95,
          children: [
            for (final a in achievements) _androidTile(c, a, bg, fg),
          ],
        ),
      ],
    );
  }

  Widget _androidTile(WandererColors c, Achievement a, Color bg, Color fg) {
    final ua = _getUnlockedAchievement(a);
    final unlocked = ua != null;
    return Material(
      color: unlocked ? bg : c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: unlocked ? fg.withAlpha(64) : c.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showAchievementDetail(a, ua),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 12, 6, 8),
          child: Column(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: unlocked ? c.surface : c.ground,
                  shape: BoxShape.circle,
                ),
                child: Icon(unlocked ? Icons.emoji_events : Icons.lock_outline,
                    size: 20, color: unlocked ? fg : c.caption),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Text(
                  context.l10n.achievementNameFor(a.type.toJson()),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: unlocked ? fg : c.textMuted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Android detail sheet for one achievement.
  void _showAndroidDetail(Achievement achievement, UserAchievement? ua) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    final (bg, fg) = _androidCategoryColors(c, achievement.type.category);
    showWandererSheet(
      context,
      builder: (context) => Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
                color: ua != null ? bg : c.raised, shape: BoxShape.circle),
            child: Icon(ua != null ? Icons.emoji_events : Icons.lock_outline,
                size: 32, color: ua != null ? fg : c.caption),
          ),
          const SizedBox(height: 16),
          Text(l10n.achievementNameFor(achievement.type.toJson()),
              textAlign: TextAlign.center,
              style: WandererTheme.display(22, color: c.text)),
          const SizedBox(height: 8),
          Text(l10n.achievementDescriptionFor(achievement.type.toJson()),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: c.textMuted)),
          const SizedBox(height: 12),
          Text(
            ua != null
                ? '${l10n.achievedValue(_formatValue(context, achievement, ua.valueAchieved))} · '
                    '${l10n.unlockedOn(_formatDate(ua.unlockedAt))}'
                : l10n.goalValue(_formatThreshold(context, achievement)),
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600, color: c.text),
          ),
        ],
      ),
    );
  }

  void _showAchievementDetail(
    Achievement achievement,
    UserAchievement? userAchievement,
  ) {
    if (AdaptiveLayout.usesDesktopLayout(context)) {
      showAchievementDialog(context, achievement,
          unlocked: userAchievement, shareUsername: _username);
      return;
    }
    _showAndroidDetail(achievement, userAchievement);
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }
}
