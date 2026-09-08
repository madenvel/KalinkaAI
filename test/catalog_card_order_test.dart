import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kalinka/data_model/data_model.dart';
import 'package:kalinka/providers/catalog_cards_provider.dart';
import 'package:kalinka/providers/kalinka_player_api_provider.dart';
import 'package:kalinka/providers/source_modules_provider.dart';

BrowseItem _module(String source, String title) => BrowseItem(
  id: 'kalinka:$source:catalog:root',
  name: title,
  canBrowse: true,
  canAdd: false,
  catalog: Catalog(id: 'kalinka:$source:catalog:root', title: title),
);

BrowseItem _catalog(String source, String title, CatalogRole role) =>
    BrowseItem(
      id: 'kalinka:$source:catalog:$title',
      name: title,
      canBrowse: true,
      canAdd: false,
      catalog: Catalog(
        id: 'kalinka:$source:catalog:$title',
        title: title,
        role: role,
      ),
    );

/// Serves the module list and each module's catalogs from a script.
class _RootApi implements KalinkaPlayerProxy {
  final List<BrowseItem> modules;
  final Map<String, List<BrowseItem>> children;

  _RootApi(this.modules, this.children);

  @override
  Future<BrowseItemsList> browse(
    String id, {
    int offset = 0,
    int limit = 10,
    String? filter,
  }) async {
    final items = id.isEmpty ? modules : (children[id] ?? const <BrowseItem>[]);
    return BrowseItemsList(offset, limit, items.length, items);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

ModuleInfo _moduleInfo(String name, {bool builtin = false}) => ModuleInfo(
  name: name,
  title: name,
  enabled: true,
  state: ModuleState.ready,
  builtin: builtin,
);

Future<List<String>> _titles(
  _RootApi api, {
  List<ModuleInfo> modules = const [],
}) async {
  final container = ProviderContainer(
    overrides: [
      kalinkaProxyProvider.overrideWithValue(api),
      sourceModulesProvider.overrideWith((ref) => modules),
    ],
  );
  addTearDown(container.dispose);
  final groups = await container.read(catalogCardGroupsProvider.future);
  return [for (final group in groups) group.sourceTitle];
}

void main() {
  test('the source holding your own library comes first', () async {
    // The server lists sources alphabetically by their internal key, which is
    // the order this arrives in.
    final api = _RootApi(
      [_module('jamendo', 'Jamendo'), _module('localfiles', 'Local files')],
      {
        'kalinka:jamendo:catalog:root': [
          _catalog('jamendo', 'New Releases', CatalogRole.discovery),
        ],
        'kalinka:localfiles:catalog:root': [
          _catalog('localfiles', 'My Library', CatalogRole.library),
        ],
      },
    );

    expect(await _titles(api), ['Local files', 'Jamendo']);
  });

  test(
    'the rest follow by name, not by the key the server sorted on',
    () async {
      final api = _RootApi(
        [_module('aaa', 'Zed'), _module('zzz', 'Alpha')],
        {
          'kalinka:aaa:catalog:root': [
            _catalog('aaa', 'One', CatalogRole.discovery),
          ],
          'kalinka:zzz:catalog:root': [
            _catalog('zzz', 'Two', CatalogRole.featured),
          ],
        },
      );

      expect(await _titles(api), ['Alpha', 'Zed']);
    },
  );

  test('a source claiming no role sorts among the rest', () async {
    final api = _RootApi(
      [_module('b', 'Beta'), _module('a', 'Alpha')],
      {
        'kalinka:b:catalog:root': [_catalog('b', 'One', CatalogRole.discovery)],
        'kalinka:a:catalog:root': [
          BrowseItem(
            id: 'kalinka:a:catalog:x',
            name: 'X',
            canBrowse: true,
            canAdd: false,
            catalog: Catalog(id: 'kalinka:a:catalog:x', title: 'X'),
          ),
        ],
      },
    );

    expect(await _titles(api), ['Alpha', 'Beta']);
  });

  test(
    'a source the server provides itself is not a catalog to explore',
    () async {
      final api = _RootApi(
        [
          _module('collections', 'Collections'),
          _module('localfiles', 'Local files'),
        ],
        {
          'kalinka:collections:catalog:root': [
            _catalog('collections', 'Your collections', CatalogRole.library),
          ],
          'kalinka:localfiles:catalog:root': [
            _catalog('localfiles', 'My Library', CatalogRole.library),
          ],
        },
      );

      final titles = await _titles(
        api,
        modules: [
          _moduleInfo('localfiles'),
          _moduleInfo('collections', builtin: true),
        ],
      );

      expect(titles, ['Local files']);
    },
  );
}
