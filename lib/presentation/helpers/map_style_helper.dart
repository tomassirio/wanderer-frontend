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
  {"elementType": "geometry", "stylers": [{"color": "#24211D"}]},
  {"elementType": "labels.text.fill", "stylers": [{"color": "#B5AEA6"}]},
  {"elementType": "labels.text.stroke", "stylers": [{"color": "#151311"}]},
  {"featureType": "administrative", "elementType": "geometry.stroke", "stylers": [{"color": "#36312B"}]},
  {"featureType": "administrative.land_parcel", "stylers": [{"visibility": "off"}]},
  {"featureType": "poi", "elementType": "geometry", "stylers": [{"color": "#2A2622"}]},
  {"featureType": "poi", "elementType": "labels.text.fill", "stylers": [{"color": "#8A837B"}]},
  {"featureType": "poi.park", "elementType": "geometry", "stylers": [{"color": "#23291F"}]},
  {"featureType": "road", "elementType": "geometry", "stylers": [{"color": "#302B26"}]},
  {"featureType": "road", "elementType": "geometry.stroke", "stylers": [{"color": "#1F1C19"}]},
  {"featureType": "road", "elementType": "labels.text.fill", "stylers": [{"color": "#8A837B"}]},
  {"featureType": "road.highway", "elementType": "geometry", "stylers": [{"color": "#3A342D"}]},
  {"featureType": "transit", "elementType": "geometry", "stylers": [{"color": "#2A2622"}]},
  {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#1C2A2B"}]},
  {"featureType": "water", "elementType": "labels.text.fill", "stylers": [{"color": "#5E7A7C"}]}
]
''';
}
