// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ext_device_events.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ExtDeviceState _$ExtDeviceStateFromJson(Map<String, dynamic> json) =>
    ExtDeviceState(
      powerOn: json['power_on'] as bool,
      volume: DeviceVolume.fromJson(json['volume'] as Map<String, dynamic>),
      seq: (json['seq'] as num).toInt(),
    );

Map<String, dynamic> _$ExtDeviceStateToJson(ExtDeviceState instance) =>
    <String, dynamic>{
      'power_on': instance.powerOn,
      'volume': instance.volume.toJson(),
      'seq': instance.seq,
    };

const _$ExtDeviceEventTypeEnumMap = {
  ExtDeviceEventType.devicePowerStateChanged: 'device_power_state_changed',
  ExtDeviceEventType.volumeChanged: 'volume_changed',
};
