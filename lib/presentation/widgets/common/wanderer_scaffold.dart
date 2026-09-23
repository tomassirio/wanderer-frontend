import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:wanderer_frontend/presentation/widgets/common/app_sidebar.dart';

/// Drop-in [Scaffold] that, on wide web screens, shows the [drawer] sidebar
/// permanently beside the page instead of behind a hamburger.
///
/// Above [expandedBreakpoint] the sidebar is full width (unless
/// [collapsedSidebar], used by map-heavy pages); between
/// [railBreakpoint] and [expandedBreakpoint] it is an icon rail. Mobile and
/// narrow web behave exactly like a plain [Scaffold].
class WandererScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final AppSidebar? drawer;
  final Widget? body;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Widget? bottomNavigationBar;
  final Color? backgroundColor;
  final bool extendBodyBehindAppBar;
  final bool? resizeToAvoidBottomInset;
  final bool collapsedSidebar;

  /// Web pages with a [WebPageHeader]: drop the top bar while the sidebar
  /// is beside the page (header carries theme toggle and notifications).
  final bool hideAppBarWithSidebar;

  const WandererScaffold({
    super.key,
    this.appBar,
    this.drawer,
    this.body,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.bottomNavigationBar,
    this.backgroundColor,
    this.extendBodyBehindAppBar = false,
    this.resizeToAvoidBottomInset,
    this.collapsedSidebar = false,
    this.hideAppBarWithSidebar = false,
  });

  static const double railBreakpoint = 720;
  static const double expandedBreakpoint = 1200;

  /// Whether the sidebar is shown beside the page (so no hamburger needed).
  static bool hasPersistentSidebar(BuildContext context) =>
      kIsWeb && MediaQuery.sizeOf(context).width >= railBreakpoint;

  @override
  Widget build(BuildContext context) {
    final persistent = drawer != null && hasPersistentSidebar(context);
    final scaffold = Scaffold(
      appBar: persistent && hideAppBarWithSidebar ? null : appBar,
      drawer: persistent ? null : drawer,
      body: body,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      bottomNavigationBar: bottomNavigationBar,
      backgroundColor: backgroundColor,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
    );
    if (!persistent) return scaffold;

    final width = MediaQuery.sizeOf(context).width;
    final collapsed = collapsedSidebar || width < expandedBreakpoint;
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Row(
        children: [
          drawer!.asPersistent(collapsed: collapsed),
          Expanded(child: scaffold),
        ],
      ),
    );
  }
}
