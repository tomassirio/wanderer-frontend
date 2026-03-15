import 'dart:ui';
import 'package:flutter/material.dart';

/// Wanderer App Theme Configuration
/// Inspired by modern trip tracking UI with warm orange/amber tones
/// Enhanced with Glassmorphism design
class WandererTheme {
  // Primary Colors
  static const Color primaryOrange = Color(0xFFE07830); // Main orange
  static const Color primaryOrangeLight =
      Color(0xFFF5A623); // Light orange/amber
  static const Color primaryOrangeDark = Color(0xFFD35400); // Dark orange

  // Background Colors
  static const Color backgroundLight = Color(0xFFFAF9F7); // Warm off-white
  static const Color backgroundCard = Color(0xFFFFFFFF); // Pure white for cards
  static const Color backgroundDark = Color(0xFF2C2C2C); // Dark mode background

  // Text Colors
  static const Color textPrimary = Color(0xFF1A1A1A); // Almost black
  static const Color textSecondary = Color(0xFF666666); // Gray
  static const Color textTertiary = Color(0xFF999999); // Light gray
  static const Color textOnPrimary = Color(0xFFFFFFFF); // White text on orange

  // Status Colors
  static const Color statusCreated = Color(0xFF4CAF50); // Green
  static const Color statusInProgress = Color(0xFFFF9800); // Orange
  static const Color statusCompleted = Color(0xFF2196F3); // Blue
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
  static const Color dayStartColor = Color(0xFFFFA726); // Warm amber/yellow
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
  static Color glassBackgroundFor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF1E1E1E).withOpacity(0.9)
        : glassBackground;
  }

  /// Returns glass panel border color adaptive to the current theme.
  static Color glassBorderColorFor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.white.withOpacity(0.12)
        : glassBorderColor;
  }

  // Glass Blur Amount
  static const double glassBlurSigma = 20.0;
  static const double glassBlurSigmaLight = 12.0;

  // Glass Border Radius
  static const double glassRadius = 16.0;
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
  static List<BoxShadow> floatingShadow = [
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
