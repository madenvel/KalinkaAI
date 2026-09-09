import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kalinka/data_model/data_model.dart';
import 'package:kalinka/providers/app_state_provider.dart';
import 'package:kalinka/providers/connection_settings_provider.dart';
import 'package:kalinka/providers/connection_state_provider.dart';
import 'package:kalinka/providers/kalinka_player_api_provider.dart';
import 'package:kalinka/providers/search_session_provider.dart';
import 'package:kalinka/providers/source_modules_provider.dart';
import 'package:kalinka/widgets/browse_rows_shimmer.dart';
import 'package:kalinka/widgets/search/results_view.dart';
import 'package:kalinka/widgets/search/inspired_block.dart';
import 'package:kalinka/widgets/shelf_heading.dart';
import 'package:kalinka/widgets/source_badge.dart';

BrowseItem _artist(String source, String id, String name, MatchTier tier) =>
    BrowseItem(
      id: 'kalinka:$source:artist:$id',
      name: name,
      canBrowse: true,
      canAdd: false,
      artist: Artist(id: 'kalinka:$source:artist:$id', name: name),
      match: NameMatch(tier: tier, score: tier == MatchTier.exact ? 100 : 60),
    );

BrowseItem _track(String source, String id, String title) => BrowseItem(
  id: 'kalinka:$source:track:$id',
  canBrowse: false,
  canAdd: true,
  track: Track(
    id: 'kalinka:$source:track:$id',
    title: title,
    duration: 200,
    album: Album(id: 'kalinka:$source:album:al', title: 'An Album'),
    performer: Artist(id: 'kalinka:$source:artist:ar', name: 'Someone'),
  ),
);

BrowseItemsList _list(List<BrowseItem> items) =>
    BrowseItemsList(0, items.length, items.length, items);

BrowseItemsList _card(String source, List<BrowseItem> tracks) => _list([
  BrowseItem(
    id: 'kalinka:$source:catalog:ai',
    name: 'AI SUGGESTIONS',
    canBrowse: false,
    canAdd: false,
    catalog: Catalog(id: 'ai', title: 'AI SUGGESTIONS', sources: [source]),
    sections: tracks,
  ),
]);

/// Answers each source's legs from a script; a source in [failing] throws
/// on its name-match leg until [heal] is called; [gates] hold a source's
/// name-match answer open until released.
class _ScriptedApi implements KalinkaPlayerProxy {
  final Map<String, List<BrowseItem>> matches;
  final Map<String, List<BrowseItem>> inspired;
  final Set<String> failing;
  final Map<String, Completer<void>> gates;
  final Map<String, int> matchCalls = {};

  _ScriptedApi({
    this.matches = const {},
    this.inspired = const {},
    Set<String> failing = const {},
    this.gates = const {},
  }) : failing = {...failing};

  void heal() => failing.clear();

  @override
  Future<BrowseItemsList> searchMatches(
    String query, {
    List<String>? sources,
  }) async {
    final source = sources!.single;
    matchCalls[source] = (matchCalls[source] ?? 0) + 1;
    if (failing.contains(source)) throw Exception('upstream down');
    await gates[source]?.future;
    return _list(matches[source] ?? const []);
  }

