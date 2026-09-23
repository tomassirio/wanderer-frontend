import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wanderer_frontend/core/providers/app_providers.dart';
import 'package:wanderer_frontend/data/models/domain/search_result.dart';
import 'package:wanderer_frontend/data/services/search_service.dart';
import 'package:wanderer_frontend/presentation/widgets/search/search_overlay.dart';

PageResponse<T> _page<T>(List<T> items) => PageResponse(
    content: items,
    totalElements: items.length,
    totalPages: 1,
    number: 0,
    size: 8,
    first: true,
    last: true,
    empty: items.isEmpty,
    numberOfElements: items.length);

class _FakeSearch extends SearchService {
  @override
  Future<SearchResultsResponse> search(String query,
          {int userPage = 0,
          int userSize = 10,
          int tripPage = 0,
          int tripSize = 10}) async =>
      SearchResultsResponse(
        users: _page([
          UserSearchResult(
              id: 'u1', username: 'tomas', displayName: '', avatarUrl: ''),
        ]),
        trips: _page([
          TripSummary(
              id: 't1',
              name: 'Tom trip',
              userId: 'u1',
              username: 'tomas',
              visibility: 'PUBLIC',
              status: 'FINISHED',
              createdAt: DateTime(2026),
              commentsCount: 2,
              isPromoted: false,
              isPreAnnounced: false,
              thumbnailUrl: ''),
        ]),
      );
}

void main() {
  testWidgets('arrow down + enter picks the trip and saves the query',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    Object? picked;
    await tester.pumpWidget(ProviderScope(
      overrides: [searchServiceProvider.overrideWithValue(_FakeSearch())],
      child: MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => picked = await showGeneralDialog<Object>(
                context: context,
                pageBuilder: (_, __, ___) => const SearchOverlay()),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'tom');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.text('@tomas · 2 comments'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(picked, isA<TripSummary>());
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('search_overlay_recent'), ['tom']);
  });
}
