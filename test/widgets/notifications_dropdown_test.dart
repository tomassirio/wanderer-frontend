import 'package:flutter_test/flutter_test.dart';
import 'package:wanderer_frontend/data/models/notification_models.dart';
import 'package:wanderer_frontend/presentation/widgets/common/notifications_dropdown.dart';

NotificationDto _n(String id, NotificationType type) => NotificationDto(
      id: id,
      recipientId: 'me',
      type: type,
      message: 'm',
      read: false,
      createdAt: DateTime(2026),
    );

void main() {
  test('groups consecutive achievements only', () {
    final groups = groupNotifications([
      _n('a1', NotificationType.achievementUnlocked),
      _n('a2', NotificationType.achievementUnlocked),
      _n('c1', NotificationType.commentOnTrip),
      _n('a3', NotificationType.achievementUnlocked),
      _n('c2', NotificationType.commentOnTrip),
      _n('c3', NotificationType.commentOnTrip),
    ]);
    expect(
      groups.map((g) => g.map((n) => n.id).toList()).toList(),
      [
        ['a1', 'a2'],
        ['c1'],
        ['a3'],
        ['c2'],
        ['c3'],
      ],
    );
  });
}
