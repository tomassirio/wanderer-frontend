import 'package:wanderer_frontend/core/errors/app_exception.dart';

/// Extracts a user-friendly message from any [Exception] or [Error].
///
/// - [ApiException] → delegates to [ApiException.userMessage] (clean 4xx
///   messages for the user, masked 5xx with WANDERER_XXX code).
/// - Legacy [Exception] → strips `Exception:` and `API Error (NNN):` prefixes.
/// - Unknown errors → generic fallback message.
///
/// Usage in catch blocks:
/// ```dart
/// } catch (e) {
///   UiHelpers.showErrorMessage(context, friendlyMessage(e));
/// }
/// ```
String friendlyMessage(Object error) {
  if (error is ApiException) {
    return error.userMessage;
  }

  // Strip the ugly "Exception: " prefix Dart adds on toString()
  final raw = error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');

  // Strip "API Error (NNN): " prefix from any legacy Exception paths
  final cleaned = raw.replaceFirst(RegExp(r'^API Error \(\d+\):\s*'), '');

  if (cleaned.isEmpty) {
    return 'Something went wrong. Please try again.';
  }

  return cleaned;
}
