import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data_model/data_model.dart';
import '../data_model/kalinka_ws_api.dart';
import '../providers/app_state_provider.dart';
import '../providers/connection_state_provider.dart';
import '../providers/kalinka_ws_api_provider.dart';
import '../providers/playback_time_provider.dart';
import '../providers/url_resolver.dart';

class MediaNotificationNotifier extends Notifier<void> {
  static const _methodChannel = MethodChannel('org.kalinka.kai/media_session');
  static const _eventChannel = EventChannel('org.kalinka.kai/media_events');

  // --- Optimistic seek state (mirrors NowPlayingContent pattern) ---
  // Holds the seek target position until server acknowledges with a new seq.
  int? _pendingSeekMs;
  int? _seekBeforeSeq;

  // --- Volume change mode ---
  // Activated on hardware key press; suppresses server echoes for 1.5 s after
  // the last press so rapid presses accumulate without stale echoes interfering.
  // Cleared automatically when the mode timer fires.
  bool _volumeChangeModeActive = false;
  Timer? _volumeChangeModeTimer;
  int? _optimisticVolume; // last intended value; cleared when mode deactivates

  @override
  void build() {
    if (!Platform.isAndroid) return;

    ref.onDispose(() {
      _volumeChangeModeTimer?.cancel();
    });

    // Listen for actions from native (play, pause, next, prev, stop, seek,
    // volumeAdjust).
    final subscription = _eventChannel.receiveBroadcastStream().listen(
      _handleNativeEvent,
      onError: (_) {},
    );
    ref.onDispose(subscription.cancel);

    // Push state whenever player state changes (play, pause, buffering, etc.).
    ref.listen(playerStateProvider, (_, __) => _pushState());

    // When the server sends a new event (seq changes), clear the pending seek
    // so we stop showing the optimistic position and trust the server.
    ref.listen(playQueueStateStoreProvider, (prev, next) {
      if (_pendingSeekMs != null && next.seq != _seekBeforeSeq) {
        _pendingSeekMs = null;
        _seekBeforeSeq = null;
      }
      _pushState();
    });

    // Push volume-only update when server confirms a new volume.
    ref.listen(volumeStateProvider, (_, vol) => _onServerVolumeUpdate(vol));

    // Hide notification when disconnected.
    ref.listen(connectionStateProvider, (_, status) {
      if (status != ConnectionStatus.connected) {
        _stopService();
      }
    });
  }

  void _handleNativeEvent(dynamic event) {
    final map = event as Map;
    final wsApi = ref.read(kalinkaWsApiProvider);
    switch (map['type']) {
      case 'play':
        wsApi.sendQueueCommand(const QueueCommand.play());
      case 'pause':
        wsApi.sendQueueCommand(const QueueCommand.pause());
      case 'next':
        wsApi.sendQueueCommand(const QueueCommand.next());
      case 'prev':
        wsApi.sendQueueCommand(const QueueCommand.prev());
      case 'stop':
        wsApi.sendQueueCommand(const QueueCommand.stop());
      case 'seek':
        final posMs = map['positionMs'];
        if (posMs != null) {
          final targetMs = (posMs as num).toInt();
          // Optimistically hold the target position until server acknowledges.
          _pendingSeekMs = targetMs;
          _seekBeforeSeq = ref.read(playQueueStateStoreProvider).seq;
          // Immediately update PlaybackStateCompat with the new position so
          // the lock screen slider shows the target without waiting for the
          // next timer tick or server round-trip.
          _pushState();
          wsApi.sendQueueCommand(QueueCommand.seek(positionMs: targetMs));
        }
      case 'volumeSet':
        final rawVol = map['volume'];
        if (rawVol != null) {
          final vol = ref.read(volumeStateProvider);
          if (vol.supported) {
            _applyVolumeChange((rawVol as num).toInt(), vol);
          }
        }
    }
  }

  void _applyVolumeChange(int newVol, DeviceVolume vol) {
    _optimisticVolume = newVol;
    // Enter / extend volume change mode: server echoes suppressed until
    // 1.5 s after the last key press.
    _volumeChangeModeActive = true;
    _volumeChangeModeTimer?.cancel();
    _volumeChangeModeTimer = Timer(const Duration(milliseconds: 1500), () {
      _volumeChangeModeActive = false;
      _volumeChangeModeTimer = null;
      _optimisticVolume = null;
    });
    // Immediately update native so the system volume indicator shows the
    // intended value rather than waiting for server round-trip.
    _methodChannel.invokeMethod<void>('updateVolumeOnly', {
      'currentVolume': newVol,
      'maxVolume': vol.maxVolume > 0 ? vol.maxVolume : 100,
    });
    ref
        .read(kalinkaWsApiProvider)
        .sendDeviceCommand(DeviceCommand.setVolume(volume: newVol));
  }

  // Called when server emits a volumeChanged event.
  void _onServerVolumeUpdate(DeviceVolume vol) {
    if (!Platform.isAndroid) return;
    // While user is actively pressing volume keys, suppress server echoes
    // to prevent stale updates from clobbering the optimistic position.
    if (_volumeChangeModeActive) return;
    _methodChannel.invokeMethod<void>('updateVolumeOnly', {
      'currentVolume': vol.currentVolume,
      'maxVolume': vol.maxVolume > 0 ? vol.maxVolume : 100,
    });
  }

  void _pushState() {
    final queueState = ref.read(playQueueStateStoreProvider);
    final playbackState = queueState.playbackState;
    final playerStateType = playbackState.state;

    // Hide when stopped or no state.
    if (playerStateType == null ||
        playerStateType == PlayerStateType.stopped ||
        playerStateType == PlayerStateType.error) {
      _stopService();
      return;
    }

    final track = playbackState.currentTrack;
    // Use pending seek position until server acknowledges (prevents jump-back).
    final positionMs = _pendingSeekMs ?? ref.read(playbackTimeMsProvider);
    final vol = ref.read(volumeStateProvider);
    // Use optimistic volume while in change mode (prevents jump-back).
    final volumeToShow = _optimisticVolume ?? vol.currentVolume;
    final urlResolver = ref.read(urlResolverProvider);

    final imageUrl = track?.album?.image?.small;
    final resolvedImageUrl = imageUrl != null
        ? urlResolver.abs(imageUrl)
        : null;

    final durationMs = track != null ? (track.duration * 1000) : 0;

    _methodChannel.invokeMethod<void>('updatePlaybackInfo', {
      'title': track?.title ?? '',
      'artist': track?.performer?.name ?? track?.album?.title ?? '',
      'albumArtUrl': resolvedImageUrl,
      'durationMs': durationMs,
      'positionMs': positionMs,
      'isPlaying':
          playerStateType == PlayerStateType.playing ||
          playerStateType == PlayerStateType.buffering,
      'currentVolume': volumeToShow,
      'maxVolume': vol.maxVolume > 0 ? vol.maxVolume : 100,
    });
  }

  void _stopService() {
    _methodChannel.invokeMethod<void>('stopService').ignore();
  }
}

final mediaNotificationProvider =
    NotifierProvider<MediaNotificationNotifier, void>(
      MediaNotificationNotifier.new,
    );
