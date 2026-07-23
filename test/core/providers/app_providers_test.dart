import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wanderer_frontend/core/constants/api_endpoints.dart';
import 'package:wanderer_frontend/core/providers/app_providers.dart';
import 'package:wanderer_frontend/data/client/auth/auth_client.dart';
import 'package:wanderer_frontend/data/client/command/admin_command_client.dart';
import 'package:wanderer_frontend/data/client/command/comment_command_client.dart';
import 'package:wanderer_frontend/data/client/command/notification_command_client.dart';
import 'package:wanderer_frontend/data/client/command/promotion_command_client.dart';
import 'package:wanderer_frontend/data/client/command/trip_command_client.dart';
import 'package:wanderer_frontend/data/client/command/trip_plan_command_client.dart';
import 'package:wanderer_frontend/data/client/command/trip_update_command_client.dart';
import 'package:wanderer_frontend/data/client/command/user_command_client.dart';
import 'package:wanderer_frontend/data/client/google_directions_api_client.dart';
import 'package:wanderer_frontend/data/client/query/achievement_query_client.dart';
import 'package:wanderer_frontend/data/client/query/admin_query_client.dart';
import 'package:wanderer_frontend/data/client/query/comment_query_client.dart';
import 'package:wanderer_frontend/data/client/query/notification_query_client.dart';
import 'package:wanderer_frontend/data/client/query/promotion_query_client.dart';
import 'package:wanderer_frontend/data/client/query/trip_plan_query_client.dart';
import 'package:wanderer_frontend/data/client/query/trip_query_client.dart';
import 'package:wanderer_frontend/data/client/query/user_query_client.dart';
import 'package:wanderer_frontend/data/storage/token_storage.dart';

void main() {
  group('Base providers', () {
    test('tokenStorageProvider returns a TokenStorage', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(tokenStorageProvider), isA<TokenStorage>());
    });

    test('tokenStorageProvider returns the same instance on repeated reads',
        () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final a = container.read(tokenStorageProvider);
      final b = container.read(tokenStorageProvider);
      expect(identical(a, b), isTrue);
    });

    test('apiClientQueryProvider uses ApiEndpoints.queryBaseUrl', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(apiClientQueryProvider).baseUrl,
          ApiEndpoints.queryBaseUrl);
    });

    test('apiClientCommandProvider uses ApiEndpoints.commandBaseUrl', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(apiClientCommandProvider).baseUrl,
          ApiEndpoints.commandBaseUrl);
    });

    test('apiClientAuthProvider uses ApiEndpoints.authBaseUrl', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(apiClientAuthProvider).baseUrl,
          ApiEndpoints.authBaseUrl);
    });

    test('the 3 ApiClient providers are distinct instances', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final query = container.read(apiClientQueryProvider);
      final command = container.read(apiClientCommandProvider);
      final auth = container.read(apiClientAuthProvider);
      expect(identical(query, command), isFalse);
      expect(identical(query, auth), isFalse);
      expect(identical(command, auth), isFalse);
    });
  });

  group('CQRS client providers', () {
    test('every client provider resolves to the correct type', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(authClientProvider), isA<AuthClient>());
      expect(container.read(adminCommandClientProvider),
          isA<AdminCommandClient>());
      expect(container.read(commentCommandClientProvider),
          isA<CommentCommandClient>());
      expect(container.read(notificationCommandClientProvider),
          isA<NotificationCommandClient>());
      expect(container.read(promotionCommandClientProvider),
          isA<PromotionCommandClient>());
      expect(
          container.read(tripCommandClientProvider), isA<TripCommandClient>());
      expect(container.read(tripPlanCommandClientProvider),
          isA<TripPlanCommandClient>());
      expect(container.read(tripUpdateCommandClientProvider),
          isA<TripUpdateCommandClient>());
      expect(
          container.read(userCommandClientProvider), isA<UserCommandClient>());
      expect(container.read(achievementQueryClientProvider),
          isA<AchievementQueryClient>());
      expect(container.read(adminQueryClientProvider), isA<AdminQueryClient>());
      expect(container.read(commentQueryClientProvider),
          isA<CommentQueryClient>());
      expect(container.read(notificationQueryClientProvider),
          isA<NotificationQueryClient>());
      expect(container.read(promotionQueryClientProvider),
          isA<PromotionQueryClient>());
      expect(container.read(tripPlanQueryClientProvider),
          isA<TripPlanQueryClient>());
      expect(container.read(tripQueryClientProvider), isA<TripQueryClient>());
      expect(container.read(userQueryClientProvider), isA<UserQueryClient>());
    });

    test(
        'googleDirectionsApiClientProvider resolves with the configured API key',
        () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(googleDirectionsApiClientProvider),
          isA<GoogleDirectionsApiClient>());
    });

    test('repeated reads of a client provider return the same instance', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final a = container.read(tripQueryClientProvider);
      final b = container.read(tripQueryClientProvider);
      expect(identical(a, b), isTrue);
    });
  });
}
