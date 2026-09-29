import 'package:flutter_test/flutter_test.dart';
import 'package:wanderer_frontend/data/models/notification_models.dart';
import 'package:wanderer_frontend/presentation/screens/android/android_notifications_screen.dart';

NotificationDto _n(String id, NotificationType type, [String? ref]) =>
    NotificationDto(
      id: id,
      recipientId: 'me',
      type: type,
      referenceId: ref,
      message: 'm',
      read: false,
      createdAt: DateTime(2026),
    );

void main() {
  test('groups trips by id and consecutive achievements', () {
    final groups = groupAndroidNotifications([
      _n('t1', NotificationType.tripStatusChanged, 'trip-a'),
      _n('a1', NotificationType.achievementUnlocked),
      _n('a2', NotificationType.achievementUnlocked),
      _n('t2', NotificationType.tripUpdatePosted, 'trip-a'),
      _n('t3', NotificationType.tripUpdatePosted, 'trip-b'),
      _n('c1', NotificationType.commentOnTrip, 'trip-a'),
      _n('a3', NotificationType.achievementUnlocked),
    ]);
    expect(groups.map((g) => g.map((n) => n.id).toList()).toList(), [
      ['t1', 't2'],
      ['a1', 'a2'],
      ['t3'],
      ['c1'],
      ['a3'],
    ]);
  });
}
