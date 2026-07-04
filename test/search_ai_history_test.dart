import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalinka/data_model/data_model.dart';
import 'package:kalinka/providers/app_state_provider.dart';
import 'package:kalinka/providers/connection_settings_provider.dart';
import 'package:kalinka/providers/kalinka_player_api_provider.dart';
import 'package:kalinka/providers/search_state_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Mirrors the private const in search_state_provider.dart. Kept as a literal
// so the test doesn't force the key into the public API; if it ever drifts,
// the composition assertions below fail loudly.
const _aiHistoryKey = 'Kalinka.aiSearchHistory';

/// Records the AI queries it's asked to run and returns an empty result set.
/// Only [aiSearch] is exercised by the paths under test; anything else throws.
class _FakeProxy implements KalinkaPlayerProxy {
  final List<String> aiQueries = [];

  @override
  Future<BrowseItemsList> aiSearch(
    String query, {
    int offset = 0,
    int limit = 10,
    List<String>? sources,
  }) async {
    aiQueries.add(query);
    return BrowseItemsList.empty();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ProviderContainer _container(SharedPreferences prefs, {_FakeProxy? proxy}) {
  final container = ProviderContainer(
    overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      if (proxy != null) kalinkaProxyProvider.overrideWithValue(proxy),
      // Stub the websocket-backed playback providers so activateSearch's
      // recommendations check reads a stopped player instead of connecting.
      playerStateProvider.overrideWithValue(PlaybackState.empty),
      playQueueProvider.overrideWithValue(const []),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<SharedPreferences> _prefs([Map<String, Object> initial = const {}]) {
  SharedPreferences.setMockInitialValues(initial);
  return SharedPreferences.getInstance();
}

void main() {
  group('AI suggestion slot composition', () {
    test('no history — all slots are canned suggestions', () async {
      final container = _container(await _prefs());
      container.read(searchStateProvider.notifier).activateSearch();

      expect(container.read(searchStateProvider).aiPromptSuggestions, [
        'something melancholic for tonight',
        'continue where I left off',
        'new additions to the library',
      ]);
    });

    test('one captured query fills only the first slot', () async {
      final container = _container(
        await _prefs({
          _aiHistoryKey: jsonEncode(['jazz for a rainy afternoon']),
        }),
      );
      container.read(searchStateProvider.notifier).activateSearch();

      expect(container.read(searchStateProvider).aiPromptSuggestions, [
        'jazz for a rainy afternoon',
        'continue where I left off',
        'new additions to the library',
      ]);
    });

    test('history fills both lead slots; pinned suggestion is kept', () async {
      final container = _container(
        await _prefs({
          _aiHistoryKey: jsonEncode(['newest', 'older', 'oldest']),
        }),
      );
      container.read(searchStateProvider.notifier).activateSearch();

      // Only two lead slots exist, so the third history entry is not shown,
      // and the pinned suggestion always trails.
      expect(container.read(searchStateProvider).aiPromptSuggestions, [
        'newest',
        'older',
        'new additions to the library',
      ]);
    });
  });

  test(
    'AI results settle for 10s → curated into AI history, not recent chips',
    () async {
      final prefs = await _prefs();
      fakeAsync((async) {
        final proxy = _FakeProxy();
        final container = _container(prefs, proxy: proxy);
        final notifier = container.read(searchStateProvider.notifier);

        notifier.reExecuteQuery('something upbeat for the gym');
        async.flushMicrotasks(); // let the AI search resolve + settle
        expect(proxy.aiQueries, ['something upbeat for the gym']);

        // Before the delay elapses nothing is captured yet.
        async.elapse(const Duration(seconds: 9));
        expect(notifier.getAiSearchHistory(), isEmpty);

        async.elapse(const Duration(seconds: 1));
        expect(notifier.getAiSearchHistory(), ['something upbeat for the gym']);
        // Recent chips are for direct search only — AI queries never land here.
        expect(notifier.getSearchHistory(), isEmpty);
      });
    },
  );

  test('starting a new search before 10s cancels the capture', () async {
    final prefs = await _prefs();
    fakeAsync((async) {
      final proxy = _FakeProxy();
      final container = _container(prefs, proxy: proxy);
      final notifier = container.read(searchStateProvider.notifier);

      notifier.reExecuteQuery('first query');
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 5)); // not yet captured

      notifier.reExecuteQuery('second query');
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 5)); // first query's timer cancelled

      // Only the second query's timer should still be pending.
      expect(notifier.getAiSearchHistory(), isEmpty);
      async.elapse(const Duration(seconds: 5));
      expect(notifier.getAiSearchHistory(), ['second query']);
    });
  });
}
