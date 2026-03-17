import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:wanderer_frontend/data/models/comment_models.dart';
import 'package:wanderer_frontend/data/models/responses/page_response.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/data/repositories/trip_detail_repository.dart';
import 'package:wanderer_frontend/data/services/comment_service.dart';
import 'package:wanderer_frontend/data/services/trip_service.dart';
import 'package:wanderer_frontend/data/services/auth_service.dart';
import 'package:wanderer_frontend/core/constants/enums.dart';

import 'trip_detail_repository_test.mocks.dart';

@GenerateMocks([CommentService, TripService, AuthService])
void main() {
  group('TripDetailRepository', () {
    late MockCommentService mockCommentService;
    late MockTripService mockTripService;
    late MockAuthService mockAuthService;
    late TripDetailRepository repository;

    setUp(() {
      mockCommentService = MockCommentService();
      mockTripService = MockTripService();
      mockAuthService = MockAuthService();
      repository = TripDetailRepository(
        commentService: mockCommentService,
        tripService: mockTripService,
        authService: mockAuthService,
      );
    });

    group('loadComments', () {
      test('returns only top-level comments from API', () async {
        final topComment1 = createMockComment('comment-1', null);
        final topComment2 = createMockComment('comment-2', null);
        final replyComment = createMockComment('comment-3', 'comment-1');

        when(
          mockCommentService.getCommentsByTripId('trip-1',
              page: anyNamed('page'), size: anyNamed('size')),
        ).thenAnswer((_) async =>
            _wrapCommentsInPage([topComment1, topComment2, replyComment]));

        final result = await repository.loadComments('trip-1');

        expect(result.content.length, 2);
        expect(result.content[0].id, 'comment-1');
        expect(result.content[1].id, 'comment-2');
        verify(mockCommentService.getCommentsByTripId('trip-1',
                page: anyNamed('page'), size: anyNamed('size')))
            .called(1);
      });

      test('returns empty list when no comments', () async {
        when(
          mockCommentService.getCommentsByTripId('trip-1',
              page: anyNamed('page'), size: anyNamed('size')),
        ).thenAnswer((_) async => _wrapCommentsInPage([]));

        final result = await repository.loadComments('trip-1');

        expect(result.content, isEmpty);
        verify(mockCommentService.getCommentsByTripId('trip-1',
                page: anyNamed('page'), size: anyNamed('size')))
            .called(1);
      });

      test('handles API errors gracefully', () async {
        when(
          mockCommentService.getCommentsByTripId('trip-1',
              page: anyNamed('page'), size: anyNamed('size')),
        ).thenThrow(Exception('API Error'));

        expect(() => repository.loadComments('trip-1'), throwsException);
      });

      test(
        'filters out all replies when all comments have parent IDs',
        () async {
          final reply1 = createMockComment('comment-1', 'parent-1');
          final reply2 = createMockComment('comment-2', 'parent-2');

          when(
            mockCommentService.getCommentsByTripId('trip-1',
                page: anyNamed('page'), size: anyNamed('size')),
          ).thenAnswer((_) async => _wrapCommentsInPage([reply1, reply2]));

          final result = await repository.loadComments('trip-1');

          expect(result.content, isEmpty);
        },
      );
    });

    group('loadReplies', () {
      test('returns replies for a specific comment from API', () async {
        final reply1 = createMockComment('reply-1', 'comment-1');
        final reply2 = createMockComment('reply-2', 'comment-1');

        when(
          mockCommentService.getRepliesByCommentId('comment-1'),
        ).thenAnswer((_) async => [reply1, reply2]);

        final result = await repository.loadReplies('comment-1');

        expect(result.length, 2);
        expect(result[0].id, 'reply-1');
        expect(result[1].id, 'reply-2');
        verify(mockCommentService.getRepliesByCommentId('comment-1')).called(1);
      });

      test('returns empty list when comment has no replies', () async {
        when(
          mockCommentService.getRepliesByCommentId('comment-1'),
        ).thenAnswer((_) async => []);

        final result = await repository.loadReplies('comment-1');

        expect(result, isEmpty);
      });

      test('handles API errors gracefully', () async {
        when(
          mockCommentService.getRepliesByCommentId('comment-1'),
        ).thenThrow(Exception('API Error'));

        expect(() => repository.loadReplies('comment-1'), throwsException);
      });
    });

    group('loadReactions', () {
      test('returns empty list as reactions are embedded in comment', () async {
        final comment = createMockComment('comment-1', null);

        final result = await repository.loadReactions(comment);

        expect(result, isEmpty);
      });
    });

    group('addComment', () {
      test('adds a top-level comment successfully', () async {
        when(
          mockCommentService.addComment(captureAny, captureAny),
        ).thenAnswer((_) async => 'new-comment');

        final result = await repository.addComment('trip-1', 'Test message');

        expect(result, 'new-comment');
        final captured =
            verify(mockCommentService.addComment(captureAny, captureAny))
                .captured;
        expect(captured[0], 'trip-1');
        expect(captured[1], isA<CreateCommentRequest>());
      });
    });

    group('addReply', () {
      test('adds a reply to a comment successfully', () async {
        when(
          mockCommentService.addComment(captureAny, captureAny),
        ).thenAnswer((_) async => 'new-reply');

        final result = await repository.addReply(
          'trip-1',
          'parent-1',
          'Reply message',
        );

        expect(result, 'new-reply');
      });
    });

    group('loadTripUpdates', () {
      test('fetches trip updates from API', () async {
        final updates = [
          createMockTripLocation(1.0, 2.0),
          createMockTripLocation(3.0, 4.0),
        ];

        when(
          mockTripService.getTripUpdates('trip-1',
              page: anyNamed('page'), size: anyNamed('size')),
        ).thenAnswer((_) async => _wrapLocationsInPage(updates));

        final result = await repository.loadTripUpdates('trip-1');

        expect(result.content.length, 2);
        verify(mockTripService.getTripUpdates('trip-1',
                page: anyNamed('page'), size: anyNamed('size')))
            .called(1);
      });

      test('returns empty list when no updates', () async {
        when(
          mockTripService.getTripUpdates('trip-1',
              page: anyNamed('page'), size: anyNamed('size')),
        ).thenAnswer((_) async => _wrapLocationsInPage([]));

        final result = await repository.loadTripUpdates('trip-1');

        expect(result.content, isEmpty);
      });
    });

    group('addReaction', () {
      test('adds reaction to a comment successfully', () async {
        when(
          mockCommentService.addReaction(captureAny, captureAny),
        ).thenAnswer((_) async => 'comment-1');

        await repository.addReaction('comment-1', ReactionType.heart);

        final captured =
            verify(mockCommentService.addReaction(captureAny, captureAny))
                .captured;
        expect(captured[0], 'comment-1');
        expect(captured[1], isA<AddReactionRequest>());
      });

      test('handles API errors gracefully', () async {
        when(
          mockCommentService.addReaction(captureAny, captureAny),
        ).thenThrow(Exception('API Error'));

        expect(
          () => repository.addReaction('comment-1', ReactionType.heart),
          throwsException,
        );
      });
    });

    group('removeReaction', () {
      test('removes reaction from a comment successfully', () async {
        when(
          mockCommentService.removeReaction('comment-1', any),
        ).thenAnswer((_) async => 'comment-1');

        await repository.removeReaction('comment-1', ReactionType.heart);

        verify(mockCommentService.removeReaction('comment-1', any)).called(1);
      });

      test('handles API errors gracefully', () async {
        when(
          mockCommentService.removeReaction('comment-1', any),
        ).thenThrow(Exception('API Error'));

        expect(
            () => repository.removeReaction('comment-1', ReactionType.smiley),
            throwsException);
      });
    });

    group('changeTripStatus', () {
      test('changes trip status successfully', () async {
        when(
          mockTripService.changeStatus(captureAny, captureAny),
        ).thenAnswer((_) async => 'trip-1');

        final result = await repository.changeTripStatus(
          'trip-1',
          TripStatus.inProgress,
        );

        expect(result, 'trip-1');
        final captured =
            verify(mockTripService.changeStatus(captureAny, captureAny))
                .captured;
        expect(captured[0], 'trip-1');
        expect(captured[1], isA<ChangeStatusRequest>());
      });

      test('handles API errors gracefully', () async {
        when(
          mockTripService.changeStatus(captureAny, captureAny),
        ).thenThrow(Exception('API Error'));

        expect(
          () => repository.changeTripStatus('trip-1', TripStatus.finished),
          throwsException,
        );
      });
    });

    group('isLoggedIn', () {
      test('returns true when user is logged in', () async {
        when(mockAuthService.isLoggedIn()).thenAnswer((_) async => true);

        final result = await repository.isLoggedIn();

        expect(result, true);
        verify(mockAuthService.isLoggedIn()).called(1);
      });

      test('returns false when user is not logged in', () async {
        when(mockAuthService.isLoggedIn()).thenAnswer((_) async => false);

        final result = await repository.isLoggedIn();

        expect(result, false);
        verify(mockAuthService.isLoggedIn()).called(1);
      });
    });

    group('getCurrentUsername', () {
      test('returns username when user is logged in', () async {
        when(
          mockAuthService.getCurrentUsername(),
        ).thenAnswer((_) async => 'testuser');

        final result = await repository.getCurrentUsername();

        expect(result, 'testuser');
        verify(mockAuthService.getCurrentUsername()).called(1);
      });

      test('returns null when no user is logged in', () async {
        when(
          mockAuthService.getCurrentUsername(),
        ).thenAnswer((_) async => null);

        final result = await repository.getCurrentUsername();

        expect(result, null);
        verify(mockAuthService.getCurrentUsername()).called(1);
      });
    });

    group('getCurrentUserId', () {
      test('returns user ID when user is logged in', () async {
        when(
          mockAuthService.getCurrentUserId(),
        ).thenAnswer((_) async => 'user-123');

        final result = await repository.getCurrentUserId();

        expect(result, 'user-123');
        verify(mockAuthService.getCurrentUserId()).called(1);
      });

      test('returns null when no user is logged in', () async {
        when(mockAuthService.getCurrentUserId()).thenAnswer((_) async => null);

        final result = await repository.getCurrentUserId();

        expect(result, null);
        verify(mockAuthService.getCurrentUserId()).called(1);
      });
    });

    group('logout', () {
      test('logs out user successfully', () async {
        when(mockAuthService.logout()).thenAnswer((_) async => {});

        await repository.logout();

        verify(mockAuthService.logout()).called(1);
      });

      test('handles errors gracefully', () async {
        when(mockAuthService.logout()).thenThrow(Exception('Logout Error'));

        expect(() => repository.logout(), throwsException);
      });
    });
  });
}

