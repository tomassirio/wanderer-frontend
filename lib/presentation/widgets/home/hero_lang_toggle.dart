import 'package:flutter/material.dart';
import 'package:wanderer_frontend/core/l10n/locale_controller.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';

/// Compact language picker for the guest hero overlay (top-left of
/// [HomeScreen]'s hero section).
class HeroLangToggle extends StatelessWidget {
  const HeroLangToggle({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: ValueListenableBuilder<Locale>(
        valueListenable: LocaleController().locale,
        builder: (context, locale, _) {
          final controller = LocaleController();
          final currentCode = controller.languageCode;
          final flag = LocaleController.localeFlags[currentCode] ?? '🌐';
          final label = LocaleController.localeLabels[currentCode] ?? 'EN';
          return PopupMenuButton<String>(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Change language',
            onSelected: (code) => controller.setLocale(Locale(code)),
            itemBuilder: (_) => LocaleController.supportedLocales.map((loc) {
              final code = loc.languageCode;
              final locFlag = LocaleController.localeFlags[code] ?? '🌐';
              final locLabel = LocaleController.localeLabels[code] ?? code;
              return PopupMenuItem<String>(
                value: code,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(locFlag, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Text(
                      locLabel,
                      style: TextStyle(
                        fontWeight: code == currentCode
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withOpacity(0.6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(flag, style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: TextStyle(
                      color: WandererTheme.primaryOrange,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                  Icon(Icons.arrow_drop_down,
                      color: WandererTheme.primaryOrange, size: 16),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
