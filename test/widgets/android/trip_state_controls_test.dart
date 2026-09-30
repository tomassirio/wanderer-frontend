import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter_test/flutter_test.dart';
import 'package:wanderer_frontend/core/constants/enums.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/presentation/strategies/trip_detail_layout_strategy.dart';
import 'package:wanderer_frontend/presentation/widgets/android/trip_checkin_sheet.dart';
import 'package:wanderer_frontend/presentation/widgets/android/trip_detail_android_layout.dart';
import 'package:wanderer_frontend/presentation/widgets/trip_detail/comments_section.dart';
import 'package:wanderer_frontend/presentation/widgets/android/trip_state_controls.dart';

void main() {
  final tapped = <String>[];

  Widget app(TripStatus status, {bool multiDay = false}) => MaterialApp(
        theme: WandererTheme.lightTheme(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TripStateControls(
              status: status,
              isMultiDay: multiDay,
              onStart: () => tapped.add('start'),
              onCheckIn: () => tapped.add('checkIn'),
              onPause: () => tapped.add('pause'),
              onRest: () => tapped.add('rest'),
              onResume: () => tapped.add('resume'),
              onContinue: () => tapped.add('continue'),
              onFinish: () => tapped.add('finish'),
            ),
          ),
        ),
      );

  Set<String> keys(WidgetTester tester) => tester
      .widgetList<TripSheetButton>(find.byType(TripSheetButton))
      .map((b) => (b.key as ValueKey<String>).value)
      .toSet();

  setUp(tapped.clear);

  testWidgets('buttons per state follow the canvas', (tester) async {
    await tester.pumpWidget(app(TripStatus.created));
    expect(keys(tester), {'trip_start'});

    await tester.pumpWidget(app(TripStatus.inProgress));
    expect(keys(tester), {'trip_check_in', 'trip_pause', 'trip_finish'});

    await tester.pumpWidget(app(TripStatus.inProgress, multiDay: true));
    expect(keys(tester),
        {'trip_check_in', 'trip_pause', 'trip_rest', 'trip_finish'});

    await tester.pumpWidget(app(TripStatus.paused));
    expect(keys(tester), {'trip_resume', 'trip_finish'});

    await tester.pumpWidget(app(TripStatus.resting, multiDay: true));
    expect(keys(tester), {'trip_continue', 'trip_finish'});

    await tester.pumpWidget(app(TripStatus.finished));
    expect(find.byType(TripSheetButton), findsNothing);
  });

  testWidgets(
      'blockStart greys out the Start button and calls onStartBlocked instead of onStart',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: WandererTheme.lightTheme(),
      home: Scaffold(
        body: Builder(
          builder: (context) => TripStateControls(
            status: TripStatus.created,
            isMultiDay: false,
            blockStart: true,
            onStartBlocked: () => tapped.add('startBlocked'),
            onStart: () => tapped.add('start'),
            onCheckIn: () => tapped.add('checkIn'),
            onPause: () => tapped.add('pause'),
            onRest: () => tapped.add('rest'),
            onResume: () => tapped.add('resume'),
            onContinue: () => tapped.add('continue'),
            onFinish: () => tapped.add('finish'),
          ),
        ),
      ),
    ));

    final startButton =
        tester.widget<TripSheetButton>(find.byKey(const Key('trip_start')));
    expect(startButton.background, WandererTheme.trail.withOpacity(0.4));

    await tester.tap(find.byKey(const Key('trip_start')));
    expect(tapped, ['startBlocked']);
  });

  testWidgets('only the main action is orange; pause is tinted paused',
      (tester) async {
    await tester.pumpWidget(app(TripStatus.inProgress, multiDay: true));
    final buttons =
        tester.widgetList<TripSheetButton>(find.byType(TripSheetButton));
    expect(buttons.where((b) => b.background == WandererTheme.trail).length, 1);
    final pause =
        tester.widget<TripSheetButton>(find.byKey(const Key('trip_pause')));
    expect(pause.background, WandererColors.light.pausedBg);

    await tester.tap(find.byKey(const Key('trip_check_in')));
    await tester.tap(find.byKey(const Key('trip_rest')));
    expect(tapped, ['checkIn', 'rest']);
  });

  testWidgets('finish sheet confirms or keeps going', (tester) async {
    bool? result;
    await tester.pumpWidget(MaterialApp(
      theme: WandererTheme.lightTheme(),
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async =>
              result = await showTripFinishSheet(context, tripName: 'Camino'),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Camino'), findsOneWidget);
    await tester.tap(find.byKey(const Key('trip_finish_confirm')));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  test('check-in titles use place names, events keep their label', () {
    final l10n = AppLocalizations('en');
    TripLocation loc(TripUpdateType type, {String? city}) => TripLocation(
          id: '1',
          latitude: 52.37,
          longitude: 4.89,
          timestamp: DateTime(2026, 3, 12, 8, 8),
          city: city,
          country: city == null ? null : 'Netherlands',
          updateType: type,
        );
    expect(
        tripCheckInTitle(l10n, loc(TripUpdateType.regular, city: 'Amsterdam')),
        'Amsterdam, Netherlands');
    expect(
        tripCheckInTitle(l10n, loc(TripUpdateType.regular)), '52.3700, 4.8900');
    expect(
        tripCheckInTitle(l10n, loc(TripUpdateType.tripEnded, city: 'Santiago')),
        'Trip finished · Santiago, Netherlands');
    expect(tripCheckInTitle(l10n, loc(TripUpdateType.dayEnd)), 'Day ended');
  });

  testWidgets('guest trip view shows the log-in CTA and no controls',
      (tester) async {
    tester.view.physicalSize = const Size(412 * 3, 915 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    var login = 0;
    final trip = Trip(
      id: 't',
      userId: 'owner',
      name: 'Santiago de Compostela 2026',
      username: 'tomassirio',
      visibility: Visibility.public,
      status: TripStatus.finished,
      createdAt: DateTime(2026, 4, 3),
      updatedAt: DateTime(2026, 5, 17),
    );
    final data = TripDetailLayoutData(
      trip: trip,
      comments: const [],
      replies: const {},
      expandedComments: const {},
      tripUpdates: [
        TripLocation(
          id: 'u1',
          latitude: 42.88,
          longitude: -8.54,
          timestamp: DateTime(2026, 5, 17, 11, 27),
          city: 'Santiago',
          country: 'Spain',
          battery: 73,
        ),
      ],
      isLoadingComments: false,
      isLoadingUpdates: false,
      isLoggedIn: false,
      isAddingComment: false,
      isTimelineCollapsed: false,
      isCommentsCollapsed: false,
      isTripInfoCollapsed: false,
      isTripUpdateCollapsed: true,
      isTripSettingsCollapsed: true,
      isSendingUpdate: false,
      sortOption: CommentSortOption.latest,
      commentController: TextEditingController(),
      scrollController: ScrollController(),
      onToggleTripInfo: () {},
      onToggleComments: () {},
      onToggleTimeline: () {},
      onToggleTripUpdate: () {},
      onToggleTripSettings: () {},
      onRefreshTimeline: () {},
      onSortChanged: (_) {},
      onReact: (_) {},
      onReactionChipTap: (_, __) {},
      onReply: (_) {},
      onToggleReplies: (_, __) {},
      onSendComment: () {},
      onCancelReply: () {},
      onSendTripUpdate: (_) async {},
    );
    await tester.pumpWidget(MaterialApp(
      theme: WandererTheme.lightTheme(),
      home: Scaffold(
        body: TripDetailAndroidLayout(
          data: data,
          map: const SizedBox.expand(),
          onLogin: () => login++,
          onCheckInTap: (_) {},
        ),
      ),
    ));
    expect(find.text('Santiago de Compostela 2026'), findsOneWidget);
    expect(find.byType(TripStateControls), findsNothing);
    await tester.pump(); // half detent settles on the measured header
    await tester.tap(find.byKey(const Key('trip_guest_login')));
    expect(login, 1);

    // Nearest Opacity above a widget: 0 = hidden by the sheet position.
    double opacityOf(Finder f) => tester
        .widget<Opacity>(
            find.ancestor(of: f, matching: find.byType(Opacity)).first)
        .opacity;
    // Hidden = not built, or built under a fully transparent Opacity.
    bool hidden(Finder f) => f.evaluate().isEmpty || opacityOf(f) == 0;
    final row = find.text('Santiago, Spain');
    final title = find.text('Santiago de Compostela 2026');

    // Half by default and no list row shows; a tab opens the full sheet
    // with the timeline, "Show map" goes back.
    expect(find.byKey(const Key('trip_sheet_show_map')), findsNothing);
    expect(hidden(row), isTrue);
    await tester.tap(find.textContaining('Timeline'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('trip_sheet_show_map')), findsOneWidget);
    expect(opacityOf(row), 1);
    await tester.tap(find.byKey(const Key('trip_sheet_show_map')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('trip_sheet_show_map')), findsNothing);
    expect(hidden(row), isTrue);

    // Collapsed shows only the handle.
    await tester.drag(title, const Offset(0, 600));
    await tester.pumpAndSettle();
    expect(hidden(title), isTrue);
  });
}
