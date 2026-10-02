import 'package:flutter_test/flutter_test.dart';
import 'package:wanderer_frontend/core/constants/enums.dart';
import 'package:wanderer_frontend/data/models/achievement_models.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/presentation/widgets/android/home_sections.dart';

Trip _trip(String id,
        {TripStatus status = TripStatus.finished,
        double? km,
        int? updates,
        DateTime? start,
        DateTime? end}) =>
    Trip(
      id: id,
      userId: 'me',
      name: id,
      username: 'me',
      visibility: Visibility.public,
      status: status,
      accruedDistanceKm: km,
      updateCount: updates,
      startDate: start,
      endDate: end,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

Achievement _badge(String id, AchievementType type, int threshold) =>
    Achievement(
        id: id,
        type: type,
        name: id,
        description: '',
        thresholdValue: threshold);

void main() {
  final now = DateTime(2026, 6, 10);

  test('days out: inclusive, open trips count to now, drafts are zero', () {
    expect(
        tripDaysOut(
            _trip('a', start: DateTime(2026, 6, 1), end: DateTime(2026, 6, 3))),
        3);
    expect(
        tripDaysOut(
            _trip('b',
                status: TripStatus.inProgress, start: DateTime(2026, 6, 9)),
            now: now),
        2);
    expect(tripDaysOut(_trip('c', status: TripStatus.created, start: now)), 0);
  });

  test('next badge: closest locked goal from the best single trip', () {
    final all = [
      _badge('first', AchievementType.firstTrip, 1),
      _badge('d100', AchievementType.distanceOneHundredKm, 100),
      _badge('d2200', AchievementType.distanceTwentyTwoHundredKm, 2200),
      _badge('u10', AchievementType.updatesTen, 10),
      _badge('f10', AchievementType.followersTen, 10),
      _badge('profile', AchievementType.profileCompleted, 1),
    ];
    final trips = [
      _trip('long', km: 2115, updates: 3),
      _trip('short', km: 40, updates: 2),
    ];
    final next = nextBadge(all, {'first', 'd100'}, trips,
        followers: 2, friends: 0, now: now);
    expect(next!.achievement.id, 'd2200');
    expect(next.value, 2115);

    // Unknown progress (profile completed) is never picked; all done → null.
    expect(
        nextBadge(all, {'first', 'd100', 'd2200', 'u10', 'f10'}, trips,
            followers: 2, friends: 0),
        isNull);
  });

  test('next badge: ties go to the smaller goal', () {
    final all = [
      _badge('d200', AchievementType.distanceTwoHundredKm, 200),
      _badge('d100', AchievementType.distanceOneHundredKm, 100),
    ];
    final next =
        nextBadge(all, {}, [_trip('t', km: 500)], followers: 0, friends: 0);
    expect(next!.achievement.id, 'd100');
  });
}
