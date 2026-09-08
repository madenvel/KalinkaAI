import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kalinka/data_model/data_model.dart';
import 'package:kalinka/providers/app_state_provider.dart';
import 'package:kalinka/providers/catalog_cards_provider.dart';
import 'package:kalinka/providers/collections_provider.dart';
import 'package:kalinka/providers/connection_settings_provider.dart';
import 'package:kalinka/providers/connection_state_provider.dart';
import 'package:kalinka/providers/indexer_status_provider.dart';
import 'package:kalinka/providers/kalinka_player_api_provider.dart';
import 'package:kalinka/providers/row_expansion_provider.dart';
import 'package:kalinka/providers/search_session_provider.dart';
import 'package:kalinka/providers/source_modules_provider.dart';
import 'package:kalinka/widgets/kalinka_button.dart';
import 'package:kalinka/widgets/search_cards/action_pill_button.dart';
import 'package:kalinka/widgets/search/search_session_view.dart';

const _shelfId = 'kalinka:collections:catalog:collections';
const _c1 = 'kalinka:collections:playlist:c1';
const _c2 = 'kalinka:collections:playlist:c2';

BrowseItem _collection(String id, String name, int tracks) => BrowseItem(
  id: id,
  name: name,
  canBrowse: true,
  canAdd: true,
  canEdit: true,
  playlist: Playlist(id: id, name: name, trackCount: tracks),
  catalog: Catalog(id: id, title: name, sources: const ['localfiles']),
);

BrowseItem _track(String id, String title) => BrowseItem(
  id: id,
  name: title,
  canBrowse: false,
  canAdd: true,
  track: Track(id: id, title: title, duration: 200),
);

/// A server with nothing in any listing: the screen with no collections made
/// yet is the whole point here.
class _EmptyApi implements KalinkaPlayerProxy {
  @override
  Future<BrowseItemsList> getFavorite(
    SearchType queryType, {
    int offset = 0,
    int limit = 10,
    String filter = '',
  }) async => BrowseItemsList(0, limit, 0, const []);

  @override
  Future<BrowseItemsList> browse(
    String id, {
    int offset = 0,
    int limit = 10,
    String? filter,
  }) async => BrowseItemsList(offset, limit, 0, const []);

  @override
  Future<SearchSuggestionList> searchSuggestions({
    int count = 4,
    int? tzOffsetMin,
  }) async => const SearchSuggestionList(suggestions: []);

  @override
  Future<BrowseItemsList> searchMatches(
    String query, {
    List<String>? sources,
  }) async => BrowseItemsList(0, 10, 0, const []);

  @override
  Future<BrowseItemsList> aiSearch(
    String query, {
    int offset = 0,
    int limit = 10,
    List<String>? sources,
  }) async => BrowseItemsList(offset, limit, 0, const []);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

/// Serves the collections screen: the shelf's rows, and each collection's
/// tracks when a row unrolls. Records what was created.
class _ShelfApi extends _EmptyApi {
  final List<String> created = [];

  @override
  Future<String> createCollection(
    String name, {
    String description = '',
  }) async {
    created.add(name);
    return 'kalinka:collections:playlist:new';
  }

  @override
  Future<BrowseItemsList> browse(
    String id, {
    int offset = 0,
    int limit = 10,
    String? filter,
  }) async {
    final items = switch (id) {
      _shelfId => [
        _collection(_c1, 'Late Night Signals', 2),
        _collection(_c2, 'Sunday Morning', 1),
      ],
      _c1 => [_track('t1', 'Night Drive'), _track('t2', 'Signals')],
      _c2 => [_track('t3', 'Hypnotic')],
      _ => const <BrowseItem>[],
    };
    return BrowseItemsList(offset, limit, items.length, items);
  }
}

class _FixedConnection extends ConnectionStateNotifier {
  @override
  ConnectionStatus build() => ConnectionStatus.connected;
}

class _IdleIndexer extends IndexerStatusNotifier {
  @override
  IndexerStatusState build() => const IndexerStatusState();

  @override
  void acquire() {}

