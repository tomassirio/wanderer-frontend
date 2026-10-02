import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:wanderer_frontend/presentation/helpers/adaptive_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/providers/app_providers.dart';
import 'package:wanderer_frontend/core/services/push_notification_manager.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/presentation/helpers/page_transitions.dart';
import 'package:wanderer_frontend/presentation/helpers/live_toast_bridge.dart';
import 'package:wanderer_frontend/presentation/screens/android/android_explore_tab.dart';
import 'package:wanderer_frontend/presentation/screens/android/android_home_tab.dart';
import 'package:wanderer_frontend/presentation/screens/android/android_trips_tab.dart';
import 'package:wanderer_frontend/presentation/screens/android/android_you_tab.dart';
import 'package:wanderer_frontend/presentation/screens/create_trip_plan_screen.dart';
import 'package:wanderer_frontend/presentation/screens/create_trip_screen.dart';
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
  bool _createOpen = false;

  void selectTab(AndroidTab tab) => setState(() {
        _tab = tab;
        _createOpen = false;
      });

  @override
  void initState() {
    super.initState();
    AndroidShell._current = this;
    _connect();
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
    if (AndroidShell._current == this) AndroidShell._current = null;
    PushNotificationManager().stop();
    if (kIsWeb) LiveToastBridge().stop();
    super.dispose();
  }

  /// Bumped after a create flow so every tab reloads with the new item.
  int _generation = 0;

  Future<void> _create(Widget screen) async {
    setState(() => _createOpen = false);
    await Navigator.of(context).push(PageTransitions.slideFromBottom(screen));
    if (mounted) setState(() => _generation++);
  }

  @override
  Widget build(BuildContext context) {
    final showCreate = _tab == AndroidTab.trips ||
        (_tab == AndroidTab.home && !AdaptiveLayout.isMobileWeb(context));
    return PopScope(
      canPop: !_createOpen && _tab == AndroidTab.home,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_createOpen) {
          setState(() => _createOpen = false);
        } else {
          selectTab(AndroidTab.home);
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            IndexedStack(
              key: ValueKey(_generation),
              index: _tab.index,
              children: const [
                AndroidHomeTab(),
                AndroidTripsTab(),
                AndroidExploreTab(),
                AndroidYouTab(),
              ],
            ),
            if (showCreate)
              _CreateMenu(
                open: _createOpen,
                onToggle: () => setState(() => _createOpen = !_createOpen),
                onPlan: () => _create(const CreateTripPlanScreen()),
                onTrip: () => _create(const CreateTripScreen()),
              ),
          ],
        ),
        bottomNavigationBar: _BottomNav(tab: _tab, onSelect: selectTab),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final AndroidTab tab;
  final ValueChanged<AndroidTab> onSelect;
  const _BottomNav({required this.tab, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    TextStyle label(bool on) => TextStyle(
          fontSize: 12,
          fontWeight: on ? FontWeight.w700 : FontWeight.w600,
          color: on ? c.accentText : c.textMuted,
        );
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
          selectedIndex: tab.index,
          onDestinationSelected: (i) => onSelect(AndroidTab.values[i]),
          destinations: [
            NavigationDestination(
                icon: const Icon(Icons.home_outlined), label: l10n.home),
            NavigationDestination(
                icon: const Icon(Icons.map_outlined), label: l10n.trips),
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

/// The + button and, when open, its scrim and "Trip plan" / "Trip" cards.
class _CreateMenu extends StatelessWidget {
  final bool open;
  final VoidCallback onToggle;
  final VoidCallback onPlan;
  final VoidCallback onTrip;
  const _CreateMenu({
    required this.open,
    required this.onToggle,
    required this.onPlan,
    required this.onTrip,
  });

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    return Stack(
      children: [
        if (open)
          Positioned.fill(
            child: GestureDetector(
              onTap: onToggle,
              child: const ColoredBox(color: Color(0x731B1A17)),
            ),
          ),
        Positioned(
          right: 16,
          bottom: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (open) ...[
                // Trip first: plans are the secondary entity. Same width.
                IntrinsicWidth(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _CreateItem(
                        icon: Icons.place_outlined,
                        bg: c.trailSoftBg,
                        fg: WandererTheme.trail,
                        title: l10n.trip,
                        subtitle: l10n.createMenuTripSubtitle,
                        onTap: onTrip,
                      ),
                      const SizedBox(height: 12),
                      _CreateItem(
                        icon: Icons.calendar_month_outlined,
                        bg: c.skyBg,
                        fg: c.skyFg,
                        title: l10n.tripPlan,
                        subtitle: l10n.createMenuPlanSubtitle,
                        onTap: onPlan,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Semantics(
                button: true,
                label: open ? l10n.closeCreateMenu : l10n.create,
                child: Material(
                  color: open ? c.surface : c.neutralButtonBg,
                  elevation: 6,
                  shadowColor: const Color(0x401B1A17),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: onToggle,
                    child: SizedBox(
                      width: 64,
                      height: 64,
                      child: AnimatedRotation(
                        turns: open ? 0.125 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(Icons.add,
                            size: 28, color: open ? c.text : c.neutralButtonFg),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CreateItem extends StatelessWidget {
  final IconData icon;
  final Color bg;
  final Color fg;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _CreateItem({
    required this.icon,
    required this.bg,
    required this.fg,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    return Material(
      color: c.surface,
      elevation: 8,
      shadowColor: const Color(0x331B1A17),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 18, 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    color: bg, borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, size: 22, color: fg),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: c.text)),
                  Text(subtitle,
                      style: TextStyle(fontSize: 13, color: c.caption)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
