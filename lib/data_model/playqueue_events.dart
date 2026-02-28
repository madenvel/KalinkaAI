import 'package:freezed_annotation/freezed_annotation.dart';
import '../data_model/data_model.dart';

part 'playqueue_events.freezed.dart';
part 'playqueue_events.g.dart';

// To regenerate code, run:
// dart run build_runner build --delete-conflicting-outputs

/// Custom converter for EntityId that handles string serialization
class EntityIdConverter implements JsonConverter<EntityId, String> {
  const EntityIdConverter();

  @override
  EntityId fromJson(String json) {
    return EntityId.fromString(json);
  }

  @override
  String toJson(EntityId object) {
    return 'kalinka:${object.source}:${object.type.toValue()}:${object.id}';
  }
}

/// Immutable state for a play queue.
@JsonSerializable()
class PlayQueueState {
  final PlaybackState playbackState;
  final List<Track> trackList;
  final PlaybackMode playbackMode;
  final int seq;

  const PlayQueueState({
    required this.playbackState,
    required this.trackList,
    required this.playbackMode,
    required this.seq,
  });

  static final PlayQueueState empty = PlayQueueState(
    playbackState: PlaybackState.empty,
    trackList: <Track>[],
    playbackMode: PlaybackMode.empty,
    seq: 0,
  );

  PlayQueueState copyWith({
    PlaybackState? playbackState,
    List<Track>? trackList,
    PlaybackMode? playbackMode,
    required int seq,
  }) => PlayQueueState(
    playbackState: playbackState ?? this.playbackState,
    trackList: trackList ?? this.trackList,
    playbackMode: playbackMode ?? this.playbackMode,
    seq: seq,
  );

  /// Apply an event to produce a new state (immutable pattern).
  PlayQueueState apply(PlayQueueEvent event, int timestamp) {
    switch (event) {
      case PlaybackStateChangedEvent(:final state, :final seq):
        return copyWith(
          playbackState: state.copyWith(state)..timestampNs = timestamp,
          seq: seq,
        );
      case TracksAddedEvent(:final tracks, :final seq):
        return copyWith(trackList: [...trackList, ...tracks], seq: seq);
      case TracksRemovedEvent(:final indices, :final seq):
        return copyWith(
          trackList: [
            for (var i = 0; i < trackList.length; i++)
              if (!indices.contains(i)) trackList[i],
          ],
          seq: seq,
        );
      case PlaybackModeChangedEvent(:final mode, :final seq):
        return copyWith(playbackMode: mode, seq: seq);
      case RequestMoreTracksEvent():
        // Ignore - no state change.
        return this;
      case TrackMovedEvent(:final fromIndex, :final toIndex, :final seq):
        final list = [...trackList];
        final item = list.removeAt(fromIndex);
        list.insert(toIndex, item);
        final oldPlaybackIndex = playbackState.index ?? 0;
        final newPlaybackIndex = _remapIndex(oldPlaybackIndex, fromIndex, toIndex);
        final newPlaybackState = newPlaybackIndex != oldPlaybackIndex
            ? playbackState.copyWithFields(index: newPlaybackIndex)
            : playbackState;
        return copyWith(trackList: list, playbackState: newPlaybackState, seq: seq);
      case PlaybackErrorEvent():
        // Ignore - no state change.
        return this;
      case ReplayPlayQueueEvent(:final state, :final serverTimeNs, :final seq):
        return PlayQueueState(
          playbackState: state.playbackState.copyWith(state.playbackState)
            ..timestampNs = timestamp
            ..position = _estimatePosition(state.playbackState, serverTimeNs),
          trackList: state.trackList,
          playbackMode: state.playbackMode,
          seq: seq,
        );
    }
  }

  /// Mirrors the server-side `_remap_index` logic.
  /// Returns the new position of [idx] after an item is moved from
  /// [fromIndex] to [toIndex] in the list.
  int _remapIndex(int idx, int fromIndex, int toIndex) {
    if (idx == fromIndex) return toIndex;
    if (fromIndex < toIndex) {
      // Item moved forward: everything in (fromIndex, toIndex] shifts back by 1
      if (fromIndex < idx && idx <= toIndex) return idx - 1;
    } else {
      // Item moved backward: everything in [toIndex, fromIndex) shifts forward by 1
      if (toIndex <= idx && idx < fromIndex) return idx + 1;
    }
    return idx;
  }

