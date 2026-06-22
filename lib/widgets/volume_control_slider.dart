import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data_model/data_model.dart' show DeviceVolume;
import '../data_model/kalinka_ws_api.dart';
import '../providers/app_state_provider.dart';
import '../providers/kalinka_ws_api_provider.dart';
import '../theme/app_theme.dart';
import '../utils/haptics.dart';

class NowPlayingVolumeControl extends ConsumerStatefulWidget {
  const NowPlayingVolumeControl({super.key});

  @override
  ConsumerState<NowPlayingVolumeControl> createState() =>
      _NowPlayingVolumeControlState();
}

class _NowPlayingVolumeControlState
    extends ConsumerState<NowPlayingVolumeControl> {
  bool _isAdjustingVolume = false;
  double _localVolumeProgress = 0.0;
  int? _volumeBeforeSeq;
  double _lastHapticVolumePosition = -1.0;
  Timer? _volumeDebounceTimer;
  int? _pendingVolume;

  // Mirrored provider state. Populated via post-frame subscriptions rather than
  // read in build: this widget mounts inside a parent's build, where reading the
  // device-state graph cold-flushes it and schedules a provider refresh mid-build
  // (setState-during-build crash). A post-frame flush runs between frames safely.
  DeviceVolume _volumeState = DeviceVolume.empty;
  ProviderSubscription? _volumeSub;
  ProviderSubscription? _seqSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _volumeSub = ref.listenManual(
        volumeStateProvider,
        (prev, next) => setState(() => _volumeState = next),
        fireImmediately: true,
      );
      _seqSub = ref.listenManual<int>(
        extDeviceStateStoreProvider.select((s) => s.seq),
        (prev, next) {
          if (_isAdjustingVolume &&
              _volumeBeforeSeq != null &&
              next != _volumeBeforeSeq) {
            setState(() {
              _isAdjustingVolume = false;
              _volumeBeforeSeq = null;
            });
          }
        },
      );
    });
  }

  @override
  void dispose() {
    _volumeDebounceTimer?.cancel();
    _volumeSub?.close();
    _seqSub?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final volumeState = _volumeState;
    if (!volumeState.supported) return const SizedBox.shrink();

    return RepaintBoundary(
      child: Row(
        children: [
          const Icon(
            Icons.volume_down,
            size: 20,
            color: KalinkaColors.textSecondary,
          ),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                activeTrackColor: KalinkaColors.textPrimary,
                inactiveTrackColor: KalinkaColors.borderDefault,
                thumbColor: KalinkaColors.textPrimary,
                overlayColor: KalinkaColors.textPrimary.withValues(alpha: 0.1),
              ),
              child: Slider(
                value: _isAdjustingVolume
                    ? _localVolumeProgress
                    : (volumeState.maxVolume > 0
                          ? (volumeState.currentVolume / volumeState.maxVolume)
                                .clamp(0.0, 1.0)
                          : 0.0),
                onChanged: (value) {
                  if (!_isAdjustingVolume) {
                    KalinkaHaptics.lightImpact();
                    _lastHapticVolumePosition = value;
                  } else if ((value - _lastHapticVolumePosition).abs() >=
                      0.10) {
                    KalinkaHaptics.selectionClick();
                    _lastHapticVolumePosition = value;
                  }

                  final newVolume = (value * volumeState.maxVolume).round();
                  setState(() {
                    _isAdjustingVolume = true;
                    _localVolumeProgress = value;
                  });

                  _pendingVolume = newVolume;
                  _volumeDebounceTimer?.cancel();
                  _volumeDebounceTimer = Timer(
                    const Duration(milliseconds: 50),
                    () {
                      final vol = _pendingVolume;
                      if (vol != null) {
                        _pendingVolume = null;
                        ref
                            .read(kalinkaWsApiProvider)
                            .sendDeviceCommand(
                              DeviceCommand.setVolume(volume: vol),
                            );
                      }
                    },
                  );
                },
                onChangeEnd: (value) {
                  _volumeDebounceTimer?.cancel();
                  _volumeDebounceTimer = null;
                  final vol =
                      _pendingVolume ??
                      (value * volumeState.maxVolume).round();
                  _pendingVolume = null;
                  ref
                      .read(kalinkaWsApiProvider)
                      .sendDeviceCommand(
                        DeviceCommand.setVolume(volume: vol),
                      );
                  _lastHapticVolumePosition = -1.0;
                  setState(() {
                    _volumeBeforeSeq = ref
                        .read(extDeviceStateStoreProvider)
                        .seq;
                  });
                },
              ),
            ),
          ),
          const Icon(
            Icons.volume_up,
            size: 20,
            color: KalinkaColors.textSecondary,
          ),
        ],
      ),
    );
  }
}
