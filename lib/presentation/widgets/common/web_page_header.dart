import 'package:flutter/material.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/theme/theme_controller.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/presentation/widgets/common/notification_bell.dart';
import 'package:wanderer_frontend/presentation/widgets/common/wanderer_scaffold.dart';
import 'package:wanderer_frontend/presentation/widgets/search/search_overlay.dart';

/// Web page header: title and subtitle on the left; on the right the
/// sun/moon toggle, notifications and the page's one orange action.
///
/// Toggle and bell only show when the sidebar is beside the page (the top
/// bar is hidden then, see [WandererScaffold.hideAppBarWithSidebar]).
class WebPageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool isLoggedIn;
  final String? userId;

  /// Secondary buttons before the primary one.
  final List<Widget> actions;

  /// The page's main action (orange). At most one per screen.
  final Widget? primaryAction;

  const WebPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.isLoggedIn = true,
    this.userId,
    this.actions = const [],
    this.primaryAction,
  });

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    final chrome = WandererScaffold.hasPersistentSidebar(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final trailing = <Widget>[
      if (chrome) ...[
        if (isLoggedIn)
          HeaderIconButton(
            tooltip: l10n.search,
            onPressed: () => showSearchOverlay(context),
            child: const Icon(Icons.search),
          ),
        HeaderIconButton(
          tooltip: isDark ? l10n.switchToLightMode : l10n.switchToDarkMode,
          onPressed: () => ThemeController().setDarkMode(!isDark),
          child: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
        ),
        if (isLoggedIn)
          NotificationBell(isLoggedIn: true, userId: userId, outlined: true),
      ],
      ...actions,
      if (primaryAction != null) primaryAction!,
    ];

    return Wrap(
      spacing: 24,
      runSpacing: 16,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              header: true,
              child: Text(title, style: WandererTheme.display(32)),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!,
                  style: TextStyle(fontSize: 15, color: c.textMuted)),
            ],
          ],
        ),
        if (trailing.isNotEmpty)
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: trailing,
          ),
      ],
    );
  }
}
