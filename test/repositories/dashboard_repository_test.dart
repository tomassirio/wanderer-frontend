import 'package:flutter_test/flutter_test.dart';
import 'package:wanderer_frontend/data/models/domain/comment.dart';
import 'package:wanderer_frontend/data/models/domain/achievement.dart';
import 'package:wanderer_frontend/data/models/domain/achievement_category.dart';
import 'package:wanderer_frontend/data/models/domain/user_achievement.dart';
import 'package:wanderer_frontend/data/models/domain/user_profile.dart';
import 'package:wanderer_frontend/data/repositories/dashboard_repository.dart';

Comment _comment(String id, String userId, int day) => Comment(
      id: id,
      tripId: 'trip',
      userId: userId,
      username: userId,
      message: 'hi',
      createdAt: DateTime(2026, 5, day),
      updatedAt: DateTime(2026, 5, day),
    );

void main() {
  group('DashboardRepository.mergeRecentComments', () {
    test('merges lists newest first, drops own comments, keeps limit', () {
      final merged = DashboardRepository.mergeRecentComments(
        [
          [_comment('a', 'friend', 10), _comment('b', 'me', 20)],
          [_comment('c', 'other', 15), _comment('d', 'friend', 5)],
          [_comment('e', 'other', 18)],
        ],
        excludeUserId: 'me',
      );

      expect(merged.map((c) => c.id), ['e', 'c', 'a']);
    });

    test('returns empty when only own comments exist', () {
      final merged = DashboardRepository.mergeRecentComments(
        [
          [_comment('a', 'me', 1)],
        ],
        excludeUserId: 'me',
      );

      expect(merged, isEmpty);
    });
  });

  group('DashboardData achievements', () {
    final km100 = Achievement(
        id: 'a-100km',
        type: AchievementType.distanceOneHundredKm,
        name: '100 km',
        description: '100 km in a single trip',
        thresholdValue: 100);
    final firstTrip = Achievement(
        id: 'a-first',
        type: AchievementType.firstTrip,
        name: 'First Trip',
        description: 'Create your first trip',
        thresholdValue: 1);
    UserAchievement unlock(String id, Achievement a, int day) =>
        UserAchievement(
            id: id,
            userId: 'me',
            achievement: a,
            tripId: 't-$id',
            unlockedAt: DateTime(2026, 5, day),
            valueAchieved: 1);
    DashboardData data(List<UserAchievement> achievements) => DashboardData(
          profile: UserProfile(
              id: 'me',
              username: 'me',
              email: 'me@example.com',
              displayName: 'me',
              followersCount: 0,
              followingCount: 0,
              tripsCount: 0,
              isFollowing: false,
              createdAt: DateTime(2026)),
          trips: const [],
          achievements: achievements,
          friendRequests: const [],
          friendRequestCount: 0,
          recentComments: const [],
          latestTripAchievements: 0,
        );

    test('counts an achievement unlocked on several trips once', () {
      final d = data([
        unlock('1', km100, 1),
        unlock('2', km100, 3),
        unlock('3', firstTrip, 2),
      ]);
      expect(d.achievements, hasLength(3));
      expect(d.unlockedAchievementCount, 2);
    });

    test('recent achievements are distinct, newest unlock first', () {
      final d = data([
        unlock('1', km100, 1),
        unlock('3', firstTrip, 2),
        unlock('2', km100, 3),
      ]);
      expect(d.recentAchievements.map((u) => u.id), ['2', '3']);
    });
  });
}
