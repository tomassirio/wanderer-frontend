import 'package:flutter_test/flutter_test.dart';
import 'package:wanderer_frontend/data/models/comment_models.dart';
import 'package:wanderer_frontend/presentation/state/trip_detail/trip_detail_notifier.dart';

void main() {
  Comment baseComment({Map<String, int>? reactions, List<Reaction>? individualReactions}) {
    return Comment(
      id: 'c1',
      tripId: 'trip-1',
      userId: 'owner',
      username: 'owner',
      message: 'hi',
      reactions: reactions,
      individualReactions: individualReactions,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
  }

  test('adds a new reaction when the user had none', () {
    final result = applyReactionChange(
      comment: baseComment(),
      userId: 'user-1',
      username: 'user-one',
      oldReaction: null,
      newReaction: ReactionType.heart,
    );
    expect(result.reactions?[ReactionType.heart.toJson()], 1);
    expect(result.individualReactions?.single.userId, 'user-1');
  });

  test('removes the reaction when newReaction is null', () {
    final comment = baseComment(
      reactions: {ReactionType.heart.toJson(): 1},
      individualReactions: [
        Reaction(userId: 'user-1', username: 'user-one', reactionType: ReactionType.heart, timestamp: DateTime(2026, 1, 1)),
      ],
    );
    final result = applyReactionChange(
      comment: comment,
      userId: 'user-1',
      username: 'user-one',
      oldReaction: ReactionType.heart,
      newReaction: null,
    );
    expect(result.reactions, isNull);
    expect(result.individualReactions, isNull);
  });

  test('replaces one reaction with another, decrementing the old and incrementing the new', () {
    final comment = baseComment(
      reactions: {ReactionType.heart.toJson(): 1},
      individualReactions: [
        Reaction(userId: 'user-1', username: 'user-one', reactionType: ReactionType.heart, timestamp: DateTime(2026, 1, 1)),
      ],
    );
    final result = applyReactionChange(
      comment: comment,
      userId: 'user-1',
      username: 'user-one',
      oldReaction: ReactionType.heart,
      newReaction: ReactionType.smiley,
    );
    expect(result.reactions?[ReactionType.heart.toJson()], isNull);
    expect(result.reactions?[ReactionType.smiley.toJson()], 1);
  });

  test('decrements (not removes) the count when another user still holds the old reaction', () {
    final comment = baseComment(
      reactions: {ReactionType.heart.toJson(): 2},
      individualReactions: [
        Reaction(userId: 'user-1', username: 'user-one', reactionType: ReactionType.heart, timestamp: DateTime(2026, 1, 1)),
        Reaction(userId: 'user-2', username: 'user-two', reactionType: ReactionType.heart, timestamp: DateTime(2026, 1, 1)),
      ],
    );
    final result = applyReactionChange(
      comment: comment,
      userId: 'user-1',
      username: 'user-one',
      oldReaction: ReactionType.heart,
      newReaction: null,
    );
    expect(result.reactions?[ReactionType.heart.toJson()], 1);
    expect(result.individualReactions, hasLength(1));
    expect(result.individualReactions?.single.userId, 'user-2');
  });

  test('skipIfDuplicate: returns the comment unchanged for a re-delivered ADD', () {
    final comment = baseComment(
      reactions: {ReactionType.heart.toJson(): 1},
      individualReactions: [
        Reaction(userId: 'user-1', username: '', reactionType: ReactionType.heart, timestamp: DateTime(2026, 1, 1)),
      ],
    );
    final result = applyReactionChange(
      comment: comment,
      userId: 'user-1',
      username: '',
      oldReaction: null,
      newReaction: ReactionType.heart,
      skipIfDuplicate: true,
    );
    expect(identical(result, comment), isTrue);
  });

  test('skipIfDuplicate: returns the comment unchanged for a re-delivered REMOVE', () {
    final comment = baseComment(); // user already has no reaction
    final result = applyReactionChange(
      comment: comment,
      userId: 'user-1',
      username: '',
      oldReaction: ReactionType.heart,
      newReaction: null,
      skipIfDuplicate: true,
    );
    expect(identical(result, comment), isTrue);
  });

  test('skipIfDuplicate: returns the comment unchanged for a re-delivered REPLACE', () {
    final comment = baseComment(
      reactions: {ReactionType.smiley.toJson(): 1},
      individualReactions: [
        Reaction(userId: 'user-1', username: '', reactionType: ReactionType.smiley, timestamp: DateTime(2026, 1, 1)),
      ],
    );
    final result = applyReactionChange(
      comment: comment,
      userId: 'user-1',
      username: '',
      oldReaction: ReactionType.heart, // previousReactionType from the event
      newReaction: ReactionType.smiley, // user already has this
      skipIfDuplicate: true,
    );
    expect(identical(result, comment), isTrue);
  });

  test('skipIfDuplicate: does NOT skip a genuinely new (non-duplicate) change', () {
    final comment = baseComment();
    final result = applyReactionChange(
      comment: comment,
      userId: 'user-1',
      username: 'user-one',
      oldReaction: null,
      newReaction: ReactionType.heart,
      skipIfDuplicate: true,
    );
    expect(result.reactions?[ReactionType.heart.toJson()], 1);
  });
}
