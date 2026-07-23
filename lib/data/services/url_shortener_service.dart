import 'package:http/http.dart' as http;

/// Shortens URLs via the tinyurl.com public API (no auth, no app backend
/// involved — this is a third-party call, not one of our own endpoints).
class UrlShortenerService {
  final http.Client _httpClient;

  UrlShortenerService({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  /// Returns the shortened URL, or null if shortening fails for any reason
  /// (non-200 response, timeout, network error).
  Future<String?> shorten(String url) async {
    try {
      final response = await _httpClient
          .get(
            Uri.parse(
              'https://tinyurl.com/api-create.php?url=${Uri.encodeComponent(url)}',
            ),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return response.body.trim();
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
