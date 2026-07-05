import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kalinka/data_model/data_model.dart';
import 'package:kalinka/providers/connection_settings_provider.dart';
import 'package:kalinka/providers/kalinka_player_api_provider.dart';
import 'package:kalinka/providers/search_session_provider.dart';
import 'package:kalinka/providers/source_modules_provider.dart';
import 'package:kalinka/widgets/search/search_session_view.dart';

/// Minimal fake proxy: only the two methods the search session calls are
/// implemented; everything else throws if unexpectedly invoked.
class _FakeApi implements KalinkaPlayerProxy {
  int aiSearchCalls = 0;
  int searchCalls = 0;
  final List<String> queries = [];

  @override
  Future<BrowseItemsList> aiSearch(
    String query, {
    int offset = 0,
    int limit = 10,
    List<String>? sources,
  }) async {
    aiSearchCalls++;
    queries.add(query);
    return _resultFor(query);
  }

  @override
  Future<BrowseItemsList> search(
    SearchType queryType,
    String query, {
    int offset = 0,
    int limit = 30,
  }) async {
    searchCalls++;
    if (queryType == SearchType.artist) {
      return BrowseItemsList(0, limit, 1, [
        BrowseItem(
          id: 'kalinka:qobuz:artist:kw1',
          canBrowse: true,
          canAdd: false,
          artist: Artist(id: 'kw1', name: 'Keyword Artist'),
        ),
      ]);
    }
    if (queryType == SearchType.track) {
      return BrowseItemsList(0, limit, 1, [
        BrowseItem(
          id: 'kalinka:qobuz:track:kwt',
          canBrowse: false,
          canAdd: true,
          track: Track(
            id: 'kwt',
            title: 'Keyword Track',
            duration: 150,
            performer: Artist(id: 'a', name: 'X'),
          ),
        ),
      ]);
    }
    return BrowseItemsList(0, limit, 0, []);
  }

