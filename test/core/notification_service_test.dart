import 'package:flutter_test/flutter_test.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/services/notification_service.dart';
import 'package:wanderer_frontend/data/models/domain/location_update_result.dart';

void main() {
  final l10n = AppLocalizations('en');

  test('is a singleton', () {
    expect(identical(NotificationService(), NotificationService()), isTrue);
  });

  group('liveTripBody', () {
    test('day, check-in time and place, then next check-in', () {
      expect(
        NotificationService.liveTripBody(l10n,
            day: 12,
            lastCheckIn: DateTime(2026, 10, 2, 22, 45),
            place: 'Nieuwegein',
            nextCheckIn: DateTime(2026, 10, 2, 23, 3)),
        'Day 12 · last check-in 22:45 in Nieuwegein\n'
        'Next auto check-in at 23:03',
      );
    });

    test('no place and no auto check-ins: no coordinates, no next line', () {
      expect(
        NotificationService.liveTripBody(l10n,
            lastCheckIn: DateTime(2026, 10, 2, 9, 5)),
        'last check-in 09:05',
      );
    });
  });

  group('checkInFailureBody', () {
    String body(LocationUpdateResult? r) =>
        NotificationService.checkInFailureBody(l10n, 'A trip mf', r);

    test('403 says the trip is gone, without codes or IDs', () {
      final text = body(const LocationUpdateResult.failureWithDetail(
          LocationFailureReason.serverError,
          'ApiException(403): User c1485b3c does not own trip',
          statusCode: 403));
      expect(text, contains('“A trip mf”'));
      expect(text, isNot(contains('403')));
      expect(text, isNot(contains('c1485b3c')));
    });

    test('offline, location off and expired session read as next steps', () {
      expect(
          body(const LocationUpdateResult.failure(
              LocationFailureReason.networkError)),
          l10n.notifCheckInOffline);
      expect(
          body(const LocationUpdateResult.failure(
              LocationFailureReason.servicesDisabled)),
          l10n.notifCheckInLocationOff);
      expect(body(null), l10n.notifSignedOut);
    });
  });
}
