import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data_model/data_model.dart';
import '../data_model/kalinka_ws_api.dart';
import '../providers/app_state_provider.dart';
import '../providers/kalinka_ws_api_provider.dart';
import '../providers/playback_time_provider.dart';
import '../providers/url_resolver.dart';
import '../theme/app_theme.dart';
import '../utils/playback_utils.dart';
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

  @override
  Widget build(BuildContext context) {
    final queueState = ref.watch(playQueueStateStoreProvider);
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final artSize = constraints.maxWidth * 0.75;

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
                    // Scrollable content
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          children: [
                            const SizedBox(height: 16),
                            // Album art
                            Container(
                              width: artSize,
                              height: artSize,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(22),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.5),
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
                                            trackId: currentTrack?.id ?? '',
                                            size: artSize,
                                          ),
                                    )
                                  : ProceduralAlbumArt(
                                      trackId: currentTrack?.id ?? '',
                                      size: artSize,
                                    ),
                            ),
                            const SizedBox(height: 28),
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
                            // Format + source badges
                            if (mimeLabel.isNotEmpty ||
                                currentTrack != null) ...[
                              const SizedBox(height: 8),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (mimeLabel.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: KalinkaColors.accent,
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        mimeLabel,
                                        style: KalinkaTextStyles.formatBadge,
                                      ),
                                    ),
                                  if (mimeLabel.isNotEmpty &&
                                      currentTrack != null)
                                    const SizedBox(width: 6),
                                  if (currentTrack != null)
                                    SourceBadge(
                                      entityId: currentTrack.id,
                                      style: SourceBadgeStyle.pill,
                                    ),
                                ],
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
                                inactiveTrackColor:
                                    KalinkaColors.borderElevated,
                                thumbColor: Colors.white,
                                overlayColor: KalinkaColors.accent.withValues(
                                  alpha: 0.25,
                                ),
                              ),
                              child: Slider(
                                value: progress,
                                onChanged: (value) {
                                  setState(() {
                                    _isSeeking = true;
                                    _seekProgress = value;
                                    _seekPositionMs = (value * durationMs)
                                        .toInt();
                                  });
                                },
                                onChangeEnd: (value) {
                                  final newPositionMs = (value * durationMs)
                                      .toInt();
                                  api.sendQueueCommand(
                                    QueueCommand.seek(
                                      positionMs: newPositionMs,
                                    ),
                                  );
                                  setState(() => _isSeeking = false);
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
                            const SizedBox(height: 28),
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
                                            KalinkaColors.borderElevated,
                                        thumbColor: KalinkaColors.textPrimary,
                                        overlayColor: KalinkaColors.textPrimary
                                            .withValues(alpha: 0.1),
                                      ),
                                      child: Slider(
                                        value: volumeState.maxVolume > 0
                                            ? (volumeState.currentVolume /
                                                      volumeState.maxVolume)
                                                  .clamp(0.0, 1.0)
                                            : 0.0,
                                        onChanged: (value) {
                                          final newVolume =
                                              (value * volumeState.maxVolume)
                                                  .round();
                                          ref
                                              .read(kalinkaWsApiProvider)
                                              .sendDeviceCommand(
                                                DeviceCommand.setVolume(
                                                  volume: newVolume,
                                                ),
                                              );
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
