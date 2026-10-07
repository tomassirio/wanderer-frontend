import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/providers/app_providers.dart';
import 'package:wanderer_frontend/core/services/notification_service.dart';
import 'package:wanderer_frontend/core/services/push_notification_manager.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/presentation/helpers/page_transitions.dart';
import 'package:wanderer_frontend/presentation/helpers/live_toast_bridge.dart';
import 'package:wanderer_frontend/presentation/screens/android/android_explore_tab.dart';
import 'package:wanderer_frontend/presentation/screens/android/android_home_tab.dart';
import 'package:wanderer_frontend/presentation/screens/android/android_trips_tab.dart';
import 'package:wanderer_frontend/presentation/screens/android/android_you_tab.dart';
import 'package:geolocator/geolocator.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/presentation/helpers/location_permission_disclosure.dart';
import 'package:wanderer_frontend/presentation/screens/android/ready_trip_screen.dart';
import 'package:wanderer_frontend/presentation/screens/trip_detail_screen.dart';
import 'package:wanderer_frontend/presentation/widgets/android/plan_editor_layout.dart';
import 'package:wanderer_frontend/presentation/widgets/common/wanderer_sheet.dart';
import 'package:wanderer_frontend/presentation/screens/initial_screen.dart';

/// Android tabs, in bottom-nav order.
enum AndroidTab { home, trips, explore, you }

/// Logged-in mobile home (native and web): bottom nav and the
/// + create button on Home and Trips. Tab roots live here; everything else
/// is pushed full screen on top and Back returns to the same tab.
///
/// Owns the app-wide live connection (WebSocket user topic and Android push
/// notifications) that used to hang off the old mobile HomeScreen.
class AndroidShell extends ConsumerStatefulWidget {
  final AndroidTab initialTab;
  const AndroidShell({super.key, this.initialTab = AndroidTab.home});

  static AndroidShellState? _current;

  /// Ticks each time the Home tab is shown again.
  static final homeShown = ValueNotifier<int>(0);

  /// The signed-in user's ongoing trip (live, paused or resting), if any.
  /// Turns the Wander button into "Live".
  static final ongoingTrip = ValueNotifier<Trip?>(null);

  /// Tests stand in for the (network-heavy) live trip screen.
  @visibleForTesting
  static Widget Function(Trip trip)? debugLiveScreen;

  /// Refreshes [ongoingTrip]; returns it (null when none or offline).
  static Future<Trip?> refreshOngoingTrip(WidgetRef ref) async {
    try {
      final page = await ref
          .read(homeRepositoryProvider)
          .getMyTrips(size: 50)
          .timeout(const Duration(seconds: 4));
      ongoingTrip.value = page.content
          .where((t) => TripsFilter.live.matches(t.status))
          .firstOrNull;
    } catch (e) {
      debugPrint('Ongoing trip check failed: $e');
    }
    return ongoingTrip.value;
  }

  /// Wander (middle of the bottom bar): opens the ongoing trip if there is
  /// one (Start would only fail, one trip at a time), else the Ready to
  /// start screen. With location off it first asks to turn it on.
  static Future<void> wander(BuildContext context, WidgetRef ref) async {
    final navigator = Navigator.of(context);
    final live = await refreshOngoingTrip(ref);
    if (!context.mounted) return;
    if (live != null) {
      await navigator.push(PageTransitions.slideFromRight(
          debugLiveScreen?.call(live) ?? TripDetailScreen(trip: live)));
    } else {
      if (!kIsWeb && !await _locationReady(context)) return;
      await navigator
          .push(PageTransitions.slideFromBottom(const ReadyTripScreen()));
    }
    refreshOngoingTrip(ref);
  }

