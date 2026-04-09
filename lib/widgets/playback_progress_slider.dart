import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data_model/kalinka_ws_api.dart';
import '../providers/app_state_provider.dart';
import '../providers/kalinka_ws_api_provider.dart';
import '../providers/playback_time_provider.dart';
import '../theme/app_theme.dart';
import '../utils/haptics.dart';

/// Playback progress slider with optimistic seeking while dragging.
class PlaybackProgressSlider extends ConsumerStatefulWidget {
  final int durationMs;

  const PlaybackProgressSlider({super.key, required this.durationMs});

  @override
  ConsumerState<PlaybackProgressSlider> createState() =>
      _PlaybackProgressSliderState();
}

class _PlaybackProgressSliderState
    extends ConsumerState<PlaybackProgressSlider> {
  bool _isSeeking = false;
  double _seekProgress = 0.0;
  int _seekPositionMs = 0;
  int? _seekBeforeSeq;
  double _lastHapticSeekPosition = -1.0;
  ProviderSubscription? _playQueueStateStoreProviderSubscription;

  String _formatTime(int milliseconds) {
    final seconds = milliseconds ~/ 1000;
    final minutes = seconds ~/ 60;
    final remaining = seconds % 60;
    return '$minutes:${remaining.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    // Clear the local seek position once the server acknowledges the seek
    // with a new event (seq changes). This prevents the thumb from jumping
    // back to the old position before the server reply arrives.
    _playQueueStateStoreProviderSubscription = ref.listenManual<int>(
      playQueueStateStoreProvider.select((s) => s.seq),
      (prev, next) {
        if (_isSeeking && next != _seekBeforeSeq) {
          setState(() {
            _isSeeking = false;
            _seekBeforeSeq = null;
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _playQueueStateStoreProviderSubscription?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playbackTimeMs = ref.watch(playbackTimeMsProvider);
    final positionMs = _isSeeking ? _seekPositionMs : playbackTimeMs;
    final progress = _isSeeking
        ? _seekProgress
        : (widget.durationMs > 0
              ? (positionMs / widget.durationMs).clamp(0.0, 1.0)
              : 0.0);

    return RepaintBoundary(
      child: Column(
        children: [
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              activeTrackColor: KalinkaColors.accent,
              inactiveTrackColor: KalinkaColors.borderDefault,
              thumbColor: Colors.white,
              overlayColor: KalinkaColors.accent.withValues(alpha: 0.25),
            ),
            child: Slider(
              value: progress,
              onChanged: (value) {
                if (!_isSeeking) {
                  KalinkaHaptics.mediumImpact();
                  _lastHapticSeekPosition = value;
                } else if ((value - _lastHapticSeekPosition).abs() >= 0.05) {
                  KalinkaHaptics.selectionClick();
                  _lastHapticSeekPosition = value;
                }
                setState(() {
                  _isSeeking = true;
                  _seekProgress = value;
                  _seekPositionMs = (value * widget.durationMs).toInt();
                });
              },
              onChangeEnd: (value) {
                KalinkaHaptics.lightImpact();
                final newPositionMs = (value * widget.durationMs).toInt();
                setState(() {
                  _seekBeforeSeq = ref.read(playQueueStateStoreProvider).seq;
                });
                ref
                    .read(kalinkaWsApiProvider)
                    .sendQueueCommand(
                      QueueCommand.seek(positionMs: newPositionMs),
                    );
              },
            ),
          ),
          // SizedBox gives tight constraints (tight width from Column + fixed
          // height here), making the Row a Flutter relayout boundary. This
          // prevents RenderParagraph.markNeedsLayout() from propagating up
          // through the RepaintBoundary and causing a full-screen relayout on
          // every playback-time tick.
          SizedBox(
            width: double
                .infinity, // combined with height → tight on both axes → relayout boundary
            height: 20,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatTime(positionMs),
                    style: KalinkaTextStyles.timeLabel,
                  ),
                  Text(
                    _formatTime(widget.durationMs),
                    style: KalinkaTextStyles.timeLabel,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
