import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:flutter/widgets.dart';

/// Presentation only: browser APIs and native capabilities must still use
/// platform checks, not the viewport-dependent layout.
abstract final class AdaptiveLayout {
  static const double desktopBreakpoint = 720;

  /// Tests set this to render the browser layouts on the VM.
  @visibleForTesting
  static bool? debugIsWeb;

  static bool get _isWeb => debugIsWeb ?? kIsWeb;

  static bool isMobileWeb(BuildContext context) =>
      _isWeb && !usesDesktopLayout(context);

  static bool usesDesktopLayout(BuildContext context) =>
      _isWeb && MediaQuery.sizeOf(context).width >= desktopBreakpoint;
}
