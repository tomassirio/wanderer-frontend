import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wanderer_frontend/data/services/url_shortener_service.dart';

void main() {
  group('UrlShortenerService', () {
    test('returns the shortened URL on success', () async {
      final mockClient = MockClient((request) async {
        expect(
          request.url.toString(),
          'https://tinyurl.com/api-create.php?url=https%3A%2F%2Fexample.com%2Ftrip%2F123',
        );
        return http.Response('https://tinyurl.com/abc123', 200);
      });

      final service = UrlShortenerService(httpClient: mockClient);
      final result = await service.shorten('https://example.com/trip/123');

      expect(result, 'https://tinyurl.com/abc123');
    });

    test('returns null on a non-200 response', () async {
      final mockClient = MockClient((request) async {
        return http.Response('error', 500);
      });

      final service = UrlShortenerService(httpClient: mockClient);
      final result = await service.shorten('https://example.com/trip/123');

      expect(result, isNull);
    });

    test('returns null when the request throws', () async {
      final mockClient = MockClient((request) async {
        throw Exception('network error');
      });

      final service = UrlShortenerService(httpClient: mockClient);
      final result = await service.shorten('https://example.com/trip/123');

      expect(result, isNull);
    });
  });
}