  int _estimatePosition(PlaybackState playbackState, int serverTimeNs) {
    if (playbackState.state == PlayerStateType.playing) {
      final delta = (serverTimeNs - playbackState.timestampNs) / 1_000_000;
      return (playbackState.position ?? 0) + delta.toInt();
    } else {
      return playbackState.position ?? 0;
    }
  }

  factory PlayQueueState.fromJson(Map<String, dynamic> json) =>
      _$PlayQueueStateFromJson(json);

  Map<String, dynamic> toJson() => _$PlayQueueStateToJson(this);
}

/// Wire event types matching PlayQueueEventType from backend.
@JsonEnum(fieldRename: FieldRename.snake, alwaysCreate: true)
enum PlayQueueEventType {
  playbackStateChanged,
  requestMoreTracks,
  tracksAdded,
  tracksRemoved,
  playbackError,
  playbackModeChanged;

  String toJson() => _$PlayQueueEventTypeEnumMap[this]!;

  factory PlayQueueEventType.fromJson(String json) =>
      _$PlayQueueEventTypeEnumMap.map(
        (key, value) => MapEntry(value, key),
      )[json]!;
}

/// Base class for PlayQueue events with event_type and seq.
@freezed
sealed class PlayQueueEvent with _$PlayQueueEvent {
  const factory PlayQueueEvent.playbackStateChanged({
    required PlaybackState state,
    required int seq,
  }) = PlaybackStateChangedEvent;

  const factory PlayQueueEvent.requestMoreTracks({required int seq}) =
      RequestMoreTracksEvent;

  const factory PlayQueueEvent.tracksAdded({
    required List<Track> tracks,
    required int seq,
  }) = TracksAddedEvent;

  const factory PlayQueueEvent.tracksRemoved({
    required List<int> indices,
    required int seq,
  }) = TracksRemovedEvent;

  const factory PlayQueueEvent.trackMoved({
    required int fromIndex,
    required int toIndex,
    required int seq,
  }) = TrackMovedEvent;

  const factory PlayQueueEvent.playbackError({
    required String message,
    required int seq,
  }) = PlaybackErrorEvent;

  const factory PlayQueueEvent.playbackModeChanged({
    required PlaybackMode mode,
    required int seq,
  }) = PlaybackModeChangedEvent;

  const factory PlayQueueEvent.replayEvent({
    required PlayQueueState state,
    required int serverTimeNs,
    required int seq,
  }) = ReplayPlayQueueEvent;

  factory PlayQueueEvent.fromJson(Map<String, dynamic> json) {
    final eventTypeStr = json['event_type'] as String;
    final seq = json['seq'] as int? ?? 0;

    switch (eventTypeStr) {
      case 'state_changed':
        return PlayQueueEvent.playbackStateChanged(
          state: PlaybackState.fromJson(json['state'] as Map<String, dynamic>),
          seq: seq,
        );
      case 'request_more_tracks':
        return PlayQueueEvent.requestMoreTracks(seq: seq);
      case 'tracks_added':
        return PlayQueueEvent.tracksAdded(
          tracks: (json['tracks'] as List)
              .map((e) => Track.fromJson(e))
              .toList(),
          seq: seq,
        );
      case 'tracks_removed':
        return PlayQueueEvent.tracksRemoved(
          indices: List<int>.from(json['indices'] as List),
          seq: seq,
        );
      case 'track_moved':
        return PlayQueueEvent.trackMoved(
          fromIndex: json['from_index'] as int,
          toIndex: json['to_index'] as int,
          seq: seq,
        );
      case 'playback_error':
        return PlayQueueEvent.playbackError(
          message: json['message'] as String,
          seq: seq,
        );
      case 'playback_mode_changed':
        return PlayQueueEvent.playbackModeChanged(
          mode: PlaybackMode.fromJson(json['mode'] as Map<String, dynamic>),
          seq: seq,
        );
      case 'replay_event':
        if (json['state_type'] == 'PlayQueueState') {
          return PlayQueueEvent.replayEvent(
            state: PlayQueueState.fromJson(
              json['state'] as Map<String, dynamic>,
            ),
            serverTimeNs: json['server_time_ns'] as int,
            seq: seq,
          );
        } else {
          throw ArgumentError(
            'Unknown state_type for replay_event: ${json['state_type']}',
          );
        }
      default:
        throw ArgumentError('Unknown event_type: $eventTypeStr');
    }
  }
}
