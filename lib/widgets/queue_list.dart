import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data_model/data_model.dart';
import '../providers/app_state_provider.dart';
import '../providers/kalinka_player_api_provider.dart';
import '../providers/kalinka_ws_api_provider.dart';
import '../providers/playback_time_provider.dart';
import '../providers/url_resolver.dart';
import '../data_model/kalinka_ws_api.dart';
import '../utils/playback_utils.dart';

/// Queue list item
class QueueListItem extends ConsumerWidget {
  final Track track;
  final int index;
  final bool isCurrentTrack;

  const QueueListItem({
    super.key,
    required this.track,
    required this.index,
    required this.isCurrentTrack,
  });

  String _formatDuration(int milliseconds) {
    final seconds = milliseconds ~/ 1000;
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  Widget _buildPlaceholder(ThemeData theme) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: theme.colorScheme.outline.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(
        Icons.album,
        color: theme.colorScheme.onSurfaceVariant,
        size: 24,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final api = ref.read(kalinkaWsApiProvider);
    final urlResolver = ref.read(urlResolverProvider);

    final imageUrl = track.album?.image?.thumbnail ?? track.album?.image?.small;
    final resolvedImageUrl = imageUrl != null
        ? urlResolver.abs(imageUrl)
        : null;

    // Watch playback state and time only for the current track
    final playerState = isCurrentTrack
        ? ref.watch(playerStateProvider).state
        : null;
    final playbackTimeMs = isCurrentTrack
        ? ref.watch(playbackTimeMsProvider)
        : 0;
    final durationMs = track.duration * 1000;
    final progress = (isCurrentTrack && durationMs > 0)
        ? (playbackTimeMs / durationMs).clamp(0.0, 1.0)
        : 0.0;

    return InkWell(
      onTap: () {
        // Play from this index
        api.sendQueueCommand(QueueCommand.play(index: index));
      },
      onLongPress: () {
        // Show context menu
        showModalBottomSheet(
          context: context,
          builder: (sheetContext) => Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: const Text('Remove from queue'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    ref.read(kalinkaProxyProvider).remove(index);
                  },
                ),
              ],
            ),
          ),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isCurrentTrack
                  ? theme.colorScheme.outline.withValues(alpha: 0.15)
                  : Colors.transparent,
            ),
            child: Row(
              children: [
                // Album art with playing indicator overlay
                SizedBox(
                  width: 48,
                  height: 48,
                  child: Stack(
                    children: [
                      // Album image
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: resolvedImageUrl != null
                            ? ColorFiltered(
                                colorFilter: ColorFilter.mode(
                                  Colors.black.withValues(
                                    alpha: isCurrentTrack ? 0.5 : 0.0,
                                  ),
                                  BlendMode.darken,
                                ),
                                child: Image.network(
                                  resolvedImageUrl,
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return _buildPlaceholder(theme);
                                  },
                                ),
                              )
                            : _buildPlaceholder(theme),
                      ),
                      // Playing indicator overlay
                      if (isCurrentTrack)
                        Center(
                          child: Icon(
                            Icons.graphic_eq,
                            size: 24,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Track info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: isCurrentTrack
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        track.performer?.name ?? 'Unknown Artist',
                        style: theme.textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Play/pause button for current track, duration for others
                if (isCurrentTrack)
                  IconButton(
                    icon: Icon(playPauseFilledIcon(playerState), size: 36),
                    color: theme.colorScheme.primary,
                    onPressed: isPlayPauseDisabled(playerState)
                        ? null
                        : () => sendPlayPauseCommand(ref, playerState),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                  )
                else
                  Text(
                    _formatDuration(track.duration * 1000),
                    style: theme.textTheme.bodySmall,
                  ),
                const SizedBox(width: 4),
                // Drag handle for reordering
                ReorderableDragStartListener(
                  index: index,
                  child: Icon(
                    Icons.drag_handle,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          // Thin progress bar for current track
          if (isCurrentTrack)
            LinearProgressIndicator(
              value: progress,
              minHeight: 2,
              backgroundColor: theme.colorScheme.outline.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation<Color>(
                theme.colorScheme.primary,
              ),
            ),
        ],
      ),
    );
  }
}
