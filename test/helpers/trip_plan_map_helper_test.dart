import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:wanderer_frontend/presentation/helpers/trip_plan_map_helper.dart';

void main() {
  group('calculateBoundsForPoints', () {
    test('returns null for an empty list', () {
      expect(TripPlanMapHelper.calculateBoundsForPoints([]), isNull);
    });

    test('returns bounds spanning all points', () {
      final bounds = TripPlanMapHelper.calculateBoundsForPoints([
        const LatLng(40.0, -75.0),
        const LatLng(41.0, -74.0),
      ]);
      expect(bounds, isNotNull);
      expect(bounds!.southwest.latitude, 40.0);
      expect(bounds.southwest.longitude, -75.0);
      expect(bounds.northeast.latitude, 41.0);
      expect(bounds.northeast.longitude, -74.0);
    });
  });
}
