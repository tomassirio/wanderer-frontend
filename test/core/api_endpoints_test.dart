import 'package:flutter_test/flutter_test.dart';
import 'package:wanderer_frontend/core/constants/api_endpoints.dart';

void main() {
  group('ApiEndpoints', () {
    group('Base URLs', () {
      test('commandBaseUrl is correct', () {
        expect(ApiEndpoints.commandBaseUrl, 'http://localhost:8081/api/1');
      });

      test('queryBaseUrl is correct', () {
        expect(ApiEndpoints.queryBaseUrl, 'http://localhost:8082/api/1');
      });

      test('authBaseUrl is correct', () {
        expect(ApiEndpoints.authBaseUrl, 'http://localhost:8083/api/1/auth');
      });
    });

    group('Auth endpoints', () {
      test('authRegister path is correct', () {
        expect(ApiEndpoints.authRegister, '/register');
      });

      test('authLogin path is correct', () {
        expect(ApiEndpoints.authLogin, '/login');
      });

      test('authLogout path is correct', () {
        expect(ApiEndpoints.authLogout, '/logout');
      });

      test('authRefresh path is correct', () {
        expect(ApiEndpoints.authRefresh, '/refresh');
      });

      test('authPasswordReset path is correct', () {
        expect(ApiEndpoints.authPasswordReset, '/password/reset');
      });

      test('authPasswordChange path is correct', () {
        expect(ApiEndpoints.authPasswordChange, '/password/change');
      });
    });

    group('User Query endpoints', () {
      test('usersMe path is correct', () {
        expect(ApiEndpoints.usersMe, '/users/me');
      });

      test('userById generates correct path', () {
        expect(ApiEndpoints.userById('123'), '/users/123');
        expect(ApiEndpoints.userById('user-abc'), '/users/user-abc');
      });

      test('userByUsername generates correct path', () {
        expect(ApiEndpoints.userByUsername('john'), '/users/username/john');
        expect(
          ApiEndpoints.userByUsername('test_user'),
          '/users/username/test_user',
        );
      });

      test('usersMeFriends path is correct', () {
        expect(ApiEndpoints.usersMeFriends, '/users/me/friends');
      });

      test('usersMeFollowing path is correct', () {
        expect(ApiEndpoints.usersMeFollowing, '/users/me/following');
      });

      test('usersMeFollowers path is correct', () {
        expect(ApiEndpoints.usersMeFollowers, '/users/me/followers');
      });

      test('usersFriendRequestsReceived path is correct', () {
        expect(
          ApiEndpoints.usersFriendRequestsReceived,
          '/users/friends/requests/received',
        );
      });

      test('usersFriendRequestsSent path is correct', () {
        expect(
          ApiEndpoints.usersFriendRequestsSent,
          '/users/friends/requests/sent',
        );
      });

      test('userFriends generates correct path', () {
        expect(ApiEndpoints.userFriends('user123'), '/users/user123/friends');
        expect(ApiEndpoints.userFriends('abc-def'), '/users/abc-def/friends');
      });

      test('userFollowing generates correct path', () {
        expect(
            ApiEndpoints.userFollowing('user123'), '/users/user123/following');
        expect(
            ApiEndpoints.userFollowing('abc-def'), '/users/abc-def/following');
      });

      test('userFollowers generates correct path', () {
        expect(
            ApiEndpoints.userFollowers('user123'), '/users/user123/followers');
        expect(
            ApiEndpoints.userFollowers('abc-def'), '/users/abc-def/followers');
      });
    });

    group('User Command endpoints', () {
      test('usersCreate path is correct', () {
        expect(ApiEndpoints.usersCreate, '/users');
      });

      test('usersFriendRequests path is correct', () {
        expect(ApiEndpoints.usersFriendRequests, '/users/friends/requests');
      });

      test('usersFriendRequestAccept generates correct path', () {
        expect(
          ApiEndpoints.usersFriendRequestAccept('req123'),
          '/users/friends/requests/req123/accept',
        );
        expect(
          ApiEndpoints.usersFriendRequestAccept('abc-def'),
          '/users/friends/requests/abc-def/accept',
        );
      });

      test('usersFriendRequestDelete generates correct path', () {
        expect(
          ApiEndpoints.usersFriendRequestDelete('req123'),
          '/users/friends/requests/req123',
        );
        expect(
          ApiEndpoints.usersFriendRequestDelete('abc-def'),
          '/users/friends/requests/abc-def',
        );
      });

      test('usersRemoveFriend generates correct path', () {
        expect(
          ApiEndpoints.usersRemoveFriend('friend123'),
          '/users/friends/friend123',
        );
        expect(
          ApiEndpoints.usersRemoveFriend('abc-def-ghi'),
          '/users/friends/abc-def-ghi',
        );
      });

      test('usersFollows path is correct', () {
        expect(ApiEndpoints.usersFollows, '/users/follows');
      });

      test('usersUnfollow generates correct path', () {
        expect(ApiEndpoints.usersUnfollow('user123'), '/users/follows/user123');
        expect(
          ApiEndpoints.usersUnfollow('followed-id'),
          '/users/follows/followed-id',
        );
      });
    });

    group('Trip Query endpoints', () {
      test('tripById generates correct path', () {
        expect(ApiEndpoints.tripById('trip123'), '/trips/trip123');
        expect(ApiEndpoints.tripById('abc-def'), '/trips/abc-def');
      });

      test('trips path is correct', () {
        expect(ApiEndpoints.trips, '/trips');
      });

      test('tripsMe path is correct', () {
        expect(ApiEndpoints.tripsMe, '/trips/me');
      });

      test('tripsPublic path is correct', () {
        expect(ApiEndpoints.tripsPublic, '/trips/public');
      });

      test('tripsAvailable path is correct', () {
        expect(ApiEndpoints.tripsAvailable, '/trips/me/available');
      });

      test('tripsByUser generates correct path', () {
        expect(ApiEndpoints.tripsByUser('user123'), '/trips/users/user123');
        expect(ApiEndpoints.tripsByUser('test-user'), '/trips/users/test-user');
      });
    });

    group('Trip Command endpoints', () {
      test('tripsCreate path is correct', () {
        expect(ApiEndpoints.tripsCreate, '/trips');
      });

      test('tripUpdate generates correct path', () {
        expect(ApiEndpoints.tripUpdate('trip123'), '/trips/trip123');
        expect(ApiEndpoints.tripUpdate('abc-def'), '/trips/abc-def');
      });

      test('tripDelete generates correct path', () {
        expect(ApiEndpoints.tripDelete('trip123'), '/trips/trip123');
        expect(ApiEndpoints.tripDelete('xyz-789'), '/trips/xyz-789');
      });

      test('tripVisibility generates correct path', () {
        expect(
          ApiEndpoints.tripVisibility('trip123'),
          '/trips/trip123/visibility',
        );
        expect(
          ApiEndpoints.tripVisibility('abc-def'),
          '/trips/abc-def/visibility',
        );
      });

      test('tripStatus generates correct path', () {
        expect(ApiEndpoints.tripStatus('trip123'), '/trips/trip123/status');
        expect(ApiEndpoints.tripStatus('xyz-789'), '/trips/xyz-789/status');
      });
    });

    group('Trip Plan Command endpoints', () {
      test('tripPlans path is correct', () {
        expect(ApiEndpoints.tripPlans, '/trips/plans');
      });

      test('tripPlanById generates correct path', () {
        expect(ApiEndpoints.tripPlanById('plan123'), '/trips/plans/plan123');
        expect(ApiEndpoints.tripPlanById('abc-def'), '/trips/plans/abc-def');
      });
    });

    group('Trip Update Command endpoints', () {
      test('tripUpdates generates correct path', () {
        expect(ApiEndpoints.tripUpdates('trip123'), '/trips/trip123/updates');
        expect(ApiEndpoints.tripUpdates('abc-def'), '/trips/abc-def/updates');
      });
    });

    group('Comment Command endpoints', () {
      test('tripComments generates correct path', () {
        expect(ApiEndpoints.tripComments('trip123'), '/trips/trip123/comments');
        expect(ApiEndpoints.tripComments('abc-def'), '/trips/abc-def/comments');
      });

      test('commentReactions generates correct path', () {
        expect(
          ApiEndpoints.commentReactions('comment123'),
          '/comments/comment123/reactions',
        );
        expect(
          ApiEndpoints.commentReactions('xyz-789'),
          '/comments/xyz-789/reactions',
        );
      });
    });

    group('App base URL', () {
      test('appBaseUrl returns production URL as default', () {
        // On non-web platforms without APP_BASE_URL dart-define set,
        // the stub returns the default production URL
        expect(
            ApiEndpoints.appBaseUrl, 'https://wanderer.localwanderer-dev.com');
      });
    });

    group('Trip deep link endpoint', () {
      test('tripDeepLink generates correct URL with default base URL', () {
        final link = ApiEndpoints.tripDeepLink('trip123');
        expect(link, endsWith('/trip/trip123'));
        expect(link, contains('trip123'));
      });

      test('tripDeepLink uses different IDs correctly', () {
        final link1 = ApiEndpoints.tripDeepLink('abc-def-ghi');
        final link2 = ApiEndpoints.tripDeepLink('123');
        expect(link1, endsWith('/trip/abc-def-ghi'));
        expect(link2, endsWith('/trip/123'));
      });
    });

    group('Achievement Query endpoints', () {
      test('achievements path is correct', () {
        expect(ApiEndpoints.achievements, '/achievements');
      });

      test('achievementsMe path is correct', () {
        expect(ApiEndpoints.achievementsMe, '/users/me/achievements');
      });

      test('userAchievements generates correct path', () {
        expect(
          ApiEndpoints.userAchievements('user123'),
          '/users/user123/achievements',
        );
        expect(
          ApiEndpoints.userAchievements('abc-def'),
          '/users/abc-def/achievements',
        );
      });

      test('tripAchievements generates correct path', () {
        expect(
          ApiEndpoints.tripAchievements('trip123'),
          '/trips/trip123/achievements',
        );
        expect(
          ApiEndpoints.tripAchievements('abc-def'),
          '/trips/abc-def/achievements',
        );
      });
    });
  });
}
