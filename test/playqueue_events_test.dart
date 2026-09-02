import 'package:flutter_test/flutter_test.dart';
import 'package:kalinka/data_model/data_model.dart';
import 'package:kalinka/data_model/playqueue_events.dart';

PlayQueueState _stateWith(List<Track> tracks) => PlayQueueState(
  playbackState: PlaybackState(state: PlayerStateType.stopped),
  trackList: tracks,
  playbackMode: PlaybackMode.empty,
  seq: 0,
);

void main() {
  group('TrackUnavailableEvent apply', () {
    test('marks the targeted track unavailable', () {
      final state = _stateWith([
        Track(id: 'a', title: 'A', duration: 10),
        Track(id: 'b', title: 'B', duration: 10),
      ]);

      final next = state.apply(
        const PlayQueueEvent.trackUnavailable(
          index: 1,
          unavailable: true,
          seq: 1,
        ),
        0,
      );

      expect(next.trackList[1].unavailable, isTrue);
      expect(next.trackList[0].unavailable, isFalse);
      expect(next.seq, 1);
    });

    test('clears the flag when unavailable is false', () {
      final state = _stateWith([
        Track(id: 'a', title: 'A', duration: 10, unavailable: true),
      ]);

      final next = state.apply(
        const PlayQueueEvent.trackUnavailable(
          index: 0,
          unavailable: false,
          seq: 1,
        ),
        0,
      );

      expect(next.trackList[0].unavailable, isFalse);
    });

    test('ignores out-of-range indices', () {
      final state = _stateWith([Track(id: 'a', title: 'A', duration: 10)]);

      final next = state.apply(
        const PlayQueueEvent.trackUnavailable(
          index: 5,
          unavailable: true,
          seq: 1,
        ),
        0,
      );

      expect(next, same(state));
    });

    test('parses the wire event', () {
      final event = PlayQueueEvent.fromJson({
        'event_type': 'track_unavailable',
        'index': 2,
        'unavailable': true,
        'seq': 7,
      });

      expect(event, isA<TrackUnavailableEvent>());
      final unavailable = event as TrackUnavailableEvent;
      expect(unavailable.index, 2);
      expect(unavailable.unavailable, isTrue);
      expect(unavailable.seq, 7);
    });

    test('parses a numeric (non-int) index defensively', () {
      final event = PlayQueueEvent.fromJson({
        'event_type': 'track_unavailable',
        'index': 3.0,
        'unavailable': true,
        'seq': 1,
      });

      expect(event, isA<TrackUnavailableEvent>());
      expect((event as TrackUnavailableEvent).index, 3);
    });
  });

  group('renderer topology events', () {
    test('parses renderers_changed with unflagged rows', () {
      final event = PlayQueueEvent.fromJson({
        'event_type': 'renderers_changed',
        'renderers': [
          {
            'renderer_id': 'r-1',
            'friendly_name': 'Kitchen',
            'status': 'connected',
            'platform': {'hostname': 'pi', 'audio_backend': 'alsa'},
          },
        ],
        'seq': 4,
      });

      expect(event, isA<RenderersChangedEvent>());
      final changed = event as RenderersChangedEvent;
      expect(changed.renderers.single.rendererId, 'r-1');
      expect(changed.renderers.single.active, isFalse);
      expect(changed.seq, 4);
    });

    test('parses current_renderer_changed, nulls meaning nothing', () {
      final event = PlayQueueEvent.fromJson({
        'event_type': 'current_renderer_changed',
        'renderer_id': null,
        'selected_renderer_id': 'r-2',
        'seq': 5,
      });

      expect(event, isA<CurrentRendererChangedEvent>());
      final current = event as CurrentRendererChangedEvent;
      expect(current.rendererId, isNull);
      expect(current.selectedRendererId, 'r-2');
    });

    test('replay state carries the topology; absent keys stay null', () {
      final withTopology = PlayQueueState.fromJson({
        'playback_state': {'state': 'STOPPED'},
        'track_list': [],
        'playback_mode': {
          'shuffle': false,
          'repeat_single': false,
          'repeat_all': false,
        },
        'seq': 1,
        'renderers': [],
        'current_renderer_id': 'r-1',
      });
      expect(withTopology.renderers, isEmpty);
      expect(withTopology.currentRendererId, 'r-1');

      final preEvents = PlayQueueState.fromJson({
        'playback_state': {'state': 'STOPPED'},
        'track_list': [],
        'playback_mode': {
          'shuffle': false,
          'repeat_single': false,
          'repeat_all': false,
        },
        'seq': 1,
      });
      expect(preEvents.renderers, isNull);
    });
  });

  group('PlaybackStateChangedEvent apply', () {
    // The server sends a whole state each time, and reports no URL once the
    // renderer is holding nothing — so the last one has to go.
    test('a state reporting no stream URL clears the one before it', () {
      final playing = _stateWith([Track(id: 'a', title: 'A', duration: 10)])
          .apply(
            PlayQueueEvent.playbackStateChanged(
              state: PlaybackState(
                state: PlayerStateType.playing,
                streamUrl: 'http://server/content/localfiles/a',
              ),
              seq: 1,
            ),
            0,
          );
      expect(playing.playbackState.streamUrl, isNotNull);

      final stopped = playing.apply(
        PlayQueueEvent.playbackStateChanged(
          state: PlaybackState(state: PlayerStateType.stopped),
          seq: 2,
        ),
        0,
      );

      expect(stopped.playbackState.streamUrl, isNull);
    });
  });
}
