import 'package:flutter/material.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/presentation/helpers/page_transitions.dart';
import 'package:wanderer_frontend/presentation/screens/admin_users_screen.dart';
import 'package:wanderer_frontend/presentation/screens/trip_maintenance_screen.dart';
import 'package:wanderer_frontend/presentation/screens/trip_promotion_screen.dart';
import 'package:wanderer_frontend/presentation/widgets/android/android_ui.dart';

/// Colours of the dark admin surfaces (the You tab's "Admin tools" button
/// and this screen's notice): ink in light mode, Raised in Dusk so it
/// doesn't sink into the dark ground.
({Color bg, Color chip, Color icon, Color title, Color sub, Color chevron})
    adminDarkColors(BuildContext context) {
  final c = WandererTheme.of(context);
  if (Theme.of(context).brightness == Brightness.dark) {
    return (
      bg: c.raised,
      chip: c.surface,
      icon: c.accentText,
      title: c.text,
      sub: c.textMuted,
      chevron: c.label,
    );
  }
  return (
    bg: WandererTheme.ink,
    chip: const Color(0xFF39332D),
    icon: const Color(0xFFF6A56A),
    title: const Color(0xFFF6F1EA),
    sub: const Color(0xFFC4BBB1),
    chevron: const Color(0xFF9E958B),
  );
}

/// Dark "Admin tools" row on the You tab (canvas: You, admin only).
class AdminToolsButton extends StatelessWidget {
  final VoidCallback onTap;
  const AdminToolsButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final a = adminDarkColors(context);
    final l10n = context.l10n;
    return Material(
      color: a.bg,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: a.chip, borderRadius: BorderRadius.circular(12)),
              child:
                  Icon(Icons.verified_user_outlined, size: 20, color: a.icon),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.adminToolsTitle,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: a.title)),
                  Text(l10n.adminToolsSub,
                      style: TextStyle(fontSize: 13, color: a.sub)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 20, color: a.chevron),
          ]),
        ),
      ),
    );
  }
}

/// Android admin hub (canvas: "Admin tools"): a warning notice and one
/// card linking to each admin screen.
class AndroidAdminScreen extends StatelessWidget {
  const AndroidAdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    final a = adminDarkColors(context);
    final l10n = context.l10n;
    void push(Widget screen) =>
        Navigator.of(context).push(PageTransitions.slideFromRight(screen));

    final tools = [
      (
        Icons.campaign_outlined,
        c.trailSoftBg,
        WandererTheme.trail,
        l10n.tripPromotion,
        l10n.youAdminPromotionSub,
        const TripPromotionScreen(),
      ),
      (
        Icons.shield_outlined,
        c.skyBg,
        c.skyFg,
        l10n.userManagement,
        l10n.youAdminUsersSub,
        const AdminUsersScreen(),
      ),
      (
        Icons.build_outlined,
        c.pausedBg,
        c.pausedFg,
        l10n.tripDataMaintenance,
        l10n.youAdminMaintenanceSub,
        const TripMaintenanceScreen(),
      ),
    ];

    return Scaffold(
      backgroundColor: c.ground,
      appBar: AndroidTopBar(title: l10n.adminToolsTitle),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
                color: a.bg, borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              Icon(Icons.verified_user_outlined, size: 18, color: a.icon),
              const SizedBox(width: 10),
              Expanded(
                child: Text(l10n.adminToolsNotice,
                    style:
                        TextStyle(fontSize: 13, height: 1.4, color: a.title)),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: WandererTheme.cardDecoration(context),
            clipBehavior: Clip.antiAlias,
            child: Material(
              type: MaterialType.transparency,
              child: Column(children: [
                for (var i = 0; i < tools.length; i++)
                  InkWell(
                    onTap: () => push(tools[i].$6),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 76),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        border: i == tools.length - 1
                            ? null
                            : Border(bottom: BorderSide(color: c.lineSoft)),
                      ),
                      child: Row(children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                              color: tools[i].$2,
                              borderRadius: BorderRadius.circular(12)),
                          child:
                              Icon(tools[i].$1, size: 20, color: tools[i].$3),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(tools[i].$4,
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: c.text)),
                              const SizedBox(height: 2),
                              Text(tools[i].$5,
                                  style: TextStyle(
                                      fontSize: 13,
                                      height: 1.4,
                                      color: c.caption)),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right, size: 18, color: c.label),
                      ]),
                    ),
                  ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
