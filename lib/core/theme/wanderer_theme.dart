import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Wanderer App Theme Configuration
///
/// Web uses the "sand" redesign (docs/design-system.md): warm sand ground,
/// white cards with thin borders, one trail-orange accent, green for
/// completed. Mobile keeps the original palette until it is redesigned.
/// [kIsWeb] is a compile-time constant, so every token below stays `const`.
class WandererTheme {
  // ========================================
  // WEB REDESIGN PALETTE (style guide board)
  // ========================================
  static const Color sand = Color(0xFFF5F2EC); // page background
  static const Color sandSidebar = Color(0xFFFBFAF7); // sidebar / rail
  static const Color paper = Color(0xFFFFFFFF); // cards, panels
  static const Color paperMuted = Color(0xFFFAF8F4); // stat tiles in cards
  static const Color line = Color(0xFFE7E1D6); // borders
  static const Color lineSoft = Color(0xFFEFEAE1); // inner dividers
  static const Color ink = Color(0xFF1B1A17); // text, dark buttons
  static const Color stone = Color(0xFF57534E); // secondary text
  static const Color stoneLight = Color(0xFF6B6560); // captions
  static const Color stoneLabel = Color(0xFF78716C); // caps labels
  static const Color trail = Color(0xFFC2410C); // primary accent
  static const Color trailDeep = Color(0xFF9A3412); // links, active nav text
  static const Color trailSoft = Color(0xFFFBEBDD); // active nav, chips
  static const Color forest = Color(0xFF2F6B4F); // completed, success
  static const Color forestSoft = Color(0xFFE3EFE8);
  static const Color sky = Color(0xFF2F5C8A); // in progress
  static const Color skySoft = Color(0xFFE6EEF7);
  static const Color gold = Color(0xFF6B4A0A); // achievements, distance
  static const Color goldSoft = Color(0xFFFFF4D6);
  static const Color goldIcon = Color(0xFFA16207);
  static const Color neutralSoft = Color(0xFFF1EEE8); // private pill
  static const Color neutralText = Color(0xFF44403C);
  static const Color mapGround = Color(0xFFECE7DB);

  // Display font for headlines; body font everywhere else (web only).
  static const String displayFont = 'Bricolage Grotesque';
  static const String bodyFont = 'Manrope';

  // Corner radii: 10–12 controls, 14 small cards, 18 panels.
  static const double radiusControl = 12.0;
  static const double radiusCard = 14.0;
  static const double radiusPanel = 18.0;

  /// Headline style in the display face (web), falls back to bold body.
  static TextStyle display(double size, {Color? color}) => TextStyle(
        fontFamily: kIsWeb ? displayFont : null,
        fontWeight: FontWeight.w700,
        fontSize: size,
        letterSpacing: size >= 28 ? -0.02 * size : 0,
        height: 1.1,
        color: color,
      );

