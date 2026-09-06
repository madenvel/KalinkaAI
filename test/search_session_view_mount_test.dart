import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kalinka/data_model/data_model.dart';
import 'package:kalinka/providers/app_state_provider.dart';
import 'package:kalinka/providers/catalog_cards_provider.dart';
import 'package:kalinka/providers/connection_settings_provider.dart';
import 'package:kalinka/providers/connection_state_provider.dart';
import 'package:kalinka/providers/indexer_status_provider.dart';
import 'package:kalinka/providers/kalinka_player_api_provider.dart';
import 'package:kalinka/providers/search_session_provider.dart';
import 'package:kalinka/providers/source_modules_provider.dart';
import 'package:kalinka/widgets/browse_filters/search_filter_button.dart';
import 'package:kalinka/widgets/search/search_session_view.dart';

/// Mounting the whole Find Music surface is the only thing that exercises its
/// `initState` — where a second AnimationController on a
/// SingleTickerProviderStateMixin threw on the first build.
class _FakeApi implements KalinkaPlayerProxy {
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
    List<String>? genreIds,
  }) async => BrowseItemsList(offset, limit, 0, const []);

  @override
  Future<SearchSuggestionList> searchSuggestions({
    int count = 4,
    int? tzOffsetMin,
  }) async => const SearchSuggestionList(suggestions: []);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _FixedConnection extends ConnectionStateNotifier {
  @override
  ConnectionStatus build() => ConnectionStatus.connected;
}

/// The real notifier polls `/indexer/status` on a repeating timer.
class _IdleIndexer extends IndexerStatusNotifier {
  @override
  IndexerStatusState build() => const IndexerStatusState();

  @override
  void acquire() {}

  @override
  void release() {}
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

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        kalinkaProxyProvider.overrideWithValue(_FakeApi()),
        sourceModulesProvider.overrideWith((ref) => <ModuleInfo>[]),
        connectionStateProvider.overrideWith(_FixedConnection.new),
        playerStateProvider.overrideWithValue(PlaybackState.empty),
        catalogCardGroupsProvider.overrideWith(
          (ref) => Future.value(const <CatalogCardGroup>[]),
        ),
        indexerStatusProvider.overrideWith(_IdleIndexer.new),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<ProviderContainer> pumpSurface(WidgetTester tester) async {
    final container = makeContainer();
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

  testWidgets('the surface mounts without throwing', (tester) async {
    await pumpSurface(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('DISCOVER'), findsOneWidget);
  });

  testWidgets('the Discover root offers no filter control', (tester) async {
    await pumpSurface(tester);
    // Nothing to narrow at the root — the button would be a dead affordance.
    expect(find.byType(SearchFilterButton), findsNothing);
  });

  testWidgets('a catalog page carries the filter control, and it opens', (
    tester,
  ) async {
    final container = await pumpSurface(tester);

    container
        .read(searchSessionProvider.notifier)
        .openCatalog(
          id: 'kalinka:localfiles:catalog:albums',
          title: 'My Albums',
        );
    await tester.pumpAndSettle();

    expect(find.byType(SearchFilterButton), findsOneWidget);

    await tester.tap(find.byType(SearchFilterButton));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('SEARCH & FILTERS'), findsOneWidget);

    // Cancel folds it away again without touching the applied filter.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('SEARCH & FILTERS'), findsNothing);
    expect(container.read(searchSessionProvider).catalogFilter.isEmpty, isTrue);
  });

  testWidgets('the DISCOVER crumb goes back, like the arrow', (tester) async {
    final container = await pumpSurface(tester);
    container
        .read(searchSessionProvider.notifier)
        .openCatalog(
          id: 'kalinka:localfiles:catalog:albums',
          title: 'My Albums',
        );
    await tester.pumpAndSettle();
    expect(container.read(searchSessionProvider).catalogPage.isRoot, isFalse);

    await tester.tap(find.text('DISCOVER'));
    await tester.pumpAndSettle();
    expect(container.read(searchSessionProvider).catalogPage.isRoot, isTrue);
  });

  testWidgets('the DISCOVER crumb highlights under the pointer', (
    tester,
  ) async {
    final container = await pumpSurface(tester);
    container
        .read(searchSessionProvider.notifier)
        .openCatalog(
          id: 'kalinka:localfiles:catalog:albums',
          title: 'My Albums',
        );
    await tester.pumpAndSettle();

    Color? crumbFill() {
      final box = tester.widget<AnimatedContainer>(
        find
            .ancestor(
              of: find.text('DISCOVER'),
              matching: find.byType(AnimatedContainer),
            )
            .first,
      );
      return (box.decoration as BoxDecoration).color;
    }

    expect(crumbFill(), Colors.transparent);

    final pointer = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await pointer.addPointer(location: Offset.zero);
    addTearDown(pointer.removePointer);
    await pointer.moveTo(tester.getCenter(find.text('DISCOVER')));
    await tester.pumpAndSettle();
    expect(crumbFill()!.a, greaterThan(0));
  });

  testWidgets('at the root the crumb names the page, and does not act', (
    tester,
  ) async {
    final container = await pumpSurface(tester);

    // Nowhere to go back to from Discover itself.
    await tester.tap(find.text('DISCOVER'));
    await tester.pumpAndSettle();
    expect(container.read(searchSessionProvider).isOpen, isTrue);
  });
}
