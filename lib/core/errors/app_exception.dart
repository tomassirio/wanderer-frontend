/// Typed API exception that separates technical details from user-facing messages.
///
/// Thrown by [ApiClient._handleError] instead of a generic [Exception].
/// Presentation-layer code can use [userMessage] for display and
/// [statusCode] / [apiMessage] for logging or conditional handling.
class ApiException implements Exception {
  /// HTTP status code from the backend (e.g. 409, 500).
  final int statusCode;

  /// Raw message extracted from the backend JSON response.
  final String apiMessage;

  const ApiException({required this.statusCode, required this.apiMessage});

  /// Stable error code for logging / support tickets.
  ///
  /// 4xx → `WANDERER_4xx` (e.g. `WANDERER_409`)
  /// 5xx → `WANDERER_5xx` (e.g. `WANDERER_500`)
  String get errorCode => 'WANDERER_$statusCode';

  /// A short, user-friendly description.
  ///
  /// Business-rule errors (4xx) forward the backend message directly because
  /// it is already written for end users (e.g. "Only one trip can be in
  /// progress at a time."). Server errors (5xx) are replaced with a generic
  /// string that includes the [errorCode] so users can report it to support
  /// without seeing raw technical details.
  String get userMessage {
    if (statusCode >= 500) {
      return 'Something went wrong. Please try again later. ($errorCode)';
    }
    // 4xx — the backend message is meaningful to the user
    return apiMessage;
  }

  @override
  String toString() => 'ApiException($statusCode): $apiMessage';
}