// Helper functions
Comment createMockComment(
  String id,
  String? parentCommentId, {
  List<Comment>? replies,
}) {
  return Comment(
    id: id,
    tripId: 'trip-1',
    userId: 'user-1',
    username: 'testuser',
    message: 'Test message',
    parentCommentId: parentCommentId,
    replies: replies,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
}

TripLocation createMockTripLocation(double lat, double lng) {
  return TripLocation(
    id: 'location-${lat.toInt()}-${lng.toInt()}',
    latitude: lat,
    longitude: lng,
    timestamp: DateTime.now(),
  );
}

PageResponse<Comment> _wrapCommentsInPage(List<Comment> comments) {
  return PageResponse(
    content: comments,
    totalElements: comments.length,
    totalPages: comments.isEmpty ? 0 : 1,
    number: 0,
    size: 20,
    first: true,
    last: true,
  );
}

PageResponse<TripLocation> _wrapLocationsInPage(List<TripLocation> locations) {
  return PageResponse(
    content: locations,
    totalElements: locations.length,
    totalPages: locations.isEmpty ? 0 : 1,
    number: 0,
    size: 50,
    first: true,
    last: true,
  );
}

Trip createMockTrip(String id, TripStatus status) {
  return Trip(
    id: id,
    userId: 'user-1',
    name: 'Test Trip',
    username: 'testuser',
    description: 'Test Description',
    status: status,
    visibility: Visibility.public,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
}
