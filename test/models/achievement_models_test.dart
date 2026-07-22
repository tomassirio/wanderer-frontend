import 'package:flutter_test/flutter_test.dart';
import 'package:wanderer_frontend/data/models/achievement_models.dart';

void main() {
  group('AchievementType', () {
    test('toJson returns correct string for distance types', () {
      expect(AchievementType.distanceOneHundredKm.toJson(), 'DISTANCE_100KM');
      expect(AchievementType.distanceTwoHundredKm.toJson(), 'DISTANCE_200KM');
      expect(AchievementType.distanceFiveHundredKm.toJson(), 'DISTANCE_500KM');
      expect(AchievementType.distanceEightHundredKm.toJson(), 'DISTANCE_800KM');
      expect(AchievementType.distanceOneThousandKm.toJson(), 'DISTANCE_1000KM');
      expect(
          AchievementType.distanceSixteenHundredKm.toJson(), 'DISTANCE_1600KM');
      expect(AchievementType.distanceTwentyTwoHundredKm.toJson(),
          'DISTANCE_2200KM');
    });

    test('toJson returns correct string for getting started types', () {
      expect(AchievementType.firstTrip.toJson(), 'FIRST_TRIP');
      expect(AchievementType.profileCompleted.toJson(), 'PROFILE_COMPLETED');
    });

    test('toJson returns correct string for update types', () {
      expect(AchievementType.updatesOne.toJson(), 'UPDATES_1');
      expect(AchievementType.updatesTen.toJson(), 'UPDATES_10');
      expect(AchievementType.updatesFifty.toJson(), 'UPDATES_50');
      expect(AchievementType.updatesOneHundred.toJson(), 'UPDATES_100');
    });

    test('toJson returns correct string for duration types', () {
      expect(AchievementType.durationSevenDays.toJson(), 'DURATION_7_DAYS');
      expect(AchievementType.durationThirtyDays.toJson(), 'DURATION_30_DAYS');
      expect(
          AchievementType.durationFortyFiveDays.toJson(), 'DURATION_45_DAYS');
      expect(AchievementType.durationSixtyDays.toJson(), 'DURATION_60_DAYS');
    });

    test('toJson returns correct string for social types', () {
      expect(AchievementType.followersOne.toJson(), 'FOLLOWERS_1');
      expect(AchievementType.followersTen.toJson(), 'FOLLOWERS_10');
      expect(AchievementType.followersFifty.toJson(), 'FOLLOWERS_50');
      expect(AchievementType.followersOneHundred.toJson(), 'FOLLOWERS_100');
      expect(AchievementType.friendsOne.toJson(), 'FRIENDS_1');
      expect(AchievementType.friendsFive.toJson(), 'FRIENDS_5');
      expect(AchievementType.friendsTwenty.toJson(), 'FRIENDS_20');
      expect(AchievementType.friendsFifty.toJson(), 'FRIENDS_50');
    });

    test('fromJson parses all types correctly', () {
      expect(
          AchievementType.fromJson('FIRST_TRIP'), AchievementType.firstTrip);
      expect(AchievementType.fromJson('PROFILE_COMPLETED'),
          AchievementType.profileCompleted);
      expect(AchievementType.fromJson('DISTANCE_100KM'),
          AchievementType.distanceOneHundredKm);
      expect(
          AchievementType.fromJson('UPDATES_1'), AchievementType.updatesOne);
      expect(
          AchievementType.fromJson('UPDATES_10'), AchievementType.updatesTen);
      expect(AchievementType.fromJson('DURATION_7_DAYS'),
          AchievementType.durationSevenDays);
      expect(AchievementType.fromJson('FOLLOWERS_1'),
          AchievementType.followersOne);
      expect(AchievementType.fromJson('FOLLOWERS_10'),
          AchievementType.followersTen);
      expect(
          AchievementType.fromJson('FRIENDS_1'), AchievementType.friendsOne);
      expect(
          AchievementType.fromJson('FRIENDS_5'), AchievementType.friendsFive);
    });

    test('fromJson is case insensitive', () {
      expect(AchievementType.fromJson('distance_100km'),
          AchievementType.distanceOneHundredKm);
      expect(
          AchievementType.fromJson('updates_10'), AchievementType.updatesTen);
    });

    test('fromJson throws on invalid value', () {
      expect(
        () => AchievementType.fromJson('INVALID'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('category returns correct grouping', () {
      expect(AchievementType.firstTrip.category, 'Getting Started');
      expect(AchievementType.profileCompleted.category, 'Getting Started');
      expect(AchievementType.distanceOneHundredKm.category, 'Distance');
      expect(AchievementType.updatesOne.category, 'Updates');
      expect(AchievementType.updatesTen.category, 'Updates');
      expect(AchievementType.durationSevenDays.category, 'Duration');
      expect(AchievementType.followersOne.category, 'Social');
      expect(AchievementType.followersTen.category, 'Social');
      expect(AchievementType.friendsOne.category, 'Social');
      expect(AchievementType.friendsFive.category, 'Social');
    });

    test('roundtrip toJson/fromJson for all types', () {
      for (final type in AchievementType.values) {
        final json = type.toJson();
        final parsed = AchievementType.fromJson(json);
        expect(parsed, type);
      }
    });
  });

  group('Achievement', () {
    test('fromJson creates Achievement from JSON', () {
      final json = {
        'id': '550e8400-e29b-41d4-a716-446655440000',
        'type': 'DISTANCE_100KM',
        'name': 'First Century',
        'description': 'Walk 100km in a single trip',
        'thresholdValue': 100,
      };

      final achievement = Achievement.fromJson(json);

      expect(achievement.id, '550e8400-e29b-41d4-a716-446655440000');
      expect(achievement.type, AchievementType.distanceOneHundredKm);
      expect(achievement.name, 'First Century');
      expect(achievement.description, 'Walk 100km in a single trip');
      expect(achievement.thresholdValue, 100);
    });

    test('toJson converts Achievement correctly', () {
      final achievement = Achievement(
        id: '550e8400-e29b-41d4-a716-446655440000',
        type: AchievementType.distanceOneHundredKm,
        name: 'First Century',
        description: 'Walk 100km in a single trip',
        thresholdValue: 100,
      );

      final json = achievement.toJson();

      expect(json['id'], '550e8400-e29b-41d4-a716-446655440000');
      expect(json['type'], 'DISTANCE_100KM');
      expect(json['name'], 'First Century');
      expect(json['description'], 'Walk 100km in a single trip');
      expect(json['thresholdValue'], 100);
    });

    test('roundtrip fromJson/toJson preserves data', () {
      final json = {
        'id': 'test-id',
        'type': 'FOLLOWERS_50',
        'name': 'Influencer',
        'description': 'Reach 50 followers',
        'thresholdValue': 50,
      };

      final achievement = Achievement.fromJson(json);
      final output = achievement.toJson();

      expect(output['id'], json['id']);
      expect(output['type'], json['type']);
      expect(output['name'], json['name']);
      expect(output['description'], json['description']);
      expect(output['thresholdValue'], json['thresholdValue']);
    });
  });

  group('UserAchievement', () {
    test('fromJson creates UserAchievement with tripId', () {
      final json = {
        'id': '660e8400-e29b-41d4-a716-446655440000',
        'userId': '123e4567-e89b-12d3-a456-426614174000',
        'achievement': {
          'id': '550e8400-e29b-41d4-a716-446655440000',
          'type': 'DISTANCE_100KM',
          'name': 'First Century',
          'description': 'Walk 100km in a single trip',
          'thresholdValue': 100,
        },
        'tripId': '789e0123-e89b-12d3-a456-426614174000',
        'unlockedAt': '2025-01-15T10:30:00.000Z',
        'valueAchieved': 105.5,
      };

      final userAchievement = UserAchievement.fromJson(json);

      expect(userAchievement.id, '660e8400-e29b-41d4-a716-446655440000');
      expect(userAchievement.userId, '123e4567-e89b-12d3-a456-426614174000');
      expect(userAchievement.achievement.name, 'First Century');
      expect(userAchievement.achievement.type,
          AchievementType.distanceOneHundredKm);
      expect(userAchievement.tripId, '789e0123-e89b-12d3-a456-426614174000');
      expect(userAchievement.unlockedAt,
          DateTime.parse('2025-01-15T10:30:00.000Z'));
      expect(userAchievement.valueAchieved, 105.5);
    });

    test('fromJson handles null tripId for social achievements', () {
      final json = {
        'id': '660e8400-e29b-41d4-a716-446655440001',
        'userId': '123e4567-e89b-12d3-a456-426614174000',
        'achievement': {
          'id': '550e8400-e29b-41d4-a716-446655440010',
          'type': 'FOLLOWERS_10',
          'name': 'Popular Walker',
          'description': 'Reach 10 followers',
          'thresholdValue': 10,
        },
        'tripId': null,
        'unlockedAt': '2025-02-01T14:22:00.000Z',
        'valueAchieved': 12.0,
      };

      final userAchievement = UserAchievement.fromJson(json);

      expect(userAchievement.tripId, isNull);
      expect(userAchievement.achievement.type, AchievementType.followersTen);
      expect(userAchievement.valueAchieved, 12.0);
    });

    test('toJson converts UserAchievement with tripId correctly', () {
      final userAchievement = UserAchievement(
        id: 'ua-1',
        userId: 'user-1',
        achievement: Achievement(
          id: 'ach-1',
          type: AchievementType.distanceOneHundredKm,
          name: 'First Century',
          description: 'Walk 100km in a single trip',
          thresholdValue: 100,
        ),
        tripId: 'trip-1',
        unlockedAt: DateTime.parse('2025-01-15T10:30:00.000Z'),
        valueAchieved: 105.5,
      );

      final json = userAchievement.toJson();

      expect(json['id'], 'ua-1');
      expect(json['userId'], 'user-1');
      expect(json['tripId'], 'trip-1');
      expect(json['valueAchieved'], 105.5);
      expect(json['achievement']['type'], 'DISTANCE_100KM');
    });

    test('toJson includes null tripId for social achievements', () {
      final userAchievement = UserAchievement(
        id: 'ua-2',
        userId: 'user-1',
        achievement: Achievement(
          id: 'ach-2',
          type: AchievementType.followersTen,
          name: 'Popular Walker',
          description: 'Reach 10 followers',
          thresholdValue: 10,
        ),
        unlockedAt: DateTime.parse('2025-02-01T14:22:00.000Z'),
        valueAchieved: 12.0,
      );

      final json = userAchievement.toJson();

      expect(json['tripId'], isNull);
      expect(json['valueAchieved'], 12.0);
    });

    test('fromJson handles integer valueAchieved', () {
      final json = {
        'id': 'ua-3',
        'userId': 'user-1',
        'achievement': {
          'id': 'ach-3',
          'type': 'UPDATES_10',
          'name': 'Getting Started',
          'description': 'Post 10 updates on a single trip',
          'thresholdValue': 10,
        },
        'tripId': 'trip-1',
        'unlockedAt': '2025-03-01T00:00:00.000Z',
        'valueAchieved': 15,
      };

      final userAchievement = UserAchievement.fromJson(json);

      expect(userAchievement.valueAchieved, 15.0);
    });
  });
}
