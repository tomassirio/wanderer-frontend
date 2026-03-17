import 'package:flutter/material.dart' hide Visibility;
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/data/services/trip_plan_service.dart';
import 'package:wanderer_frontend/data/services/trip_service.dart';
import 'package:wanderer_frontend/data/repositories/home_repository.dart';
import 'package:wanderer_frontend/presentation/helpers/dialog_helper.dart';
import 'package:wanderer_frontend/presentation/helpers/ui_helpers.dart';
import 'package:wanderer_frontend/presentation/widgets/common/wanderer_app_bar.dart';
import 'package:wanderer_frontend/presentation/widgets/common/app_sidebar.dart';
import 'package:wanderer_frontend/presentation/widgets/trip_plans/trip_from_plan_dialog.dart';
import 'package:wanderer_frontend/presentation/widgets/trip_plans/trip_plans_content.dart';
import 'auth_screen.dart';
import 'create_trip_plan_screen.dart';
import 'home_screen.dart';
import 'settings_screen.dart';
import 'trip_detail_screen.dart';
import 'trip_plan_detail_screen.dart';

/// Trip Plans screen showing list of planned trips
class TripPlansScreen extends StatefulWidget {
  const TripPlansScreen({super.key});

  @override
  State<TripPlansScreen> createState() => _TripPlansScreenState();
}

class _TripPlansScreenState extends State<TripPlansScreen> {
  final TripPlanService _tripPlanService = TripPlanService();
  final HomeRepository _homeRepository = HomeRepository();
  late final TripService _tripService;
  List<TripPlan> _tripPlans = [];
  List<TripPlan> _filteredPlans = [];
  bool _isLoading = false;
  String? _error;
  String? _userId;
  String? _username;
  String? _displayName;
  String? _avatarUrl;
  bool _isLoggedIn = false;
  bool _isAdmin = false;
  final int _selectedSidebarIndex = 1; // Trip Plans is index 1

  @override
  void initState() {
    super.initState();
    _tripService = TripService();
    _loadUserInfo();
    _loadTripPlans();
  }

  @override
  void dispose() {
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

  Future<void> _loadTripPlans() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Get user's trip plans
      final plans = await _tripPlanService.getUserTripPlans();
      setState(() {
        _tripPlans = plans;
        _filteredPlans = plans;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
    final confirm = await DialogHelper.showLogoutConfirmation(context);

    if (confirm) {
      await _homeRepository.logout();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      }
    }
  }

  void _handleSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
  }

  Future<void> _navigateToAuth() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AuthScreen()),
    );

    if (result == true || mounted) {
      await _loadUserInfo();
      await _loadTripPlans();
    }
  }

  Future<void> _handleTripPlanTap(TripPlan plan) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TripPlanDetailScreen(tripPlan: plan),
      ),
    );

    // Always reload trip plans when returning to reflect any modifications or deletions
    if (mounted) {
      await _loadTripPlans();
    }
  }

  Future<void> _handleCreatePlan() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreateTripPlanScreen()),
    );

    // Always reload trip plans when returning to ensure new plans are shown
    if (mounted) {
      await _loadTripPlans();
    }
  }

  Future<void> _handleCreateTripFromPlan(TripPlan plan) async {
    final request = await showDialog<TripFromPlanRequest>(
      context: context,
      builder: (context) =>
          TripFromPlanDialog(planName: plan.name, planType: plan.planType),
    );

    if (request == null || !mounted) return;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final tripId = await _tripService.createTripFromPlan(plan.id, request);

      // Fetch the created trip to get full details
      final trip = await _tripService.getTripById(tripId);

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        UiHelpers.showSuccessMessage(
          context,
          'Trip created successfully from plan!',
        );
        // Navigate to trip detail screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TripDetailScreen(trip: trip),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        UiHelpers.showErrorMessage(context, 'Error creating trip: $e');
      }
    }
  }

  Future<void> _handleDeletePlan(TripPlan plan) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Trip Plan'),
        content: Text(
          'Are you sure you want to delete "${plan.name}"? This action cannot be undone.',
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

    if (confirm != true || !mounted) return;

    try {
      await _tripPlanService.deleteTripPlan(plan.id);
      if (mounted) {
        UiHelpers.showSuccessMessage(context, 'Trip plan deleted');
        await _loadTripPlans();
      }
    } catch (e) {
      if (mounted) {
        UiHelpers.showErrorMessage(context, 'Error deleting trip plan: $e');
      }
    }
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
        onProfile: () {}, // Not used in this screen
        onSettings: _handleSettings,
        onLogout: _logout,
      ),
      drawer: AppSidebar(
        username: _username,
        userId: _userId,
        displayName: _displayName,
        avatarUrl: _avatarUrl,
        selectedIndex: _selectedSidebarIndex,
        onLogout: _logout,
        onSettings: _handleSettings,
        isAdmin: _isAdmin,
      ),
      body: TripPlansContent(
        isLoading: _isLoading,
        error: _error,
        tripPlans: _filteredPlans,
        isLoggedIn: _isLoggedIn,
        onRefresh: _loadTripPlans,
        onTripPlanTap: _handleTripPlanTap,
        onCreateTripFromPlan: _handleCreateTripFromPlan,
        onDeletePlan: _handleDeletePlan,
        onLoginPressed: _navigateToAuth,
        onCreatePressed: _handleCreatePlan,
      ),
      floatingActionButton: _isLoggedIn && !_isLoading && _tripPlans.isNotEmpty
          ? FloatingActionButton(
              onPressed: _handleCreatePlan,
              backgroundColor: Theme.of(context).primaryColor,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }
}