  /// Location on and usable, or turned on from the "Turn on location to
  /// wander" sheet. Never-asked permission is left to the ready screen.
  static Future<bool> _locationReady(BuildContext context) async {
    try {
      if (await Geolocator.isLocationServiceEnabled() &&
          await Geolocator.checkPermission() !=
              LocationPermission.deniedForever) {
        return true;
      }
    } catch (_) {
      return true; // Unknown: the ready screen explains if needed.
    }
    if (!context.mounted) return false;
    final turnOn = await showWanderLocationSheet(context);
    if (turnOn != true || !context.mounted) return false;
    final access = await ensureLocationAccess(context);
    if (access == LocationAccess.serviceOff) {
      await Geolocator.openLocationSettings();
    }
    return true;
  }

  static Widget navigationBar(BuildContext context, AndroidTab selected) =>
      _BottomNav(
          tab: selected,
          onSelect: (tab) {
            if (!selectTab(context, tab)) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                    builder: (_) => InitialScreen(initialTab: tab)),
                (_) => false,
              );
            }
          });

  /// Switch tab from anywhere, including screens pushed over the shell:
  /// those are popped so the tab shows. Returns false when no shell is up
  /// (logged out, desktop web).
  static bool selectTab(BuildContext context, AndroidTab tab) {
    final shell = _current;
    if (shell == null || !shell.mounted) return false;
    Navigator.of(context).popUntil((route) => route.isFirst);
    shell.selectTab(tab);
    return true;
  }

  @override
  ConsumerState<AndroidShell> createState() => AndroidShellState();
}

class AndroidShellState extends ConsumerState<AndroidShell> {
  late AndroidTab _tab = widget.initialTab;

  void selectTab(AndroidTab tab) {
    // Home refreshes when you come back to it (friends, badges, trips may
    // have changed on other tabs).
    if (tab == AndroidTab.home && _tab != AndroidTab.home) {
      AndroidShell.homeShown.value++;
    }
    setState(() => _tab = tab);
    AndroidShell.refreshOngoingTrip(ref);
  }

  @override
  void initState() {
    super.initState();
    AndroidShell._current = this;
    // Notification taps and buttons need a signed-in session and navigator.
    NotificationService.onResponse = const NotificationActions().handlePush;
    _connect();
    AndroidShell.refreshOngoingTrip(ref);
  }

  Future<void> _connect() async {
    final userId = await ref.read(homeRepositoryProvider).getCurrentUserId();
    if (userId == null || !mounted) return;
    final ws = ref.read(websocketServiceProvider);
    PushNotificationManager().start(userId);
    await ws.connect();
    if (mounted) {
      ws.subscribeToUser(userId);
      if (kIsWeb) LiveToastBridge().start(userId);
    }
  }

  @override
  void dispose() {
    if (AndroidShell._current == this) {
      AndroidShell._current = null;
      NotificationService.onResponse = null;
    }
    PushNotificationManager().stop();
    if (kIsWeb) LiveToastBridge().stop();
    super.dispose();
  }

  /// Bumped after Wander so every tab reloads with the new trip or plan.
  int _generation = 0;

  Future<void> _wander() async {
    await AndroidShell.wander(context, ref);
    if (mounted) setState(() => _generation++);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _tab == AndroidTab.home,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) selectTab(AndroidTab.home);
      },
      child: Scaffold(
        body: IndexedStack(
          key: ValueKey(_generation),
          index: _tab.index,
          children: const [
            AndroidHomeTab(),
            AndroidTripsTab(),
            AndroidExploreTab(),
            AndroidYouTab(),
          ],
        ),
        bottomNavigationBar:
            _BottomNav(tab: _tab, onSelect: selectTab, onWander: _wander),
      ),
    );
  }
}

class _BottomNav extends ConsumerWidget {
  final AndroidTab tab;
  final ValueChanged<AndroidTab> onSelect;

