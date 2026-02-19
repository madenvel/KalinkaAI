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
import 'gradient_progress_line.dart';
import 'procedural_album_art.dart';

/// Fixed bottom mini player — 72px tall plus safe area inset.
class MiniPlayer extends ConsumerWidget {
  final VoidCallback? onTap;

  const MiniPlayer({super.key, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueState = ref.watch(playQueueStateStoreProvider);
    final playbackState = queueState.playbackState;
    final currentTrack = playbackState.currentTrack;
    final playerState = playbackState.state;
    final playbackTimeMs = ref.watch(playbackTimeMsProvider);
    final urlResolver = ref.read(urlResolverProvider);
    final api = ref.read(kalinkaWsApiProvider);

    final durationMs = (currentTrack?.duration ?? 0) * 1000;
    final progress = durationMs > 0
        ? (playbackTimeMs / durationMs).clamp(0.0, 1.0)
        : 0.0;

    final imageUrl =
        currentTrack?.album?.image?.thumbnail ??
        currentTrack?.album?.image?.small;
    final resolvedImageUrl = imageUrl != null
        ? urlResolver.abs(imageUrl)
        : null;

    return Container(
      decoration: const BoxDecoration(
        color: KalinkaColors.miniPlayerSurface,
        border: Border(
          top: BorderSide(color: KalinkaColors.borderElevated, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 2px gradient progress line at very top
            GradientProgressLine(progress: progress),
            // Main content — 72px
            GestureDetector(
              onTap: onTap,
              behavior: HitTestBehavior.opaque,
              child: SizedBox(
                height: 70, // 72 - 2px progress line
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      // Album art 46x46
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: resolvedImageUrl != null
                            ? Image.network(
                                resolvedImageUrl,
                                width: 46,
                                height: 46,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    ProceduralAlbumArt(
                                      trackId: currentTrack?.id ?? '',
                                      size: 46,
                                    ),
                              )
                            : ProceduralAlbumArt(
                                trackId: currentTrack?.id ?? '',
                                size: 46,
                              ),
                      ),
                      const SizedBox(width: 10),
                      // Track title + artist
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentTrack?.title ?? 'No track',
                              style: KalinkaTextStyles.miniPlayerTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              currentTrack?.performer?.name ?? '\u2014',
                              style: KalinkaTextStyles.miniPlayerArtist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Transport controls: prev, play/pause, next
                      _TransportButton(
                        icon: Icons.skip_previous_rounded,
                        size: 24,
                        onTap: () =>
                            api.sendQueueCommand(const QueueCommand.prev()),
                      ),
                      const SizedBox(width: 4),
                      // Play/pause — filled white circle 36px
                      GestureDetector(
                        onTap: isPlayPauseDisabled(playerState)
                            ? null
                            : () => sendPlayPauseCommand(ref, playerState),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            playerState == PlayerStateType.playing
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            size: 22,
                            color: KalinkaColors.background,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      _TransportButton(
                        icon: Icons.skip_next_rounded,
                        size: 24,
                        onTap: () =>
                            api.sendQueueCommand(const QueueCommand.next()),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransportButton extends StatelessWidget {
  final IconData icon;
  final double size;
  final VoidCallback? onTap;

  const _TransportButton({required this.icon, required this.size, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: size, color: KalinkaColors.textPrimary),
      ),
    );
  }
}
