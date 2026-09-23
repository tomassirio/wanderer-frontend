import 'package:flutter_test/flutter_test.dart';
import 'package:wanderer_frontend/data/models/domain/comment.dart';
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
}
