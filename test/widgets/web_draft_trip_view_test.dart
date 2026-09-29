import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wanderer_frontend/core/constants/enums.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/presentation/strategies/trip_detail_layout_strategy.dart';
import 'package:wanderer_frontend/presentation/widgets/trip_detail/comments_section.dart';
import 'package:wanderer_frontend/presentation/widgets/trip_detail/web_draft_trip_view.dart';

Trip _trip({TripStatus status = TripStatus.created, int? updateCount}) => Trip(
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

TripDetailLayoutData _data(Trip trip) => TripDetailLayoutData(
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

Future<void> _pump(WidgetTester tester, {double width = 1440}) async {
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(body: WebDraftTripView(data: _data(_trip()))),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('WebDraftTripView.shouldShow', () {
    test('owner, draft, nothing tracked', () {
      expect(WebDraftTripView.shouldShow(_trip(), 'me', const []), isTrue);
    });
    test('not for other viewers or logged out', () {
      expect(
          WebDraftTripView.shouldShow(_trip(), 'someone', const []), isFalse);
      expect(WebDraftTripView.shouldShow(_trip(), null, const []), isFalse);
    });
    test('not once started or tracked', () {
      for (final s in TripStatus.values.where((s) => s != TripStatus.created)) {
        expect(WebDraftTripView.shouldShow(_trip(status: s), 'me', const []),
            isFalse);
      }
      expect(WebDraftTripView.shouldShow(_trip(updateCount: 1), 'me', const []),
          isFalse);
    });
  });

  testWidgets('shows heading, steps, QR, copy link and settings rows',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
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

  testWidgets('× hides the card and persists per trip', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await _pump(tester);

    await tester.tap(find.byTooltip('Hide this for this trip'));
    await tester.pumpAndSettle();

    expect(find.text('Start this trip from your phone'), findsNothing);
    expect(find.text('Copy trip link'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(WebDraftTripView.dismissedKey('trip-1')), isTrue);
  });

  testWidgets('stays hidden when dismissed earlier', (tester) async {
    SharedPreferences.setMockInitialValues(
        {WebDraftTripView.dismissedKey('trip-1'): true});
    await _pump(tester);

    expect(find.text('Start this trip from your phone'), findsNothing);
    await tester.tap(find.text('Show'));
    await tester.pumpAndSettle();
    expect(find.text('Start this trip from your phone'), findsOneWidget);
  });

  testWidgets('stacks without overflow on narrow web widths', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await _pump(tester, width: 700);

    expect(tester.takeException(), isNull);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('Copy trip link'), findsOneWidget);
  });
}
