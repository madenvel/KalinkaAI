import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kalinka/data_model/data_model.dart';
import 'package:kalinka/providers/connection_settings_provider.dart';
import 'package:kalinka/providers/kalinka_player_api_provider.dart';
import 'package:kalinka/providers/search_state_provider.dart';

/// Fake proxy whose [aiSearch] returns futures we resolve by hand, so we can
/// model a slow AI backend and out-of-order responses.
class _FakeProxy implements KalinkaPlayerProxy {
  final Map<String, Completer<BrowseItemsList>> pending = {};
  final List<String> aiCalls = [];

  @override
  Future<BrowseItemsList> aiSearch(
    String query, {
    int offset = 0,
    int limit = 10,
    List<String>? sources,
  }) {
    aiCalls.add(query);
    final c = Completer<BrowseItemsList>();
    pending[query] = c;
    return c.future;
  }

  void resolve(String query) {
    pending[query]!.complete(
      BrowseItemsList(0, 10, 1, [
        BrowseItem(
          id: 'id-$query',
          name: query,
          canBrowse: false,
          canAdd: true,
        ),
      ]),
    );
  }

  @override
  Future<IndexerStatus> getIndexerStatus({List<String>? sources}) async =>
      const IndexerStatus({});

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

void main() {
  late ProviderContainer container;
  late _FakeProxy proxy;
  late SearchStateNotifier notifier;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    proxy = _FakeProxy();
    container = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        kalinkaProxyProvider.overrideWithValue(proxy),
      ],
    );
    notifier = container.read(searchStateProvider.notifier);
    notifier.toggleAiMode(); // enable AI mode
    expect(container.read(searchStateProvider).isAiEnabled, isTrue);
  });

  tearDown(() => container.dispose());

  // Lets the 300ms debounce timer fire.
  Future<void> settleDebounce() =>
      Future<void>.delayed(const Duration(milliseconds: 350));

  test('latest typed query wins when responses arrive out of order', () async {
    // Type "a", let the debounce fire a search for it.
    notifier.setQuery('a');
    await settleDebounce();
    expect(proxy.aiCalls, contains('a'));

    // Type "ab", let its debounce fire too — now two searches in flight.
    notifier.setQuery('ab');
    await settleDebounce();
    expect(proxy.aiCalls, contains('ab'));

    // The newest query resolves first, then the stale one resolves late.
    proxy.resolve('ab');
    await Future<void>.value();
    proxy.resolve('a');
    await Future<void>.value();

    final state = container.read(searchStateProvider);
    final shownId = state.aiSearchResults?.items.first.id;
    expect(
      shownId,
      'id-ab',
      reason: 'Screen must show the latest typed query ("ab"), not the '
          'earlier "a" whose response landed last.',
    );
  });

  test('typing a new prompt does not keep the previous prompt results on '
      'screen while the new search is in flight', () async {
    // First prompt resolves and is shown.
    notifier.setQuery('first prompt');
    await settleDebounce();
    proxy.resolve('first prompt');
    await Future<void>.value();
    expect(
      container.read(searchStateProvider).aiSearchResults?.items.first.id,
      'id-first prompt',
    );

    // User types a different, not-yet-cached prompt. Before any pause/enter,
    // the stale first-prompt results must be gone (replaced by a loading
    // state), not presented as the answer to the new prompt.
    notifier.setQuery('second prompt');
    final mid = container.read(searchStateProvider);
    expect(mid.aiSearchResults, isNull,
        reason: 'previous prompt results must not linger as if current');
    expect(mid.isLoading, isTrue);

    // And once the new search lands it shows the new prompt.
    await settleDebounce();
    proxy.resolve('second prompt');
    await Future<void>.value();
    expect(
      container.read(searchStateProvider).aiSearchResults?.items.first.id,
      'id-second prompt',
    );
  });

  test('typing then pausing shows that query without pressing enter', () async {
    notifier.setQuery('jazz');
    await settleDebounce();
    expect(proxy.aiCalls, contains('jazz'));

    proxy.resolve('jazz');
    await Future<void>.value();

    final state = container.read(searchStateProvider);
    expect(state.searchPhase, SearchPhase.results);
    expect(state.aiSearchResults?.items.first.id, 'id-jazz');
  });
}
