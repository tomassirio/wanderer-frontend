import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wanderer_frontend/core/constants/enums.dart';
import 'package:wanderer_frontend/core/providers/app_providers.dart';
import 'package:wanderer_frontend/data/models/domain/release_note.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/data/services/release_notes_service.dart';
import 'package:wanderer_frontend/presentation/screens/android/android_admin_screen.dart';
import 'package:wanderer_frontend/presentation/screens/android/android_changelog_screen.dart';
import 'package:wanderer_frontend/presentation/screens/settings_screen.dart';
import 'package:wanderer_frontend/presentation/widgets/android/release_notes_widgets.dart';

ReleaseNote _release(String version,
        {bool draft = false, String headline = 'Start a trip in one tap'}) =>
    ReleaseNote(
      version: version,
      draft: draft,
      headline: headline,
      platforms: [ReleasePlatform('ANDROID', DateTime.utc(2026, 10, 6))],
      items: const [
        ReleaseChange(
            type: ReleaseChangeType.newFeature,
            title: 'Start a trip in one tap',
            text: 'Press Start and you are live.',
            prNumber: 112),
        ReleaseChange(
            type: ReleaseChangeType.fixed,
            title: 'Auto check-ins only run on live trips'),
      ],
    );

/// Server stand-in: the unread list follows `lastSeenVersion` like the API.
class _FakeReleaseNotesService extends ReleaseNotesService {
  String? lastSeen;
  List<ReleaseNote> published;
  List<ReleaseNote> admin;
  List<ReleaseNote>? cache;
  bool offline = false;
  int unreadCalls = 0;
  final seen = <String>[];

  _FakeReleaseNotesService(
      {this.lastSeen,
      this.published = const [],
      this.admin = const [],
      this.cache});

  @override
  Future<String> appVersion() async => '1.7.0';

  @override
  Future<List<ReleaseNote>> getReleases() async {
    if (offline) throw Exception('offline');
    return published;
  }

  @override
  Future<List<ReleaseNote>?> cachedReleases() async => cache;

  @override
  Future<({String? lastSeenVersion, List<ReleaseNote> releases})> getUnread(
      String currentVersion) async {
    unreadCalls++;
    if (offline) throw Exception('offline');
    final last = lastSeen;
    return (
      lastSeenVersion: last,
      releases: last == null
          ? <ReleaseNote>[]
          : published
              .where((r) =>
                  r.showPopup &&
                  compareVersions(r.version, last) > 0 &&
                  compareVersions(r.version, currentVersion) <= 0)
              .toList(),
    );
  }

  @override
  Future<void> markSeen(String version) async {
    seen.add(version);
    if (lastSeen == null || compareVersions(version, lastSeen!) > 0) {
      lastSeen = version;
    }
  }

  @override
  Future<List<ReleaseNote>> getAdminReleases() async => admin;
}

