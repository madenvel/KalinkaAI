import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kalinka/data_model/data_model.dart';
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

/// Pinned connection state — the real notifier arms a retry [Timer] that
/// would outlive widget tests.
class _FixedConnection extends ConnectionStateNotifier {
  @override
  ConnectionStatus build() => ConnectionStatus.connected;
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
      expect(api.aiSearchCalls, 0, reason: 'no search-as-you-type on open');
    });

    test('submit switches to Results, loads, then resolves', () async {
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
      expect(state.searchLoading, isFalse);
      expect(state.searchResults, isNotNull);
      expect(state.searchResults!.items, hasLength(1));
      expect(api.aiSearchCalls, 1);
    });

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
      expect(api.queries, ['one', 'two']);
      // Newest-first history.
      expect(state.history.take(2), ['two', 'one']);
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
      expect(state.searchResults, isNull);
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
            home: Scaffold(body: SearchZeroState(onOpenCatalog: (_, __) {})),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('OR EXPLORE CATALOGS'), findsOneWidget);
      expect(find.text('RECENTLY FAVOURITED'), findsOneWidget);
    });
  });
}
