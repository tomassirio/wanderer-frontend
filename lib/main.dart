import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/l10n/locale_controller.dart';
import 'package:wanderer_frontend/core/l10n/translation_loader.dart';
import 'package:wanderer_frontend/core/routing/app_router.dart';
import 'package:wanderer_frontend/core/theme/theme_controller.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/core/services/background_update_manager.dart';
import 'package:wanderer_frontend/core/services/navigation_service.dart';
import 'package:wanderer_frontend/core/services/notification_service.dart';
import 'package:wanderer_frontend/presentation/helpers/web_marker_generator.dart';
import 'package:wanderer_frontend/presentation/widgets/search/search_overlay.dart';

/// Global route observer for detecting when screens become visible again
final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Use clean URLs on web (e.g. /login instead of /#/login)
  usePathUrlStrategy();

  // Load the persisted theme preference before showing the app
  await ThemeController().initialize();

  // Load the persisted locale preference before showing the app
  await LocaleController().initialize();

  // Load translations from assets
  await TranslationLoader.instance.load();

  // Pre-generate coloured map markers for the web platform
  await WebMarkerGenerator.init();

  // Initialize Android-only services
  if (!kIsWeb && Platform.isAndroid) {
    await BackgroundUpdateManager().initialize();
    final notificationService = NotificationService();
    await notificationService.initialize();
    await notificationService.requestPermission();
  }

  if (kIsWeb) HardwareKeyboard.instance.addHandler(_openSearchShortcut);

  runApp(const ProviderScope(child: MyApp()));
}

/// Web: Ctrl+K / Cmd+K opens the search overlay from anywhere, regardless of
/// which widget has focus.
bool _openSearchShortcut(KeyEvent event) {
  final keyboard = HardwareKeyboard.instance;
  if (event is! KeyDownEvent ||
      event.logicalKey != LogicalKeyboardKey.keyK ||
      !(keyboard.isControlPressed || keyboard.isMetaPressed)) {
    return false;
  }
  final context = NavigationService().navigatorKey.currentContext;
  if (context == null) return false;
  showSearchOverlay(context);
  return true; // stop the browser's own Ctrl+K
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static final AppRouter _router = AppRouter();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: LocaleController().locale,
      builder: (context, locale, _) {
        return ValueListenableBuilder<ThemeMode>(
          valueListenable: ThemeController().themeMode,
          builder: (context, themeMode, _) {
            return MaterialApp(
              title: 'Wanderer',
              debugShowCheckedModeBanner: false,
              theme: WandererTheme.lightTheme(),
              darkTheme: WandererTheme.darkTheme(),
              themeMode: themeMode,
              locale: locale,
              supportedLocales: LocaleController.supportedLocales,
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              // Inject L10nScope inside MaterialApp so every screen
              // automatically rebuilds via context.l10n when locale changes.
              builder: (context, child) => L10nScope(
                notifier: LocaleController().locale,
                child: child!,
              ),
              navigatorKey: NavigationService().navigatorKey,
              navigatorObservers: [routeObserver],
              onGenerateRoute: _router.onGenerateRoute,
            );
          },
        );
      },
    );
  }
}
