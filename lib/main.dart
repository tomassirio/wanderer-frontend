import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:wanderer_frontend/core/l10n/locale_controller.dart';
import 'package:wanderer_frontend/core/routing/app_router.dart';
import 'package:wanderer_frontend/core/theme/theme_controller.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/core/services/background_update_manager.dart';
import 'package:wanderer_frontend/core/services/navigation_service.dart';
import 'package:wanderer_frontend/core/services/notification_service.dart';

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

  // Initialize Android-only services
  if (!kIsWeb && Platform.isAndroid) {
    await BackgroundUpdateManager().initialize();
    final notificationService = NotificationService();
    await notificationService.initialize();
    await notificationService.requestPermission();
  }

  runApp(const MyApp());
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
              supportedLocales: const [Locale('en'), Locale('es')],
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
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