  /// Null outside the shell: Wander then runs on its own.
  final VoidCallback? onWander;
  const _BottomNav({required this.tab, required this.onSelect, this.onWander});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    TextStyle label(bool on) => TextStyle(
          fontSize: 12,
          fontWeight: on ? FontWeight.w700 : FontWeight.w600,
          color: on ? c.accentText : c.textMuted,
        );
    // Five slots: Home, Trips, Wander, Explore, You (canvas ANav).
    int slot(AndroidTab t) => t.index < 2 ? t.index : t.index + 1;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.sidebar,
        border: Border(top: BorderSide(color: c.line)),
      ),
      child: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          indicatorColor: c.trailSoftBg,
          height: 72,
          labelTextStyle: WidgetStateProperty.resolveWith(
              (s) => label(s.contains(WidgetState.selected))),
          iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
              size: 22,
              color: s.contains(WidgetState.selected)
                  ? c.accentText
                  : c.textMuted)),
        ),
        child: NavigationBar(
          elevation: 0,
          selectedIndex: slot(tab),
          onDestinationSelected: (i) {
            if (i == 2) return;
            onSelect(AndroidTab.values[i < 2 ? i : i - 1]);
          },
          destinations: [
            NavigationDestination(
                icon: const Icon(Icons.home_outlined), label: l10n.home),
            NavigationDestination(
                icon: const Icon(Icons.map_outlined), label: l10n.trips),
            ValueListenableBuilder<Trip?>(
              valueListenable: AndroidShell.ongoingTrip,
              builder: (context, live, _) => WanderButton(
                live: live != null,
                onTap: onWander ?? () => AndroidShell.wander(context, ref),
              ),
            ),
            NavigationDestination(
                icon: const Icon(Icons.explore_outlined), label: l10n.explore),
            NavigationDestination(
                icon: const Icon(Icons.person_outline), label: l10n.you),
          ],
        ),
      ),
    );
  }
}

/// Wander (canvas AFab): orange pill "Wander" to start a trip, or a sky
/// pill "Live" with a dot that opens the ongoing trip.
class WanderButton extends StatelessWidget {
  final bool live;
  final VoidCallback onTap;
  const WanderButton({super.key, required this.live, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    final bg = live ? WandererTheme.sky : WandererTheme.trail;
    final fg = live ? c.skyFg : c.accentText;
    return Semantics(
      button: true,
      label: live ? l10n.wanderOpenLive : l10n.wanderStart,
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        key: const Key('wander_button'),
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 72, minHeight: 56),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(clipBehavior: Clip.none, children: [
                Container(
                  width: 64,
                  height: 32,
                  decoration: BoxDecoration(
                      color: bg, borderRadius: BorderRadius.circular(999)),
                  child: const Icon(Icons.directions_walk,
                      size: 22, color: Colors.white),
                ),
                if (live)
                  Positioned(
                    top: -2,
                    right: 6,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: c.skyBg,
                        shape: BoxShape.circle,
                        border: Border.all(color: c.sidebar, width: 2),
                      ),
                    ),
                  ),
              ]),
              const SizedBox(height: 4),
              Text(live ? l10n.live : l10n.wander,
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700, color: fg)),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Turn on location to wander" (canvas: Wander pressed, location off).
/// True when the person picked Turn on location.
Future<bool?> showWanderLocationSheet(BuildContext context) {
  final c = WandererTheme.of(context);
  final l10n = context.l10n;
  return showWandererSheet<bool>(
    context,
    builder: (sheet) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
                color: c.skyBg, borderRadius: BorderRadius.circular(16)),
            child: Icon(Icons.place_outlined, size: 26, color: c.skyFg),
          ),
        ),
        const SizedBox(height: 14),
        Text(l10n.wanderLocationTitle,
            style: WandererTheme.display(22, color: c.text)),
        const SizedBox(height: 6),
        Text(l10n.wanderLocationBody,
            style: TextStyle(fontSize: 14, height: 1.5, color: c.textMuted)),
        const SizedBox(height: 14),
        PlanPrimaryButton(
          key: const Key('wander_turn_on_location'),
          label: l10n.wanderTurnOnLocation,
          onPressed: () => Navigator.pop(sheet, true),
        ),
        SizedBox(
          height: 48,
          child: TextButton(
            onPressed: () => Navigator.pop(sheet, false),
            style: TextButton.styleFrom(
                foregroundColor: c.text,
                textStyle:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            child: Text(l10n.wanderNotNow),
          ),
        ),
      ],
    ),
  );
}
