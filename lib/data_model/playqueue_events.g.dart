// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'playqueue_events.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PlayQueueState _$PlayQueueStateFromJson(Map<String, dynamic> json) =>
    PlayQueueState(
      playbackState: PlaybackState.fromJson(
        json['playback_state'] as Map<String, dynamic>,
      ),
      trackList: (json['track_list'] as List<dynamic>)
          .map((e) => Track.fromJson(e as Map<String, dynamic>))
          .toList(),
      playbackMode: PlaybackMode.fromJson(
        json['playback_mode'] as Map<String, dynamic>,
      ),
      seq: (json['seq'] as num).toInt(),
    );

Map<String, dynamic> _$PlayQueueStateToJson(PlayQueueState instance) =>
    <String, dynamic>{
      'playback_state': instance.playbackState.toJson(),
      'track_list': instance.trackList.map((e) => e.toJson()).toList(),
      'playback_mode': instance.playbackMode.toJson(),
      'seq': instance.seq,
    };

const _$PlayQueueEventTypeEnumMap = {
  PlayQueueEventType.playbackStateChanged: 'playback_state_changed',
  PlayQueueEventType.requestMoreTracks: 'request_more_tracks',
  PlayQueueEventType.tracksAdded: 'tracks_added',
  PlayQueueEventType.tracksRemoved: 'tracks_removed',
  PlayQueueEventType.playbackError: 'playback_error',
  PlayQueueEventType.playbackModeChanged: 'playback_mode_changed',
};
