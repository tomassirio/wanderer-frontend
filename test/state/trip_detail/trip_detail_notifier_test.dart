import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:wanderer_frontend/core/constants/enums.dart';
import 'package:wanderer_frontend/core/providers/app_providers.dart';
import 'package:wanderer_frontend/data/client/query/promotion_query_client.dart';
import 'package:wanderer_frontend/data/models/comment_models.dart';
import 'package:wanderer_frontend/data/models/domain/location_update_result.dart';
import 'package:wanderer_frontend/data/models/responses/page_response.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/data/models/user_models.dart';
import 'package:wanderer_frontend/data/models/websocket/websocket_event.dart';
import 'package:wanderer_frontend/data/repositories/trip_detail_repository.dart';
import 'package:wanderer_frontend/data/services/achievement_service.dart';
import 'package:wanderer_frontend/data/services/user_service.dart';
import 'package:wanderer_frontend/presentation/state/trip_detail/trip_detail_notifier.dart';
import 'package:wanderer_frontend/presentation/state/trip_detail/trip_detail_state.dart';
import 'package:wanderer_frontend/presentation/widgets/trip_detail/custom_planned_info_window.dart';

import 'trip_detail_notifier_test.mocks.dart';

@GenerateMocks(
    [TripDetailRepository, PromotionQueryClient, AchievementService, UserService])