  @override
  Future<BrowseItemsList> aiSearch(
    String query, {
    int offset = 0,
    int limit = 10,
    List<String>? sources,
  }) async {
    final source = sources!.single;
    final tracks = inspired[source];
    return tracks == null ? _list(const []) : _card(source, tracks);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _FixedConnection extends ConnectionStateNotifier {
  @override
  ConnectionStatus build() => ConnectionStatus.connected;
}

// Both suggest: this file is about how their suggestions are laid out.
final _modules = <ModuleInfo>[
  ModuleInfo(
    name: 'qobuz',
    title: 'Qobuz',
    enabled: true,
    state: ModuleState.ready,
    capabilities: const [ModuleCapability.aiSearch],
  ),
  ModuleInfo(
    name: 'localfiles',
    title: 'Local files',
    enabled: true,
    state: ModuleState.ready,
    capabilities: const [ModuleCapability.aiSearch],
  ),
];

late SharedPreferences _prefs;

/// The legs hold their answer on screen for a moment even when it is
/// instant, so a settled screen is one pump past that hold.
const _settle = Duration(milliseconds: 700);

Future<ProviderContainer> _pump(
  WidgetTester tester,
  _ScriptedApi api, {
  List<ModuleInfo>? modules,
}) async {
  final container = ProviderContainer(
    overrides: [
      sharedPrefsProvider.overrideWithValue(_prefs),
      kalinkaProxyProvider.overrideWithValue(api),
      sourceModulesProvider.overrideWith((ref) => modules ?? _modules),
      connectionStateProvider.overrideWith(_FixedConnection.new),
      playerStateProvider.overrideWithValue(PlaybackState.empty),
    ],
  );
  addTearDown(container.dispose);
  container.read(searchSessionProvider.notifier).open();
  container.read(searchSessionProvider.notifier).submit('jazz');

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: ResultsView())),
    ),
  );
  await tester.pump();
  return container;
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'Kalinka.host': 'localhost',
      'Kalinka.port': 8080,
      'Kalinka.name': 'Test',
    });
    _prefs = await SharedPreferences.getInstance();
  });

  testWidgets('the name block shimmers until every source has answered', (
    tester,
  ) async {
    final gate = Completer<void>();
    final api = _ScriptedApi(
      matches: {
        'localfiles': [
          _artist('localfiles', '1', 'Local Act', MatchTier.exact),
        ],
        'qobuz': [_artist('qobuz', '1', 'Slow Act', MatchTier.exact)],
      },
      gates: {'qobuz': gate},
    );
    await _pump(tester, api);
    await tester.pump(_settle);

    // The local source answered, but the list is a merge: nothing shows
    // until the slow one has too.
    expect(find.text('MATCHES BY NAME'), findsOneWidget);
    expect(find.byType(BrowseRowsShimmer), findsWidgets);
    expect(find.text('Local Act'), findsNothing);

    gate.complete();
    await tester.pump(_settle);
    expect(find.byType(BrowseRowsShimmer), findsNothing);
    expect(find.text('Local Act'), findsOneWidget);
    expect(find.text('Slow Act'), findsOneWidget);
  });

  testWidgets('four lead, and VIEW ALL opens the rest as a filter', (
    tester,
  ) async {
    final api = _ScriptedApi(
      matches: {
        'qobuz': [
          for (var i = 1; i <= 6; i++)
            _artist('qobuz', '$i', 'Act $i', MatchTier.partial),
        ],
      },
    );
    await _pump(tester, api);
    await tester.pump(_settle);

    expect(find.text('Act 4'), findsOneWidget);
    expect(find.text('Act 5'), findsNothing);
    expect(find.text('VIEW ALL'), findsOneWidget);

    await tester.tap(find.text('VIEW ALL'));
    await tester.pump();

    expect(find.text('Name matches'), findsOneWidget);
    expect(find.text('Act 6'), findsOneWidget);
    expect(find.text('VIEW ALL'), findsNothing);
  });

  testWidgets('an exact hit wears its badge, a partial one does not', (
    tester,
  ) async {
    final api = _ScriptedApi(
      matches: {
        'qobuz': [
          _artist('qobuz', '1', 'Jazz', MatchTier.exact),
          _artist('qobuz', '2', 'Jazz Club', MatchTier.partial),
        ],
      },
    );
    await _pump(tester, api);
    await tester.pump(_settle);

    expect(find.text('EXACT NAME'), findsOneWidget);
  });

  testWidgets('a source that failed is named, and retried in place', (
    tester,
  ) async {
    final api = _ScriptedApi(
      matches: {
        'localfiles': [
          _artist('localfiles', '1', 'Local Act', MatchTier.exact),
        ],
        'qobuz': [_artist('qobuz', '1', 'Remote Act', MatchTier.exact)],
      },
      failing: {'qobuz'},
    );
    await _pump(tester, api);
    await tester.pump(_settle);

    expect(find.text('Local Act'), findsOneWidget);
    expect(find.text('Qobuz · Source unavailable'), findsOneWidget);
    expect(find.text('Remote Act'), findsNothing);

    api.heal();
    await tester.tap(find.text('RETRY'));
    await tester.pump(_settle);

    expect(api.matchCalls['qobuz'], 2);
    expect(api.matchCalls['localfiles'], 1);
    expect(find.text('Qobuz · Source unavailable'), findsNothing);
    expect(find.text('Remote Act'), findsOneWidget);
  });

  testWidgets('recommendations stay grouped by source, with their actions', (
    tester,
  ) async {
    final api = _ScriptedApi(
      inspired: {
        'localfiles': [_track('localfiles', 'l1', 'Home Song')],
        'qobuz': [
          for (var i = 1; i <= 5; i++) _track('qobuz', '$i', 'Away Song $i'),
        ],
      },
    );
    await _pump(tester, api);
    await tester.pump(_settle);

    expect(find.text('INSPIRED BY YOUR REQUEST'), findsOneWidget);
    expect(find.text('YOUR LIBRARY'), findsOneWidget);
    expect(find.text('QOBUZ'), findsOneWidget);
    // The library is the unmarked default; only the other source wears a
    // letter.
    expect(find.byType(SourceLetter), findsOneWidget);
    expect(find.text('Play all'), findsNWidgets(2));
    expect(find.text('Away Song 3'), findsOneWidget);
    expect(find.text('Away Song 4'), findsNothing);
    // Only the group holding more than its preview offers to open in full,
    // and it sits on the block's right edge, like the block's own link.
    expect(find.text('VIEW ALL'), findsOneWidget);
    expect(
      tester.getTopRight(find.byType(ViewAllAction)).dx,
      closeTo(tester.getTopRight(find.byType(InspiredBlock)).dx, 0.5),
    );
    // The Discover mark on the heading; the query chip wears the same glyph
    // outside the block.
    expect(
      find.descendant(
        of: find.byType(InspiredBlock),
        matching: find.byIcon(Icons.auto_awesome),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('VIEW ALL'));
    await tester.pump();

    // One source in full: its kind and its source, each a chip of its own.
    expect(find.text('Recommendations'), findsOneWidget);
    expect(find.text('Qobuz'), findsOneWidget);
    expect(find.text('Away Song 5'), findsOneWidget);
    expect(find.text('YOUR LIBRARY'), findsNothing);
    expect(find.text('MATCHES BY NAME'), findsNothing);
  });

  testWidgets('with one source, VIEW ALL narrows by kind alone', (
    tester,
  ) async {
    final api = _ScriptedApi(
      inspired: {
        'qobuz': [
          for (var i = 1; i <= 5; i++) _track('qobuz', '$i', 'Away Song $i'),
        ],
      },
    );
    await _pump(tester, api, modules: [_modules.first]);
    await tester.pump(_settle);

    await tester.tap(find.text('VIEW ALL'));
    await tester.pump();

    expect(find.text('Recommendations'), findsOneWidget);
    expect(find.text('Qobuz'), findsNothing);
    expect(find.text('Away Song 5'), findsOneWidget);
  });

  testWidgets('nothing found says so', (tester) async {
    await _pump(tester, _ScriptedApi());
    await tester.pump(_settle);

    expect(find.text('No matches'), findsOneWidget);
  });
}
