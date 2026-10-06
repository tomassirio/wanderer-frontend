import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' hide Visibility;
import 'package:wanderer_frontend/presentation/helpers/adaptive_layout.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wanderer_frontend/core/constants/enums.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/data/repositories/create_trip_repository.dart';
import 'package:wanderer_frontend/data/services/trip_plan_service.dart';
import 'package:wanderer_frontend/data/services/trip_service.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/presentation/helpers/ui_helpers.dart';
import 'package:wanderer_frontend/presentation/helpers/page_transitions.dart';
import 'package:wanderer_frontend/presentation/screens/trip_detail_screen.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/presentation/helpers/tutorial_helper.dart';
import 'package:wanderer_frontend/presentation/widgets/trip_plans/trip_from_plan_dialog.dart';
import 'package:wanderer_frontend/core/providers/app_providers.dart';
import 'package:wanderer_frontend/data/repositories/home_repository.dart';
import 'package:wanderer_frontend/presentation/screens/initial_screen.dart';
import 'package:wanderer_frontend/presentation/screens/settings_screen.dart';
import 'package:wanderer_frontend/presentation/screens/trip_plans_screen.dart';
import 'package:wanderer_frontend/presentation/helpers/dialog_helper.dart';
import 'package:wanderer_frontend/presentation/widgets/common/app_sidebar.dart';
import 'package:wanderer_frontend/presentation/widgets/common/wanderer_scaffold.dart';
import 'package:wanderer_frontend/presentation/widgets/android/android_ui.dart';
import 'package:wanderer_frontend/presentation/widgets/android/new_trip_form.dart';
import 'package:wanderer_frontend/presentation/widgets/common/toasts.dart';
import 'package:wanderer_frontend/presentation/widgets/create_trip/web_create_trip_layout.dart';

/// Screen for creating a new trip with a clean, modern design
class CreateTripScreen extends ConsumerStatefulWidget {
  const CreateTripScreen({super.key});

  @override
  ConsumerState<CreateTripScreen> createState() => _CreateTripScreenState();
}

class _CreateTripScreenState extends ConsumerState<CreateTripScreen> {
  late final CreateTripRepository _repository;
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  Visibility _selectedVisibility = Visibility.public;
  TripModality _selectedModality = TripModality.simple;
  bool _isLoading = false;
  TripPlan? _selectedTripPlan;
  List<TripPlan> _tripPlans = [];
  bool _createFromPlan = false;
  // Saved on the trip everywhere; the app applies it once tracking starts.
  bool _automaticUpdates = true;
  final _intervalController = TextEditingController(text: '15');
  static const int _minIntervalMinutes = 15;
  late final TripPlanService _tripPlanService;
  late final TripService _tripService;

