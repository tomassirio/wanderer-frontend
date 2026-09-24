import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Google Maps styling for the web dark theme, so the map doesn't glow.
/// Colours follow the dark style guide's map card (warm night ground,
/// teal-grey water, olive parks, subtle roads).
class MapStyleHelper {
  MapStyleHelper._();

  /// JSON style for [GoogleMap.style], or null for the default look.
  static String? of(BuildContext context) =>
      kIsWeb && Theme.of(context).brightness == Brightness.dark ? night : null;

  static const String night = '''
[
  {"elementType": "geometry", "stylers": [{"color": "#2E2924"}]},
  {"elementType": "labels.text.fill", "stylers": [{"color": "#C4BBB1"}]},
  {"elementType": "labels.text.stroke", "stylers": [{"color": "#24201C"}]},
  {"featureType": "administrative", "elementType": "geometry.stroke", "stylers": [{"color": "#4A423A"}]},
  {"featureType": "administrative.land_parcel", "stylers": [{"visibility": "off"}]},
  {"featureType": "poi", "elementType": "geometry", "stylers": [{"color": "#39332D"}]},
  {"featureType": "poi", "elementType": "labels.text.fill", "stylers": [{"color": "#9E958B"}]},
  {"featureType": "poi.park", "elementType": "geometry", "stylers": [{"color": "#2C3527"}]},
  {"featureType": "road", "elementType": "geometry", "stylers": [{"color": "#433C35"}]},
  {"featureType": "road", "elementType": "geometry.stroke", "stylers": [{"color": "#2E2924"}]},
  {"featureType": "road", "elementType": "labels.text.fill", "stylers": [{"color": "#9E958B"}]},
  {"featureType": "road.highway", "elementType": "geometry", "stylers": [{"color": "#4F463D"}]},
  {"featureType": "transit", "elementType": "geometry", "stylers": [{"color": "#39332D"}]},
  {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#243538"}]},
  {"featureType": "water", "elementType": "labels.text.fill", "stylers": [{"color": "#5E7A7C"}]}
]
''';
}
