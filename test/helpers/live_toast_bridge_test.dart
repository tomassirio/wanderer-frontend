import 'package:flutter_test/flutter_test.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/data/models/websocket/websocket_event.dart';
import 'package:wanderer_frontend/presentation/helpers/live_toast_bridge.dart';
import 'package:wanderer_frontend/presentation/widgets/common/toasts.dart';

NotificationCreatedEvent _n(String type, String message,
        {String recipient = 'me', String? actor = 'u1', String? ref = 't1'}) =>
    NotificationCreatedEvent.fromJson({
      'type': 'NOTIFICATION_CREATED',
      'payload': {
        'id': 'n1',
        'recipientId': recipient,
        'actorId': actor,
        'type': type,
        'referenceId': ref,
        'message': message,
      },
    });

void main() {
  final l10n = AppLocalizations('en');
  ToastData? map(NotificationCreatedEvent e, {String? comment}) =>
      liveToastFor(e, myUserId: 'me', l10n: l10n, commentText: comment);

  test('comment on my trip -> grouped social toast with reply link', () {
    final t = map(
        _n('COMMENT_ON_TRIP', 'julresch commented on your trip "Santiago"'),
        comment: 'Nice!')!;
    expect(t.kind, ToastKind.social);
    expect(t.title, '@julresch commented');
    expect(t.body, '“Nice!”');
    expect(t.initial, 'julresch');
    expect(t.groupKey, 'comments:t1');
    expect(t.groupedTitle!(5), '5 new comments on Santiago');
    expect(t.linkLabel, 'Reply');
  });

  test('friend request -> request with accept/decline', () {
    final t =
        map(_n('FRIEND_REQUEST_RECEIVED', 'ana sent you a friend request'))!;
    expect(t.kind, ToastKind.request);
    expect(t.title, '@ana sent you a friend request');
    expect(t.onAccept, isNotNull);
    expect(t.onDecline, isNotNull);
  });

  test('achievement and trip status map to their kinds', () {
    final a = map(_n(
        'ACHIEVEMENT_UNLOCKED', 'You unlocked the achievement "First 100 km"!',
        actor: null))!;
    expect(a.kind, ToastKind.achievement);
    expect(a.body, 'First 100 km');
    final s =
        map(_n('TRIP_STATUS_CHANGED', 'bob finished their trip "Andes"'))!;
    expect(s.kind, ToastKind.info);
    expect(s.title, '@bob finished Andes');
    expect(s.linkLabel, 'Open live map');
  });

  test('skips my own actions, other recipients and unknown types', () {
    expect(map(_n('NEW_FOLLOWER', 'me started following you', actor: 'me')),
        isNull);
    expect(map(_n('NEW_FOLLOWER', 'x started following you', recipient: 'o')),
        isNull);
    expect(map(_n('SOMETHING_NEW', 'x did a thing')), isNull);
  });
}
