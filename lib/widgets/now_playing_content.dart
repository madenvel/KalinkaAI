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
  bool _isAdjustingVolume = false;
  double _localVolumeProgress = 0.0;
  int? _volumeBeforeSeq;
  ProviderSubscription? _extDeviceStateStoreProviderSubscription;

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
  void initState() {
    super.initState();
    // Clear the local volume position once the server acknowledges the change
    // with a new event (seq changes). Mirrors the seek bar pattern.
    _extDeviceStateStoreProviderSubscription = ref.listenManual(
      extDeviceStateStoreProvider,
      (prev, next) {
        if (_isAdjustingVolume && next.seq != _volumeBeforeSeq) {
          setState(() {
            _isAdjustingVolume = false;
            _volumeBeforeSeq = null;
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _extDeviceStateStoreProviderSubscription?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final queueState = ref.watch(playQueueStateStoreProvider);

    final playbackState = queueState.playbackState;
    final currentTrack = playbackState.currentTrack;
    final playerState = playbackState.state;
    final playbackMode = queueState.playbackMode;
    final volumeState = ref.watch(volumeStateProvider);
    final api = ref.read(kalinkaWsApiProvider);
    final urlResolver = ref.read(urlResolverProvider);

    final durationMs = (currentTrack?.duration ?? 0) * 1000;

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

    return Container(
      color: KalinkaColors.background,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(),
            // Content — fills remaining space with controls pinned to bottom
            _buildBodyContent(
              currentTrack: currentTrack,
              resolvedImageUrl: resolvedImageUrl,
              sourceInfo: sourceInfo,
              mimeLabel: mimeLabel,
              qualityLabel: qualityLabel,
              durationMs: durationMs,
              playerState: playerState,
              playbackMode: playbackMode,
              volumeState: volumeState,
              api: api,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBodyContent({
    required Track? currentTrack,
    required String? resolvedImageUrl,
    required SourceDisplayInfo? sourceInfo,
    required String mimeLabel,
    required String qualityLabel,
    required int durationMs,
    required PlayerStateType? playerState,
    required PlaybackMode playbackMode,
    required DeviceVolume volumeState,
    required KalinkaWsApi api,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            const SizedBox(height: 8),
            _AlbumArtSection(
              trackId: currentTrack?.id,
              resolvedImageUrl: resolvedImageUrl,
            ),
            const SizedBox(height: 20),
            _buildTrackMetadataSection(
              currentTrack: currentTrack,
              sourceInfo: sourceInfo,
              mimeLabel: mimeLabel,
              qualityLabel: qualityLabel,
            ),
            const SizedBox(height: 24),
            _NowPlayingProgressSection(
              durationMs: durationMs,
              formatTime: _formatTime,
            ),
            const SizedBox(height: 20),
            _buildTransportRow(
              api: api,
              playerState: playerState,
              playbackMode: playbackMode,
            ),
            const SizedBox(height: 16),
            if (volumeState.supported)
              _buildVolumeRow(volumeState: volumeState),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackMetadataSection({
    required Track? currentTrack,
    required SourceDisplayInfo? sourceInfo,
    required String mimeLabel,
    required String qualityLabel,
  }) {
    return Column(
      children: [
        Text(
          currentTrack?.title ?? 'No track',
          style: KalinkaTextStyles.expandedTitle,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
        Text(
          currentTrack?.performer?.name ?? '\u2014',
          style: KalinkaTextStyles.expandedArtist,
          textAlign: TextAlign.center,
        ),
        if (currentTrack?.album != null) ...[
          const SizedBox(height: 4),
          Text(
            () {
              final album = currentTrack!.album!;
              final year = album.year;
              return year != null ? '${album.title} · $year' : album.title;
            }(),
            style: KalinkaTextStyles.expandedAlbum,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        if (currentTrack != null) ...[
          const SizedBox(height: 4),
          _buildSourceAttributionRow(
            currentTrack: currentTrack,
            sourceInfo: sourceInfo,
            mimeLabel: mimeLabel,
            qualityLabel: qualityLabel,
          ),
        ],
      ],
    );
  }

  Widget _buildSourceAttributionRow({
    required Track currentTrack,
    required SourceDisplayInfo? sourceInfo,
    required String mimeLabel,
    required String qualityLabel,
  }) {
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
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SourceBadge(entityId: currentTrack.id),
        if (attributionText.isNotEmpty) ...[
          const SizedBox(width: 6),
          Text(
            attributionText,
            style: KalinkaTextStyles.expandedAttribution,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  Widget _buildTransportRow({
    required KalinkaWsApi api,
    required PlayerStateType? playerState,
    required PlaybackMode playbackMode,
  }) {
    final isShuffle = playbackMode.shuffle;
    final isRepeatAll = playbackMode.repeatAll;
    final isRepeatOne = playbackMode.repeatSingle;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
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
            color: isShuffle ? KalinkaColors.gold : KalinkaColors.textSecondary,
          ),
        ),
        GestureDetector(
          onTapDown: (_) => KalinkaHaptics.mediumImpact(),
          onTap: () => api.sendQueueCommand(const QueueCommand.prev()),
          child: const Icon(
            Icons.skip_previous_rounded,
            size: 36,
            color: KalinkaColors.textPrimary,
          ),
        ),
        GestureDetector(
          onTapDown: isPlayPauseDisabled(playerState)
              ? null
              : (_) => playerState == PlayerStateType.playing
                    ? KalinkaHaptics.lightImpact()
                    : KalinkaHaptics.mediumImpact(),
          onTap: isPlayPauseDisabled(playerState)
              ? null
              : () => sendPlayPauseCommand(ref, playerState),
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
        GestureDetector(
          onTapDown: (_) => KalinkaHaptics.mediumImpact(),
          onTap: () => api.sendQueueCommand(const QueueCommand.next()),
          child: const Icon(
            Icons.skip_next_rounded,
            size: 36,
            color: KalinkaColors.textPrimary,
          ),
        ),
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
            isRepeatOne ? Icons.repeat_one : Icons.repeat,
            size: 22,
            color: (isRepeatAll || isRepeatOne)
                ? KalinkaColors.accent
                : KalinkaColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildVolumeRow({required DeviceVolume volumeState}) {
    return Row(
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
                } else if ((value - _lastHapticVolumePosition).abs() >= 0.10) {
                  KalinkaHaptics.selectionClick();
                  _lastHapticVolumePosition = value;
                }
                final newVolume = (value * volumeState.maxVolume).round();
                setState(() {
                  _isAdjustingVolume = true;
                  _localVolumeProgress = value;
                });
                ref
                    .read(kalinkaWsApiProvider)
                    .sendDeviceCommand(
                      DeviceCommand.setVolume(volume: newVolume),
                    );
              },
              onChangeEnd: (_) {
                _lastHapticVolumePosition = -1.0;
                setState(() {
                  _volumeBeforeSeq = ref.read(extDeviceStateStoreProvider).seq;
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

class _NowPlayingProgressSection extends ConsumerStatefulWidget {
  final int durationMs;
  final String Function(int milliseconds) formatTime;

  const _NowPlayingProgressSection({
    required this.durationMs,
    required this.formatTime,
  });

  @override
  ConsumerState<_NowPlayingProgressSection> createState() =>
      _NowPlayingProgressSectionState();
}

class _NowPlayingProgressSectionState
    extends ConsumerState<_NowPlayingProgressSection> {
  bool _isSeeking = false;
  double _seekProgress = 0.0;
  int _seekPositionMs = 0;
  int? _seekBeforeSeq;
  double _lastHapticSeekPosition = -1.0;
  ProviderSubscription? _playQueueStateStoreProviderSubscription;

  @override
  void initState() {
    super.initState();
    // Clear the local seek position once the server acknowledges the seek
    // with a new event (seq changes). This prevents the thumb from jumping
    // back to the old position before the server reply arrives.
    _playQueueStateStoreProviderSubscription = ref.listenManual(
      playQueueStateStoreProvider,
      (prev, next) {
        if (_isSeeking && next.seq != _seekBeforeSeq) {
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.formatTime(positionMs),
                  style: KalinkaTextStyles.timeLabel,
                ),
                Text(
                  widget.formatTime(widget.durationMs),
                  style: KalinkaTextStyles.timeLabel,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Album art section with a LayoutBuilder for size calculation.
/// Extracted into its own widget so that LayoutBuilder._rebuildWithConstraints
/// only rebuilds this element, not the parent _NowPlayingContentState.
class _AlbumArtSection extends StatelessWidget {
  final String? trackId;
  final String? resolvedImageUrl;

  const _AlbumArtSection({
    required this.trackId,
    required this.resolvedImageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: LayoutBuilder(
        builder: (context, artConstraints) {
          final artSize = (artConstraints.maxWidth * 0.88).clamp(
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
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 40,
                    offset: const Offset(0, 20),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: resolvedImageUrl != null
                  ? Image.network(
                      resolvedImageUrl!,
                      width: artSize,
                      height: artSize,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => ProceduralAlbumArt(
                        trackId: trackId ?? '',
                        size: artSize,
                      ),
                    )
                  : ProceduralAlbumArt(trackId: trackId ?? '', size: artSize),
            ),
          );
        },
      ),
    );
  }
}
