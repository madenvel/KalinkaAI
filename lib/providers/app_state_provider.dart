import 'package:flutter/material.dart' show WidgetsBinding;
import 'package:flutter_riverpod/flutter_riverpod.dart'
    show
        AsyncValueExtensions,
        Notifier,
        NotifierProvider,
        Provider,
        ProviderListenableSelect;
import '../data_model/ext_device_events.dart';
import '../data_model/playqueue_events.dart'
    show PlayQueueState, PlayQueueEvent, TrackMovedEvent;
import '../providers/monotonic_clock_provider.dart' show monotonicClockProvider;
import '../providers/wire_event_provider.dart'
    show playQueueEventBusProvider, extDeviceEventBusProvider;
import 'package:logger/logger.dart';

final logger = Logger();

class PlayQueueStateStore extends Notifier<PlayQueueState> {
  /// Tracks moves issued by this client that have not yet been confirmed by
  /// the server.  When the matching `track_moved` event arrives we consume
  /// the pending entry and skip re-applying the move (it was already applied
  /// optimistically), preventing a double-move.
  final List<({int from, int to})> _pendingMoves = [];

  @override
  PlayQueueState build() {
    state = PlayQueueState.empty;

    ref.listen(playQueueEventBusProvider, (prev, next) {
      next.when(
        data: (PlayQueueEvent event) {
          final timestamp = ref
              .read(monotonicClockProvider)
              .elapsedMilliseconds;
          // Defer state updates to avoid modifying during build phase
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (event is TrackMovedEvent) {
              final idx = _pendingMoves.indexWhere(
                (m) => m.from == event.fromIndex && m.to == event.toIndex,
              );
              if (idx != -1) {
                // Our own move — already applied optimistically. Just sync seq.
                _pendingMoves.removeAt(idx);
                state = state.copyWith(seq: event.seq);
                return;
              }
            }
            state = state.apply(event, timestamp);
          });
        },
        loading: () {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _pendingMoves.clear();
            state = PlayQueueState.empty;
          });
        },
        error: (Object error, StackTrace stackTrace) {
          logger.e('Error occurred: $error', stackTrace: stackTrace);
          // Defer state update to avoid modifying during build phase
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _pendingMoves.clear();
            state = PlayQueueState.empty;
          });
        },
      );
    });

    return state;
  }

  static int _remapIndex(int idx, int from, int to) {
    if (idx == from) return to;
    if (from < to) {
      if (from < idx && idx <= to) return idx - 1;
    } else {
      if (to <= idx && idx < from) return idx + 1;
    }
    return idx;
  }

  void optimisticallyReorder(int oldIndex, int newIndex) {
    final list = [...state.trackList];
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    _pendingMoves.add((from: oldIndex, to: newIndex));
    final oldPlaybackIndex = state.playbackState.index ?? 0;
    final newPlaybackIndex = _remapIndex(oldPlaybackIndex, oldIndex, newIndex);
    final newPlaybackState = newPlaybackIndex != oldPlaybackIndex
        ? state.playbackState.copyWithFields(index: newPlaybackIndex)
        : state.playbackState;
    state = state.copyWith(
      trackList: list,
      playbackState: newPlaybackState,
      seq: state.seq,
    );
  }
}

class ExtDeviceStateStore extends Notifier<ExtDeviceState> {
  @override
  ExtDeviceState build() {
    state = ExtDeviceState.empty;

    ref.listen(extDeviceEventBusProvider, (prev, next) {
      next.when(
        data: (ExtDeviceEvent event) {
          // Defer state updates to avoid modifying during build phase
          WidgetsBinding.instance.addPostFrameCallback((_) {
            state = state.apply(event);
          });
        },
        loading: () {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            state = ExtDeviceState.empty;
          });
        },
        error: (Object error, StackTrace stackTrace) {
          logger.e('Error occurred: $error', stackTrace: stackTrace);
          // Defer state update to avoid modifying during build phase
          WidgetsBinding.instance.addPostFrameCallback((_) {
            state = ExtDeviceState.empty;
          });
        },
      );
    });

    return state;
  }
}

final playQueueStateStoreProvider =
    NotifierProvider<PlayQueueStateStore, PlayQueueState>(
      () => PlayQueueStateStore(),
    );

final extDeviceStateStoreProvider =
    NotifierProvider<ExtDeviceStateStore, ExtDeviceState>(
      () => ExtDeviceStateStore(),
    );

final playerStateProvider = Provider(
  (ref) =>
      ref.watch(playQueueStateStoreProvider.select((s) => s.playbackState)),
);

final playQueueProvider = Provider(
  (ref) => ref.watch(playQueueStateStoreProvider.select((s) => s.trackList)),
);

final volumeStateProvider = Provider(
  (ref) => ref.watch(extDeviceStateStoreProvider.select((s) => s.volume)),
);

final playbackModeProvider = Provider(
  (ref) => ref.watch(playQueueStateStoreProvider.select((s) => s.playbackMode)),
);

// Queue expansion state
class QueueExpansionNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
  void expand() => state = true;
  void collapse() => state = false;
}

final queueExpansionProvider = NotifierProvider<QueueExpansionNotifier, bool>(
  QueueExpansionNotifier.new,
);
