import 'package:flutter_test/flutter_test.dart';
import 'package:wanderer_frontend/core/constants/enums.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';

void main() {
  group('TripModels', () {
    group('CreateTripRequest', () {
      test('toJson converts CreateTripRequest correctly', () {
        final request = CreateTripRequest(
          name: 'My Trip',
          description: 'A great adventure',
          visibility: Visibility.public,
          startDate: DateTime(2024, 1, 1),
        );

        final json = request.toJson();

        expect(json['name'], 'My Trip');
        expect(json['description'], 'A great adventure');
        expect(json['visibility'], 'PUBLIC');
        expect(json['startDate'], '2024-01-01T00:00:00.000');
      });

      test('toJson excludes null values', () {
        final request = CreateTripRequest(
          name: 'My Trip',
          visibility: Visibility.private,
        );

        final json = request.toJson();

        expect(json.containsKey('description'), false);
        expect(json.containsKey('startDate'), false);
        expect(json.containsKey('endDate'), false);
        expect(json.containsKey('automaticUpdates'), false);
        expect(json.containsKey('updateRefresh'), false);
      });

      test('toJson includes automaticUpdates and updateRefresh when set', () {
        final request = CreateTripRequest(
          name: 'My Trip',
          visibility: Visibility.public,
          automaticUpdates: true,
          updateRefresh: 900,
        );

        final json = request.toJson();

        expect(json['automaticUpdates'], true);
        expect(json['updateRefresh'], 900);
      });

      test('toJson excludes automaticUpdates and updateRefresh when null', () {
        final request = CreateTripRequest(
          name: 'My Trip',
          visibility: Visibility.public,
        );

        final json = request.toJson();

        expect(json.containsKey('automaticUpdates'), false);
        expect(json.containsKey('updateRefresh'), false);
      });
    });

    group('Trip', () {
      test('fromJson creates Trip from JSON', () {
        final json = {
          'id': 'trip123',
          'userId': 'user456',
          'name': 'My Trip',
          'description': 'A great adventure',
          'visibility': 'PUBLIC',
          'status': 'IN_PROGRESS',
          'commentsCount': 5,
          'reactionsCount': 10,
          'createdAt': '2024-01-01T00:00:00.000Z',
          'updatedAt': '2024-01-02T00:00:00.000Z',
        };

        final trip = Trip.fromJson(json);

        expect(trip.id, 'trip123');
        expect(trip.userId, 'user456');
        expect(trip.name, 'My Trip');
        expect(trip.description, 'A great adventure');
        expect(trip.visibility, Visibility.public);
        expect(trip.status, TripStatus.inProgress);
        expect(trip.commentsCount, 5);
        expect(trip.reactionsCount, 10);
      });

      test('toJson converts Trip correctly', () {
        final trip = Trip(
          id: 'trip123',
          userId: 'user456',
          username: "username",
          name: 'My Trip',
          description: 'A great adventure',
          visibility: Visibility.public,
          status: TripStatus.inProgress,
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 2),
        );

        final json = trip.toJson();

        expect(json['id'], 'trip123');
        expect(json['userId'], 'user456');
        expect(json['name'], 'My Trip');
        expect(json['visibility'], 'PUBLIC');
        expect(json['status'], 'IN_PROGRESS');
      });

      test('fromJson parses encodedPolyline and polylineUpdatedAt', () {
        final json = {
          'id': 'trip123',
          'userId': 'user456',
          'name': 'My Trip',
          'visibility': 'PUBLIC',
          'status': 'IN_PROGRESS',
          'createdAt': '2024-01-01T00:00:00.000Z',
          'updatedAt': '2024-01-02T00:00:00.000Z',
          'encodedPolyline': 'a~l~Fjk~uOwHJy@P',
          'polylineUpdatedAt': '2024-01-02T10:30:00.000Z',
        };

        final trip = Trip.fromJson(json);

        expect(trip.encodedPolyline, 'a~l~Fjk~uOwHJy@P');
        expect(trip.polylineUpdatedAt, DateTime.utc(2024, 1, 2, 10, 30));
      });

      test('fromJson handles missing encodedPolyline gracefully', () {
        final json = {
          'id': 'trip123',
          'userId': 'user456',
          'name': 'My Trip',
          'visibility': 'PUBLIC',
          'status': 'CREATED',
          'createdAt': '2024-01-01T00:00:00.000Z',
          'updatedAt': '2024-01-01T00:00:00.000Z',
        };

        final trip = Trip.fromJson(json);

        expect(trip.encodedPolyline, isNull);
        expect(trip.polylineUpdatedAt, isNull);
      });

      test('toJson includes encodedPolyline when present', () {
        final trip = Trip(
          id: 'trip123',
          userId: 'user456',
          username: 'username',
          name: 'My Trip',
          visibility: Visibility.public,
          status: TripStatus.inProgress,
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 2),
          encodedPolyline: 'a~l~Fjk~uOwHJy@P',
          polylineUpdatedAt: DateTime(2024, 1, 2, 10, 30),
        );

        final json = trip.toJson();

        expect(json['encodedPolyline'], 'a~l~Fjk~uOwHJy@P');
        expect(json.containsKey('polylineUpdatedAt'), true);
      });

      test('toJson excludes encodedPolyline when null', () {
        final trip = Trip(
          id: 'trip123',
          userId: 'user456',
          username: 'username',
          name: 'My Trip',
          visibility: Visibility.public,
          status: TripStatus.inProgress,
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 2),
        );

        final json = trip.toJson();

        expect(json.containsKey('encodedPolyline'), false);
        expect(json.containsKey('polylineUpdatedAt'), false);
      });

      test('copyWith preserves encodedPolyline', () {
        final trip = Trip(
          id: 'trip123',
          userId: 'user456',
          username: 'username',
          name: 'My Trip',
          visibility: Visibility.public,
          status: TripStatus.inProgress,
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 2),
          encodedPolyline: 'a~l~Fjk~uOwHJy@P',
        );

        final updated = trip.copyWith(name: 'Updated Trip');

        expect(updated.name, 'Updated Trip');
        expect(updated.encodedPolyline, 'a~l~Fjk~uOwHJy@P');
      });
    });

    group('ChangeVisibilityRequest', () {
      test('toJson converts ChangeVisibilityRequest correctly', () {
        final request = ChangeVisibilityRequest(
          visibility: Visibility.protected,
        );

        final json = request.toJson();

        expect(json['visibility'], 'PROTECTED');
      });
    });

    group('ChangeStatusRequest', () {
      test('toJson converts ChangeStatusRequest correctly', () {
        final request = ChangeStatusRequest(status: TripStatus.finished);

        final json = request.toJson();

        expect(json['status'], 'FINISHED');
      });
    });

    group('TripUpdateRequest', () {
      test('toJson converts TripUpdateRequest correctly', () {
        final request = TripUpdateRequest(
          latitude: 40.7128,
          longitude: -74.0060,
          message: 'Hello from NYC!',
        );

        final json = request.toJson();

        expect(json['location']['lat'], 40.7128);
        expect(json['location']['lon'], -74.0060);
        expect(json['message'], 'Hello from NYC!');
      });

      test('toJson includes battery when provided', () {
        final request = TripUpdateRequest(
          latitude: 40.7128,
          longitude: -74.0060,
          battery: 85,
        );

        final json = request.toJson();

        expect(json['battery'], 85);
      });

      test('toJson excludes optional fields when null', () {
        final request = TripUpdateRequest(
          latitude: 40.7128,
          longitude: -74.0060,
        );

        final json = request.toJson();

        expect(json.containsKey('message'), isFalse);
        expect(json.containsKey('imageUrl'), isFalse);
        expect(json.containsKey('battery'), isFalse);
      });

      test('toJson handles zero battery level', () {
        final request = TripUpdateRequest(
          latitude: 0.0,
          longitude: 0.0,
          battery: 0,
        );

        final json = request.toJson();
        expect(json['battery'], 0);
      });

      test('toJson handles negative coordinates', () {
        final request = TripUpdateRequest(
          latitude: -33.8688,
          longitude: -151.2093,
        );

        final json = request.toJson();
        final location = json['location'] as Map<String, dynamic>;

        expect(location['lat'], -33.8688);
        expect(location['lon'], -151.2093);
      });
    });

    group('Trip updateRefresh', () {
      test('defaultUpdateRefresh is 30 minutes (1800 seconds)', () {
        expect(Trip.defaultUpdateRefresh, 1800);
      });

      test('minUpdateRefresh is 1 minute (60 seconds)', () {
        expect(Trip.minUpdateRefresh, 60);
      });

      test(
          'effectiveUpdateRefresh returns updateRefresh when set and above minimum',
          () {
        final trip = Trip(
          id: 'trip123',
          userId: 'user456',
          username: 'testuser',
          name: 'Test Trip',
          visibility: Visibility.public,
          status: TripStatus.inProgress,
          updateRefresh: 3600, // 1 hour
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(trip.effectiveUpdateRefresh, 3600);
      });

      test('effectiveUpdateRefresh returns default when updateRefresh is null',
          () {
        final trip = Trip(
          id: 'trip123',
          userId: 'user456',
          username: 'testuser',
          name: 'Test Trip',
          visibility: Visibility.public,
          status: TripStatus.inProgress,
          updateRefresh: null,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(trip.effectiveUpdateRefresh, Trip.defaultUpdateRefresh);
      });

      test('effectiveUpdateRefresh clamps to minimum when below threshold', () {
        final trip = Trip(
          id: 'trip123',
          userId: 'user456',
          username: 'testuser',
          name: 'Test Trip',
          visibility: Visibility.public,
          status: TripStatus.inProgress,
          updateRefresh: 30, // 30 seconds - below minimum
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(trip.effectiveUpdateRefresh, Trip.minUpdateRefresh);
      });

      test('effectiveUpdateRefresh returns exactly minimum when set to minimum',
          () {
        final trip = Trip(
          id: 'trip123',
          userId: 'user456',
          username: 'testuser',
          name: 'Test Trip',
          visibility: Visibility.public,
          status: TripStatus.inProgress,
          updateRefresh: Trip.minUpdateRefresh,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(trip.effectiveUpdateRefresh, Trip.minUpdateRefresh);
      });

      test('effectiveUpdateRefresh handles zero updateRefresh', () {
        final trip = Trip(
          id: 'trip123',
          userId: 'user456',
          username: 'testuser',
          name: 'Test Trip',
          visibility: Visibility.public,
          status: TripStatus.inProgress,
          updateRefresh: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Zero should be clamped to minimum
        expect(trip.effectiveUpdateRefresh, Trip.minUpdateRefresh);
      });
    });

    group('Trip automaticUpdates', () {
      test('automaticUpdates defaults to false when not provided', () {
        final trip = Trip(
          id: 'trip123',
          userId: 'user456',
          username: 'testuser',
          name: 'Test Trip',
          visibility: Visibility.public,
          status: TripStatus.inProgress,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(trip.automaticUpdates, false);
        expect(trip.updateRefresh, null);
      });

      test('automaticUpdates can be set to true with updateRefresh', () {
        final trip = Trip(
          id: 'trip123',
          userId: 'user456',
          username: 'testuser',
          name: 'Test Trip',
          visibility: Visibility.public,
          status: TripStatus.inProgress,
          automaticUpdates: true,
          updateRefresh: 1800, // 30 minutes in seconds
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(trip.automaticUpdates, true);
        expect(trip.updateRefresh, 1800);
      });

      test(
          'fromJson parses automaticUpdates and updateRefresh from tripSettings',
          () {
        final json = {
          'id': 'trip123',
          'userId': 'user456',
          'username': 'testuser',
          'name': 'Test Trip',
          'visibility': 'PUBLIC',
          'status': 'IN_PROGRESS',
          'tripSettings': {
            'automaticUpdates': true,
            'updateRefresh': 2700, // 45 minutes in seconds
          },
          'createdAt': '2024-01-01T00:00:00.000Z',
          'updatedAt': '2024-01-02T00:00:00.000Z',
        };

        final trip = Trip.fromJson(json);

        expect(trip.automaticUpdates, true);
        expect(trip.updateRefresh, 2700);
      });

      test('fromJson defaults automaticUpdates to false when not in JSON', () {
        final json = {
          'id': 'trip123',
          'userId': 'user456',
          'username': 'testuser',
          'name': 'Test Trip',
          'visibility': 'PUBLIC',
          'status': 'IN_PROGRESS',
          'createdAt': '2024-01-01T00:00:00.000Z',
          'updatedAt': '2024-01-02T00:00:00.000Z',
        };

        final trip = Trip.fromJson(json);

        expect(trip.automaticUpdates, false);
        expect(trip.updateRefresh, null);
      });

      test(
          'fromJson parses automaticUpdates and updateRefresh from top-level keys',
          () {
        final json = {
          'id': 'trip123',
          'userId': 'user456',
          'username': 'testuser',
          'name': 'Test Trip',
          'visibility': 'PUBLIC',
          'status': 'IN_PROGRESS',
          'automaticUpdates': true,
          'updateRefresh': 900,
          'tripModality': 'SIMPLE',
          'createdAt': '2024-01-01T00:00:00.000Z',
          'updatedAt': '2024-01-02T00:00:00.000Z',
        };

        final trip = Trip.fromJson(json);

        expect(trip.automaticUpdates, true);
        expect(trip.updateRefresh, 900);
        expect(trip.tripModality, TripModality.simple);
      });

      test(
          'fromJson prefers tripSettings over top-level keys for automaticUpdates',
          () {
        final json = {
          'id': 'trip123',
          'userId': 'user456',
          'username': 'testuser',
          'name': 'Test Trip',
          'visibility': 'PUBLIC',
          'status': 'IN_PROGRESS',
          'automaticUpdates': false,
          'updateRefresh': 300,
          'tripSettings': {
            'automaticUpdates': true,
            'updateRefresh': 1800,
          },
          'createdAt': '2024-01-01T00:00:00.000Z',
          'updatedAt': '2024-01-02T00:00:00.000Z',
        };

        final trip = Trip.fromJson(json);

        // tripSettings should take priority over top-level
        expect(trip.automaticUpdates, true);
        expect(trip.updateRefresh, 1800);
      });

      test('toJson includes automaticUpdates and updateRefresh', () {
        final trip = Trip(
          id: 'trip123',
          userId: 'user456',
          username: 'testuser',
          name: 'Test Trip',
          visibility: Visibility.public,
          status: TripStatus.inProgress,
          automaticUpdates: true,
          updateRefresh: 3600, // 60 minutes in seconds
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 2),
        );

        final json = trip.toJson();

        expect(json['automaticUpdates'], true);
        expect(json['updateRefresh'], 3600);
      });

      test('copyWith updates automaticUpdates and updateRefresh', () {
        final trip = Trip(
          id: 'trip123',
          userId: 'user456',
          username: 'testuser',
          name: 'Test Trip',
          visibility: Visibility.public,
          status: TripStatus.inProgress,
          automaticUpdates: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final updatedTrip = trip.copyWith(
          automaticUpdates: true,
          updateRefresh: 1800, // 30 minutes in seconds
        );

        expect(updatedTrip.automaticUpdates, true);
        expect(updatedTrip.updateRefresh, 1800);
        expect(updatedTrip.id, trip.id);
        expect(updatedTrip.name, trip.name);
      });
    });

    group('ChangeTripSettingsRequest', () {
      test(
          'toJson converts ChangeTripSettingsRequest correctly with both fields',
          () {
        final request = ChangeTripSettingsRequest(
          automaticUpdates: true,
          updateRefresh: 1800, // 30 minutes in seconds
        );

        final json = request.toJson();

        expect(json['automaticUpdates'], true);
        expect(json['updateRefresh'], 1800);
      });

      test('toJson excludes null values', () {
        final request = ChangeTripSettingsRequest(
          automaticUpdates: true,
        );

        final json = request.toJson();

        expect(json['automaticUpdates'], true);
        expect(json.containsKey('updateRefresh'), false);
      });

      test('toJson handles only updateRefresh', () {
        final request = ChangeTripSettingsRequest(
          updateRefresh: 2700, // 45 minutes in seconds
        );

        final json = request.toJson();

        expect(json.containsKey('automaticUpdates'), false);
        expect(json['updateRefresh'], 2700);
      });

      test('toJson with automaticUpdates false', () {
        final request = ChangeTripSettingsRequest(
          automaticUpdates: false,
        );

        final json = request.toJson();

        expect(json['automaticUpdates'], false);
      });
    });

    group('TripModality', () {
      test('toJson converts simple modality correctly', () {
        expect(TripModality.simple.toJson(), 'SIMPLE');
      });

      test('toJson converts multiDay modality correctly', () {
        expect(TripModality.multiDay.toJson(), 'MULTI_DAY');
      });

      test('fromJson parses SIMPLE correctly', () {
        expect(TripModality.fromJson('SIMPLE'), TripModality.simple);
      });

      test('fromJson parses MULTI_DAY correctly', () {
        expect(TripModality.fromJson('MULTI_DAY'), TripModality.multiDay);
      });

      test('fromJson is case-insensitive', () {
        expect(TripModality.fromJson('simple'), TripModality.simple);
        expect(TripModality.fromJson('multi_day'), TripModality.multiDay);
      });

      test('fromJson throws for invalid value', () {
        expect(
          () => TripModality.fromJson('INVALID'),
          throwsArgumentError,
        );
      });
    });

    group('TripStatus resting', () {
      test('toJson converts resting status correctly', () {
        expect(TripStatus.resting.toJson(), 'RESTING');
      });

      test('fromJson parses RESTING correctly', () {
        expect(TripStatus.fromJson('RESTING'), TripStatus.resting);
      });

      test('displayLabel for resting is Resting', () {
        expect(TripStatus.resting.displayLabel, 'Resting');
      });
    });

    group('CreateTripRequest with tripModality', () {
      test('toJson includes tripModality when set', () {
        final request = CreateTripRequest(
          name: 'My Trip',
          visibility: Visibility.public,
          tripModality: TripModality.multiDay,
        );

        final json = request.toJson();

        expect(json['tripModality'], 'MULTI_DAY');
      });

      test('toJson excludes tripModality when null', () {
        final request = CreateTripRequest(
          name: 'My Trip',
          visibility: Visibility.public,
        );

        final json = request.toJson();

        expect(json.containsKey('tripModality'), false);
      });
    });

    group('ChangeTripSettingsRequest with tripModality', () {
      test('toJson includes tripModality when set', () {
        final request = ChangeTripSettingsRequest(
          automaticUpdates: true,
          tripModality: TripModality.multiDay,
        );

        final json = request.toJson();

        expect(json['tripModality'], 'MULTI_DAY');
      });

      test('toJson excludes tripModality when null', () {
        final request = ChangeTripSettingsRequest(
          automaticUpdates: true,
        );

        final json = request.toJson();

        expect(json.containsKey('tripModality'), false);
      });
    });

    group('Trip tripModality', () {
      test('fromJson parses tripModality from tripSettings', () {
        final json = {
          'id': 'trip123',
          'userId': 'user456',
          'name': 'My Trip',
          'visibility': 'PUBLIC',
          'status': 'IN_PROGRESS',
          'tripSettings': {
            'tripModality': 'MULTI_DAY',
          },
          'createdAt': '2024-01-01T00:00:00.000Z',
          'updatedAt': '2024-01-02T00:00:00.000Z',
        };

        final trip = Trip.fromJson(json);

        expect(trip.tripModality, TripModality.multiDay);
      });

      test('fromJson defaults tripModality to null when absent', () {
        final json = {
          'id': 'trip123',
          'userId': 'user456',
          'name': 'My Trip',
          'visibility': 'PUBLIC',
          'status': 'IN_PROGRESS',
          'createdAt': '2024-01-01T00:00:00.000Z',
          'updatedAt': '2024-01-02T00:00:00.000Z',
        };

        final trip = Trip.fromJson(json);

        expect(trip.tripModality, isNull);
      });

      test('toJson includes tripModality when set', () {
        final trip = Trip(
          id: 'trip123',
          userId: 'user456',
          username: 'testuser',
          name: 'Test Trip',
          visibility: Visibility.public,
          status: TripStatus.inProgress,
          tripModality: TripModality.simple,
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 2),
        );

        final json = trip.toJson();

        expect(json['tripModality'], 'SIMPLE');
      });

      test('toJson excludes tripModality when null', () {
        final trip = Trip(
          id: 'trip123',
          userId: 'user456',
          username: 'testuser',
          name: 'Test Trip',
          visibility: Visibility.public,
          status: TripStatus.inProgress,
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 2),
        );

        final json = trip.toJson();

        expect(json.containsKey('tripModality'), false);
      });

      test('copyWith preserves tripModality when not overridden', () {
        final trip = Trip(
          id: 'trip123',
          userId: 'user456',
          username: 'testuser',
          name: 'Test Trip',
          visibility: Visibility.public,
          status: TripStatus.inProgress,
          tripModality: TripModality.multiDay,
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 2),
        );

        final updated = trip.copyWith(name: 'Updated Trip');

        expect(updated.tripModality, TripModality.multiDay);
      });

      test('copyWith updates tripModality when provided', () {
        final trip = Trip(
          id: 'trip123',
          userId: 'user456',
          username: 'testuser',
          name: 'Test Trip',
          visibility: Visibility.public,
          status: TripStatus.inProgress,
          tripModality: TripModality.simple,
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 2),
        );

        final updated = trip.copyWith(tripModality: TripModality.multiDay);

        expect(updated.tripModality, TripModality.multiDay);
      });

      test('copyWith updates tripDays and currentDay', () {
        final trip = Trip(
          id: 'trip123',
          userId: 'user456',
          username: 'testuser',
          name: 'Test Trip',
          visibility: Visibility.public,
          status: TripStatus.inProgress,
          tripModality: TripModality.multiDay,
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 2),
        );

        final days = [
          TripDay(
            id: 'day-1',
            tripId: 'trip123',
            dayNumber: 1,
            startTimestamp: DateTime(2024, 1, 1),
          ),
        ];

        final updated = trip.copyWith(tripDays: days, currentDay: 2);

        expect(updated.tripDays, isNotNull);
        expect(updated.tripDays!.length, 1);
        expect(updated.currentDay, 2);
      });

      test('fromJson parses tripDays and currentDay', () {
        final json = {
          'id': 'trip123',
          'userId': 'user456',
          'name': 'Multi Day Trip',
          'username': 'testuser',
          'status': 'IN_PROGRESS',
          'visibility': 'PUBLIC',
          'creationTimestamp': '2024-01-01T00:00:00.000Z',
          'tripSettings': {
            'tripModality': 'MULTI_DAY',
          },
          'tripDetails': {
            'currentDay': 3,
          },
          'tripDays': [
            {
              'id': 'day-1',
              'tripId': 'trip123',
              'dayNumber': 1,
              'startTimestamp': '2024-01-01T08:00:00.000Z',
              'endTimestamp': '2024-01-01T18:00:00.000Z',
            },
            {
              'id': 'day-2',
              'tripId': 'trip123',
              'dayNumber': 2,
              'startTimestamp': '2024-01-02T08:00:00.000Z',
              'endTimestamp': '2024-01-02T17:00:00.000Z',
            },
            {
              'id': 'day-3',
              'tripId': 'trip123',
              'dayNumber': 3,
              'startTimestamp': '2024-01-03T09:00:00.000Z',
            },
          ],
        };

        final trip = Trip.fromJson(json);

        expect(trip.tripModality, TripModality.multiDay);
        expect(trip.currentDay, 3);
        expect(trip.tripDays, isNotNull);
        expect(trip.tripDays!.length, 3);
        expect(trip.tripDays![0].dayNumber, 1);
        expect(trip.tripDays![0].endTimestamp, isNotNull);
        expect(trip.tripDays![0].isActive, false);
        expect(trip.tripDays![2].dayNumber, 3);
        expect(trip.tripDays![2].endTimestamp, isNull);
        expect(trip.tripDays![2].isActive, true);
      });
    });

    group('TripDay', () {
      test('fromJson creates TripDay from JSON', () {
        final json = {
          'id': 'day-1',
          'tripId': 'trip-123',
          'dayNumber': 1,
          'startTimestamp': '2024-01-01T08:00:00.000Z',
          'endTimestamp': '2024-01-01T18:00:00.000Z',
        };

        final day = TripDay.fromJson(json);

        expect(day.id, 'day-1');
        expect(day.tripId, 'trip-123');
        expect(day.dayNumber, 1);
        expect(day.startTimestamp, isNotNull);
        expect(day.endTimestamp, isNotNull);
        expect(day.isActive, false);
      });

      test('fromJson creates active TripDay (no endTimestamp)', () {
        final json = {
          'id': 'day-2',
          'tripId': 'trip-123',
          'dayNumber': 2,
          'startTimestamp': '2024-01-02T08:00:00.000Z',
        };

        final day = TripDay.fromJson(json);

        expect(day.id, 'day-2');
        expect(day.dayNumber, 2);
        expect(day.endTimestamp, isNull);
        expect(day.isActive, true);
      });

      test('toJson converts TripDay correctly', () {
        final day = TripDay(
          id: 'day-1',
          tripId: 'trip-123',
          dayNumber: 1,
          startTimestamp: DateTime.utc(2024, 1, 1, 8, 0),
          endTimestamp: DateTime.utc(2024, 1, 1, 18, 0),
        );

        final json = day.toJson();

        expect(json['id'], 'day-1');
        expect(json['tripId'], 'trip-123');
        expect(json['dayNumber'], 1);
        expect(json.containsKey('startTimestamp'), true);
        expect(json.containsKey('endTimestamp'), true);
      });

      test('toJson excludes null endTimestamp', () {
        final day = TripDay(
          id: 'day-1',
          tripId: 'trip-123',
          dayNumber: 1,
          startTimestamp: DateTime.utc(2024, 1, 1, 8, 0),
        );

        final json = day.toJson();

        expect(json.containsKey('endTimestamp'), false);
      });
    });

    group('TripLocation lifecycle markers', () {
      test('regular update is not a lifecycle marker', () {
        final loc = TripLocation(
          id: 'loc-1',
          latitude: 40.0,
          longitude: -74.0,
          timestamp: DateTime.now(),
          updateType: TripUpdateType.regular,
        );

        expect(loc.isLifecycleMarker, false);
        expect(loc.hasLocation, true);
      });

      test('dayStart is a lifecycle marker', () {
        final loc = TripLocation(
          id: 'loc-2',
          latitude: 0.0,
          longitude: 0.0,
          timestamp: DateTime.now(),
          updateType: TripUpdateType.dayStart,
        );

        expect(loc.isLifecycleMarker, true);
        expect(loc.hasLocation, false);
      });

      test('dayEnd is a lifecycle marker', () {
        final loc = TripLocation(
          id: 'loc-3',
          latitude: 0.0,
          longitude: 0.0,
          timestamp: DateTime.now(),
          updateType: TripUpdateType.dayEnd,
        );

        expect(loc.isLifecycleMarker, true);
        expect(loc.hasLocation, false);
      });

      test('tripStarted is a lifecycle marker', () {
        final loc = TripLocation(
          id: 'loc-4',
          latitude: 0.0,
          longitude: 0.0,
          timestamp: DateTime.now(),
          updateType: TripUpdateType.tripStarted,
        );

        expect(loc.isLifecycleMarker, true);
      });

      test('tripEnded is a lifecycle marker', () {
        final loc = TripLocation(
          id: 'loc-5',
          latitude: 0.0,
          longitude: 0.0,
          timestamp: DateTime.now(),
          updateType: TripUpdateType.tripEnded,
        );

        expect(loc.isLifecycleMarker, true);
      });

      test('lifecycle marker with real location has hasLocation true', () {
        final loc = TripLocation(
          id: 'loc-6',
          latitude: 40.0,
          longitude: -74.0,
          timestamp: DateTime.now(),
          updateType: TripUpdateType.dayStart,
        );

        expect(loc.isLifecycleMarker, true);
        expect(loc.hasLocation, true);
      });
    });

    group('Trip tripPlanId and thumbnail', () {
      test('thumbnailUrl returns trip thumbnail when no tripPlanId', () {
        final trip = Trip(
          id: 'trip123',
          userId: 'user456',
          username: 'testuser',
          name: 'Test Trip',
          visibility: Visibility.public,
          status: TripStatus.inProgress,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(trip.thumbnailUrl, '/thumbnails/trips/trip123.png');
      });

      test('thumbnailUrl returns trip thumbnail when trip has updates', () {
        final trip = Trip(
          id: 'trip123',
          userId: 'user456',
          username: 'testuser',
          name: 'Test Trip',
          visibility: Visibility.public,
          status: TripStatus.inProgress,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          tripPlanId: 'plan456',
          locations: [
            TripLocation(
              id: 'loc1',
              latitude: 40.0,
              longitude: -74.0,
              timestamp: DateTime.now(),
              updateType: TripUpdateType.regular,
            ),
          ],
        );

        expect(trip.thumbnailUrl, '/thumbnails/trips/trip123.png');
      });

      test(
          'thumbnailUrl returns trip thumbnail when no updates and has tripPlanId',
          () {
        final trip = Trip(
          id: 'trip123',
          userId: 'user456',
          username: 'testuser',
          name: 'Test Trip',
          visibility: Visibility.public,
          status: TripStatus.created,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          tripPlanId: 'plan456',
        );

        expect(trip.thumbnailUrl, '/thumbnails/trips/trip123.png');
      });

      test('thumbnailUrl returns trip thumbnail when empty updates list', () {
        final trip = Trip(
          id: 'trip123',
          userId: 'user456',
          username: 'testuser',
          name: 'Test Trip',
          visibility: Visibility.public,
          status: TripStatus.created,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          tripPlanId: 'plan456',
          locations: [],
        );

        expect(trip.thumbnailUrl, '/thumbnails/trips/trip123.png');
      });

      test('fromJson parses tripPlanId', () {
        final json = {
          'id': 'trip123',
          'userId': 'user456',
          'username': 'testuser',
          'name': 'Test Trip',
          'visibility': 'PUBLIC',
          'status': 'CREATED',
          'createdAt': '2024-01-01T00:00:00.000Z',
          'updatedAt': '2024-01-02T00:00:00.000Z',
          'tripPlanId': 'plan456',
        };

        final trip = Trip.fromJson(json);

        expect(trip.tripPlanId, 'plan456');
      });

      test('toJson includes tripPlanId when set', () {
        final trip = Trip(
          id: 'trip123',
          userId: 'user456',
          username: 'testuser',
          name: 'Test Trip',
          visibility: Visibility.public,
          status: TripStatus.created,
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 2),
          tripPlanId: 'plan456',
        );

        final json = trip.toJson();

        expect(json['tripPlanId'], 'plan456');
      });

      test('toJson excludes tripPlanId when null', () {
        final trip = Trip(
          id: 'trip123',
          userId: 'user456',
          username: 'testuser',
          name: 'Test Trip',
          visibility: Visibility.public,
          status: TripStatus.created,
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 2),
        );

        final json = trip.toJson();

        expect(json.containsKey('tripPlanId'), false);
      });

      test('copyWith preserves tripPlanId when not overridden', () {
        final trip = Trip(
          id: 'trip123',
          userId: 'user456',
          username: 'testuser',
          name: 'Test Trip',
          visibility: Visibility.public,
          status: TripStatus.created,
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 2),
          tripPlanId: 'plan456',
        );

        final updated = trip.copyWith(name: 'Updated Trip');

        expect(updated.tripPlanId, 'plan456');
      });

      test('copyWith updates tripPlanId when provided', () {
        final trip = Trip(
          id: 'trip123',
          userId: 'user456',
          username: 'testuser',
          name: 'Test Trip',
          visibility: Visibility.public,
          status: TripStatus.created,
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 2),
          tripPlanId: 'plan456',
        );

        final updated = trip.copyWith(tripPlanId: 'plan789');

        expect(updated.tripPlanId, 'plan789');
      });
    });
  });
}
