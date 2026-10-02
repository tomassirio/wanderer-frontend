import 'package:flutter_test/flutter_test.dart';
import 'package:wanderer_frontend/core/constants/enums.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/presentation/helpers/update_markers.dart';
import 'package:wanderer_frontend/presentation/widgets/trip_detail/trip_duration.dart';

Trip _trip(TripStatus status, {TripModality? modality, DateTime? start}) =>
    Trip(
      id: 't',
      userId: 'u',
      name: 't',
      username: 'u',
      visibility: Visibility.public,
      status: status,
      tripModality: modality,
      startDate: start,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

TripLocation _u(TripUpdateType type, DateTime at, {String? message}) =>
    TripLocation(
        id: '$type$at',
        latitude: 1,
        longitude: 1,
        timestamp: at,
        updateType: type,
        message: message);

void main() {
  final l10n = AppLocalizations('en');
  final t0 = DateTime(2026, 5, 1, 8);

  test('single-day: h m s from the Trip started update, no dash', () {
    final trip = _trip(TripStatus.inProgress, modality: TripModality.simple);
    final updates = [_u(TripUpdateType.tripStarted, t0)];
    expect(
        tripDurationLabel(l10n, trip, updates,
            now: t0.add(const Duration(hours: 2, minutes: 5, seconds: 9))),
        '2h 05m 09s');
  });

  test('single-day finished: stops at Trip finished', () {
    final trip = _trip(TripStatus.finished);
    final updates = [
      _u(TripUpdateType.tripEnded, t0.add(const Duration(minutes: 90))),
      _u(TripUpdateType.tripStarted, t0),
    ];
    expect(tripDurationLabel(l10n, trip, updates, now: DateTime(2030)),
        '1h 30m 00s');
  });

  test('multi-day counts days; falls back to the start date', () {
    final trip = _trip(TripStatus.inProgress,
        modality: TripModality.multiDay, start: t0);
    expect(
        tripDurationLabel(l10n, trip, const [],
            now: t0.add(const Duration(days: 2, hours: 1))),
        l10n.daysCount(3));
  });

  test('not started shows a dash', () {
    expect(tripDurationLabel(l10n, _trip(TripStatus.created), const []), '—');
  });

  test('update kinds: auto check-ins are told apart from tapped ones', () {
    expect(updateKind(_u(TripUpdateType.regular, t0)), UpdateKind.checkIn);
    expect(
        updateKind(_u(TripUpdateType.regular, t0, message: 'Automatic Update')),
        UpdateKind.autoCheckIn);
    expect(updateKind(_u(TripUpdateType.dayEnd, t0)), UpdateKind.dayEnded);
    expect(UpdateKind.tripFinished.isKeyMoment, isTrue);
    expect(UpdateKind.autoCheckIn.isKeyMoment, isFalse);
  });
}
