import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/services/notification_service.dart';
import 'package:wanderer_frontend/core/services/push_notification_manager.dart';

void main() {
  group('PushNotificationManager - Preferences', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('defaults to enabled when no preference is stored', () async {
      final manager = PushNotificationManager();
      final enabled = await manager.loadEnabled();
      expect(enabled, isTrue);
    });

    test('persists enabled=true to SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        'push_notifications_enabled': false,
      });
      final manager = PushNotificationManager();
      await manager.setEnabled(true);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('push_notifications_enabled'), isTrue);
      expect(manager.isEnabled, isTrue);
    });

    test('persists enabled=false to SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        'push_notifications_enabled': true,
      });
      final manager = PushNotificationManager();
      await manager.setEnabled(false);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('push_notifications_enabled'), isFalse);
      expect(manager.isEnabled, isFalse);
    });

    test('loads saved preference from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        'push_notifications_enabled': false,
      });
      final manager = PushNotificationManager();
      final enabled = await manager.loadEnabled();
      expect(enabled, isFalse);
    });
  });

  group('activityNotification', () {
    final l10n = AppLocalizations('en');

    test('comment: channel, unquoted title, opens the trip, grouped', () {
      final n = activityNotification(l10n, 'COMMENT_ON_TRIP',
          message: 'julresch commented on your trip "Santiago 2026"',
          referenceId: 't1',
          actorId: 'u1')!;
      expect(n.kind, NotificationChannelKind.comments);
      expect(n.title, 'julresch commented on your trip Santiago 2026');
      expect(n.payload, 'trip:t1');
      expect(n.groupKey, 'comments:t1');
      expect(n.actions.map((a) => a.id),
          [NotificationService.actionReply, NotificationService.actionOpen]);
    });

    test('friend request has Accept and Decline', () {
      final n = activityNotification(l10n, 'FRIEND_REQUEST_RECEIVED',
          message: 'joni sent you a friend request', referenceId: 'r1')!;
      expect(n.kind, NotificationChannelKind.friends);
      expect(n.payload, 'request:r1');
      expect(n.actions.map((a) => a.id), [
        NotificationService.actionAccept,
        NotificationService.actionDecline
      ]);
    });

    test('achievements are their own channel; check-ins are not pushed', () {
      expect(
          activityNotification(l10n, 'ACHIEVEMENT_UNLOCKED',
                  message: 'You unlocked "First steps"', referenceId: 'a1')!
              .kind,
          NotificationChannelKind.achievements);
      expect(
          activityNotification(l10n, 'TRIP_UPDATE_POSTED',
              message: 'joni checked in', referenceId: 't1'),
          isNull);
    });
  });
}
