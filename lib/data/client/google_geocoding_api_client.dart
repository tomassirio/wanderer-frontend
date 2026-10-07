import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Reverse geocoding (coordinates → town name) for the ready-to-start
/// trip name, via the Geocoding API.
class GoogleGeocodingApiClient {
  final String _apiKey;
  final http.Client _httpClient;

  static const String _baseUrl =
      'https://maps.googleapis.com/maps/api/geocode/json';

  GoogleGeocodingApiClient(this._apiKey, {http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  /// Town or city at [lat]/[lon], or null when unknown or offline.
  Future<String?> placeName(double lat, double lon, {String? language}) async {
    // ponytail: the REST API has no CORS, so browsers get the date-only
    // name; add a JS Geocoder bridge (like directions_web_impl) if wanted.
    if (kIsWeb || _apiKey.isEmpty) return null;
    try {
      final uri = Uri.parse(_baseUrl).replace(queryParameters: {
        'latlng': '$lat,$lon',
        'result_type': 'locality|postal_town|administrative_area_level_2',
        if (language != null) 'language': language,
        'key': _apiKey,
      });
      final response =
          await _httpClient.get(uri).timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) return null;
      return parsePlaceName(jsonDecode(response.body) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('GoogleGeocodingApiClient: $e');
      return null;
    }
  }

  /// First locality-like component of a Geocoding API response.
  @visibleForTesting
  static String? parsePlaceName(Map<String, dynamic> body) {
    const wanted = [
      'locality',
      'postal_town',
      'administrative_area_level_2',
    ];
    final results = body['results'] as List? ?? const [];
    for (final type in wanted) {
      for (final r in results) {
        for (final c in (r as Map)['address_components'] as List? ?? const []) {
          final types = ((c as Map)['types'] as List?)?.cast<String>() ?? [];
          final name = c['long_name'] as String?;
          if (types.contains(type) && name != null && name.isNotEmpty) {
            return name;
          }
        }
      }
    }
    return null;
  }
}
