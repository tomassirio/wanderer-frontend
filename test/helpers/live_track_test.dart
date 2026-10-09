import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/presentation/helpers/trip_map_helper.dart';

void main() {
  final t0 = DateTime.utc(2026, 10, 8, 9);
  TrackPoint p(int seconds, double lat, {double? accuracy}) => TrackPoint(
        id: 'p$seconds',
        tripId: 'trip-1',
        lat: lat,
        lon: 5.0,
        accuracyM: accuracy,
        recordedAt: t0.add(Duration(seconds: seconds)),
      );

  group('trackDistanceKm', () {
    test('sums the distance between points', () {
      // 0.001° of latitude ≈ 111 m.
      final km = TripMapHelper.trackDistanceKm(
          [p(0, 52), p(10, 52.001), p(20, 52.002)]);
      expect(km, closeTo(0.222, 0.002));
    });

    test('skips jitter and inaccurate fixes', () {
      final km = TripMapHelper.trackDistanceKm([
        p(0, 52),
        p(5, 52.00002), // ~2 m: jitter
        p(8, 52.01, accuracy: 500), // way off, inaccurate
        p(10, 52.001),
      ]);
      expect(km, closeTo(0.111, 0.002));
    });

    test('is zero for an empty track', () {
      expect(TripMapHelper.trackDistanceKm([]), 0);
    });
  });

  group('withTrack', () {
    final serverRoute = Polyline(
        polylineId: const PolylineId('route'),
        points: const [LatLng(1, 1), LatLng(2, 2)]);
    final data = MapData(markers: const {}, polylines: {serverRoute});

    test('draws the route from the track', () {
      final route = TripMapHelper.withTrack(
          data, [p(0, 52), p(10, 52.001), p(20, 52.002)]).polylines.single;
      expect(route.polylineId.value, 'route');
      expect(route.points, const [
        LatLng(52, 5),
        LatLng(52.001, 5),
        LatLng(52.002, 5),
      ]);
    });

    test('keeps the backend route when there is no track', () {
      expect(TripMapHelper.withTrack(data, []).polylines.single, serverRoute);
      expect(TripMapHelper.withTrack(data, [p(0, 52)]).polylines.single,
          serverRoute);
    });
  });
}
