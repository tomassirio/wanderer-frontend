import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
}
