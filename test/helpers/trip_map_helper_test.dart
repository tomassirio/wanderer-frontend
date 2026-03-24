import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:wanderer_frontend/core/constants/enums.dart';
import 'package:wanderer_frontend/data/models/domain/trip.dart';
import 'package:wanderer_frontend/data/models/domain/trip_location.dart';
import 'package:wanderer_frontend/presentation/helpers/trip_map_helper.dart';

void main() {
  group('TripMapHelper', () {
    group('getInitialZoom', () {
      test('returns 12 when trip has locations', () {
        final trip = _createTrip(locations: [
          _createLocation(
            id: 'loc1',
            lat: 40.0,
            lng: -74.0,
            timestamp: DateTime(2025, 1, 1),
          ),
        ]);
        expect(TripMapHelper.getInitialZoom(trip), 12);
      });

      test('returns 12 when trip has locations even with userLocation', () {
        final trip = _createTrip(locations: [
          _createLocation(
            id: 'loc1',
            lat: 40.0,
            lng: -74.0,
            timestamp: DateTime(2025, 1, 1),
          ),
        ]);
        expect(
          TripMapHelper.getInitialZoom(trip,
              userLocation: const LatLng(41.0, -73.0)),
          12,
        );
      });

      test('returns 10 when trip has planned route', () {
        final trip = _createTrip(
          plannedStartLocation:
              PlannedWaypoint(latitude: 40.0, longitude: -74.0),
        );
        expect(TripMapHelper.getInitialZoom(trip), 10);
      });

      test('returns 10 when trip has planned route even with userLocation', () {
        final trip = _createTrip(
          plannedStartLocation:
              PlannedWaypoint(latitude: 40.0, longitude: -74.0),
        );
        expect(
          TripMapHelper.getInitialZoom(trip,
              userLocation: const LatLng(41.0, -73.0)),
          10,
        );
      });

      test('returns 14 when trip has no data but userLocation is provided', () {
        final trip = _createTrip();
        expect(
          TripMapHelper.getInitialZoom(trip,
              userLocation: const LatLng(41.0, -73.0)),
          14,
        );
      });

      test('returns 4 when trip has no data and no userLocation', () {
        final trip = _createTrip();
        expect(TripMapHelper.getInitialZoom(trip), 4);
      });
    });

    group('getInitialLocation', () {
      test('returns last valid location when trip has locations', () {
        final trip = _createTrip(locations: [
          _createLocation(
            id: 'loc1',
            lat: 40.0,
            lng: -74.0,
            timestamp: DateTime(2025, 1, 1, 10, 0),
          ),
          _createLocation(
            id: 'loc2',
            lat: 41.0,
            lng: -73.0,
            timestamp: DateTime(2025, 1, 1, 12, 0),
          ),
        ]);
        final result = TripMapHelper.getInitialLocation(trip);
        expect(result.latitude, 41.0);
        expect(result.longitude, -73.0);
      });

      test('returns planned start when trip has no locations but has plan', () {
        final trip = _createTrip(
          plannedStartLocation:
              PlannedWaypoint(latitude: 35.0, longitude: -118.0),
        );
        final result = TripMapHelper.getInitialLocation(trip);
        expect(result.latitude, 35.0);
        expect(result.longitude, -118.0);
      });

      test('returns userLocation when trip has no data', () {
        final trip = _createTrip();
        final userLoc = const LatLng(51.5, -0.1);
        final result =
            TripMapHelper.getInitialLocation(trip, userLocation: userLoc);
        expect(result.latitude, 51.5);
        expect(result.longitude, -0.1);
      });

      test('returns NYC default when trip has no data and no userLocation', () {
        final trip = _createTrip();
        final result = TripMapHelper.getInitialLocation(trip);
        expect(result.latitude, 40.7128);
        expect(result.longitude, -74.0060);
      });

      test('prefers trip locations over userLocation', () {
        final trip = _createTrip(locations: [
          _createLocation(
            id: 'loc1',
            lat: 48.8,
            lng: 2.3,
            timestamp: DateTime(2025, 1, 1),
          ),
        ]);
        final result = TripMapHelper.getInitialLocation(trip,
            userLocation: const LatLng(51.5, -0.1));
        expect(result.latitude, 48.8);
        expect(result.longitude, 2.3);
      });

      test('prefers planned start over userLocation', () {
        final trip = _createTrip(
          plannedStartLocation:
              PlannedWaypoint(latitude: 35.0, longitude: -118.0),
        );
        final result = TripMapHelper.getInitialLocation(trip,
            userLocation: const LatLng(51.5, -0.1));
        expect(result.latitude, 35.0);
        expect(result.longitude, -118.0);
      });

      test('skips lifecycle markers without real coordinates', () {
        final trip = _createTrip(locations: [
          TripLocation(
            id: 'lifecycle1',
            latitude: 0.0,
            longitude: 0.0,
            timestamp: DateTime(2025, 1, 1),
            updateType: TripUpdateType.tripStarted,
          ),
        ]);
        final userLoc = const LatLng(42.0, -71.0);
        final result =
            TripMapHelper.getInitialLocation(trip, userLocation: userLoc);
        // Lifecycle marker with 0,0 should be skipped; falls back to user loc
        expect(result.latitude, 42.0);
        expect(result.longitude, -71.0);
      });
    });

    group('createMapData - tripStarted/tripEnded on map', () {
      test('tripStarted with real location appears as marker', () {
        final trip = _createTrip(locations: [
          TripLocation(
            id: 'trip-start',
            latitude: 40.0,
            longitude: -74.0,
            timestamp: DateTime(2025, 1, 1, 8, 0),
            updateType: TripUpdateType.tripStarted,
          ),
          _createLocation(
            id: 'loc1',
            lat: 40.5,
            lng: -73.5,
            timestamp: DateTime(2025, 1, 1, 12, 0),
          ),
        ]);
        final mapData = TripMapHelper.createMapData(trip);
        // Both the tripStarted marker and the regular update should be present
        expect(mapData.markers.length, 2);
        expect(
          mapData.markers.any((m) => m.markerId.value == 'trip-start'),
          true,
        );
      });

      test('tripEnded with real location appears as marker', () {
        final trip = _createTrip(locations: [
          _createLocation(
            id: 'loc1',
            lat: 40.0,
            lng: -74.0,
            timestamp: DateTime(2025, 1, 1, 8, 0),
          ),
          TripLocation(
            id: 'trip-end',
            latitude: 41.0,
            longitude: -73.0,
            timestamp: DateTime(2025, 1, 1, 18, 0),
            updateType: TripUpdateType.tripEnded,
          ),
        ]);
        final mapData = TripMapHelper.createMapData(trip);
        expect(mapData.markers.length, 2);
        expect(
          mapData.markers.any((m) => m.markerId.value == 'trip-end'),
          true,
        );
      });

      test('tripStarted without location gets fallback to first real location',
          () {
        final trip = _createTrip(locations: [
          TripLocation(
            id: 'trip-start',
            latitude: 0.0,
            longitude: 0.0,
            timestamp: DateTime(2025, 1, 1, 8, 0),
            updateType: TripUpdateType.tripStarted,
          ),
          TripLocation(
            id: 'loc1',
            latitude: 40.0,
            longitude: -74.0,
            timestamp: DateTime(2025, 1, 1, 12, 0),
            city: 'New York',
            country: 'United States',
          ),
        ]);
        final mapData = TripMapHelper.createMapData(trip);
        // tripStarted should be present with fallback position
        expect(mapData.markers.length, 2);
        final startMarker =
            mapData.markers.firstWhere((m) => m.markerId.value == 'trip-start');
        expect(startMarker.position.latitude, 40.0);
        expect(startMarker.position.longitude, -74.0);
      });

      test('tripEnded without location gets fallback to last real location',
          () {
        final trip = _createTrip(locations: [
          _createLocation(
            id: 'loc1',
            lat: 40.0,
            lng: -74.0,
            timestamp: DateTime(2025, 1, 1, 8, 0),
          ),
          TripLocation(
            id: 'loc2',
            latitude: 41.0,
            longitude: -73.0,
            timestamp: DateTime(2025, 1, 1, 14, 0),
            city: 'Newark',
            country: 'United States',
          ),
          TripLocation(
            id: 'trip-end',
            latitude: 0.0,
            longitude: 0.0,
            timestamp: DateTime(2025, 1, 1, 18, 0),
            updateType: TripUpdateType.tripEnded,
          ),
        ]);
        final mapData = TripMapHelper.createMapData(trip);
        expect(mapData.markers.length, 3);
        final endMarker =
            mapData.markers.firstWhere((m) => m.markerId.value == 'trip-end');
        // Should fallback to last real location (loc2)
        expect(endMarker.position.latitude, 41.0);
        expect(endMarker.position.longitude, -73.0);
      });

      test('dayStart/dayEnd without location get fallback positions', () {
        final trip = _createTrip(locations: [
          TripLocation(
            id: 'day-start',
            latitude: 0.0,
            longitude: 0.0,
            timestamp: DateTime(2025, 1, 1, 7, 0),
            updateType: TripUpdateType.dayStart,
          ),
          TripLocation(
            id: 'loc1',
            latitude: 40.0,
            longitude: -74.0,
            timestamp: DateTime(2025, 1, 1, 12, 0),
            city: 'New York',
            country: 'United States',
          ),
          TripLocation(
            id: 'day-end',
            latitude: 0.0,
            longitude: 0.0,
            timestamp: DateTime(2025, 1, 1, 22, 0),
            updateType: TripUpdateType.dayEnd,
          ),
        ]);
        final mapData = TripMapHelper.createMapData(trip);
        // All three markers should appear (dayStart, regular, dayEnd)
        expect(mapData.markers.length, 3);
        expect(
          mapData.markers.any((m) => m.markerId.value == 'day-start'),
          true,
        );
        expect(
          mapData.markers.any((m) => m.markerId.value == 'loc1'),
          true,
        );
        expect(
          mapData.markers.any((m) => m.markerId.value == 'day-end'),
          true,
        );
        // dayStart/dayEnd should have fallback positions from nearest real loc
        final dayStartMarker =
            mapData.markers.firstWhere((m) => m.markerId.value == 'day-start');
        expect(dayStartMarker.position.latitude, 40.0);
        expect(dayStartMarker.position.longitude, -74.0);
        final dayEndMarker =
            mapData.markers.firstWhere((m) => m.markerId.value == 'day-end');
        expect(dayEndMarker.position.latitude, 40.0);
        expect(dayEndMarker.position.longitude, -74.0);
      });
    });
  });
}

/// Helper to create a Trip for testing
Trip _createTrip({
  String id = 'test-trip-id',
  List<TripLocation>? locations,
  String? encodedPolyline,
  String? plannedEncodedPolyline,
  PlannedWaypoint? plannedStartLocation,
  PlannedWaypoint? plannedEndLocation,
  List<PlannedWaypoint>? plannedWaypoints,
}) {
  return Trip(
    id: id,
    userId: 'user-1',
    name: 'Test Trip',
    username: 'testuser',
    visibility: Visibility.public,
    status: TripStatus.created,
    createdAt: DateTime(2025, 1, 1),
    updatedAt: DateTime(2025, 1, 1),
    locations: locations,
    encodedPolyline: encodedPolyline,
    plannedEncodedPolyline: plannedEncodedPolyline,
    plannedStartLocation: plannedStartLocation,
    plannedEndLocation: plannedEndLocation,
    plannedWaypoints: plannedWaypoints,
  );
}

/// Helper to create a TripLocation for testing
TripLocation _createLocation({
  required String id,
  required double lat,
  required double lng,
  required DateTime timestamp,
}) {
  return TripLocation(
    id: id,
    latitude: lat,
    longitude: lng,
    timestamp: timestamp,
  );
}
