import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data_model/data_model.dart';
import '../data_model/kalinka_ws_api.dart';
import '../providers/app_state_provider.dart';
import '../providers/kalinka_ws_api_provider.dart';
import '../providers/playback_time_provider.dart';
import '../providers/url_resolver.dart';
import '../theme/app_theme.dart';
import '../utils/haptics.dart';
import '../utils/playback_utils.dart';
import '../providers/source_modules_provider.dart';
import 'procedural_album_art.dart';
import 'server_chip.dart';
import 'source_badge.dart';

/// Core now-playing UI: album art, track info, transport controls, volume.
/// Used embedded in tablet layout and wrapped with animation in phone overlay.
class NowPlayingContent extends ConsumerStatefulWidget {
  /// When true, renders tablet-specific embedded header layout.
  final bool isTablet;

  /// Optional tap handler for the server chip in tablet header mode.
  final VoidCallback? onServerChipTap;

  /// When true, shows drag handle and close button (phone overlay mode).
  final bool showOverlayHeader;

  /// Close callback, used when [showOverlayHeader] is true.
  final VoidCallback? onClose;

  const NowPlayingContent({
    super.key,
    this.isTablet = false,
    this.onServerChipTap,
    this.showOverlayHeader = false,
    this.onClose,
  });

  @override
  ConsumerState<NowPlayingContent> createState() => _NowPlayingContentState();
}

class _NowPlayingContentState extends ConsumerState<NowPlayingContent> {
  bool _isSeeking = false;
  double _seekProgress = 0.0;
  int _seekPositionMs = 0;
  int? _seekBeforeSeq;

  bool _isAdjustingVolume = false;
  double _localVolumeProgress = 0.0;
  int? _volumeBeforeSeq;

  double _lastHapticSeekPosition = -1.0;
  double _lastHapticVolumePosition = -1.0;

  String _formatTime(int milliseconds) {
    final seconds = milliseconds ~/ 1000;
    final minutes = seconds ~/ 60;
    final remaining = seconds % 60;
    return '$minutes:${remaining.toString().padLeft(2, '0')}';
  }

  String _formatLabel(String? mimeType) {
    if (mimeType == null) return '';
    if (mimeType.contains('flac')) return 'FLAC';
    if (mimeType.contains('wav')) return 'WAV';
    if (mimeType.contains('mp3') || mimeType.contains('mpeg')) return 'MP3';
    if (mimeType.contains('aac')) return 'AAC';
    if (mimeType.contains('ogg')) return 'OGG';
    if (mimeType.contains('opus')) return 'OPUS';
    return mimeType.split('/').last.toUpperCase();
  }