  @override
  Future<BrowseItemsList> getFavorite(
    SearchType queryType, {
    int offset = 0,
    int limit = 10,
    String filter = '',
  }) async {
    return BrowseItemsList(0, limit, 1, [
      BrowseItem(
        id: 'kalinka:localfiles:track:fav_${queryType.name}',
        canBrowse: false,
        canAdd: true,
        timestamp: 1000,
        track: Track(
          id: 'fav_${queryType.name}',
          title: 'Favourite ${queryType.name}',
          duration: 120,
          performer: Artist(id: 'a', name: 'Someone'),
        ),
      ),
    ]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

BrowseItemsList _resultFor(String query) {
  BrowseItem track(String id, String title) => BrowseItem(
    id: 'kalinka:qobuz:track:$id',
    canBrowse: false,
    canAdd: true,
    track: Track(
      id: id,
      title: title,
      duration: 200,
      performer: Artist(id: 'ar', name: 'An Artist'),
    ),
  );
  final section = BrowseItem(
    id: 'kalinka:qobuz:catalog:sec1',
    name: 'Best Match',
    canBrowse: true,
    canAdd: false,
    catalog: Catalog(
      id: 'sec1',
      title: 'Best Match',
      canGenreFilter: false,
      sources: const ['qobuz'],
    ),
    sections: [track('t1', 'Song A'), track('t2', 'Song B')],
  );
  return BrowseItemsList(0, 10, 1, [section]);
}

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'Kalinka.host': 'localhost',
      'Kalinka.port': 8080,
      'Kalinka.name': 'Test',
    });
    prefs = await SharedPreferences.getInstance();
  });

  ProviderContainer makeContainer(_FakeApi api) {
    final container = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        kalinkaProxyProvider.overrideWithValue(api),
        sourceModulesProvider.overrideWith((ref) => <ModuleInfo>[]),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('SearchSessionNotifier', () {
    test('opening loads favourites but fires no search', () async {
      final api = _FakeApi();
      final container = makeContainer(api);
      final notifier = container.read(searchSessionProvider.notifier);

      notifier.open();
      await Future.delayed(const Duration(milliseconds: 50));

      final state = container.read(searchSessionProvider);
      expect(state.isOpen, isTrue);
      expect(state.isZeroState, isTrue);
      expect(state.recentFavourites, isNotEmpty);
      expect(api.aiSearchCalls, 0, reason: 'no search-as-you-type on open');
    });

    test('submit shows a loading block, then resolves to results', () async {
      final api = _FakeApi();
      final container = makeContainer(api);
      final notifier = container.read(searchSessionProvider.notifier);
      notifier.open();

      notifier.submit('jazz for a rainy night');
      var state = container.read(searchSessionProvider);
      expect(state.blocks.length, 1);
      expect(state.isZeroState, isFalse);
      expect(state.blocks.first.query, 'jazz for a rainy night');
      expect(state.blocks.first.loading, isTrue);
      expect(state.expandedBlockId, state.blocks.first.id);

      await Future.delayed(const Duration(milliseconds: 900));
      state = container.read(searchSessionProvider);
      expect(state.blocks.first.loading, isFalse);
      expect(state.blocks.first.results, isNotNull);
      expect(state.blocks.first.resultCount, 2);
      expect(api.aiSearchCalls, 1);
    });

    test('AI off runs a keyword search grouped by type', () async {
      final api = _FakeApi();
      final container = makeContainer(api);
      final notifier = container.read(searchSessionProvider.notifier);
      notifier.open();

      notifier.toggleAiMode();
      expect(container.read(searchSessionProvider).isAiEnabled, isFalse);

      notifier.submit('the beatles');
      await Future.delayed(const Duration(milliseconds: 900));

      final block = container.read(searchSessionProvider).blocks.first;
      expect(block.loading, isFalse);
      expect(api.aiSearchCalls, 0, reason: 'AI off must not call aiSearch');
      expect(api.searchCalls, 4, reason: 'one keyword search per type');
      final sectionNames = block.results!.items.map((s) => s.name).toList();
      expect(sectionNames, ['Artists', 'Tracks']);
    });

    test('keeps at most three blocks; older ones drop from view', () async {
      final api = _FakeApi();
      final container = makeContainer(api);
      final notifier = container.read(searchSessionProvider.notifier);
      notifier.open();

      notifier.submit('one');
      notifier.submit('two');
      notifier.submit('three');
      notifier.submit('four');

      final state = container.read(searchSessionProvider);
      expect(state.blocks.length, 3);
      expect(state.blocks.map((b) => b.query), ['four', 'three', 'two']);

      await Future.delayed(const Duration(milliseconds: 900));
    });

    test('tapping a folded block expands it, collapsing the other', () async {
      final api = _FakeApi();
      final container = makeContainer(api);
      final notifier = container.read(searchSessionProvider.notifier);
      notifier.open();

      notifier.submit('first');
      final firstId = container.read(searchSessionProvider).blocks.first.id;
      notifier.submit('second');
      var state = container.read(searchSessionProvider);
      // Newest is expanded by default.
      expect(state.expandedBlockId, state.blocks.first.id);
      expect(state.expandedBlockId, isNot(firstId));

      notifier.expandBlock(firstId);
      state = container.read(searchSessionProvider);
      expect(state.expandedBlockId, firstId);

      await Future.delayed(const Duration(milliseconds: 900));
    });

    test('closing preserves session queries into history and clears', () async {
      final api = _FakeApi();
      final container = makeContainer(api);
      final notifier = container.read(searchSessionProvider.notifier);
      notifier.open();
      notifier.submit('jazz');
      notifier.submit('techno');
      await Future.delayed(const Duration(milliseconds: 900));

      notifier.close();
      var state = container.read(searchSessionProvider);
      expect(state.isOpen, isFalse);
      expect(state.blocks, isEmpty);

      notifier.open();
      state = container.read(searchSessionProvider);
      // Newest-first history.
      expect(state.history.take(2), ['techno', 'jazz']);
    });
  });

  group('SearchSessionView', () {
    testWidgets('zero state shows AI suggestions and favourites', (
      tester,
    ) async {
      final api = _FakeApi();
      final container = makeContainer(api);
      container.read(searchSessionProvider.notifier).open();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: MediaQuery(
                data: const MediaQueryData(),
                child: Overlay(
                  initialEntries: [
                    OverlayEntry(builder: (_) => const SearchSessionView()),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('ASK THE AI'), findsOneWidget);
      expect(find.text('RECENTLY FAVOURITED'), findsOneWidget);
    });

    testWidgets('submitting shows the query bubble then results', (
      tester,
    ) async {
      final api = _FakeApi();
      final container = makeContainer(api);
      container.read(searchSessionProvider.notifier).open();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Overlay(
                initialEntries: [
                  OverlayEntry(builder: (_) => const SearchSessionView()),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      // No send button while empty.
      expect(find.byIcon(Icons.arrow_upward_rounded), findsNothing);

      await tester.enterText(find.byType(TextField), 'jazz please');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200)); // send fades in

      // Send button appears with text.
      expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pump();

      // Query bubble on screen; composer cleared.
      expect(find.text('jazz please'), findsOneWidget);

      // Resolve past the minimum loading window.
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pump();

      expect(find.text('BEST MATCH'), findsOneWidget);
      expect(find.text('Song A'), findsOneWidget);
      expect(find.text('Song B'), findsOneWidget);
    });
  });
}
