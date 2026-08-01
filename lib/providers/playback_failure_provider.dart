import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data_model/data_model.dart';
import 'app_state_provider.dart';

/// Ids of tracks that failed to play during this session.
///
/// The server only flags a track `unavailable` when a plugin can't produce a
/// URL for it; every other failure (decode, transport, device) arrives as a
/// transient `error` playback state and leaves no mark once playback moves on.
/// This keeps that mark client-side so the queue can still show which track
/// went wrong after the error dialog is gone.
///
/// An id is dropped again when that track plays, so a successful retry clears
/// the marker; the whole set is dropped when the queue empties. Keyed by track
/// id, so two copies of the same track in the queue share one mark.
final playbackFailuresProvider =
    NotifierProvider<PlaybackFailuresNotifier, Set<String>>(
      PlaybackFailuresNotifier.new,
    );

class PlaybackFailuresNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    ref.listen(
      playQueueStateStoreProvider.select(
        (s) => (
          state: s.playbackState.state,
          trackId: s.playbackState.currentTrack?.id,
          queueEmpty: s.trackList.isEmpty,
        ),
      ),
      (_, next) => _record(next),
    );
    return const {};
  }

  void _record(
    ({PlayerStateType? state, String? trackId, bool queueEmpty}) next,
  ) {
    if (next.queueEmpty) {
      if (state.isNotEmpty) state = const {};
      return;
    }
    final id = next.trackId;
    if (id == null) return;
    switch (next.state) {
      case PlayerStateType.error:
        if (!state.contains(id)) state = {...state, id};
      case PlayerStateType.playing:
        if (state.contains(id)) state = {...state}..remove(id);
      // Paused/stopped/buffering say nothing either way — a paused track that
      // failed earlier keeps its mark.
      case PlayerStateType.paused:
      case PlayerStateType.stopped:
      case PlayerStateType.buffering:
      case null:
        break;
    }
  }
}