  /// White card on sand with a 1px line border and no heavy shadow.
  static BoxDecoration cardDecoration(BuildContext context,
      {double radius = radiusPanel}) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: dark ? const Color(0xFF3A3632) : line),
    );
  }

  // Primary Colors
  static const Color primaryOrange =
      kIsWeb ? trail : Color(0xFFE07830); // Main orange
  static const Color primaryOrangeLight =
      Color(0xFFF5A623); // Light orange/amber
  static const Color primaryOrangeDark = Color(0xFFD35400); // Dark orange

  // Background Colors
  static const Color backgroundLight =
      kIsWeb ? sand : Color(0xFFFAF9F7); // Warm off-white
  static const Color backgroundCard = Color(0xFFFFFFFF); // Pure white for cards
  static const Color backgroundDark = Color(0xFF2C2C2C); // Dark mode background

  // Text Colors
  static const Color textPrimary = kIsWeb ? ink : Color(0xFF1A1A1A);
  static const Color textSecondary = kIsWeb ? stone : Color(0xFF666666);
  static const Color textTertiary = kIsWeb ? stoneLabel : Color(0xFF999999);
  static const Color textOnPrimary = Color(0xFFFFFFFF); // White text on orange

  // Status Colors
  static const Color statusCreated = Color(0xFF4CAF50); // Green
  static const Color statusInProgress =
      kIsWeb ? sky : Color(0xFFFF9800); // Orange
  static const Color statusCompleted =
      kIsWeb ? forest : Color(0xFF2196F3); // Blue
  static const Color statusCancelled = Color(0xFFF44336); // Red
  static const Color statusResting = Color(0xFF5C6BC0); // Indigo

  // Map Colors
  static const Color mapRouteColor = Color(0xFF0088FF); // Blue route line
  static const Color mapMarkerStart = Color(0xFF4CAF50); // Green
  static const Color mapMarkerEnd = Color(0xFFF44336); // Red
  static const Color mapMarkerWaypoint = Color(0xFFFF9800); // Orange

  // Timeline Colors
  static const Color timelineConnector = Color(0xFFE0E0E0);
  static const Color timelineNodeActive = Color(0xFFE07830);
  static const Color timelineNodeCompleted = Color(0xFF4CAF50);

  // Day Marker Colors (multi-day trip timeline)
  static const Color dayStartColor = Color(0xFFFFCA28); // Yellow/golden
  static const Color dayEndColor = Color(0xFF7E57C2); // Violet/purple

  // Trip Lifecycle Marker Colors (timeline)
  static const Color tripStartedColor = Color(0xFF81C784); // Pastel green
  static const Color tripEndedColor = Color(0xFFE57373); // Pastel red

  // ========================================
  // GLASSMORPHISM DESIGN SYSTEM
  // ========================================

  // Glass Colors - Semi-transparent backgrounds
  static Color glassBackground = Colors.white.withOpacity(0.85);
  static Color glassBackgroundLight = Colors.white.withOpacity(0.75);
  static Color glassBackgroundDark = Colors.white.withOpacity(0.92);
  static Color glassBorderColor = Colors.white.withOpacity(0.4);
  static Color glassHighlight = Colors.white.withOpacity(0.6);

  /// Returns glass panel background color adaptive to the current theme.
  /// On web, panels are solid cards (no frosted glass) per the style guide.
  static Color glassBackgroundFor(BuildContext context) {
    if (kIsWeb) return Theme.of(context).colorScheme.surface;
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF1E1E1E).withOpacity(0.9)
        : glassBackground;
  }

  /// Returns glass panel border color adaptive to the current theme.
  static Color glassBorderColorFor(BuildContext context) {
    if (kIsWeb) return Theme.of(context).colorScheme.outline;
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.white.withOpacity(0.12)
        : glassBorderColor;
  }

  // Glass Blur Amount
  static const double glassBlurSigma = 20.0;
  static const double glassBlurSigmaLight = 12.0;

  // Glass Border Radius
  static const double glassRadius = kIsWeb ? radiusPanel : 16.0;
  static const double glassRadiusSmall = 12.0;
  static const double glassRadiusLarge = 20.0;

  // Shadows
  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.08),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> elevatedShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.12),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  // Floating Shadow - More diffused for glassmorphism floating effect
  static List<BoxShadow> floatingShadow = kIsWeb
      ? const [
          BoxShadow(
              color: Color(0x141B1A17), blurRadius: 16, offset: Offset(0, 4)),
        ]
      : [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 24,
            spreadRadius: 0,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 48,
            spreadRadius: 0,
            offset: const Offset(0, 16),
          ),
        ];

  // Glass panel shadow - subtle all-around glow
  static List<BoxShadow> glassShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.1),
      blurRadius: 32,
      spreadRadius: -4,
      offset: const Offset(0, 12),
    ),
  ];

  /// Creates a glass-style BoxDecoration with semi-transparent background
  /// and subtle border for the "frosted glass" edge effect
  static BoxDecoration glassDecoration({
    double radius = glassRadius,
    Color? backgroundColor,
    bool showBorder = true,
    List<BoxShadow>? shadow,
  }) {
    return BoxDecoration(
      color: backgroundColor ?? glassBackground,
      borderRadius: BorderRadius.circular(radius),
      border: showBorder
          ? Border.all(
              color: glassBorderColor,
              width: 1,
            )
          : null,
      boxShadow: shadow ?? floatingShadow,
    );
  }

  /// Creates a glass decoration with only specific borders (for docked panels)
  static BoxDecoration glassDecorationWithBorders({
    Color? backgroundColor,
    BorderRadius? borderRadius,
    Border? border,
    List<BoxShadow>? shadow,
  }) {
    return BoxDecoration(
      color: backgroundColor ?? glassBackground,
      borderRadius: borderRadius,
      border: border,
      boxShadow: shadow ?? glassShadow,
    );
  }

  /// Wraps a widget with frosted glass blur effect
  /// Use inside a ClipRRect for proper edge clipping
  static Widget glassContainer({
    required Widget child,
    double blurSigma = glassBlurSigma,
    double radius = glassRadius,
    Color? backgroundColor,
    bool showBorder = true,
    List<BoxShadow>? shadow,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
  }) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: shadow ?? floatingShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: backgroundColor ?? glassBackground,
              borderRadius: BorderRadius.circular(radius),
              border: showBorder
                  ? Border.all(
                      color: glassBorderColor,
                      width: 1,
                    )
                  : null,
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  /// Get the light theme
  static ThemeData lightTheme() {
    if (kIsWeb) return _webTheme(_mobileLightTheme(), dark: false);
    return _mobileLightTheme();
  }

  static ThemeData _mobileLightTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryOrange,
        primary: primaryOrange,
        secondary: primaryOrangeLight,
        surface: backgroundLight,
        background: backgroundLight,
        onPrimary: textOnPrimary,
        onSecondary: textOnPrimary,
        onSurface: textPrimary,
        onBackground: textPrimary,
      ),
      scaffoldBackgroundColor: backgroundLight,
      appBarTheme: const AppBarTheme(
        backgroundColor: backgroundCard,
        foregroundColor: textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryOrange,
          foregroundColor: textOnPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryOrange,
          side: const BorderSide(color: primaryOrange),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryOrange,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: backgroundLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primaryOrange, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: backgroundLight,
        selectedColor: primaryOrange.withOpacity(0.2),
        labelStyle: const TextStyle(fontSize: 12),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: Colors.grey.shade200,
        thickness: 1,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryOrange,
        foregroundColor: textOnPrimary,
      ),
    );
  }

  /// Get the dark theme
  static ThemeData darkTheme() {
    if (kIsWeb) return _webTheme(_mobileDarkTheme(), dark: true);
    return _mobileDarkTheme();
  }

  /// Layers the web redesign (fonts, sand surfaces, 12px controls, thin
  /// borders) over the base theme.
  static ThemeData _webTheme(ThemeData base, {required bool dark}) {
    final ground = dark ? const Color(0xFF171513) : sand;
    final surface = dark ? const Color(0xFF211F1C) : paper;
    final border = dark ? const Color(0xFF3A3632) : line;
    final text = dark ? const Color(0xFFF1EDE6) : ink;
    final muted = dark ? const Color(0xFFB5AEA4) : stone;
    final controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusControl),
    );
    const buttonText = TextStyle(
      fontFamily: bodyFont,
      fontSize: 14,
      fontWeight: FontWeight.w700,
    );
    final textTheme = base.textTheme
        .apply(fontFamily: bodyFont, bodyColor: text, displayColor: text)
        .copyWith(
          displayLarge: display(57, color: text),
          displayMedium: display(45, color: text),
          displaySmall: display(36, color: text),
          headlineLarge: display(32, color: text),
          headlineMedium: display(28, color: text),
          headlineSmall: display(24, color: text),
        );

    return base.copyWith(
      scaffoldBackgroundColor: ground,
      canvasColor: ground,
      colorScheme: base.colorScheme.copyWith(
        primary: trail,
        onPrimary: Colors.white,
        surface: surface,
        onSurface: text,
        onSurfaceVariant: muted,
        outline: border,
        outlineVariant: border,
        surfaceContainerLowest: surface,
        surfaceContainerLow: surface,
        surfaceContainer: surface,
        surfaceContainerHigh: surface,
        surfaceContainerHighest: dark ? const Color(0xFF2A2724) : paperMuted,
      ),
      textTheme: textTheme,
      primaryTextTheme: base.primaryTextTheme.apply(fontFamily: bodyFont),
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: ground,
        foregroundColor: text,
        titleTextStyle: display(20, color: text),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusPanel),
          side: BorderSide(color: border),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: trail,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          shape: controlShape,
          textStyle: buttonText,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: trail,
          foregroundColor: Colors.white,
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          shape: controlShape,
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: surface,
          foregroundColor: text,
          side: BorderSide(color: border),
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          shape: controlShape,
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: dark ? const Color(0xFFF0A36F) : trailDeep,
          minimumSize: const Size(44, 44),
          shape: controlShape,
          textStyle: buttonText,
        ),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusControl),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusControl),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusControl),
          borderSide: const BorderSide(color: trail, width: 2),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: dark ? const Color(0xFF2A2724) : neutralSoft,
        selectedColor: trailSoft,
        side: BorderSide.none,
        labelStyle: const TextStyle(
          fontFamily: bodyFont,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        shape: const StadiumBorder(),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusPanel),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          side: BorderSide(color: border),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ink,
        contentTextStyle: const TextStyle(
          fontFamily: bodyFont,
          color: Colors.white,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusControl),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: text,
        unselectedLabelColor: muted,
        indicatorColor: trail,
        labelStyle: buttonText,
        unselectedLabelStyle: buttonText.copyWith(fontWeight: FontWeight.w600),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: trail,
        foregroundColor: Colors.white,
      ),
    );
  }

  static ThemeData _mobileDarkTheme() {
    const Color darkBackground = Color(0xFF121212);
    const Color darkCard = Color(0xFF1E1E1E);
    const Color darkTextPrimary = Color(0xFFEFEFEF);
    const Color darkTextSecondary = Color(0xFFB0B0B0);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryOrange,
        brightness: Brightness.dark,
        primary: primaryOrange,
        secondary: primaryOrangeLight,
        surface: darkCard,
        onPrimary: textOnPrimary,
        onSecondary: textOnPrimary,
        onSurface: darkTextPrimary,
      ),
      scaffoldBackgroundColor: darkBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: darkCard,
        foregroundColor: darkTextPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: darkTextPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryOrange,
          foregroundColor: textOnPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryOrange,
          side: const BorderSide(color: primaryOrange),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryOrange,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF3A3A3A)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF3A3A3A)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primaryOrange, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        labelStyle: const TextStyle(color: darkTextSecondary),
        hintStyle: const TextStyle(color: darkTextSecondary),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: darkCard,
        selectedColor: primaryOrange.withOpacity(0.3),
        labelStyle: const TextStyle(fontSize: 12, color: darkTextPrimary),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF3A3A3A),
        thickness: 1,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryOrange,
        foregroundColor: textOnPrimary,
      ),
      listTileTheme: const ListTileThemeData(
        textColor: darkTextPrimary,
        iconColor: darkTextSecondary,
      ),
    );
  }

  /// Status chip decoration
  static BoxDecoration statusChipDecoration(String status) {
    Color bgColor;
    switch (status.toUpperCase()) {
      case 'CREATED':
        bgColor = statusCreated.withOpacity(0.15);
        break;
      case 'IN_PROGRESS':
        bgColor = statusInProgress.withOpacity(0.15);
        break;
      case 'COMPLETED':
        bgColor = statusCompleted.withOpacity(0.15);
        break;
      case 'CANCELLED':
        bgColor = statusCancelled.withOpacity(0.15);
        break;
      case 'RESTING':
        bgColor = statusResting.withOpacity(0.15);
        break;
      default:
        bgColor = Colors.grey.withOpacity(0.15);
    }
    return BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(12),
    );
  }

  /// Get status text color
  static Color statusTextColor(String status) {
    switch (status.toUpperCase()) {
      case 'CREATED':
        return statusCreated;
      case 'IN_PROGRESS':
        return statusInProgress;
      case 'COMPLETED':
        return statusCompleted;
      case 'CANCELLED':
        return statusCancelled;
      case 'RESTING':
        return statusResting;
      default:
        return textSecondary;
    }
  }
}
