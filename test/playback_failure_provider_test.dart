import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kalinka/data_model/data_model.dart';
import 'package:kalinka/data_model/playqueue_events.dart';
import 'package:kalinka/providers/app_state_provider.dart';
import 'package:kalinka/providers/playback_failure_provider.dart';

// The server only marks a track `unavailable` when a plugin can't produce a
// URL. Everything else surfaces as a transient error state, so the app has to
// remember which track it was for the queue to keep showing it.

class _SettableQueueNotifier extends PlayQueueStateStore {
  @override
  PlayQueueState build() => _state(state: null, index: 0);

  void set(PlayQueueState s) => state = s;
}

Track _track(String id) => Track(
  id: id,
  title: 'Track $id',
  duration: 100,
  performer: Artist(id: 'a', name: 'Someone'),
);

PlayQueueState _state({
  required PlayerStateType? state,
  required int index,
  List<Track>? tracks,
}) => PlayQueueState(
  playbackState: PlaybackState(
    state: state,
    index: index,
    currentTrack: _track('t$index'),
  ),
  trackList: tracks ?? [_track('t0'), _track('t1')],
  playbackMode: PlaybackMode.empty,
  seq: 0,
);

void main() {
  late ProviderContainer container;
  late _SettableQueueNotifier queue;

  setUp(() {
    queue = _SettableQueueNotifier();
    container = ProviderContainer(
      overrides: [playQueueStateStoreProvider.overrideWith(() => queue)],
    );
    // Instantiate the notifier so its listener is armed before the first
    // state change — the app does the same from MusicPlayerScreen.
    container.read(playbackFailuresProvider);
    addTearDown(container.dispose);
  });

  test('remembers the track that failed', () {
    queue.set(_state(state: PlayerStateType.error, index: 0));
    expect(container.read(playbackFailuresProvider), {'t0'});
  });

  test('keeps the mark once playback moves to another track', () {
    queue.set(_state(state: PlayerStateType.error, index: 0));
    queue.set(_state(state: PlayerStateType.playing, index: 1));

    expect(container.read(playbackFailuresProvider), {'t0'});
  });

  test('clears the mark when the same track plays', () {
    queue.set(_state(state: PlayerStateType.error, index: 0));
    queue.set(_state(state: PlayerStateType.playing, index: 0));

    expect(container.read(playbackFailuresProvider), isEmpty);
  });

  test('a pause does not clear the mark', () {
    queue.set(_state(state: PlayerStateType.error, index: 0));
    queue.set(_state(state: PlayerStateType.paused, index: 0));

    expect(container.read(playbackFailuresProvider), {'t0'});
  });

  test('emptying the queue drops every mark', () {
    queue.set(_state(state: PlayerStateType.error, index: 0));
    queue.set(_state(state: PlayerStateType.stopped, index: 0, tracks: []));

    expect(container.read(playbackFailuresProvider), isEmpty);
  });
}