void main() {
  late MockTripDetailRepository mockRepository;
  late MockPromotionQueryClient mockPromotionClient;
  late MockAchievementService mockAchievementService;
  late MockUserService mockUserService;
  late Trip trip;

  setUp(() {
    mockRepository = MockTripDetailRepository();
    mockPromotionClient = MockPromotionQueryClient();
    mockAchievementService = MockAchievementService();
    mockUserService = MockUserService();
    trip = Trip(
      id: 'trip-1',
      userId: 'owner-1',
      username: 'owner',
      name: 'Test Trip',
      status: TripStatus.created,
      visibility: Visibility.public,
      tripModality: TripModality.simple,
      automaticUpdates: false,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
  });

  ProviderContainer buildContainer() {
    final container = ProviderContainer(overrides: [
      tripDetailRepositoryProvider.overrideWithValue(mockRepository),
      promotionQueryClientProvider.overrideWithValue(mockPromotionClient),
      achievementServiceProvider.overrideWithValue(mockAchievementService),
      userServiceProvider.overrideWithValue(mockUserService),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  test('build() seeds state with the trip passed at construction', () {
    final container = buildContainer();
    final notifier =
        container.read(tripDetailNotifierProvider(trip.id).notifier);
    notifier.seedInitialTrip(trip);
    final state = container.read(tripDetailNotifierProvider(trip.id));
    expect(state.trip.id, 'trip-1');
    expect(state.identity.userId, isNull);
    expect(state.identity.isLoggedIn, isFalse);
  });

  test(
      'is autoDispose: once nothing watches a tripId, the next visit gets '
      'a fresh notifier instead of the stale cached one', () async {
    final container = buildContainer();

    // First "screen visit": subscribe (as the widget's ref.watch would),
    // seed the real trip, and confirm it stuck.
    final sub = container.listen(
      tripDetailNotifierProvider(trip.id),
      (previous, next) {},
    );
    container
        .read(tripDetailNotifierProvider(trip.id).notifier)
        .seedInitialTrip(trip);
    expect(
      container.read(tripDetailNotifierProvider(trip.id)).trip.name,
      'Test Trip',
    );

    // Screen is popped: the widget's watch goes away and nothing else
    // reads this tripId's provider — it should become eligible for
    // disposal, matching the old field's per-screen-instance lifetime.
    sub.close();
    await container.pump();

    // Next "screen visit" for the same tripId (e.g. re-fetched elsewhere
    // in the app with a different Trip value): must build a fresh
    // notifier, not resurrect the old cached state.
    final freshState = container.read(tripDetailNotifierProvider(trip.id));
    expect(
      freshState.trip.name,
      isEmpty,
      reason: 'expected a fresh build() placeholder, not the previous '
          'visit\'s stale cached trip',
    );
  });

  test(
      'seedInitialTrip always applies its argument, even when the '
      'provider instance is reused (e.g. a rapid re-navigation to the '
      'same trip id lands on a not-yet-disposed instance from the '
      'previous screen, since Flutter keeps a popped route\'s State — and '
      'its ref.watch subscription — mounted for the entire pop transition, '
      'not just until autoDispose\'s scheduled teardown runs) — there is '
      'no guard that could silently discard a newer value', () async {
    final container = buildContainer();

    // Old screen's ref.watch — stays open, exactly as it would during a
    // pop transition still in flight.
    final oldScreenSub = container.listen(
      tripDetailNotifierProvider(trip.id),
      (previous, next) {},
    );
    container
        .read(tripDetailNotifierProvider(trip.id).notifier)
        .seedInitialTrip(trip);
    expect(
      container.read(tripDetailNotifierProvider(trip.id)).trip.name,
      'Test Trip',
    );

    // A different Trip value for the same id, as if re-fetched elsewhere
    // and handed to a brand-new screen instance for the same trip, while
    // the old screen's subscription (and therefore this same provider
    // instance) is still alive.
    final rushedRevisitTrip = trip.copyWith(name: 'Rushed Revisit Trip');
    container
        .read(tripDetailNotifierProvider(trip.id).notifier)
        .seedInitialTrip(rushedRevisitTrip);

    expect(
      container.read(tripDetailNotifierProvider(trip.id)).trip.name,
      'Rushed Revisit Trip',
      reason: 'seedInitialTrip must apply the latest call\'s trip '
          'unconditionally, matching the pre-migration behavior where '
          'each screen\'s own initState() always won',
    );

    oldScreenSub.close();
  });

  test('checkLoginStatus sets identity.isLoggedIn from the repository',
      () async {
    when(mockRepository.isLoggedIn()).thenAnswer((_) async => true);
    final container = buildContainer();
    final notifier =
        container.read(tripDetailNotifierProvider(trip.id).notifier);
    notifier.seedInitialTrip(trip);

    await notifier.checkLoginStatus();

    final state = container.read(tripDetailNotifierProvider(trip.id));
    expect(state.identity.isLoggedIn, isTrue);
  });

  test('loadUserInfo populates identity fields from the repository', () async {
    when(mockRepository.getCurrentUsername()).thenAnswer((_) async => 'me');
    when(mockRepository.getCurrentUserId()).thenAnswer((_) async => 'user-9');
    when(mockRepository.isAdmin()).thenAnswer((_) async => false);
    when(mockRepository.refreshUserDetails()).thenAnswer((_) async => true);
    when(mockRepository.getCurrentDisplayName())
        .thenAnswer((_) async => 'Me Display');
    when(mockRepository.getCurrentAvatarUrl())
        .thenAnswer((_) async => 'https://example.com/a.png');

    final container = buildContainer();
    final notifier =
        container.read(tripDetailNotifierProvider(trip.id).notifier);
    notifier.seedInitialTrip(trip);

    await notifier.loadUserInfo();

    final state = container.read(tripDetailNotifierProvider(trip.id));
    expect(state.identity.username, 'me');
    expect(state.identity.userId, 'user-9');
    expect(state.identity.displayName, 'Me Display');
    expect(state.identity.avatarUrl, 'https://example.com/a.png');
    expect(state.identity.isAdmin, isFalse);
  });

  test('loadUserInfo does not call refreshUserDetails when userId is null',
      () async {
    when(mockRepository.getCurrentUsername()).thenAnswer((_) async => null);
    when(mockRepository.getCurrentUserId()).thenAnswer((_) async => null);
    when(mockRepository.isAdmin()).thenAnswer((_) async => false);
    when(mockRepository.getCurrentDisplayName()).thenAnswer((_) async => null);
    when(mockRepository.getCurrentAvatarUrl()).thenAnswer((_) async => null);

    final container = buildContainer();
    final notifier =
        container.read(tripDetailNotifierProvider(trip.id).notifier);
    notifier.seedInitialTrip(trip);

    await notifier.loadUserInfo();

    verifyNever(mockRepository.refreshUserDetails());
  });

  test('loadPromotionInfo sets isPromoted and donationLink on success',
      () async {
    when(mockPromotionClient.getTripPromotion('trip-1')).thenAnswer(
      (_) async => TripPromotion(
        tripId: 'trip-1',
        donationLink: 'https://example.com/donate',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
    );
    final container = buildContainer();
    final notifier =
        container.read(tripDetailNotifierProvider(trip.id).notifier);
    notifier.seedInitialTrip(trip);

    await notifier.loadPromotionInfo();

    final state = container.read(tripDetailNotifierProvider(trip.id));
    expect(state.promotion.isPromoted, isTrue);
    expect(state.promotion.donationLink, 'https://example.com/donate');
  });

  test('loadPromotionInfo clears promotion state when the client throws',
      () async {
    when(mockPromotionClient.getTripPromotion('trip-1'))
        .thenThrow(Exception('404 not promoted'));
    final container = buildContainer();
    final notifier =
        container.read(tripDetailNotifierProvider(trip.id).notifier);
    notifier.seedInitialTrip(trip);

    await notifier.loadPromotionInfo();

    final state = container.read(tripDetailNotifierProvider(trip.id));
    expect(state.promotion.isPromoted, isFalse);
    expect(state.promotion.donationLink, isNull);
  });

  test('loadTripAchievements populates tripAchievements from the service',
      () async {
    when(mockAchievementService.getTripAchievements('trip-1'))
        .thenAnswer((_) async => []);
    final container = buildContainer();
    final notifier =
        container.read(tripDetailNotifierProvider(trip.id).notifier);
    notifier.seedInitialTrip(trip);

    await notifier.loadTripAchievements();

    verify(mockAchievementService.getTripAchievements('trip-1')).called(1);
  });

  test('loadTripAchievements silently no-ops when the service throws',
      () async {
    when(mockAchievementService.getTripAchievements('trip-1'))
        .thenThrow(Exception('network error'));
    final container = buildContainer();
    final notifier =
        container.read(tripDetailNotifierProvider(trip.id).notifier);
    notifier.seedInitialTrip(trip);

    await notifier.loadTripAchievements(); // must not throw

    final state = container.read(tripDetailNotifierProvider(trip.id));
    expect(state.tripAchievements, isEmpty);
  });

  test('debouncedAchievementRefresh only calls the service once after the delay',
      () async {
    when(mockAchievementService.getTripAchievements('trip-1'))
        .thenAnswer((_) async => []);
    final container = buildContainer();
    // Keep the autoDispose notifier alive for the duration of the debounce
    // timer, mirroring the widget's persistent ref.watch subscription — a
    // bare container.read() here would let the provider (and its timer) get
    // disposed before the Timer fires.
    final sub = container.listen(
      tripDetailNotifierProvider(trip.id),
      (previous, next) {},
    );
    final notifier =
        container.read(tripDetailNotifierProvider(trip.id).notifier);
    notifier.seedInitialTrip(trip);

    notifier.debouncedAchievementRefresh();
    notifier.debouncedAchievementRefresh(); // re-arms, should not double-fire
    notifier.debouncedAchievementRefresh();

    await Future.delayed(const Duration(seconds: 4));

    verify(mockAchievementService.getTripAchievements('trip-1')).called(1);
    sub.close();
  }, timeout: const Timeout(Duration(seconds: 10)));

  test('loadSocialStatus computes isFollowing/hasSentRequest/isAlreadyFriends',
      () async {
    when(mockUserService.getFollowing(page: 0, size: 100)).thenAnswer(
      (_) async => PageResponse<UserFollow>(
        content: [
          UserFollow(
            id: 'follow-1',
            followerId: 'me',
            followedId: 'owner-1',
            createdAt: DateTime(2026, 1, 1),
          ),
        ],
        totalElements: 1,
        totalPages: 1,
        number: 0,
        size: 100,
        first: true,
        last: true,
      ),
    );
    when(mockUserService.getSentFriendRequests()).thenAnswer((_) async => [
          FriendRequest(
            id: 'req-1',
            senderId: 'me',
            receiverId: 'owner-1',
            status: FriendRequestStatus.pending,
            createdAt: DateTime(2026, 1, 1),
            updatedAt: DateTime(2026, 1, 1),
          ),
        ]);
    when(mockUserService.getFriends(page: 0, size: 100)).thenAnswer(
      (_) async => PageResponse<Friendship>(
        content: <Friendship>[],
        totalElements: 0,
        totalPages: 0,
        number: 0,
        size: 100,
        first: true,
        last: true,
      ),
    );

    final container = buildContainer();
    final notifier =
        container.read(tripDetailNotifierProvider(trip.id).notifier);
    notifier.seedInitialTrip(trip);

    await notifier.loadSocialStatus();

    final state = container.read(tripDetailNotifierProvider(trip.id));
    expect(state.social.isFollowingTripOwner, isTrue);
    expect(state.social.hasSentFriendRequest, isTrue);
    expect(state.social.sentFriendRequestId, 'req-1');
    expect(state.social.isAlreadyFriends, isFalse);
  });

  test('followTripOwner(unfollow: true) calls unfollowUser and clears the flag',
      () async {
    when(mockUserService.unfollowUser('owner-1')).thenAnswer((_) async => 'ok');
    final container = buildContainer();
    final notifier =
        container.read(tripDetailNotifierProvider(trip.id).notifier);
    notifier.seedInitialTrip(trip);
    notifier.debugSetSocialForTest(
      const TripDetailSocialState(isFollowingTripOwner: true),
    );

    await notifier.followTripOwner();

    verify(mockUserService.unfollowUser('owner-1')).called(1);
    expect(
      container.read(tripDetailNotifierProvider(trip.id)).social.isFollowingTripOwner,
      isFalse,
    );
  });

  test('followTripOwner(unfollow: false) calls followUser and sets the flag',
      () async {
    when(mockUserService.followUser('owner-1')).thenAnswer((_) async => 'ok');
    final container = buildContainer();
    final notifier =
        container.read(tripDetailNotifierProvider(trip.id).notifier);
    notifier.seedInitialTrip(trip);

    await notifier.followTripOwner();

    verify(mockUserService.followUser('owner-1')).called(1);
    expect(
      container.read(tripDetailNotifierProvider(trip.id)).social.isFollowingTripOwner,
      isTrue,
    );
  });

  test('sendFriendRequestToTripOwner sends a new request when none is pending',
      () async {
    when(mockUserService.sendFriendRequest('owner-1'))
        .thenAnswer((_) async => 'req-9');
    final container = buildContainer();
    final notifier =
        container.read(tripDetailNotifierProvider(trip.id).notifier);
    notifier.seedInitialTrip(trip);

    await notifier.sendFriendRequestToTripOwner();

    final state = container.read(tripDetailNotifierProvider(trip.id));
    expect(state.social.hasSentFriendRequest, isTrue);
    expect(state.social.sentFriendRequestId, 'req-9');
  });

  test(
      'sendFriendRequestToTripOwner removes friend and clears the flag '
      'when already friends', () async {
    when(mockUserService.removeFriend('owner-1')).thenAnswer((_) async => 'ok');
    final container = buildContainer();
    final notifier =
        container.read(tripDetailNotifierProvider(trip.id).notifier);
    notifier.seedInitialTrip(trip);
    notifier.debugSetSocialForTest(
      const TripDetailSocialState(isAlreadyFriends: true),
    );

    await notifier.sendFriendRequestToTripOwner();

    verify(mockUserService.removeFriend('owner-1')).called(1);
    expect(
      container.read(tripDetailNotifierProvider(trip.id)).social.isAlreadyFriends,
      isFalse,
    );
  });

  test(
      'sendFriendRequestToTripOwner cancels the pending request when one '
      'exists', () async {
    when(mockUserService.deleteFriendRequest('req-1'))
        .thenAnswer((_) async => 'ok');
    final container = buildContainer();
    final notifier =
        container.read(tripDetailNotifierProvider(trip.id).notifier);
    notifier.seedInitialTrip(trip);
    notifier.debugSetSocialForTest(
      const TripDetailSocialState(
        hasSentFriendRequest: true,
        sentFriendRequestId: 'req-1',
      ),
    );

    await notifier.sendFriendRequestToTripOwner();

    verify(mockUserService.deleteFriendRequest('req-1')).called(1);
    final state = container.read(tripDetailNotifierProvider(trip.id));
    expect(state.social.hasSentFriendRequest, isFalse);
    expect(state.social.sentFriendRequestId, isNull);
  });

  test('loadTripUpdates populates timeline.tripUpdates on success', () async {
    when(mockRepository.loadTripUpdates('trip-1', page: 0, size: 50)).thenAnswer(
      (_) async => PageResponse<TripLocation>(
        content: [
          TripLocation(
            id: 'loc-1',
            latitude: 1.0,
            longitude: 2.0,
            timestamp: DateTime(2026, 1, 1),
          ),
        ],
        totalElements: 1,
        totalPages: 1,
        number: 0,
        size: 50,
        first: true,
        last: true,
      ),
    );
    final container = buildContainer();
    final notifier = container.read(tripDetailNotifierProvider(trip.id).notifier);
    notifier.seedInitialTrip(trip);

    await notifier.loadTripUpdates();

    final state = container.read(tripDetailNotifierProvider(trip.id));
    expect(state.timeline.tripUpdates, hasLength(1));
    expect(state.timeline.hasMoreUpdates, isFalse);
    expect(state.timeline.isLoadingUpdates, isFalse);
  });

  test('loadTripUpdates preserves ws_-prefixed entries not yet in the API response',
      () async {
    when(mockRepository.loadTripUpdates('trip-1', page: 0, size: 50)).thenAnswer(
      (_) async => PageResponse<TripLocation>(
        content: <TripLocation>[],
        totalElements: 0,
        totalPages: 0,
        number: 0,
        size: 50,
        first: true,
        last: true,
      ),
    );
    final container = buildContainer();
    final notifier = container.read(tripDetailNotifierProvider(trip.id).notifier);
    notifier.seedInitialTrip(trip);
    notifier.debugSeedTimelineForTest(
      TripDetailTimelineState(
        tripUpdates: [
          TripLocation(
            id: 'ws_123',
            latitude: 1.0,
            longitude: 2.0,
            timestamp: DateTime(2026, 1, 1),
          ),
        ],
      ),
    );

    await notifier.loadTripUpdates();

    final state = container.read(tripDetailNotifierProvider(trip.id));
    expect(state.timeline.tripUpdates.map((u) => u.id), contains('ws_123'));
  });

  test('loadTripUpdates rethrows after exhausting retries', () async {
    when(mockRepository.loadTripUpdates('trip-1', page: 0, size: 50))
        .thenThrow(Exception('500'));
    final container = buildContainer();
    final notifier = container.read(tripDetailNotifierProvider(trip.id).notifier);
    notifier.seedInitialTrip(trip);

    await expectLater(
      () => notifier.loadTripUpdates(retryCount: 3),
      throwsA(isA<Exception>()),
    );
  });

  test('loadMoreTripUpdates appends the next page and advances currentUpdatesPage',
      () async {
    when(mockRepository.loadTripUpdates('trip-1', page: 1, size: 50)).thenAnswer(
      (_) async => PageResponse<TripLocation>(
        content: [
          TripLocation(
            id: 'loc-2',
            latitude: 3.0,
            longitude: 4.0,
            timestamp: DateTime(2026, 1, 2),
          ),
        ],
        totalElements: 1,
        totalPages: 1,
        number: 1,
        size: 50,
        first: false,
        last: true,
      ),
    );
    final container = buildContainer();
    final notifier = container.read(tripDetailNotifierProvider(trip.id).notifier);
    notifier.seedInitialTrip(trip);
    notifier.debugSeedTimelineForTest(
      const TripDetailTimelineState(hasMoreUpdates: true, currentUpdatesPage: 0),
    );

    await notifier.loadMoreTripUpdates();

    final state = container.read(tripDetailNotifierProvider(trip.id));
    expect(state.timeline.currentUpdatesPage, 1);
    expect(state.timeline.tripUpdates.map((u) => u.id), contains('loc-2'));
  });

  test('loadMoreTripUpdates is a no-op when hasMoreUpdates is false', () async {
    final container = buildContainer();
    final notifier = container.read(tripDetailNotifierProvider(trip.id).notifier);
    notifier.seedInitialTrip(trip);

    await notifier.loadMoreTripUpdates();

    verifyNever(mockRepository.loadTripUpdates(any,
        page: anyNamed('page'), size: anyNamed('size')));
  });

  test('loadComments populates comments and sorts by latest by default',
      () async {
    when(mockRepository.loadComments('trip-1', page: 0, size: 20)).thenAnswer(
      (_) async => PageResponse(
        content: [
          Comment(
            id: 'c1',
            tripId: 'trip-1',
            userId: 'u1',
            username: 'alice',
            message: 'first',
            createdAt: DateTime(2026, 1, 1),
            updatedAt: DateTime(2026, 1, 1),
          ),
          Comment(
            id: 'c2',
            tripId: 'trip-1',
            userId: 'u2',
            username: 'bob',
            message: 'second',
            createdAt: DateTime(2026, 1, 2),
            updatedAt: DateTime(2026, 1, 2),
          ),
        ],
        totalElements: 2,
        totalPages: 1,
        number: 0,
        size: 20,
        first: true,
        last: true,
      ),
    );
    final container = buildContainer();
    final notifier = container.read(tripDetailNotifierProvider(trip.id).notifier);
    notifier.seedInitialTrip(trip);

    await notifier.loadComments();

    final state = container.read(tripDetailNotifierProvider(trip.id));
    expect(state.comments.comments.map((c) => c.id), ['c2', 'c1']); // latest first
    expect(state.comments.hasMoreComments, isFalse);
  });

  test('changeSortOption re-sorts existing comments by oldest', () async {
    final container = buildContainer();
    final notifier = container.read(tripDetailNotifierProvider(trip.id).notifier);
    notifier.seedInitialTrip(trip);
    notifier.debugSeedCommentsForTest(TripDetailCommentsState(comments: [
      Comment(id: 'c1', tripId: 'trip-1', userId: 'u1', username: 'a', message: 'x', createdAt: DateTime(2026, 1, 2), updatedAt: DateTime(2026, 1, 2)),
      Comment(id: 'c2', tripId: 'trip-1', userId: 'u2', username: 'b', message: 'y', createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1)),
    ]));

    notifier.changeSortOption(CommentSortOption.oldest);

    final state = container.read(tripDetailNotifierProvider(trip.id));
    expect(state.comments.comments.map((c) => c.id), ['c2', 'c1']);
    expect(state.comments.sortOption, CommentSortOption.oldest);
  });

  test('addComment (top-level) optimistically inserts and calls the repository',
      () async {
    when(mockRepository.addComment('trip-1', 'hello')).thenAnswer((_) async => 'new-id');
    final container = buildContainer();
    final notifier = container.read(tripDetailNotifierProvider(trip.id).notifier);
    notifier.seedInitialTrip(trip);

    await notifier.addComment(
      'hello',
      currentUserId: 'me',
      currentUsername: 'me-name',
      currentAvatarUrl: null,
    );

    final state = container.read(tripDetailNotifierProvider(trip.id));
    expect(state.comments.comments.first.id, 'new-id');
    expect(state.comments.comments.first.message, 'hello');
  });

  test('addComment (reply) increments the parent responsesCount', () async {
    when(mockRepository.addReply('trip-1', 'parent-1', 'a reply'))
        .thenAnswer((_) async => 'reply-id');
    final container = buildContainer();
    final notifier = container.read(tripDetailNotifierProvider(trip.id).notifier);
    notifier.seedInitialTrip(trip);
    notifier.debugSeedCommentsForTest(TripDetailCommentsState(
      comments: [
        Comment(id: 'parent-1', tripId: 'trip-1', userId: 'owner', username: 'owner', message: 'parent', responsesCount: 0, createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1)),
      ],
      replyingToCommentId: 'parent-1',
    ));

    await notifier.addComment(
      'a reply',
      currentUserId: 'me',
      currentUsername: 'me-name',
      currentAvatarUrl: null,
    );

    final state = container.read(tripDetailNotifierProvider(trip.id));
    expect(state.comments.replies['parent-1'], hasLength(1));
    expect(state.comments.comments.first.responsesCount, 1);
    expect(state.comments.replyingToCommentId, isNull);
  });

  test('loadReplies uses the comment\'s cached replies when present', () async {
    final container = buildContainer();
    final notifier = container.read(tripDetailNotifierProvider(trip.id).notifier);
    notifier.seedInitialTrip(trip);
    final cachedReply = Comment(id: 'r1', tripId: 'trip-1', userId: 'u1', username: 'a', message: 'cached', createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1));
    notifier.debugSeedCommentsForTest(TripDetailCommentsState(comments: [
      Comment(id: 'parent-1', tripId: 'trip-1', userId: 'owner', username: 'owner', message: 'parent', replies: [cachedReply], createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1)),
    ]));

    await notifier.loadReplies('parent-1');

    verifyNever(mockRepository.loadReplies(any));
    final state = container.read(tripDetailNotifierProvider(trip.id));
    expect(state.comments.replies['parent-1'], [cachedReply]);
    expect(state.comments.expandedComments['parent-1'], isTrue);
  });

  test('loadReplies propagates a repository failure', () async {
    final container = buildContainer();
    final notifier = container.read(tripDetailNotifierProvider(trip.id).notifier);
    notifier.seedInitialTrip(trip);
    notifier.debugSeedCommentsForTest(TripDetailCommentsState(comments: [
      Comment(id: 'parent-1', tripId: 'trip-1', userId: 'owner', username: 'owner', message: 'parent', createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1)),
    ]));
    when(mockRepository.loadReplies('parent-1')).thenThrow(Exception('network error'));

    await expectLater(notifier.loadReplies('parent-1'), throwsException);
  });

  test('toggleRepliesExpanded propagates a loadReplies failure so the caller can surface it',
      () async {
    final container = buildContainer();
    final notifier = container.read(tripDetailNotifierProvider(trip.id).notifier);
    notifier.seedInitialTrip(trip);
    notifier.debugSeedCommentsForTest(TripDetailCommentsState(comments: [
      Comment(id: 'parent-1', tripId: 'trip-1', userId: 'owner', username: 'owner', message: 'parent', createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1)),
    ]));
    when(mockRepository.loadReplies('parent-1')).thenThrow(Exception('network error'));

    await expectLater(
      notifier.toggleRepliesExpanded('parent-1', false),
      throwsException,
    );
  });

  test('getUserReaction finds the current user\'s reaction on a top-level comment',
      () async {
    final container = buildContainer();
    final notifier = container.read(tripDetailNotifierProvider(trip.id).notifier);
    notifier.seedInitialTrip(trip);
    notifier.debugSeedCommentsForTest(TripDetailCommentsState(comments: [
      Comment(
        id: 'c1', tripId: 'trip-1', userId: 'owner', username: 'owner', message: 'hi',
        individualReactions: [
          Reaction(userId: 'me', username: 'me', reactionType: ReactionType.heart, timestamp: DateTime(2026, 1, 1)),
        ],
        createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1),
      ),
    ]));

    expect(notifier.getUserReaction('c1', 'me'), ReactionType.heart);
    expect(notifier.getUserReaction('c1', 'someone-else'), isNull);
  });

  test('handleReactionClick adds a reaction optimistically then calls the repository',
      () async {
    when(mockRepository.addReaction('c1', ReactionType.heart))
        .thenAnswer((_) async {});
    final container = buildContainer();
    final notifier = container.read(tripDetailNotifierProvider(trip.id).notifier);
    notifier.seedInitialTrip(trip);
    notifier.debugSeedCommentsForTest(TripDetailCommentsState(comments: [
      Comment(id: 'c1', tripId: 'trip-1', userId: 'owner', username: 'owner', message: 'hi', createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1)),
    ]));

    await notifier.handleReactionClick('c1', ReactionType.heart,
        currentUserId: 'me', currentUsername: 'me-name');

    verify(mockRepository.addReaction('c1', ReactionType.heart)).called(1);
    final state = container.read(tripDetailNotifierProvider(trip.id));
    expect(state.comments.comments.first.reactions?[ReactionType.heart.toJson()], 1);
  });

  test('handleReactionClick reverts the optimistic update when the repository throws',
      () async {
    when(mockRepository.addReaction('c1', ReactionType.heart))
        .thenThrow(Exception('500'));
    final container = buildContainer();
    final notifier = container.read(tripDetailNotifierProvider(trip.id).notifier);
    notifier.seedInitialTrip(trip);
    notifier.debugSeedCommentsForTest(TripDetailCommentsState(comments: [
      Comment(id: 'c1', tripId: 'trip-1', userId: 'owner', username: 'owner', message: 'hi', createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1)),
    ]));

    await expectLater(
      () => notifier.handleReactionClick('c1', ReactionType.heart,
          currentUserId: 'me', currentUsername: 'me-name'),
      throwsA(isA<Exception>()),
    );

    final state = container.read(tripDetailNotifierProvider(trip.id));
    expect(state.comments.comments.first.reactions, isNull); // reverted
  });

  test('refreshTripData merges ws_-only locations not yet in the API response',
      () async {
    when(mockRepository.getTripById('trip-1')).thenAnswer(
      (_) async => trip.copyWith(locations: [
        TripLocation(id: 'api-1', latitude: 1, longitude: 1, timestamp: DateTime(2026, 1, 1)),
      ]),
    );
    final container = buildContainer();
    final notifier = container.read(tripDetailNotifierProvider(trip.id).notifier);
    notifier.seedInitialTrip(trip.copyWith(locations: [
      TripLocation(id: 'ws_999', latitude: 2, longitude: 2, timestamp: DateTime(2026, 1, 2)),
    ]));

    await notifier.refreshTripData();

    final state = container.read(tripDetailNotifierProvider(trip.id));
    expect(state.trip.locations?.map((l) => l.id), containsAll(['api-1', 'ws_999']));
  });

  test('refreshTripData preserves automaticUpdates when the API has not caught up',
      () async {
    when(mockRepository.getTripById('trip-1'))
        .thenAnswer((_) async => trip.copyWith(automaticUpdates: false));
    final container = buildContainer();
    final notifier = container.read(tripDetailNotifierProvider(trip.id).notifier);
    notifier.seedInitialTrip(trip.copyWith(automaticUpdates: true));

    await notifier.refreshTripData();

    expect(container.read(tripDetailNotifierProvider(trip.id)).trip.automaticUpdates, isTrue);
  });

  test('markWsCameraUpdate makes isWsCameraGuardActive true immediately after', () async {
    final container = buildContainer();
    final notifier = container.read(tripDetailNotifierProvider(trip.id).notifier);
    notifier.seedInitialTrip(trip);

    notifier.markWsCameraUpdate();

    expect(notifier.isWsCameraGuardActive, isTrue);
  });

  test('selectMapLocation clears any selected planned waypoint', () async {
    final container = buildContainer();
    final notifier = container.read(tripDetailNotifierProvider(trip.id).notifier);
    notifier.seedInitialTrip(trip);
    notifier.selectPlannedWaypoint(
      const PlannedWaypointInfo(type: PlannedWaypointType.start, position: LatLng(1, 1)),
    );

    notifier.selectMapLocation(
      TripLocation(id: 'loc-1', latitude: 1, longitude: 1, timestamp: DateTime(2026, 1, 1)),
    );

    final state = container.read(tripDetailNotifierProvider(trip.id));
    expect(state.map.selectedMapLocation?.id, 'loc-1');
    expect(state.map.selectedPlannedWaypoint, isNull);
  });

  test('applyTripStatusChanged updates trip status and defaults currentDay to 1 when starting a multi-day trip',
      () async {
    final container = buildContainer();
    final notifier = container.read(tripDetailNotifierProvider(trip.id).notifier);
    notifier.seedInitialTrip(trip.copyWith(tripModality: TripModality.multiDay));

    notifier.applyTripStatusChanged(TripStatusChangedEvent(
      tripId: 'trip-1',
      newStatus: TripStatus.inProgress,
      previousStatus: TripStatus.created,
      currentDay: null,
      timestamp: DateTime(2026, 1, 1),
      payload: const {},
    ));

    final state = container.read(tripDetailNotifierProvider(trip.id));
    expect(state.trip.status, TripStatus.inProgress);
    expect(state.trip.currentDay, 1);
  });

  test('applyPolylineUpdated sets trip.encodedPolyline', () async {
    final container = buildContainer();
    final notifier = container.read(tripDetailNotifierProvider(trip.id).notifier);
    notifier.seedInitialTrip(trip);

    notifier.applyPolylineUpdated(PolylineUpdatedEvent(
      tripId: 'trip-1',
      encodedPolyline: 'abc123',
      timestamp: DateTime(2026, 1, 1),
      payload: const {},
    ));

    expect(container.read(tripDetailNotifierProvider(trip.id)).trip.encodedPolyline, 'abc123');
  });

  test('applyTripSettingsUpdated updates automaticUpdates/updateRefresh from the event',
      () async {
    final container = buildContainer();
    final notifier = container.read(tripDetailNotifierProvider(trip.id).notifier);
    notifier.seedInitialTrip(trip);

    notifier.applyTripSettingsUpdated(TripSettingsUpdatedEvent(
      tripId: 'trip-1',
      automaticUpdates: true,
      updateRefresh: 30,
      timestamp: DateTime(2026, 1, 1),
      payload: const {},
    ));

    final state = container.read(tripDetailNotifierProvider(trip.id));
    expect(state.trip.automaticUpdates, isTrue);
    expect(state.trip.updateRefresh, 30);
  });

  test('applyTripUpdateEvent adds a new update, returns true when it has a location',
      () async {
    final container = buildContainer();
    final notifier = container.read(tripDetailNotifierProvider(trip.id).notifier);
    notifier.seedInitialTrip(trip);

    final applied = notifier.applyTripUpdateEvent(
      updateId: 'ws_1',
      latitude: 1.0,
      longitude: 2.0,
      timestamp: DateTime(2026, 1, 1),
      batteryLevel: 80,
      message: null,
      city: null,
      country: null,
      temperatureCelsius: null,
      weatherCondition: null,
      updateType: TripUpdateType.regular,
      distanceSoFarKm: 5.0,
    );

    expect(applied, isTrue);
    final state = container.read(tripDetailNotifierProvider(trip.id));
    expect(state.timeline.tripUpdates.single.id, 'ws_1');
    expect(state.trip.accruedDistanceKm, 5.0);
    expect(state.trip.locations?.single.id, 'ws_1');
  });

  test('applyTripUpdateEvent is a no-op for a duplicate updateId', () async {
    final container = buildContainer();
    final notifier = container.read(tripDetailNotifierProvider(trip.id).notifier);
    notifier.seedInitialTrip(trip);
    notifier.applyTripUpdateEvent(
      updateId: 'ws_1', latitude: 1.0, longitude: 2.0, timestamp: DateTime(2026, 1, 1),
      batteryLevel: null, message: null, city: null, country: null,
      temperatureCelsius: null, weatherCondition: null,
      updateType: TripUpdateType.regular, distanceSoFarKm: null,
    );

    final appliedAgain = notifier.applyTripUpdateEvent(
      updateId: 'ws_1', latitude: 1.0, longitude: 2.0, timestamp: DateTime(2026, 1, 1),
      batteryLevel: null, message: null, city: null, country: null,
      temperatureCelsius: null, weatherCondition: null,
      updateType: TripUpdateType.regular, distanceSoFarKm: null,
    );

    expect(appliedAgain, isFalse);
    expect(container.read(tripDetailNotifierProvider(trip.id)).timeline.tripUpdates, hasLength(1));
  });

  test('applyTripUpdateEvent returns false for a lifecycle marker with no location',
      () async {
    final container = buildContainer();
    final notifier = container.read(tripDetailNotifierProvider(trip.id).notifier);
    notifier.seedInitialTrip(trip);

    final applied = notifier.applyTripUpdateEvent(
      updateId: 'ws_2', latitude: null, longitude: null, timestamp: DateTime(2026, 1, 1),
      batteryLevel: null, message: 'Day 1 started!', city: null, country: null,
      temperatureCelsius: null, weatherCondition: null,
      updateType: TripUpdateType.dayStart, distanceSoFarKm: null,
    );

    expect(applied, isFalse); // no location → timeline entry added, but no camera animation needed
    expect(container.read(tripDetailNotifierProvider(trip.id)).timeline.tripUpdates, hasLength(1));
  });

  test('applyCommentAdded inserts a new top-level comment', () async {
    final container = buildContainer();
    final notifier = container.read(tripDetailNotifierProvider(trip.id).notifier);
    notifier.seedInitialTrip(trip);

    notifier.applyCommentAdded(CommentAddedEvent(
      tripId: 'trip-1', commentId: 'c1', userId: 'u1', username: 'alice',
      message: 'hi', parentCommentId: null, timestamp: DateTime(2026, 1, 1),
      payload: const {},
    ));

    expect(container.read(tripDetailNotifierProvider(trip.id)).comments.comments.single.id, 'c1');
  });

  test('applyCommentAdded increments parent responsesCount for a new reply', () async {
    final container = buildContainer();
    final notifier = container.read(tripDetailNotifierProvider(trip.id).notifier);
    notifier.seedInitialTrip(trip);
    notifier.debugSeedCommentsForTest(TripDetailCommentsState(comments: [
      Comment(id: 'parent-1', tripId: 'trip-1', userId: 'owner', username: 'owner', message: 'parent', responsesCount: 0, createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1)),
    ]));

    notifier.applyCommentAdded(CommentAddedEvent(
      tripId: 'trip-1', commentId: 'r1', userId: 'u1', username: 'alice',
      message: 'a reply', parentCommentId: 'parent-1', timestamp: DateTime(2026, 1, 1),
      payload: const {},
    ));

    final state = container.read(tripDetailNotifierProvider(trip.id));
    expect(state.comments.replies['parent-1']?.single.id, 'r1');
    expect(state.comments.comments.single.responsesCount, 1);
  });

  test('applyCommentReaction uses the unified reducer with skipIfDuplicate: true',
      () async {
    final container = buildContainer();
    final notifier = container.read(tripDetailNotifierProvider(trip.id).notifier);
    notifier.seedInitialTrip(trip);
    notifier.debugSeedCommentsForTest(TripDetailCommentsState(comments: [
      Comment(id: 'c1', tripId: 'trip-1', userId: 'owner', username: 'owner', message: 'hi', createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1)),
    ]));

    notifier.applyCommentReaction('c1', currentUserId: 'user-9', newReaction: ReactionType.heart);
    // Re-delivery of the same ADDED event must be a no-op (skipIfDuplicate).
    notifier.applyCommentReaction('c1', currentUserId: 'user-9', newReaction: ReactionType.heart);

    final state = container.read(tripDetailNotifierProvider(trip.id));
    expect(state.comments.comments.single.reactionsCount, 1);
  });

  test('changeTripStatus optimistically sets status and defaults currentDay for a fresh multi-day start',
      () async {
    when(mockRepository.changeTripStatus('trip-1', TripStatus.inProgress))
        .thenAnswer((_) async => 'ok');
    when(mockRepository.sendLifecycleUpdate('trip-1',
            updateType: TripUpdateType.tripStarted, message: anyNamed('message')))
        .thenAnswer((_) async => LocationUpdateResult.success());
    final container = buildContainer();
    final notifier = container.read(tripDetailNotifierProvider(trip.id).notifier);
    notifier.seedInitialTrip(trip.copyWith(
      status: TripStatus.created, tripModality: TripModality.multiDay,
    ));

    await notifier.changeTripStatus(TripStatus.inProgress, isMultiDay: true);

    final state = container.read(tripDetailNotifierProvider(trip.id));
    expect(state.trip.status, TripStatus.inProgress);
    expect(state.trip.currentDay, 1);
    expect(state.lifecycle.isChangingStatus, isFalse);
  });

  test(
      'changeTripStatus swallows a failing fire-and-forget sendLifecycleUpdate '
      'instead of leaking an unhandled Future error', () async {
    when(mockRepository.changeTripStatus('trip-1', TripStatus.inProgress))
        .thenAnswer((_) async => 'ok');
    when(mockRepository.sendLifecycleUpdate('trip-1',
            updateType: TripUpdateType.tripStarted, message: anyNamed('message')))
        .thenAnswer((_) =>
            Future<LocationUpdateResult>.error(Exception('network down')));
    final container = buildContainer();
    // Keep the autoDispose provider alive across the `Future.delayed` below —
    // otherwise it gets torn down (zero listeners) before we re-read it.
    container.listen(tripDetailNotifierProvider(trip.id), (_, __) {});
    final notifier = container.read(tripDetailNotifierProvider(trip.id).notifier);
    notifier.seedInitialTrip(trip.copyWith(status: TripStatus.created));

    await notifier.changeTripStatus(TripStatus.inProgress, isMultiDay: false);
    // Give the unawaited sendLifecycleUpdate Future a turn to complete (and
    // its error to be caught) before the test ends. If the notifier ever
    // regresses to a bare `unawaited(...)` with no `.catchError`, this
    // surfaces as an unhandled async exception failing this test.
    await Future<void>.delayed(Duration.zero);

    final state = container.read(tripDetailNotifierProvider(trip.id));
    expect(state.trip.status, TripStatus.inProgress);
  });

  test(
      'toggleDay swallows a failing fire-and-forget sendLifecycleUpdate '
      'instead of leaking an unhandled Future error', () async {
    when(mockRepository.toggleDay('trip-1')).thenAnswer((_) async => 'ok');
    when(mockRepository.sendLifecycleUpdate('trip-1',
            updateType: TripUpdateType.dayEnd, message: anyNamed('message')))
        .thenAnswer((_) =>
            Future<LocationUpdateResult>.error(Exception('network down')));
    final container = buildContainer();
    container.listen(tripDetailNotifierProvider(trip.id), (_, __) {});
    final notifier = container.read(tripDetailNotifierProvider(trip.id).notifier);
    notifier.seedInitialTrip(trip.copyWith(status: TripStatus.inProgress));

    await notifier.toggleDay(isFinishingDay: true);
    await Future<void>.delayed(Duration.zero);

    expect(container.read(tripDetailNotifierProvider(trip.id)).trip.status,
        TripStatus.resting);
  });

  test('changeTripVisibility updates trip.visibility', () async {
    when(mockRepository.changeTripVisibility('trip-1', Visibility.private))
        .thenAnswer((_) async => 'ok');
    final container = buildContainer();
    final notifier = container.read(tripDetailNotifierProvider(trip.id).notifier);
    notifier.seedInitialTrip(trip);

    await notifier.changeTripVisibility(Visibility.private);

    expect(container.read(tripDetailNotifierProvider(trip.id)).trip.visibility, Visibility.private);
  });

  test('toggleDay(isFinishingDay: true) sets status to resting', () async {
    when(mockRepository.toggleDay('trip-1')).thenAnswer((_) async => 'ok');
    when(mockRepository.sendLifecycleUpdate('trip-1',
            updateType: TripUpdateType.dayEnd, message: anyNamed('message')))
        .thenAnswer((_) async => LocationUpdateResult.success());
    final container = buildContainer();
    final notifier = container.read(tripDetailNotifierProvider(trip.id).notifier);
    notifier.seedInitialTrip(trip.copyWith(status: TripStatus.inProgress));

    await notifier.toggleDay(isFinishingDay: true);

    expect(container.read(tripDetailNotifierProvider(trip.id)).trip.status, TripStatus.resting);
  });

  test('toggleDay(isFinishingDay: false) sets status to inProgress and increments currentDay',
      () async {
    when(mockRepository.toggleDay('trip-1')).thenAnswer((_) async => 'ok');
    when(mockRepository.sendLifecycleUpdate('trip-1',
            updateType: TripUpdateType.dayStart, message: anyNamed('message')))
        .thenAnswer((_) async => LocationUpdateResult.success());
    final container = buildContainer();
    final notifier = container.read(tripDetailNotifierProvider(trip.id).notifier);
    notifier.seedInitialTrip(trip.copyWith(status: TripStatus.resting, currentDay: 1));

    await notifier.toggleDay(isFinishingDay: false);

    final state = container.read(tripDetailNotifierProvider(trip.id));
    expect(state.trip.status, TripStatus.inProgress);
    expect(state.trip.currentDay, 2);
  });

  test('changeTripSettings updates automaticUpdates/updateRefresh/tripModality', () async {
    when(mockRepository.changeTripSettings('trip-1', true, 15, tripModality: TripModality.multiDay))
        .thenAnswer((_) async => 'ok');
    final container = buildContainer();
    final notifier = container.read(tripDetailNotifierProvider(trip.id).notifier);
    notifier.seedInitialTrip(trip);

    await notifier.changeTripSettings(true, 15, TripModality.multiDay);

    final state = container.read(tripDetailNotifierProvider(trip.id));
    expect(state.trip.automaticUpdates, isTrue);
    expect(state.trip.updateRefresh, 15);
    expect(state.trip.tripModality, TripModality.multiDay);
  });

  test('deleteTrip calls the repository', () async {
    when(mockRepository.deleteTrip('trip-1')).thenAnswer((_) async => 'ok');
    final container = buildContainer();
    final notifier = container.read(tripDetailNotifierProvider(trip.id).notifier);
    notifier.seedInitialTrip(trip);

    await notifier.deleteTrip();

    verify(mockRepository.deleteTrip('trip-1')).called(1);
  });

  test('sendManualUpdate calls the repository and returns the result', () async {
    when(mockRepository.sendTripUpdate('trip-1', message: 'hi'))
        .thenAnswer((_) async => LocationUpdateResult.success());
    final container = buildContainer();
    final notifier = container.read(tripDetailNotifierProvider(trip.id).notifier);
    notifier.seedInitialTrip(trip);

    final result = await notifier.sendManualUpdate('hi');

    expect(result.isSuccess, isTrue);
  });
}
