// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'kalinka_ws_api.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PowerOnCommand _$PowerOnCommandFromJson(Map<String, dynamic> json) =>
    PowerOnCommand($type: json['command'] as String?);

Map<String, dynamic> _$PowerOnCommandToJson(PowerOnCommand instance) =>
    <String, dynamic>{'command': instance.$type};

PowerOffCommand _$PowerOffCommandFromJson(Map<String, dynamic> json) =>
    PowerOffCommand($type: json['command'] as String?);

Map<String, dynamic> _$PowerOffCommandToJson(PowerOffCommand instance) =>
    <String, dynamic>{'command': instance.$type};

SetVolumeCommand _$SetVolumeCommandFromJson(Map<String, dynamic> json) =>
    SetVolumeCommand(
      volume: (json['volume'] as num).toInt(),
      $type: json['command'] as String?,
    );

Map<String, dynamic> _$SetVolumeCommandToJson(SetVolumeCommand instance) =>
    <String, dynamic>{'volume': instance.volume, 'command': instance.$type};

PlayCommand _$PlayCommandFromJson(Map<String, dynamic> json) => PlayCommand(
  index: (json['index'] as num?)?.toInt(),
  $type: json['command'] as String?,
);

Map<String, dynamic> _$PlayCommandToJson(PlayCommand instance) =>
    <String, dynamic>{'index': instance.index, 'command': instance.$type};

PauseCommand _$PauseCommandFromJson(Map<String, dynamic> json) => PauseCommand(
  paused: json['paused'] as bool? ?? true,
  $type: json['command'] as String?,
);

Map<String, dynamic> _$PauseCommandToJson(PauseCommand instance) =>
    <String, dynamic>{'paused': instance.paused, 'command': instance.$type};

NextCommand _$NextCommandFromJson(Map<String, dynamic> json) =>
    NextCommand($type: json['command'] as String?);

Map<String, dynamic> _$NextCommandToJson(NextCommand instance) =>
    <String, dynamic>{'command': instance.$type};

PrevCommand _$PrevCommandFromJson(Map<String, dynamic> json) =>
    PrevCommand($type: json['command'] as String?);

Map<String, dynamic> _$PrevCommandToJson(PrevCommand instance) =>
    <String, dynamic>{'command': instance.$type};

StopCommand _$StopCommandFromJson(Map<String, dynamic> json) =>
    StopCommand($type: json['command'] as String?);

Map<String, dynamic> _$StopCommandToJson(StopCommand instance) =>
    <String, dynamic>{'command': instance.$type};

SeekCommand _$SeekCommandFromJson(Map<String, dynamic> json) => SeekCommand(
  positionMs: (json['position_ms'] as num).toInt(),
  $type: json['command'] as String?,
);

Map<String, dynamic> _$SeekCommandToJson(SeekCommand instance) =>
    <String, dynamic>{
      'position_ms': instance.positionMs,
      'command': instance.$type,
    };

SetPlaybackModeCommand _$SetPlaybackModeCommandFromJson(
  Map<String, dynamic> json,
) => SetPlaybackModeCommand(
  shuffle: json['shuffle'] as bool?,
  repeatSingle: json['repeat_single'] as bool?,
  repeatAll: json['repeat_all'] as bool?,
  $type: json['command'] as String?,
);

Map<String, dynamic> _$SetPlaybackModeCommandToJson(
  SetPlaybackModeCommand instance,
) => <String, dynamic>{
  'shuffle': instance.shuffle,
  'repeat_single': instance.repeatSingle,
  'repeat_all': instance.repeatAll,
  'command': instance.$type,
};

MoveCommand _$MoveCommandFromJson(Map<String, dynamic> json) => MoveCommand(
  from: (json['from'] as num).toInt(),
  to: (json['to'] as num).toInt(),
  $type: json['command'] as String?,
);

Map<String, dynamic> _$MoveCommandToJson(MoveCommand instance) =>
    <String, dynamic>{
      'from': instance.from,
      'to': instance.to,
      'command': instance.$type,
    };