  @override
  void release() {}
}

final _modules = [
  ModuleInfo(
    name: 'localfiles',
    title: 'Local files',
    enabled: true,
    state: ModuleState.ready,
  ),
  ModuleInfo(
    name: 'collections',
    title: 'Collections',
    enabled: true,
    state: ModuleState.ready,
    builtin: true,
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

  Future<ProviderContainer> pumpSurface(
    WidgetTester tester, {
    KalinkaPlayerProxy? api,
  }) async {
    final container = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        kalinkaProxyProvider.overrideWithValue(api ?? _EmptyApi()),
        sourceModulesProvider.overrideWith((ref) => _modules),
        connectionStateProvider.overrideWith(_FixedConnection.new),
        playerStateProvider.overrideWithValue(PlaybackState.empty),
        catalogCardGroupsProvider.overrideWith(
          (ref) => Future.value(const <CatalogCardGroup>[]),
        ),
        collectionsShelfProvider.overrideWith((ref) => Future.value(null)),
        indexerStatusProvider.overrideWith(_IdleIndexer.new),
      ],
    );
    addTearDown(container.dispose);
    container.read(searchSessionProvider.notifier).open();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: SearchSessionView())),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    return container;
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('the collections screen with none yet shows the invitation', (
    tester,
  ) async {
    final container = await pumpSurface(tester);
    container
        .read(searchSessionProvider.notifier)
        .openCatalog(id: _shelfId, title: 'Your collections', canEdit: true);
    await settle(tester);

    expect(find.text('No collections yet'), findsOneWidget);
    // Making one is the screen's own action and is live; rearranging what is
    // there waits on the rest of the write API.
    final pills = tester
        .widgetList<ActionPillButton>(find.byType(ActionPillButton))
        .toList();
    expect(pills.map((b) => b.label), ['New', 'Edit']);
    expect(pills.map((b) => b.enabled), [true, false]);
    // Berry marks a commit or a receipt; a standing action is neither.
    expect(pills.every((b) => !b.accent), isTrue);
    // The one fill a screen at rest may carry is the empty state's call.
    final invitation = tester.widget<KalinkaButton>(find.byType(KalinkaButton));
    expect(invitation.label, 'CREATE COLLECTION');
    expect(invitation.variant, KalinkaButtonVariant.accent);
  });

  testWidgets('a source catalog with nothing in it stays plain', (
    tester,
  ) async {
    final container = await pumpSurface(tester);
    container
        .read(searchSessionProvider.notifier)
        .openCatalog(id: 'kalinka:localfiles:catalog:albums', title: 'Albums');
    await settle(tester);

    expect(find.text('Nothing here yet'), findsOneWidget);
    expect(find.text('No collections yet'), findsNothing);
    expect(find.byType(ActionPillButton), findsNothing);
  });

  testWidgets('a collection unrolls in place rather than opening a page', (
    tester,
  ) async {
    final container = await pumpSurface(tester, api: _ShelfApi());
    container
        .read(searchSessionProvider.notifier)
        .openCatalog(id: _shelfId, title: 'Your collections', canEdit: true);
    await settle(tester);

    expect(find.text('Late Night Signals'), findsOneWidget);
    expect(find.text('2 tracks · 1 source'), findsOneWidget);
    expect(find.text('Night Drive'), findsNothing);

    await tester.tap(find.text('Late Night Signals'));
    await settle(tester);

    expect(find.text('Night Drive'), findsOneWidget);
    expect(find.text('Signals'), findsOneWidget);
    // Still the same screen — the collection is not somewhere you went.
    expect(container.read(searchSessionProvider).catalogPage.id, _shelfId);
  });

  testWidgets('an unrolled collection carries the actions every list has', (
    tester,
  ) async {
    final container = await pumpSurface(tester, api: _ShelfApi());
    container
        .read(searchSessionProvider.notifier)
        .openCatalog(id: _shelfId, title: 'Your collections', canEdit: true);
    await settle(tester);
    await tester.tap(find.text('Sunday Morning'));
    await settle(tester);

    // The same pair a section of results carries, named the same way.
    expect(find.text('Play all'), findsOneWidget);
    expect(find.text('Enqueue'), findsOneWidget);
    // Editing is the screen's mode, not a row's action.
    expect(find.text('Edit tracks'), findsNothing);
  });

  testWidgets('making a collection names it and reloads the listing', (
    tester,
  ) async {
    final api = _ShelfApi();
    final container = await pumpSurface(tester, api: api);
    container
        .read(searchSessionProvider.notifier)
        .openCatalog(id: _shelfId, title: 'Your collections', canEdit: true);
    await settle(tester);
    final before = container.read(collectionsRevisionProvider);

    await tester.tap(find.widgetWithText(ActionPillButton, 'New'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), '  Night Drive  ');
    await tester.pump();
    await tester.tap(find.text('CREATE'));
    await settle(tester);

    expect(api.created, ['Night Drive']);
    // The listing refetches off the revision rather than being handed a row.
    expect(container.read(collectionsRevisionProvider), greaterThan(before));
    // The confirmation toast retires itself on a timer the container
    // outlives; left pending, it fails the test after the tree is gone.
    await tester.pump(const Duration(seconds: 30));
  });

  testWidgets('entering by one collection lands on it, already open', (
    tester,
  ) async {
    final container = await pumpSurface(tester, api: _ShelfApi());
    container.read(rowExpansionProvider.notifier).unroll(_c2);
    container
        .read(searchSessionProvider.notifier)
        .openCatalog(
          id: _shelfId,
          title: 'Your collections',
          canEdit: true,
          focusItemId: _c2,
        );
    await settle(tester);

    expect(find.text('Hypnotic'), findsOneWidget);
    expect(find.text('Night Drive'), findsNothing);
    // Spent on arrival, so a row built again later does not jump the list.
    final page = container.read(searchSessionProvider).catalogPage;
    expect(page.focusItemId, isNull);
    expect(page.canEdit, isTrue);
  });
}