  String _formatAudioQuality(AudioInfo? audioInfo) {
    if (audioInfo == null) return '';

    final bitsPerSample = audioInfo.bitsPerSample;
    final sampleRate = audioInfo.sampleRate;

    final parts = <String>[];
    if (bitsPerSample > 0) {
      parts.add('$bitsPerSample-bit');
    }
    if (sampleRate > 0) {
      final khz = sampleRate / 1000;
      final khzLabel = sampleRate % 1000 == 0
          ? khz.toStringAsFixed(0)
          : khz.toStringAsFixed(1);
      parts.add('$khzLabel kHz');
    }

    return parts.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    final queueState = ref.watch(playQueueStateStoreProvider);

    // Clear the local seek position once the server acknowledges the seek
    // with a new event (seq changes). This prevents the thumb from jumping
    // back to the old position before the server reply arrives.
    ref.listen(playQueueStateStoreProvider, (prev, next) {
      if (_isSeeking && next.seq != _seekBeforeSeq) {
        setState(() {
          _isSeeking = false;
          _seekBeforeSeq = null;
        });
      }
    });

    // Clear the local volume position once the server acknowledges the change
    // with a new event (seq changes). Mirrors the seek bar pattern.
    ref.listen(extDeviceStateStoreProvider, (prev, next) {
      if (_isAdjustingVolume && next.seq != _volumeBeforeSeq) {
        setState(() {
          _isAdjustingVolume = false;
          _volumeBeforeSeq = null;
        });
      }
    });

    final playbackState = queueState.playbackState;
    final currentTrack = playbackState.currentTrack;
    final playerState = playbackState.state;
    final playbackMode = queueState.playbackMode;
    final playbackTimeMs = ref.watch(playbackTimeMsProvider);
    final volumeState = ref.watch(volumeStateProvider);
    final api = ref.read(kalinkaWsApiProvider);
    final urlResolver = ref.read(urlResolverProvider);

    final durationMs = (currentTrack?.duration ?? 0) * 1000;
    final positionMs = _isSeeking ? _seekPositionMs : playbackTimeMs;
    final progress = _isSeeking
        ? _seekProgress
        : (durationMs > 0 ? (positionMs / durationMs).clamp(0.0, 1.0) : 0.0);

    final isShuffle = playbackMode.shuffle;
    final isRepeatAll = playbackMode.repeatAll;
    final isRepeatOne = playbackMode.repeatSingle;

    final imageUrl = currentTrack?.album?.image?.large;
    final resolvedImageUrl = imageUrl != null
        ? urlResolver.abs(imageUrl)
        : null;

    final mimeLabel = _formatLabel(playbackState.mimeType);
    final qualityLabel = _formatAudioQuality(playbackState.audioInfo);

    // Source display info for the attribution line.
    final sourceMap = ref.watch(sourceDisplayInfoProvider);
    final String? currentSource = (() {
      if (currentTrack == null) return null;
      try {
        return EntityId.fromString(currentTrack.id).source;
      } catch (_) {
        return null;
      }
    })();
    final sourceInfo = currentSource != null ? sourceMap[currentSource] : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          color: KalinkaColors.background,
          child: Stack(
            children: [
              // Radial accent glow at top
              Positioned(
                top: -100,
                left: 0,
                right: 0,
                height: 400,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.topCenter,
                      radius: 1.2,
                      colors: [
                        KalinkaColors.accent.withValues(alpha: 0.15),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              // Main content
              SafeArea(
                child: Column(
                  children: [
                    // Header
                    _buildHeader(),
                    // Content — fills remaining space with controls pinned to bottom
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: [
                            const SizedBox(height: 8),
                            // Album art — Expanded so it claims all vertical space
                            // that isn't occupied by fixed-height elements below.
                            // Inner LayoutBuilder sizes the square to fit the zone.
                            Expanded(
                              child: LayoutBuilder(
                                builder: (context, artConstraints) {
                                  final artSize =
                                      (artConstraints.maxWidth * 0.88).clamp(
                                        0.0,
                                        artConstraints.maxHeight,
                                      );
                                  return Center(
                                    child: Container(
                                      width: artSize,
                                      height: artSize,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(22),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.5,
                                            ),
                                            blurRadius: 40,
                                            offset: const Offset(0, 20),
                                          ),
                                        ],
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      child: resolvedImageUrl != null
                                          ? Image.network(
                                              resolvedImageUrl,
                                              width: artSize,
                                              height: artSize,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) =>
                                                  ProceduralAlbumArt(
                                                    trackId:
                                                        currentTrack?.id ?? '',
                                                    size: artSize,
                                                  ),
                                            )
                                          : ProceduralAlbumArt(
                                              trackId: currentTrack?.id ?? '',
                                              size: artSize,
                                            ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 20),
                            // Track title
                            Text(
                              currentTrack?.title ?? 'No track',
                              style: KalinkaTextStyles.expandedTitle,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            // Artist
                            Text(
                              currentTrack?.performer?.name ?? '\u2014',
                              style: KalinkaTextStyles.expandedArtist,
                              textAlign: TextAlign.center,
                            ),
                            // Source attribution line: [Q] Qobuz · FLAC 24-bit • 96 kHz
                            if (currentTrack != null) ...[
                              const SizedBox(height: 4),
                              Builder(
                                builder: (context) {
                                  final List<String> parts = [];
                                  if (sourceInfo != null) {
                                    parts.add(sourceInfo.title);
                                  }
                                  final List<String> fmtParts = [
                                    if (mimeLabel.isNotEmpty) mimeLabel,
                                    if (qualityLabel.isNotEmpty) qualityLabel,
                                  ];
                                  if (fmtParts.isNotEmpty) {
                                    parts.add(fmtParts.join(' '));
                                  }
                                  final attributionText = parts.join(' · ');
                                  return Row(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      SourceBadge(entityId: currentTrack.id),
                                      if (attributionText.isNotEmpty) ...[
                                        const SizedBox(width: 6),
                                        Text(
                                          attributionText,
                                          style: KalinkaTextStyles
                                              .expandedAttribution,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ],
                                  );
                                },
                              ),
                            ],
                            const SizedBox(height: 24),
                            // Progress bar
                            SliderTheme(
                              data: SliderThemeData(
                                trackHeight: 3,
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 6,
                                ),
                                overlayShape: const RoundSliderOverlayShape(
                                  overlayRadius: 14,
                                ),
                                activeTrackColor: KalinkaColors.accent,
                                inactiveTrackColor: KalinkaColors.borderDefault,
                                thumbColor: Colors.white,
                                overlayColor: KalinkaColors.accent.withValues(
                                  alpha: 0.25,
                                ),
                              ),
                              child: Slider(
                                value: progress,
                                onChanged: (value) {
                                  if (!_isSeeking) {
                                    KalinkaHaptics.mediumImpact();
                                    _lastHapticSeekPosition = value;
                                  } else if ((value - _lastHapticSeekPosition)
                                          .abs() >=
                                      0.05) {
                                    KalinkaHaptics.selectionClick();
                                    _lastHapticSeekPosition = value;
                                  }
                                  setState(() {
                                    _isSeeking = true;
                                    _seekProgress = value;
                                    _seekPositionMs = (value * durationMs)
                                        .toInt();
                                  });
                                },
                                onChangeEnd: (value) {
                                  KalinkaHaptics.lightImpact();
                                  final newPositionMs = (value * durationMs)
                                      .toInt();
                                  setState(() {
                                    _seekBeforeSeq = queueState.seq;
                                  });
                                  api.sendQueueCommand(
                                    QueueCommand.seek(
                                      positionMs: newPositionMs,
                                    ),
                                  );
                                },
                              ),
                            ),
                            // Time labels
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _formatTime(positionMs),
                                    style: KalinkaTextStyles.timeLabel,
                                  ),
                                  Text(
                                    _formatTime(durationMs),
                                    style: KalinkaTextStyles.timeLabel,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            // Transport row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                // Shuffle
                                GestureDetector(
                                  onTapDown: (_) => isShuffle
                                      ? KalinkaHaptics.lightImpact()
                                      : KalinkaHaptics.mediumImpact(),
                                  onTap: () {
                                    api.sendQueueCommand(
                                      QueueCommand.setPlaybackMode(
                                        shuffle: !isShuffle,
                                        repeatAll: playbackMode.repeatAll,
                                        repeatSingle: playbackMode.repeatSingle,
                                      ),
                                    );
                                  },
                                  child: Icon(
                                    Icons.shuffle,
                                    size: 22,
                                    color: isShuffle
                                        ? KalinkaColors.gold
                                        : KalinkaColors.textSecondary,
                                  ),
                                ),
                                // Previous
                                GestureDetector(
                                  onTapDown: (_) =>
                                      KalinkaHaptics.mediumImpact(),
                                  onTap: () => api.sendQueueCommand(
                                    const QueueCommand.prev(),
                                  ),
                                  child: const Icon(
                                    Icons.skip_previous_rounded,
                                    size: 36,
                                    color: KalinkaColors.textPrimary,
                                  ),
                                ),
                                // Play/pause
                                GestureDetector(
                                  onTapDown: isPlayPauseDisabled(playerState)
                                      ? null
                                      : (_) =>
                                            playerState ==
                                                PlayerStateType.playing
                                            ? KalinkaHaptics.lightImpact()
                                            : KalinkaHaptics.mediumImpact(),
                                  onTap: isPlayPauseDisabled(playerState)
                                      ? null
                                      : () => sendPlayPauseCommand(
                                          ref,
                                          playerState,
                                        ),
                                  child: Container(
                                    width: 68,
                                    height: 68,
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      playerState == PlayerStateType.playing
                                          ? Icons.pause_rounded
                                          : Icons.play_arrow_rounded,
                                      size: 38,
                                      color: KalinkaColors.background,
                                    ),
                                  ),
                                ),
                                // Next
                                GestureDetector(
                                  onTapDown: (_) =>
                                      KalinkaHaptics.mediumImpact(),
                                  onTap: () => api.sendQueueCommand(
                                    const QueueCommand.next(),
                                  ),
                                  child: const Icon(
                                    Icons.skip_next_rounded,
                                    size: 36,
                                    color: KalinkaColors.textPrimary,
                                  ),
                                ),
                                // Repeat
                                GestureDetector(
                                  onTap: () {
                                    KalinkaHaptics.selectionClick();
                                    final bool newRepeatAll;
                                    final bool newRepeatSingle;
                                    if (isRepeatOne) {
                                      newRepeatAll = false;
                                      newRepeatSingle = false;
                                    } else if (isRepeatAll) {
                                      newRepeatAll = false;
                                      newRepeatSingle = true;
                                    } else {
                                      newRepeatAll = true;
                                      newRepeatSingle = false;
                                    }
                                    api.sendQueueCommand(
                                      QueueCommand.setPlaybackMode(
                                        shuffle: playbackMode.shuffle,
                                        repeatAll: newRepeatAll,
                                        repeatSingle: newRepeatSingle,
                                      ),
                                    );
                                  },
                                  child: Icon(
                                    isRepeatOne
                                        ? Icons.repeat_one
                                        : Icons.repeat,
                                    size: 22,
                                    color: (isRepeatAll || isRepeatOne)
                                        ? KalinkaColors.accent
                                        : KalinkaColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Volume row
                            if (volumeState.supported) ...[
                              Row(
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
                                        thumbShape: const RoundSliderThumbShape(
                                          enabledThumbRadius: 5,
                                        ),
                                        overlayShape:
                                            const RoundSliderOverlayShape(
                                              overlayRadius: 12,
                                            ),
                                        activeTrackColor:
                                            KalinkaColors.textPrimary,
                                        inactiveTrackColor:
                                            KalinkaColors.borderDefault,
                                        thumbColor: KalinkaColors.textPrimary,
                                        overlayColor: KalinkaColors.textPrimary
                                            .withValues(alpha: 0.1),
                                      ),
                                      child: Slider(
                                        value: _isAdjustingVolume
                                            ? _localVolumeProgress
                                            : (volumeState.maxVolume > 0
                                                  ? (volumeState.currentVolume /
                                                            volumeState
                                                                .maxVolume)
                                                        .clamp(0.0, 1.0)
                                                  : 0.0),
                                        onChanged: (value) {
                                          if (!_isAdjustingVolume) {
                                            KalinkaHaptics.lightImpact();
                                            _lastHapticVolumePosition = value;
                                          } else if ((value -
                                                      _lastHapticVolumePosition)
                                                  .abs() >=
                                              0.10) {
                                            KalinkaHaptics.selectionClick();
                                            _lastHapticVolumePosition = value;
                                          }
                                          final newVolume =
                                              (value * volumeState.maxVolume)
                                                  .round();
                                          setState(() {
                                            _isAdjustingVolume = true;
                                            _localVolumeProgress = value;
                                          });
                                          ref
                                              .read(kalinkaWsApiProvider)
                                              .sendDeviceCommand(
                                                DeviceCommand.setVolume(
                                                  volume: newVolume,
                                                ),
                                              );
                                        },
                                        onChangeEnd: (_) {
                                          _lastHapticVolumePosition = -1.0;
                                          setState(() {
                                            _volumeBeforeSeq = ref
                                                .read(
                                                  extDeviceStateStoreProvider,
                                                )
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
                            ],
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    if (widget.showOverlayHeader) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            // Drag handle pill
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // NOW PLAYING + close button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 36),
                Text('NOW PLAYING', style: KalinkaTextStyles.nowPlayingLabel),
                GestureDetector(
                  onTap: widget.onClose,
                  child: const Icon(
                    Icons.keyboard_arrow_down,
                    size: 28,
                    color: KalinkaColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    if (widget.isTablet) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('NOW PLAYING', style: KalinkaTextStyles.nowPlayingLabel),
            ServerChip(onTap: widget.onServerChipTap),
          ],
        ),
      );
    }

    // Embedded mode: just the label
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Center(
        child: Text('NOW PLAYING', style: KalinkaTextStyles.nowPlayingLabel),
      ),
    );
  }
}
