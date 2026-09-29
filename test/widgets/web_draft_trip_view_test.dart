import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wanderer_frontend/core/constants/enums.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/presentation/strategies/trip_detail_layout_strategy.dart';
import 'package:wanderer_frontend/presentation/widgets/trip_detail/comments_section.dart';
import 'package:wanderer_frontend/presentation/widgets/trip_detail/web_draft_trip_view.dart';
import 'package:wanderer_frontend/presentation/widgets/trip_detail/web_trip_detail_layout.dart';

Trip tripFor({TripStatus status = TripStatus.created, int? updateCount}) =>
    Trip(
      id: 'trip-1',
      userId: 'me',
      name: 'Trjs',
      username: 'tomassirio',
      visibility: Visibility.public,
      status: status,
      automaticUpdates: true,
      updateRefresh: 1200,
      tripModality: TripModality.simple,
      updateCount: updateCount,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

TripDetailLayoutData dataFor(Trip trip) => TripDetailLayoutData(
      trip: trip,
      comments: const [],
      replies: const {},
      expandedComments: const {},
      tripUpdates: const [],
      isLoadingComments: false,
      isLoadingUpdates: false,
      isLoggedIn: true,
      isAddingComment: false,
      isTimelineCollapsed: false,
      isCommentsCollapsed: true,
      isTripInfoCollapsed: true,
      isTripUpdateCollapsed: true,
      isTripSettingsCollapsed: true,
      isSendingUpdate: false,
      sortOption: CommentSortOption.latest,
      commentController: TextEditingController(),
      scrollController: ScrollController(),
      currentUserId: 'me',
      onToggleTripInfo: () {},
      onToggleComments: () {},
      onToggleTimeline: () {},
      onToggleTripUpdate: () {},
      onToggleTripSettings: () {},
      onRefreshTimeline: () async {},
      onSortChanged: (_) {},
      onReact: (_) {},
      onReactionChipTap: (_, __) {},
      onReply: (_) {},
      onToggleReplies: (_, __) {},
      onSendComment: () {},
      onCancelReply: () {},
      onSendTripUpdate: (_) async {},
    );

Future<void> _pump(WidgetTester tester,
    {double width = 1440, VoidCallback? onDismiss}) async {
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
        body: WebDraftTripView(
            data: dataFor(tripFor()), onDismiss: onDismiss ?? () {})),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('WebDraftTripView.shouldShow', () {
    test('owner, draft, nothing tracked', () {
      expect(WebDraftTripView.shouldShow(tripFor(), 'me', const []), isTrue);
    });
    test('not for other viewers or logged out', () {
      expect(
          WebDraftTripView.shouldShow(tripFor(), 'someone', const []), isFalse);
      expect(WebDraftTripView.shouldShow(tripFor(), null, const []), isFalse);
    });
    test('not once started or tracked', () {
      for (final s in TripStatus.values.where((s) => s != TripStatus.created)) {
        expect(WebDraftTripView.shouldShow(tripFor(status: s), 'me', const []),
            isFalse);
      }
      expect(
          WebDraftTripView.shouldShow(tripFor(updateCount: 1), 'me', const []),
          isFalse);
    });
  });

  testWidgets('shows heading, steps, QR, copy link and settings rows',
      (tester) async {
    await _pump(tester);

    expect(find.text('Start this trip from your phone'), findsOneWidget);
    expect(find.textContaining('sign in as @tomassirio', findRichText: true),
        findsOneWidget);
    expect(find.textContaining('Open this trip', findRichText: true),
        findsOneWidget);
    expect(find.textContaining('Tap Start trip', findRichText: true),
        findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('Copy trip link'), findsOneWidget);
    expect(find.text('Single day'), findsOneWidget);
    expect(find.text('Every 20 min'), findsOneWidget);
    expect(find.text('Visible to'), findsOneWidget);
  });

  testWidgets('× calls onDismiss', (tester) async {
    var dismissed = 0;
    await _pump(tester, onDismiss: () => dismissed++);

    await tester.tap(find.byTooltip('Hide this for this trip'));
    expect(dismissed, 1);
  });

  test('dismissal persists per trip and hides the view', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await WebDraftTripView.isDismissed('trip-1'), isFalse);

    await WebDraftTripView.setDismissed('trip-1');

    expect(await WebDraftTripView.isDismissed('trip-1'), isTrue);
    expect(await WebDraftTripView.isDismissed('trip-2'), isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('draft_start_hint_dismissed_trip-1'), isTrue);
    expect(
        WebDraftTripView.shouldShow(tripFor(), 'me', const [], dismissed: true),
        isFalse);
  });

  testWidgets('stacks without overflow on narrow web widths', (tester) async {
    await _pump(tester, width: 700);

    expect(tester.takeException(), isNull);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('Copy trip link'), findsOneWidget);
  });

  testWidgets('wide windows: fluid page, three columns, capped text',
      (tester) async {
    await _pump(tester, width: 2000);

    final heading =
        tester.getRect(find.text('Start this trip from your phone'));
    final body = tester.getRect(find.textContaining('Live tracking needs'));
    final qr = tester.getRect(find.byType(QrImageView));
    expect(qr.left, greaterThan(heading.right));
    expect(body.width, lessThanOrEqualTo(WebDraftTripView.maxTextWidth));
    // Side column is pinned to the right content edge (40px gutter).
    expect(tester.getRect(find.text('Copy trip link')).right,
        closeTo(2000 - 40 - 21, 200));
    expect(tester.getRect(find.text('Edit trip')).right, greaterThan(1900));
  });

  group('WebTripDetailLayout "Start on phone" button', () {
    Future<void> pumpLayout(WidgetTester tester, VoidCallback? onTap) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: WebTripDetailLayout(
              data: dataFor(tripFor()),
              map: const SizedBox(),
              onStartOnPhone: onTap,
            ),
          ),
        ),
      ));
      await tester.pump();
    }

    testWidgets('shown when given and brings the guide back', (tester) async {
      var taps = 0;
      await pumpLayout(tester, () => taps++);

      await tester.tap(find.text('Start on phone'));
      expect(taps, 1);
      expect(find.byIcon(Icons.phone_android), findsOneWidget);
    });

    testWidgets('hidden without a callback (non-owner / started)',
        (tester) async {
      await pumpLayout(tester, null);
      expect(find.text('Start on phone'), findsNothing);
    });
  });

  test('clearDismissed removes the per-trip flag', () async {
    SharedPreferences.setMockInitialValues(
        {WebDraftTripView.dismissedKey('trip-1'): true});
    await WebDraftTripView.clearDismissed('trip-1');
    expect(await WebDraftTripView.isDismissed('trip-1'), isFalse);
  });
}
