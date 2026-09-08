import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kalinka/data_model/browse_filters.dart';
import 'package:kalinka/data_model/data_model.dart';
import 'package:kalinka/data_model/search_results.dart';
import 'package:kalinka/providers/app_state_provider.dart';
import 'package:kalinka/providers/catalog_cards_provider.dart';
import 'package:kalinka/providers/connection_settings_provider.dart';
import 'package:kalinka/providers/connection_state_provider.dart';
import 'package:kalinka/providers/kalinka_player_api_provider.dart';
import 'package:kalinka/providers/search_session_provider.dart';
import 'package:kalinka/providers/source_modules_provider.dart';
import 'package:kalinka/widgets/search/search_zero_state.dart';

/// Minimal fake proxy: only the methods the search session calls are
/// implemented; everything else throws if unexpectedly invoked.
class _FakeApi implements KalinkaPlayerProxy {
  int aiSearchCalls = 0;
  int matchCalls = 0;
  final List<String> queries = [];

  @override
  Future<BrowseItemsList> aiSearch(
    String query, {
    int offset = 0,
    int limit = 10,
    List<String>? sources,
  }) async {
    aiSearchCalls++;
    return _inspiredFor(sources!.single);
  }

  @override
  Future<BrowseItemsList> searchMatches(
    String query, {
    List<String>? sources,
  }) async {
    matchCalls++;
    queries.add(query);
    return _matchesFor(sources!.single);
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

/// The search that never answers — neither leg's future ever completes.
class _HangingApi extends _FakeApi {
  @override
  Future<BrowseItemsList> aiSearch(
    String query, {
    int offset = 0,
    int limit = 10,
    List<String>? sources,
  }) {
    aiSearchCalls++;
    return Completer<BrowseItemsList>().future;
  }

  @override
  Future<BrowseItemsList> searchMatches(String query, {List<String>? sources}) {
    matchCalls++;
    return Completer<BrowseItemsList>().future;
  }
}

/// A source whose name-match leg fails on the first ask and answers after.
class _FlakyApi extends _FakeApi {
  @override
  Future<BrowseItemsList> searchMatches(
    String query, {
    List<String>? sources,
  }) async {
    matchCalls++;
    if (matchCalls == 1) throw Exception('upstream down');
    return _matchesFor(sources!.single);
  }
}

/// Pinned connection state — the real notifier arms a retry [Timer] that
/// would outlive widget tests.
class _FixedConnection extends ConnectionStateNotifier {
  @override
  ConnectionStatus build() => ConnectionStatus.connected;
}

BrowseItem _track(String source, String id, String title) => BrowseItem(
  id: 'kalinka:$source:track:$id',
  canBrowse: false,
  canAdd: true,
  track: Track(
    id: id,
    title: title,
    duration: 200,
    performer: Artist(id: 'ar', name: 'An Artist'),
  ),
);

BrowseItemsList _matchesFor(String source) => BrowseItemsList(0, 1, 1, [
  BrowseItem(
    id: 'kalinka:$source:artist:a1',
    name: 'An Artist',
    canBrowse: true,
    canAdd: false,
    artist: Artist(id: 'a1', name: 'An Artist'),
    match: const NameMatch(tier: MatchTier.exact, score: 100),
  ),
]);

BrowseItemsList _inspiredFor(String source) => BrowseItemsList(0, 1, 1, [
  BrowseItem(
    id: 'kalinka:$source:catalog:ai',
    name: 'AI SUGGESTIONS',
    canBrowse: false,
    canAdd: false,
    catalog: Catalog(id: 'ai', title: 'AI SUGGESTIONS', sources: [source]),
    sections: [_track(source, 't1', 'Song A'), _track(source, 't2', 'Song B')],
  ),
]);

final _modules = <ModuleInfo>[
  ModuleInfo(
    name: 'qobuz',
    title: 'Qobuz',
    enabled: true,
    state: ModuleState.ready,
  ),
];

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
        sourceModulesProvider.overrideWith((ref) => _modules),
        connectionStateProvider.overrideWith(_FixedConnection.new),
        // The real provider opens the wire-event WebSocket (retry timer).
        playerStateProvider.overrideWithValue(PlaybackState.empty),
        // Keep the zero-state's catalog section inert (its real fetch arms a
        // refresh timer that would outlive the test).
        catalogCardGroupsProvider.overrideWith(
          (ref) => Future.value(const <CatalogCardGroup>[]),
        ),
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
      expect(state.activeView, FindMusicView.catalogs);
      expect(state.resultsAvailable, isFalse);
      expect(state.recentFavourites, isNotEmpty);
      expect(api.matchCalls + api.aiSearchCalls, 0);
    });

    test(
      'submit asks every source twice and lands each leg on its own',
      () async {
        final api = _FakeApi();
        final container = makeContainer(api);
        final notifier = container.read(searchSessionProvider.notifier);
        notifier.open();

        notifier.submit('jazz for a rainy night');
        var state = container.read(searchSessionProvider);
        expect(state.activeView, FindMusicView.results);
        expect(state.resultsAvailable, isTrue);
        expect(state.searchQuery, 'jazz for a rainy night');
        expect(state.searchLoading, isTrue);

        await Future.delayed(const Duration(milliseconds: 900));
        state = container.read(searchSessionProvider);
        final results = state.results!;
        expect(state.searchLoading, isFalse);
        expect(results.matchesSettled, isTrue);
        expect(results.rankedMatches, hasLength(1));
        expect(results.inspiredGroups.single.tracks, hasLength(2));
        expect(api.matchCalls, 1);
        expect(api.aiSearchCalls, 1);
      },
    );

    test('a new submit replaces the previous query', () async {
      final api = _FakeApi();
      final container = makeContainer(api);
      final notifier = container.read(searchSessionProvider.notifier);
      notifier.open();

      notifier.submit('one');
      notifier.submit('two');
      await Future.delayed(const Duration(milliseconds: 900));

      final state = container.read(searchSessionProvider);
      expect(state.searchQuery, 'two');
      expect(state.results!.query, 'two');
      // Superseded before its sources were even resolved, the first query
      // never reaches the network.
      expect(api.queries, ['two']);
      // Newest-first history.
      expect(state.history.take(2), ['two', 'one']);
    });

    test('a source that never answers is unavailable, leg by leg', () {
      fakeAsync((async) {
        final api = _HangingApi();
        final container = makeContainer(api);
        final notifier = container.read(searchSessionProvider.notifier);
        notifier.open();
        notifier.submit('jazz');
        async.flushMicrotasks();
        var results = container.read(searchSessionProvider).results!;
        expect(results.matches['qobuz'], isA<LegLoading>());
        expect(api.matchCalls, 1);

        // Just short of the cap the legs are still patiently loading…
        async.elapse(const Duration(seconds: 9));
        results = container.read(searchSessionProvider).results!;
        expect(results.matches['qobuz'], isA<LegLoading>());

        // …and past it each leg gives up and says so.
        async.elapse(const Duration(seconds: 2));
        final state = container.read(searchSessionProvider);
        results = state.results!;
        expect(results.matches['qobuz'], isA<LegFailed>());
        expect(results.inspired['qobuz'], isA<LegFailed>());
        expect(state.searchError, isNull);
      });
    });

    test('retry asks that one source for that one leg again', () async {
      final api = _FlakyApi();
      final container = makeContainer(api);
      final notifier = container.read(searchSessionProvider.notifier);
      notifier.open();

      notifier.submit('jazz');
      await Future.delayed(const Duration(milliseconds: 900));
      expect(
        container.read(searchSessionProvider).results!.matches['qobuz'],
        isA<LegFailed>(),
      );

      notifier.retry(ResultsLeg.matches, 'qobuz');
      expect(
        container.read(searchSessionProvider).results!.matches['qobuz'],
        isA<LegLoading>(),
      );
      await Future.delayed(const Duration(milliseconds: 900));
      final results = container.read(searchSessionProvider).results!;
      expect(results.matches['qobuz'], isA<LegReady>());
      expect(api.matchCalls, 2);
      expect(api.aiSearchCalls, 1, reason: 'the other leg is left alone');
    });

    test('narrowing keeps the query out of the facets', () async {
      final api = _FakeApi();
      final container = makeContainer(api);
      final notifier = container.read(searchSessionProvider.notifier);
      notifier.open();
      notifier.submit('jazz');

      notifier.setResultsFilter(
        const BrowseFilterQuery(text: 'jazz', type: SearchType.album),
      );

      final filter = container.read(searchSessionProvider).resultsFilter;
      expect(filter.type, SearchType.album);
      expect(filter.text, isEmpty);
      await Future.delayed(const Duration(milliseconds: 900));
    });

    test('clearing the search returns to Catalogs with nothing kept', () async {
      final api = _FakeApi();
      final container = makeContainer(api);
      final notifier = container.read(searchSessionProvider.notifier);
      notifier.open();
      notifier.submit('jazz');
      await Future.delayed(const Duration(milliseconds: 900));

      notifier.clearSearch();

      final state = container.read(searchSessionProvider);
      expect(state.activeView, FindMusicView.catalogs);
      expect(state.resultsAvailable, isFalse);
      expect(state.results, isNull);
      expect(state.searchQuery, isEmpty);
    });

    test('view switches are gated and layered', () async {
      final api = _FakeApi();
      final container = makeContainer(api);
      final notifier = container.read(searchSessionProvider.notifier);
      notifier.open();

      // Results is inert until a search has run.
      notifier.selectView(FindMusicView.results);
      expect(
        container.read(searchSessionProvider).activeView,
        FindMusicView.catalogs,
      );

      notifier.openCatalog(id: 'cat1', title: 'Popular Tracks');
      expect(container.read(searchSessionProvider).catalogPage.isRoot, isFalse);

      // Reselecting Catalogs while on a page returns to its root.
      notifier.selectView(FindMusicView.catalogs);
      expect(container.read(searchSessionProvider).catalogPage.isRoot, isTrue);

      notifier.submit('jazz');
      expect(
        container.read(searchSessionProvider).activeView,
        FindMusicView.results,
      );
      notifier.selectView(FindMusicView.catalogs);
      expect(
        container.read(searchSessionProvider).activeView,
        FindMusicView.catalogs,
      );
      // Results stays reachable once available.
      notifier.selectView(FindMusicView.results);
      expect(
        container.read(searchSessionProvider).activeView,
        FindMusicView.results,
      );
      await Future.delayed(const Duration(milliseconds: 900));
    });

    test('closing discards the workspace but keeps history', () async {
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
      expect(state.resultsAvailable, isFalse);
      expect(state.results, isNull);
      expect(state.catalogPage.isRoot, isTrue);

      notifier.open();
      state = container.read(searchSessionProvider);
      // Newest-first history.
      expect(state.history.take(2), ['techno', 'jazz']);
    });
  });

  group('SearchZeroState', () {
    testWidgets('shows the catalogs divider and favourites', (tester) async {
      final api = _FakeApi();
      final container = makeContainer(api);
      container.read(searchSessionProvider.notifier).open();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: SearchZeroState(onOpenCatalog: (_, __, {focusItemId}) {}),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('EXPLORE CATALOGS'), findsOneWidget);
      expect(find.text('RECENTLY FAVOURITED'), findsOneWidget);
    });
  });
}
