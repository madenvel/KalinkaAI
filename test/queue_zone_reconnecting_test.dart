import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kalinka/data_model/data_model.dart';
import 'package:kalinka/data_model/playqueue_events.dart';
import 'package:kalinka/providers/app_state_provider.dart';
import 'package:kalinka/providers/connection_settings_provider.dart';
import 'package:kalinka/providers/connection_state_provider.dart';
import 'package:kalinka/providers/playback_time_provider.dart';
import 'package:kalinka/providers/source_modules_provider.dart';
import 'package:kalinka/providers/url_resolver.dart';
import 'package:kalinka/widgets/queue_zone.dart';

// Regression: while reconnecting (isOffline), QueueZone dimmed the queue by
// wrapping it in an Expanded — but that Expanded was a direct child of a Stack,
// which applies FlexParentData to a RenderStack child and throws at layout. In
// release that surfaces as a gray ErrorWidget filling the queue area for the
// 1-2s reconnect window at startup. This test renders a non-empty queue while
// reconnecting and asserts nothing throws.

class _SettableQueueNotifier extends PlayQueueStateStore {
  _SettableQueueNotifier(this._initial);
  final PlayQueueState _initial;
  @override
  PlayQueueState build() => _initial;
}

class _FakeConnectionNotifier extends ConnectionStateNotifier {
  _FakeConnectionNotifier(this._status);
  final ConnectionStatus _status;
  @override
  ConnectionStatus build() => _status;
}

class _FakePlaybackTimeNotifier extends PlaybackTimeMsNotifier {
  @override
  int build() => 0;
}

Track _track(String id) => Track(id: id, title: 'Track $id', duration: 200000);

PlayQueueState _queueWithTracks() => PlayQueueState(
  playbackState: PlaybackState(state: PlayerStateType.playing, index: 0),
  trackList: [_track('a'), _track('b')],
  playbackMode: PlaybackMode.empty,
  seq: 0,
);

Future<void> _pumpQueueZone(
  WidgetTester tester,
  ConnectionStatus status,
) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        playQueueStateStoreProvider.overrideWith(
          () => _SettableQueueNotifier(_queueWithTracks()),
        ),
        connectionStateProvider.overrideWith(
          () => _FakeConnectionNotifier(status),
        ),
        playbackTimeMsProvider.overrideWith(() => _FakePlaybackTimeNotifier()),
        sourceCountProvider.overrideWithValue(1),
        urlResolverProvider.overrideWithValue(UrlResolver('')),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 400, height: 700, child: QueueZone()),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('renders a non-empty queue while reconnecting without throwing',
      (tester) async {
    await _pumpQueueZone(tester, ConnectionStatus.reconnecting);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders a non-empty queue while connected without throwing',
      (tester) async {
    await _pumpQueueZone(tester, ConnectionStatus.connected);
    expect(tester.takeException(), isNull);
  });
}
