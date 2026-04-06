import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data_model/data_model.dart';
import '../data_model/kalinka_ws_api.dart';
import '../providers/app_state_provider.dart';
import '../providers/kalinka_ws_api_provider.dart';
import '../providers/url_resolver.dart';
import '../theme/app_theme.dart';
import '../utils/haptics.dart';
import '../utils/playback_utils.dart';
import '../providers/source_modules_provider.dart';
import 'playback_progress_slider.dart';
import 'procedural_album_art.dart';
import 'server_chip.dart';
import 'source_badge.dart';
import 'volume_control_slider.dart';

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
    // Use only primitive-typed selectors so Riverpod's == comparison works by
    // value. Object-typed selectors (Track, AudioInfo) fail because play/pause
    // events may produce new instances with identical content but different
    // references, causing false-positive rebuilds of the whole screen.
    // Play/pause/buffering is handled exclusively by _TransportControls.
    ref.watch(
      playerStateProvider.select(
        (s) => (
          trackId: s.currentTrack?.id,
          mimeType: s.mimeType,
          bitsPerSample: s.audioInfo?.bitsPerSample,
          sampleRate: s.audioInfo?.sampleRate,
        ),
      ),
    );
    // Read full state without watching — content is current because the
    // selector above already gated the rebuild on a meaningful change.
    final playbackState = ref.read(playerStateProvider);
    final currentTrack = playbackState.currentTrack;
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
            PlaybackProgressSlider(durationMs: durationMs),
            const SizedBox(height: 20),
            const _TransportControls(),
            const SizedBox(height: 16),
            const NowPlayingVolumeControl(),
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

/// Transport controls row (shuffle, prev, play/pause, next, repeat).
/// Extracted so only this widget rebuilds on playerState / playbackMode changes,
/// leaving the rest of NowPlayingContent (album art, metadata) untouched.
class _TransportControls extends ConsumerWidget {
  const _TransportControls();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerStateProvider.select((s) => s.state));
    final playbackMode = ref.watch(playbackModeProvider);
    final api = ref.read(kalinkaWsApiProvider);

    final isShuffle = playbackMode.shuffle;
    final isRepeatAll = playbackMode.repeatAll;
    final isRepeatOne = playbackMode.repeatSingle;

    return RepaintBoundary(
      child: Row(
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
              color: isShuffle
                  ? KalinkaColors.gold
                  : KalinkaColors.textSecondary,
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
