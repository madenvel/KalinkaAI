import 'package:flutter/material.dart' show IconData, Icons;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data_model/data_model.dart';
import '../data_model/kalinka_ws_api.dart';
import '../providers/kalinka_ws_api_provider.dart';

/// Sends the appropriate play/pause command based on the current player state.
void sendPlayPauseCommand(WidgetRef ref, PlayerStateType? playerState) {
  final api = ref.read(kalinkaWsApiProvider);
  if (playerState == PlayerStateType.buffering) return;

  if (playerState == PlayerStateType.stopped) {
    api.sendQueueCommand(const QueueCommand.play());
  } else if (playerState == PlayerStateType.paused) {
    api.sendQueueCommand(const QueueCommand.pause(paused: false));
  } else if (playerState == PlayerStateType.playing) {
    api.sendQueueCommand(const QueueCommand.pause(paused: true));
  }
}

/// Returns the appropriate icon for the current player state.
IconData playPauseIcon(PlayerStateType? playerState, {double? size}) {
  if (playerState == PlayerStateType.playing) {
    return Icons.pause;
  } else if (playerState == PlayerStateType.buffering) {
    return Icons.hourglass_bottom;
  }
  return Icons.play_arrow;
}

/// Returns the appropriate filled icon for the current player state.
IconData playPauseFilledIcon(PlayerStateType? playerState) {
  if (playerState == PlayerStateType.playing) {
    return Icons.pause_circle_filled;
  } else if (playerState == PlayerStateType.buffering) {
    return Icons.hourglass_bottom;
  }
  return Icons.play_circle_filled;
}

/// Whether the play/pause button should be disabled (during buffering).
bool isPlayPauseDisabled(PlayerStateType? playerState) {
  return playerState == PlayerStateType.buffering;
}
