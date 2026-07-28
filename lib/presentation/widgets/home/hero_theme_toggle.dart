import 'package:flutter/material.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/theme/theme_controller.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';

/// Compact dark/light mode toggle for the guest hero overlay (top-right of
/// [HomeScreen]'s hero section).
class HeroThemeToggle extends StatelessWidget {
  final AppLocalizations l10n;

  const HeroThemeToggle({super.key, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: ThemeController().themeMode,
        builder: (context, mode, _) {
          final isDark = mode == ThemeMode.dark;
          return IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              color: WandererTheme.primaryOrange,
              size: 20,
            ),
            tooltip: isDark ? l10n.switchToLightMode : l10n.switchToDarkMode,
            onPressed: () => ThemeController().setDarkMode(!isDark),
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
          );
        },
      ),
    );
  }
}