  // First-time create trip tutorial (coach marks)
  final GlobalKey _tutorialTitleKey = GlobalKey();
  final GlobalKey _tutorialTripTypeKey = GlobalKey();
  final GlobalKey _tutorialVisibilityKey = GlobalKey();
  final GlobalKey _tutorialAutoUpdatesKey = GlobalKey();
  final GlobalKey _tutorialCreateButtonKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _repository = ref.read(createTripRepositoryProvider);
    _tripPlanService = ref.read(tripPlanServiceProvider);
    _tripService = ref.read(tripServiceProvider);
    _loadTripPlans();
    if (kIsWeb) _loadUserInfo();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final route = ModalRoute.of(context);
      final routeAnimation = route?.animation;
      if (routeAnimation != null &&
          routeAnimation.status != AnimationStatus.completed) {
        late final AnimationStatusListener listener;
        listener = (status) {
          if (status == AnimationStatus.completed) {
            routeAnimation.removeStatusListener(listener);
            _startCreateTripTutorial();
          }
        };
        routeAnimation.addStatusListener(listener);
      } else {
        _startCreateTripTutorial();
      }
    });
  }

  /// Starts the first-time coach-mark tutorial. Only called once the
  /// screen's own push transition has finished, so tutorial targets are
  /// measured against their final settled positions instead of a
  /// transient mid-animation layout (see [PageTransitions.slideFromBottom]).
  void _startCreateTripTutorial() {
    if (!mounted) return;
    final l10n = context.l10n;
    showFirstTimeTutorial(
      context: context,
      tutorialKey: TutorialKeys.createTrip,
      steps: [
        TutorialStep(
          key: _tutorialTitleKey,
          title: l10n.tutorialTripNameTitle,
          description: l10n.tutorialTripNameDescription,
          shape: ShapeLightFocus.RRect,
          radius: 12,
        ),
        TutorialStep(
          key: _tutorialTripTypeKey,
          title: l10n.tutorialTripTypeTitle,
          description: l10n.tutorialTripTypeDescription,
          shape: ShapeLightFocus.RRect,
          radius: 12,
        ),
        TutorialStep(
          key: _tutorialVisibilityKey,
          title: l10n.tutorialVisibilityTitle,
          description: l10n.tutorialVisibilityDescription,
          shape: ShapeLightFocus.RRect,
          radius: 12,
        ),
        TutorialStep(
          key: _tutorialAutoUpdatesKey,
          title: l10n.tutorialAutoUpdatesTitle,
          description: l10n.tutorialAutoUpdatesDescription,
          shape: ShapeLightFocus.RRect,
          radius: 12,
          align: ContentAlign.top,
        ),
        TutorialStep(
          key: _tutorialCreateButtonKey,
          title: l10n.tutorialCreateButtonTitle,
          description: l10n.tutorialCreateButtonDescription,
          shape: ShapeLightFocus.RRect,
          radius: 14,
          align: ContentAlign.top,
        ),
      ],
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _intervalController.dispose();
    super.dispose();
  }

  Future<void> _loadTripPlans() async {
    try {
      final plans = await _tripPlanService.getUserTripPlans();
      setState(() {
        _tripPlans = plans;
      });
    } catch (e) {
      debugPrint('Failed to load trip plans: $e');
    }
  }

  Future<void> _createTrip() async {
    if (_createFromPlan && _selectedTripPlan != null) {
      await _createTripFromPlan();
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final tripId = await _repository.createTrip(
        name: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        visibility: _selectedVisibility,
        tripModality: _selectedModality,
        automaticUpdates: _automaticUpdates ? true : null,
        updateRefresh: _automaticUpdates
            ? (int.tryParse(_intervalController.text) ?? _minIntervalMinutes) *
                60
            : null,
      );

      final trip = await _repository.getTripById(tripId);

      // Apply creation settings that the backend may not have propagated yet
      // into the query model (e.g. automaticUpdates / updateRefresh).
      final effectiveTrip = _automaticUpdates
          ? trip.copyWith(
              automaticUpdates: true,
              updateRefresh: (int.tryParse(_intervalController.text) ??
                      _minIntervalMinutes) *
                  60,
            )
          : trip;

      if (mounted) {
        _showSuccess(context.l10n.msgTripCreated);
        Navigator.pushReplacement(
          context,
          PageTransitions.slideFromRight(TripDetailScreen(trip: effectiveTrip)),
        );
      }
    } catch (e) {
      if (mounted) {
        _showError(context.l10n.msgTripCreateError(e));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _createTripFromPlan() async {
    if (_selectedTripPlan == null) return;

    final request = await TripFromPlanDialog.show(context,
        planName: _selectedTripPlan!.name,
        planType: _selectedTripPlan!.planType);

    if (request == null || !mounted) return;

    setState(() => _isLoading = true);

    try {
      final tripId = await _tripService.createTripFromPlan(
        _selectedTripPlan!.id,
        request,
      );
      final trip = await _tripService.getTripById(tripId);

      if (mounted) {
        _showSuccess(AdaptiveLayout.usesDesktopLayout(context)
            ? 'Trip created from plan successfully!'
            : context.l10n.msgTripCreatedFromPlan);
        Navigator.pushReplacement(
          context,
          PageTransitions.slideFromRight(TripDetailScreen(trip: trip)),
        );
      }
    } catch (e) {
      if (mounted) {
        _showError(context.l10n.msgTripCreateError(e));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Web only: sidebar user details.
  String? _userId;
  String? _username;
  String? _displayName;
  String? _avatarUrl;
  bool _isLoggedIn = true;
  bool _isAdmin = false;

  HomeRepository get _homeRepository => ref.read(homeRepositoryProvider);

  Future<void> _loadUserInfo() async {
    try {
      final repo = _homeRepository;
      final isLoggedIn = await repo.isLoggedIn();
      final username = await repo.getCurrentUsername();
      final userId = await repo.getCurrentUserId();
      final isAdmin = await repo.isAdmin();
      final displayName = await repo.getCurrentDisplayName();
      final avatarUrl = await repo.getCurrentAvatarUrl();
      if (!mounted) return;
      setState(() {
        _isLoggedIn = isLoggedIn;
        _username = username;
        _userId = userId;
        _isAdmin = isAdmin;
        _displayName = displayName;
        _avatarUrl = avatarUrl;
      });
    } catch (e) {
      debugPrint('Failed to load user info: $e');
    }
  }

  Future<void> _logout() async {
    if (!await DialogHelper.showLogoutConfirmation(context)) return;
    await _homeRepository.logout();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        PageTransitions.fade(const InitialScreen()),
        (route) => false,
      );
    }
  }

  int get _intervalMinutes =>
      int.tryParse(_intervalController.text) ?? _minIntervalMinutes;

  Widget _buildWeb(BuildContext context) {
    final l10n = context.l10n;
    return WandererScaffold(
      hideAppBarWithSidebar: true,
      backgroundColor: WandererTheme.of(context).ground,
      appBar: AppBar(
        title: Text(l10n.newTripTitle),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      drawer: WandererScaffold.hasPersistentSidebar(context)
          ? AppSidebar(
              username: _username,
              userId: _userId,
              displayName: _displayName,
              avatarUrl: _avatarUrl,
              selectedIndex: AppSidebar.myTripsIndex,
              onLogout: _logout,
              onSettings: () => Navigator.push(
                context,
                PageTransitions.slideFromBottom(const SettingsScreen()),
              ),
              isAdmin: _isAdmin,
            )
          : null,
      body: WebCreateTripLayout(
        formKey: _formKey,
        titleController: _titleController,
        descriptionController: _descriptionController,
        modality: _selectedModality,
        onModalityChanged: (m) => setState(() => _selectedModality = m),
        visibility: _selectedVisibility,
        onVisibilityChanged: (v) => setState(() => _selectedVisibility = v),
        automaticUpdates: _automaticUpdates,
        onAutomaticUpdatesChanged: (v) => setState(() => _automaticUpdates = v),
        intervalMinutes: _intervalMinutes,
        onIntervalChanged: (m) =>
            setState(() => _intervalController.text = '$m'),
        isLoading: _isLoading,
        isLoggedIn: _isLoggedIn,
        userId: _userId,
        onCreate: _createTrip,
        onCancel: () => Navigator.maybePop(context),
        onFromPlan: () => Navigator.pushReplacement(
          context,
          PageTransitions.fade(const TripPlansScreen()),
        ),
        titleKey: _tutorialTitleKey,
        tripTypeKey: _tutorialTripTypeKey,
        visibilityKey: _tutorialVisibilityKey,
        autoUpdatesKey: _tutorialAutoUpdatesKey,
        createButtonKey: _tutorialCreateButtonKey,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (AdaptiveLayout.usesDesktopLayout(context)) return _buildWeb(context);
    final c = WandererTheme.of(context);
    return Scaffold(
      backgroundColor: c.ground,
      appBar: AndroidTopBar(title: context.l10n.newTripBreadcrumb, close: true),
      body: NewTripForm(
        formKey: _formKey,
        titleController: _titleController,
        descriptionController: _descriptionController,
        modality: _selectedModality,
        onModalityChanged: (m) => setState(() => _selectedModality = m),
        visibility: _selectedVisibility,
        onVisibilityChanged: (v) => setState(() => _selectedVisibility = v),
        automaticUpdates: _automaticUpdates,
        onAutomaticUpdatesChanged: (v) => setState(() => _automaticUpdates = v),
        intervalMinutes: _intervalMinutes,
        onIntervalChanged: (m) =>
            setState(() => _intervalController.text = '$m'),
        plans: _tripPlans,
        fromPlan: _createFromPlan,
        onFromPlanChanged: (v) => setState(() => _createFromPlan = v),
        selectedPlan: _selectedTripPlan,
        onPlanSelected: (p) => setState(() => _selectedTripPlan = p),
        isLoading: _isLoading,
        onCreate: _createTrip,
        titleKey: _tutorialTitleKey,
        tripTypeKey: _tutorialTripTypeKey,
        visibilityKey: _tutorialVisibilityKey,
        autoUpdatesKey: _tutorialAutoUpdatesKey,
        createButtonKey: _tutorialCreateButtonKey,
      ),
    );
  }

  /// Web keeps its floating notifications; Android uses the canvas toasts.
  void _showSuccess(String message) {
    if (AdaptiveLayout.usesDesktopLayout(context)) {
      return UiHelpers.showSuccessMessage(context, message);
    }
    Toasts.show(ToastData(kind: ToastKind.success, title: message));
  }

  void _showError(String message) {
    if (AdaptiveLayout.usesDesktopLayout(context)) {
      return UiHelpers.showErrorMessage(context, message);
    }
    Toasts.show(ToastData(kind: ToastKind.error, title: message));
  }
}