Trip _trip(TripStatus status) => Trip.fromJson({
      'id': 't1',
      'userId': 'u1',
      'name': 'Camino',
      'username': 'me',
      'visibility': 'PUBLIC',
      'status': status.toJson(),
      'createdAt': '2026-10-01T00:00:00Z',
      'updatedAt': '2026-10-01T00:00:00Z',
    });

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    resetWhatsNewSession();
  });

  Future<void> pumpHome(WidgetTester tester, _FakeReleaseNotesService service,
      {required List<Trip> trips}) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => maybeShowWhatsNew(context, service,
                tripRunning: trips.any(isTripRunning)),
            child: const Text('open home'),
          ),
        ),
      ),
    ));
  }

  Future<void> openHome(WidgetTester tester) async {
    await tester.tap(find.text('open home'));
    await tester.pumpAndSettle();
  }

  group('What\'s new popup', () {
    testWidgets('shows once after an update, then never again', (tester) async {
      final service = _FakeReleaseNotesService(
          lastSeen: '1.6.11', published: [_release('1.7.0')]);
      await pumpHome(tester, service, trips: const []);

      await openHome(tester);
      expect(find.text("What's new · 1.7.0"), findsOneWidget);
      expect(find.text('New'), findsOneWidget);
      expect(find.text('Fixed'), findsOneWidget);

      await tester.tap(find.text('Got it'));
      await tester.pumpAndSettle();
      expect(find.text("What's new · 1.7.0"), findsNothing);
      expect(service.seen, ['1.7.0']);

      // Same session, and a fresh session (server says it's read).
      await openHome(tester);
      resetWhatsNewSession();
      await openHome(tester);
      expect(find.text("What's new · 1.7.0"), findsNothing);
    });

    testWidgets('waits while a trip is running', (tester) async {
      final service = _FakeReleaseNotesService(
          lastSeen: '1.6.11', published: [_release('1.7.0')]);
      for (final status in [
        TripStatus.inProgress,
        TripStatus.paused,
        TripStatus.resting
      ]) {
        await pumpHome(tester, service, trips: [_trip(status)]);
        await openHome(tester);
        expect(find.text("What's new · 1.7.0"), findsNothing);
      }
      expect(service.unreadCalls, 0);
      expect(service.seen, isEmpty);

      // Next Home open with the trip finished.
      await pumpHome(tester, service, trips: [_trip(TripStatus.finished)]);
      await openHome(tester);
      expect(find.text("What's new · 1.7.0"), findsOneWidget);
    });

    testWidgets('a brand-new user gets no popup, only a baseline',
        (tester) async {
      final service = _FakeReleaseNotesService(published: [_release('1.7.0')]);
      await pumpHome(tester, service, trips: const []);
      await openHome(tester);
      expect(find.text("What's new · 1.7.0"), findsNothing);
      expect(service.seen, ['1.7.0']);
    });

    testWidgets('no popup when the release has it turned off', (tester) async {
      final service = _FakeReleaseNotesService(lastSeen: '1.6.11', published: [
        ReleaseNote(version: '1.7.0', showPopup: false, headline: 'Quiet')
      ]);
      await pumpHome(tester, service, trips: const []);
      await openHome(tester);
      expect(find.text('Quiet'), findsNothing);
      expect(service.seen, ['1.7.0']);
    });

    testWidgets('See every change opens the changelog', (tester) async {
      final service = _FakeReleaseNotesService(
          lastSeen: '1.6.11',
          published: [_release('1.7.0'), _release('1.6.11')]);
      await tester.pumpWidget(ProviderScope(
        overrides: [releaseNotesServiceProvider.overrideWithValue(service)],
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  maybeShowWhatsNew(context, service, tripRunning: false),
              child: const Text('open home'),
            ),
          ),
        ),
      ));
      await openHome(tester);
      await tester.tap(find.text('See every change'));
      await tester.pumpAndSettle();
      expect(find.textContaining("You're on Wanderer 1.7.0"), findsOneWidget);
      expect(find.text('Latest'), findsOneWidget);
    });
  });

  group('Web popup', () {
    testWidgets('Latest tab, switch to All versions, close', (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final service = _FakeReleaseNotesService(
          published: [_release('1.7.0'), _release('1.6.11')]);
      await tester.pumpWidget(ProviderScope(
        overrides: [releaseNotesServiceProvider.overrideWithValue(service)],
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  showWebWhatsNewDialog(context, latest: _release('1.7.0')),
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text('Latest · 1.7.0'), findsOneWidget);
      expect(find.text('Got it'), findsOneWidget);
      expect(find.text('1.6.11'), findsNothing);

      await tester.tap(find.text('All versions').last);
      await tester.pumpAndSettle();
      expect(find.text('1.6.11'), findsOneWidget);
      expect(find.byType(Dialog), findsOneWidget);
      expect(service.seen, ['1.7.0']);

      await tester.tap(find.widgetWithText(FilledButton, 'Close'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
    });
  });

  group('Changelog', () {
    Future<void> pumpChangelog(
        WidgetTester tester, _FakeReleaseNotesService service) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [releaseNotesServiceProvider.overrideWithValue(service)],
        child: const MaterialApp(home: AndroidChangelogScreen()),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('latest expanded, others collapsed, filters', (tester) async {
      final service = _FakeReleaseNotesService(
          published: [_release('1.7.0'), _release('1.6.11')]);
      await pumpChangelog(tester, service);
      expect(find.text('Start a trip in one tap'), findsOneWidget);
      expect(find.text('1.6.11'), findsOneWidget);

      await tester.tap(find.widgetWithText(InkWell, 'Fixed'));
      await tester.pumpAndSettle();
      expect(find.text('Start a trip in one tap'), findsNothing);
      expect(
          find.text('Auto check-ins only run on live trips'), findsOneWidget);
      expect(service.seen, ['1.7.0']);
    });

    testWidgets('update available when the app is behind', (tester) async {
      await pumpChangelog(
          tester, _FakeReleaseNotesService(published: [_release('1.8.0')]));
      expect(find.textContaining('Update available'), findsOneWidget);
    });

    testWidgets('empty history', (tester) async {
      await pumpChangelog(tester, _FakeReleaseNotesService());
      expect(find.text('No release notes yet.'), findsOneWidget);
    });

    testWidgets('offline shows cached notes', (tester) async {
      final service = _FakeReleaseNotesService(cache: [_release('1.7.0')])
        ..offline = true;
      await pumpChangelog(tester, service);
      expect(find.text("You're offline. Showing saved notes."), findsOneWidget);
      expect(find.text('Start a trip in one tap'), findsOneWidget);
    });
  });

  group('Settings › What\'s new', () {
    Future<void> pumpSettings(
        WidgetTester tester, _FakeReleaseNotesService service) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [releaseNotesServiceProvider.overrideWithValue(service)],
        child: const MaterialApp(home: SettingsScreen()),
      ));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text("What's new"), 200,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
    }

    testWidgets('dot until read, cleared after opening', (tester) async {
      final service = _FakeReleaseNotesService(
          lastSeen: '1.6.11', published: [_release('1.7.0')]);
      await pumpSettings(tester, service);
      expect(find.text('Wanderer 1.7.0 · 2 changes'), findsOneWidget);
      expect(find.byType(UnreadDot), findsOneWidget);

      await tester.tap(find.text("What's new"));
      await tester.pumpAndSettle();
      expect(find.textContaining("You're on Wanderer 1.7.0"), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(UnreadDot), findsNothing);
    });

    testWidgets('offline: cached notes, no dot', (tester) async {
      final service = _FakeReleaseNotesService(
          lastSeen: '1.6.11', cache: [_release('1.7.0')])
        ..offline = true;
      await pumpSettings(tester, service);
      expect(find.text('Wanderer 1.7.0 · 2 changes'), findsOneWidget);
      expect(find.byType(UnreadDot), findsNothing);
    });

    testWidgets('no admin release notes in Settings', (tester) async {
      final service =
          _FakeReleaseNotesService(admin: [_release('1.8.0', draft: true)]);
      await pumpSettings(tester, service);
      expect(find.text('Release notes'), findsNothing);
    });
  });

  group('Admin tools › Release notes', () {
    testWidgets('draft pill, editor, preview, publish', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.6;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final published = <ReleaseNote>[];
      final service = _PublishingFake(published,
          admin: [_release('1.8.0', draft: true), _release('1.7.0')]);
      await tester.pumpWidget(ProviderScope(
        overrides: [releaseNotesServiceProvider.overrideWithValue(service)],
        child: const MaterialApp(home: AndroidAdminScreen()),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Release notes'), findsOneWidget);
      expect(find.text('1 draft'), findsOneWidget);

      await tester.tap(find.text('Release notes'));
      await tester.pumpAndSettle();
      expect(find.text('Publish with 1.8.0'), findsOneWidget);
      expect(find.text('from PR #112'), findsOneWidget);

      // Reorder: move the second change up.
      await tester.tap(find.byTooltip('Move up').at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Remove change').at(1));
      await tester.pumpAndSettle();
      expect(find.text('Changes · 1'), findsOneWidget);

      await tester.tap(find.text('Preview'));
      await tester.pumpAndSettle();
      expect(find.text("What's new · 1.8.0"), findsOneWidget);
      await tester.tap(find.text('Got it'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Publish with 1.8.0'));
      await tester.pumpAndSettle();
      expect(published.single.version, '1.8.0');
      expect(published.single.items.single.type, ReleaseChangeType.fixed);
      expect(jsonEncode(published.single.toUpdateJson()),
          contains('"platform":"ANDROID"'));
    });
  });
}

class _PublishingFake extends _FakeReleaseNotesService {
  final List<ReleaseNote> out;
  _PublishingFake(this.out, {super.admin});

  @override
  Future<ReleaseNote> publish(ReleaseNote note) async {
    out.add(note);
    return note;
  }
}
