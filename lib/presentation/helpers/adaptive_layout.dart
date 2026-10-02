import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';

/// Presentation only: browser APIs and native capabilities must still use
/// platform checks, not the viewport-dependent layout.
abstract final class AdaptiveLayout {
  static const double desktopBreakpoint = 720;

  static bool isMobileWeb(BuildContext context) =>
      kIsWeb && !usesDesktopLayout(context);

  static bool usesDesktopLayout(BuildContext context) =>
      kIsWeb && MediaQuery.sizeOf(context).width >= desktopBreakpoint;
}
