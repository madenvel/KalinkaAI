import 'package:freezed_annotation/freezed_annotation.dart';

part 'kalinka_ws_api.freezed.dart';
part 'kalinka_ws_api.g.dart';

// To regenerate code, run:
// dart run build_runner build --delete-conflicting-outputs

@Freezed(unionKey: 'command', unionValueCase: FreezedUnionCase.snake)
sealed class DeviceCommand with _$DeviceCommand {
  const factory DeviceCommand.powerOn() = PowerOnCommand;

  const factory DeviceCommand.powerOff() = PowerOffCommand;

  // Volume is in the device's native scale (e.g. MusicCast = 0..161). The
  // server-side plugin clamps to its own max_volume; don't enforce a fixed
  // 0..100 range here or sliders for high-range devices reject valid values.
  @Assert('volume >= 0', 'Volume must be non-negative')
  const factory DeviceCommand.setVolume({required int volume}) =
      SetVolumeCommand;

  factory DeviceCommand.fromJson(Map<String, dynamic> json) =>
      _$DeviceCommandFromJson(json);
}

@Freezed(unionKey: 'command', unionValueCase: FreezedUnionCase.snake)
sealed class QueueCommand with _$QueueCommand {
  const QueueCommand._();

  const factory QueueCommand.play({int? index}) = PlayCommand;

  const factory QueueCommand.pause({@Default(true) bool paused}) = PauseCommand;

  const factory QueueCommand.next() = NextCommand;

  const factory QueueCommand.prev() = PrevCommand;

  const factory QueueCommand.stop() = StopCommand;

  const factory QueueCommand.seek({required int positionMs}) = SeekCommand;

  const factory QueueCommand.setPlaybackMode({
    bool? shuffle,
    bool? repeatSingle,
    bool? repeatAll,
  }) = SetPlaybackModeCommand;

  const factory QueueCommand.move({
    required int fromIndex,
    required int toIndex,
  }) = MoveCommand;

  factory QueueCommand.fromJson(Map<String, dynamic> json) =>
      _$QueueCommandFromJson(json);
}
