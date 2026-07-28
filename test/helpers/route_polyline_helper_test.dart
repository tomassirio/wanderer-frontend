import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:wanderer_frontend/data/client/google_directions_api_client.dart';
import 'package:wanderer_frontend/presentation/helpers/route_polyline_helper.dart';

import 'route_polyline_helper_test.mocks.dart';

@GenerateMocks([GoogleDirectionsApiClient])
void main() {
  late MockGoogleDirectionsApiClient mockClient;
  final points = [const LatLng(40.0, -74.0), const LatLng(41.0, -75.0)];

  setUp(() {
    mockClient = MockGoogleDirectionsApiClient();
  });

  group('placeholderPolylines', () {
    test('returns empty set for fewer than 2 points', () {
      final result = RoutePolylineHelper.placeholderPolylines(
        points: [const LatLng(40.0, -74.0)],
        polylineId: 'route',
        color: Colors.blue,
        width: 3,
      );
      expect(result, isEmpty);
    });

    test('returns dashed polylines for 2+ points', () {
      final result = RoutePolylineHelper.placeholderPolylines(
        points: points,
        polylineId: 'route',
        color: Colors.blue,
        width: 3,
      );
      expect(result, isNotEmpty);
    });
  });

  group('computeRoute', () {
    test('returns empty result for fewer than 2 points', () async {
      final result = await RoutePolylineHelper.computeRoute(
        points: [const LatLng(40.0, -74.0)],
        directionsClient: mockClient,
        polylineId: 'route',
        color: Colors.blue,
        width: 5,
      );
      expect(result.polylines, isEmpty);
      expect(result.encodedPolyline, isNull);
      verifyZeroInteractions(mockClient);
    });

    test('returns the API route when available', () async {
      when(mockClient.getRouteWithPoints(points)).thenAnswer(
        (_) async => DirectionsResult(
          encodedPolyline: 'encoded123',
          routePoints: points,
        ),
      );
      final result = await RoutePolylineHelper.computeRoute(
        points: points,
        directionsClient: mockClient,
        polylineId: 'route',
        color: Colors.blue,
        width: 5,
      );
      expect(result.encodedPolyline, 'encoded123');
      expect(result.polylines, hasLength(1));
      expect(result.polylines.first.polylineId.value, 'route');
    });

    test('falls back to straight-line encoding when the API returns null',
        () async {
      when(mockClient.getRouteWithPoints(points))
          .thenAnswer((_) async => null);
      final result = await RoutePolylineHelper.computeRoute(
        points: points,
        directionsClient: mockClient,
        polylineId: 'route',
        color: Colors.blue,
        width: 5,
      );
      expect(result.polylines, isEmpty);
      expect(result.encodedPolyline, isNotNull);
    });

    test('falls back to straight-line encoding when the API throws',
        () async {
      when(mockClient.getRouteWithPoints(points))
          .thenThrow(Exception('network down'));
      final result = await RoutePolylineHelper.computeRoute(
        points: points,
        directionsClient: mockClient,
        polylineId: 'route',
        color: Colors.blue,
        width: 5,
      );
      expect(result.polylines, isEmpty);
      expect(result.encodedPolyline, isNotNull);
    });
  });
}
