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
        const PlayQueueEvent.trackUnavailable(index: 1, unavailable: true, seq: 1),
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
        const PlayQueueEvent.trackUnavailable(index: 0, unavailable: false, seq: 1),
        0,
      );

      expect(next.trackList[0].unavailable, isFalse);
    });

    test('ignores out-of-range indices', () {
      final state = _stateWith([Track(id: 'a', title: 'A', duration: 10)]);

      final next = state.apply(
        const PlayQueueEvent.trackUnavailable(index: 5, unavailable: true, seq: 1),
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
  });
}
