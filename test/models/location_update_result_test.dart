import 'package:flutter_test/flutter_test.dart';
import 'package:wanderer_frontend/data/models/domain/location_update_result.dart';

void main() {
  group('LocationFailureReason', () {
    test('has all expected values', () {
      expect(LocationFailureReason.values, hasLength(7));
      expect(
        LocationFailureReason.values,
        containsAll([
          LocationFailureReason.servicesDisabled,
          LocationFailureReason.permissionDenied,
          LocationFailureReason.permissionDeniedForever,
          LocationFailureReason.timeout,
          LocationFailureReason.unknownError,
          LocationFailureReason.networkError,
          LocationFailureReason.serverError,
        ]),
      );
    });
  });

  group('LocationUpdateResult', () {
    group('success', () {
      test('isSuccess is true', () {
        const result = LocationUpdateResult.success();
        expect(result.isSuccess, isTrue);
      });

      test('failureReason is null', () {
        const result = LocationUpdateResult.success();
        expect(result.failureReason, isNull);
      });

      test('userMessage is empty string', () {
        const result = LocationUpdateResult.success();
        expect(result.userMessage, isEmpty);
      });

      test('location and battery default to null', () {
        const result = LocationUpdateResult.success();
        expect(result.latitude, isNull);
        expect(result.longitude, isNull);
        expect(result.batteryLevel, isNull);
      });

      test('success with location and battery data', () {
        const result = LocationUpdateResult.success(
          latitude: 40.7128,
          longitude: -74.0060,
          batteryLevel: 85,
        );
        expect(result.isSuccess, isTrue);
        expect(result.latitude, 40.7128);
        expect(result.longitude, -74.0060);
        expect(result.batteryLevel, 85);
      });

      test('success with partial location data', () {
        const result = LocationUpdateResult.success(
          latitude: 51.5074,
          longitude: -0.1278,
        );
        expect(result.latitude, 51.5074);
        expect(result.longitude, -0.1278);
        expect(result.batteryLevel, isNull);
      });
    });

    group('failure', () {
      test('isSuccess is false', () {
        const result = LocationUpdateResult.failure(
          LocationFailureReason.servicesDisabled,
        );
        expect(result.isSuccess, isFalse);
      });

      test('failureReason is set', () {
        const result = LocationUpdateResult.failure(
          LocationFailureReason.permissionDenied,
        );
        expect(result.failureReason, LocationFailureReason.permissionDenied);
      });
    });

    group('userMessage', () {
      test('servicesDisabled returns GPS message', () {
        const result = LocationUpdateResult.failure(
          LocationFailureReason.servicesDisabled,
        );
        expect(result.userMessage, contains('Location services are disabled'));
        expect(result.userMessage, contains('enable GPS'));
      });

      test('permissionDenied returns permission message', () {
        const result = LocationUpdateResult.failure(
          LocationFailureReason.permissionDenied,
        );
        expect(result.userMessage, contains('permission was denied'));
        expect(result.userMessage, contains('allow location access'));
      });

      test('permissionDeniedForever returns settings message', () {
        const result = LocationUpdateResult.failure(
          LocationFailureReason.permissionDeniedForever,
        );
        expect(result.userMessage, contains('permanently denied'));
        expect(result.userMessage, contains('device settings'));
      });

      test('timeout returns signal message', () {
        const result = LocationUpdateResult.failure(
          LocationFailureReason.timeout,
        );
        expect(result.userMessage, contains('GPS fix'));
        expect(result.userMessage, contains('better signal'));
      });

      test('unknownError returns generic location error', () {
        const result = LocationUpdateResult.failure(
          LocationFailureReason.unknownError,
        );
        expect(result.userMessage, contains('unexpected error'));
      });

      test('networkError returns connection message', () {
        const result = LocationUpdateResult.failure(
          LocationFailureReason.networkError,
        );
        expect(result.userMessage, contains('Failed to send'));
        expect(result.userMessage, contains('internet connection'));
      });

      test('serverError without detail returns generic server message', () {
        const result = LocationUpdateResult.failure(
          LocationFailureReason.serverError,
        );
        expect(result.userMessage, contains('server returned an error'));
      });

      test('serverError never shows the raw detail', () {
        const result = LocationUpdateResult.failureWithDetail(
          LocationFailureReason.serverError,
          'API Error (403): Forbidden',
          statusCode: 403,
        );
        expect(result.userMessage, contains('server returned an error'));
        expect(result.userMessage, isNot(contains('403')));
        expect(result.statusCode, 403);
      });

      test('failureWithDetail sets errorDetail', () {
        const result = LocationUpdateResult.failureWithDetail(
          LocationFailureReason.serverError,
          'some detail',
        );
        expect(result.isSuccess, isFalse);
        expect(result.failureReason, LocationFailureReason.serverError);
        expect(result.errorDetail, 'some detail');
      });

      test('failure constructor has null errorDetail', () {
        const result = LocationUpdateResult.failure(
          LocationFailureReason.networkError,
        );
        expect(result.errorDetail, isNull);
      });

      test('failure constructor has null location and battery', () {
        const result = LocationUpdateResult.failure(
          LocationFailureReason.networkError,
        );
        expect(result.latitude, isNull);
        expect(result.longitude, isNull);
        expect(result.batteryLevel, isNull);
      });

      test('failureWithDetail has null location and battery', () {
        const result = LocationUpdateResult.failureWithDetail(
          LocationFailureReason.serverError,
          'error detail',
        );
        expect(result.latitude, isNull);
        expect(result.longitude, isNull);
        expect(result.batteryLevel, isNull);
      });

      test('success constructor has null errorDetail', () {
        const result = LocationUpdateResult.success();
        expect(result.errorDetail, isNull);
      });

      test('every failure reason produces a non-empty message', () {
        for (final reason in LocationFailureReason.values) {
          final result = LocationUpdateResult.failure(reason);
          expect(
            result.userMessage,
            isNotEmpty,
            reason: '$reason should have a user message',
          );
        }
      });
    });
  });
}
