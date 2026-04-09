import 'package:freezed_annotation/freezed_annotation.dart';
import '../data_model/data_model.dart';

part 'ext_device_events.freezed.dart';
part 'ext_device_events.g.dart';

// To regenerate code, run:
// dart run build_runner build --delete-conflicting-outputs

/// External device event types matching backend values.
@JsonEnum(fieldRename: FieldRename.snake, alwaysCreate: true)
enum ExtDeviceEventType {
  devicePowerStateChanged,
  volumeChanged;

  String toJson() => _$ExtDeviceEventTypeEnumMap[this]!;

  factory ExtDeviceEventType.fromJson(String json) =>
      _$ExtDeviceEventTypeEnumMap.map(
        (key, value) => MapEntry(value, key),
      )[json]!;
}

/// Immutable state for an external device.
@JsonSerializable()
class ExtDeviceState {
  final bool powerOn;
  final DeviceVolume volume;
  final int seq;

  const ExtDeviceState({
    required this.powerOn,
    required this.volume,
    required this.seq,
  });

  static final ExtDeviceState empty = ExtDeviceState(
    powerOn: false,
    volume: DeviceVolume.empty,
    seq: 0,
  );

  ExtDeviceState copyWith({
    bool? powerOn,
    DeviceVolume? volume,
    required int seq,
  }) =>
      ExtDeviceState(
        powerOn: powerOn ?? this.powerOn,
        volume: volume ?? this.volume,
        seq: seq,
      );

  /// Apply an event to produce a new state (immutable pattern).
  ExtDeviceState apply(ExtDeviceEvent event) {
    switch (event) {
      case DevicePowerStateChangedEvent(:final powerOn):
        return copyWith(powerOn: powerOn, seq: event.seq);
      case VolumeChangedEvent(:final volume):
        return copyWith(volume: volume, seq: event.seq);
      case ExtDeviceReplayEvent(:final state):
        return state;
    }
  }

  factory ExtDeviceState.fromJson(Map<String, dynamic> json) =>
      _$ExtDeviceStateFromJson(json);

  Map<String, dynamic> toJson() => _$ExtDeviceStateToJson(this);
}

/// Base class for external device events with event_type and seq.
@freezed
sealed class ExtDeviceEvent with _$ExtDeviceEvent {
  const factory ExtDeviceEvent.devicePowerStateChanged({
    required bool powerOn,
    required int seq,
  }) = DevicePowerStateChangedEvent;

  const factory ExtDeviceEvent.volumeChanged({
    required DeviceVolume volume,
    required int seq,
  }) = VolumeChangedEvent;

  /// Synthetic replay event delivering a snapshot of state.
  const factory ExtDeviceEvent.replayEvent({
    required ExtDeviceState state,
    required int serverTimeNs,
    required int seq,
  }) = ExtDeviceReplayEvent;

  factory ExtDeviceEvent.fromJson(Map<String, dynamic> json) {
    final eventTypeStr = json['event_type'] as String;
    final seq = json['seq'] as int? ?? 0;

    switch (eventTypeStr) {
      case 'device_power_state_changed':
        return ExtDeviceEvent.devicePowerStateChanged(
          powerOn: json['power_on'] as bool,
          seq: seq,
        );
      case 'volume_changed':
        return ExtDeviceEvent.volumeChanged(
          volume: DeviceVolume.fromJson(json['volume'] as Map<String, dynamic>),
          seq: seq,
        );
      case 'replay_event':
        if (json['state_type'] == 'ExtDeviceState') {
          return ExtDeviceEvent.replayEvent(
            state: ExtDeviceState.fromJson(
              json['state'] as Map<String, dynamic>,
            ),
            serverTimeNs: json['server_time_ns'] as int,
            seq: seq,
          );
        } else {
          throw ArgumentError(
            'Unknown state_type for ExtDeviceReplayEvent: ${json['state_type']}',
          );
        }

      default:
        throw ArgumentError('Unknown event_type: $eventTypeStr');
    }
  }
}
