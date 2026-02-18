import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data_model/data_model.dart';
import '../data_model/kalinka_ws_api.dart';
import '../providers/kalinka_ws_api_provider.dart';
import '../providers/app_state_provider.dart';
import '../providers/playback_time_provider.dart';
import '../providers/url_resolver.dart';
import '../providers/search_state_provider.dart';
import '../utils/playback_utils.dart';

/// Pinned playbar header with controls
class Playbar extends ConsumerStatefulWidget {
  const Playbar({super.key});

  @override
  ConsumerState<Playbar> createState() => _PlaybarState();
}

class _PlaybarState extends ConsumerState<Playbar>
    with SingleTickerProviderStateMixin {
  bool _isSeeking = false;
  double _seekProgress = 0.0;
  int _seekPositionMs = 0;
  late AnimationController _collapseController;
  late Animation<double> _collapseAnimation;

  String _formatTime(int milliseconds) {
    final seconds = milliseconds ~/ 1000;
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();

    _collapseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _collapseAnimation = CurvedAnimation(
      parent: _collapseController,
      curve: Curves.easeInOut,
    );

    ref.listenManual(playerStateProvider, (previous, next) {
      // Reset seeking state when playback state changes
      if (!mounted) return;
      if (_isSeeking && next.state == PlayerStateType.playing) {
        setState(() {
          _isSeeking = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _collapseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final searchState = ref.watch(searchStateProvider);
    final isSearchExpanded = searchState.isExpanded;

    // Sync animation with search expansion state
    if (isSearchExpanded) {
      _collapseController.forward();
    } else {
      _collapseController.reverse();
    }

    return AnimatedBuilder(
      animation: _collapseAnimation,
      builder: (context, child) {
        final collapseProgress = _collapseAnimation.value;
        final isFullyCollapsed = collapseProgress == 1.0;
        final isFullyExpanded = collapseProgress == 0.0;

        if (isFullyCollapsed) {
          return _buildCompactPlaybar(context, theme);
        }

        if (isFullyExpanded) {
          return _buildFullPlaybar(context, theme);
        }

        // During animation, cross-fade between full and compact
        return Stack(
          children: [
            Opacity(
              opacity: 1.0 - collapseProgress,
              child: _buildFullPlaybar(context, theme),
            ),
            Opacity(
              opacity: collapseProgress,
              child: _buildCompactPlaybar(context, theme),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFullPlaybar(BuildContext context, ThemeData theme) {
    final queueState = ref.watch(playQueueStateStoreProvider);
    final playbackState = queueState.playbackState;
    final currentTrack = playbackState.currentTrack;
    final currentIndex = playbackState.index ?? 0;
    final trackList = queueState.trackList;
    final playbackMode = queueState.playbackMode;
    final playbackTimeMs = ref.watch(playbackTimeMsProvider);
    final api = ref.read(kalinkaWsApiProvider);

    final playerState = playbackState.state;
    // Track.duration appears to be in seconds, convert to milliseconds
    final durationMs = (currentTrack?.duration ?? 0) * 1000;

    // Use seek position while seeking, otherwise use actual playback time
    final positionMs = _isSeeking ? _seekPositionMs : playbackTimeMs;
    final progress = _isSeeking
        ? _seekProgress
        : (durationMs > 0 ? (positionMs / durationMs).clamp(0.0, 1.0) : 0.0);

    // Get next track if available
    Track? nextTrack;
    if (currentIndex + 1 < trackList.length) {
      nextTrack = trackList[currentIndex + 1];
    }

    // Check shuffle and repeat modes
    final isShuffle = playbackMode.shuffle;
    final isRepeatAll = playbackMode.repeatAll;
    final isRepeatOne = playbackMode.repeatSingle;

    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Track title
            Text(
              currentTrack?.title ?? 'No track',
              style: theme.textTheme.titleMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            // Track performer
            Text(
              currentTrack?.performer?.name ?? '—',
              style: theme.textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            // Progress bar with time display
            Column(
              children: [
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 2,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 4,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 12,
                    ),
                    activeTrackColor: theme.colorScheme.primary,
                    inactiveTrackColor: theme.colorScheme.outline,
                    thumbColor: theme.colorScheme.primary,
                  ),
                  child: Slider(
                    value: progress,
                    onChanged: (value) {
                      // Update local state during drag
                      setState(() {
                        _isSeeking = true;
                        _seekProgress = value;
                        _seekPositionMs = (value * durationMs).toInt();
                      });
                    },
                    onChangeEnd: (value) {
                      // Send seek command on release
                      final newPositionMs = (value * durationMs).toInt();
                      api.sendQueueCommand(
                        QueueCommand.seek(positionMs: newPositionMs),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatTime(positionMs),
                        style: theme.textTheme.bodySmall,
                      ),
                      Text(
                        _formatTime(durationMs),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Controls - shuffle, prev, play/pause, next, repeat
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Shuffle button
                IconButton(
                  icon: Icon(Icons.shuffle, size: 18),
                  color: isShuffle
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                  onPressed: () {
                    api.sendQueueCommand(
                      QueueCommand.setPlaybackMode(
                        shuffle: !isShuffle,
                        repeatAll: playbackMode.repeatAll,
                        repeatSingle: playbackMode.repeatSingle,
                      ),
                    );
                  },
                ),
                // Previous button
                IconButton(
                  icon: const Icon(Icons.skip_previous, size: 26),
                  onPressed: () =>
                      api.sendQueueCommand(const QueueCommand.prev()),
                ),
                // Play/pause button (larger)
                IconButton(
                  icon: Icon(
                    playPauseIcon(playerState),
                    size: 42,
                  ),
                  onPressed: isPlayPauseDisabled(playerState)
                      ? null
                      : () => sendPlayPauseCommand(ref, playerState),
                ),
                // Next button
                IconButton(
                  icon: const Icon(Icons.skip_next, size: 26),
                  onPressed: () =>
                      api.sendQueueCommand(const QueueCommand.next()),
                ),
                // Repeat button
                IconButton(
                  icon: Icon(
                    isRepeatOne
                        ? Icons.repeat_one
                        : isRepeatAll
                        ? Icons.repeat
                        : Icons.repeat,
                    size: 18,
                  ),
                  color: (isRepeatAll || isRepeatOne)
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                  onPressed: () {
                    // Cycle: off -> repeatAll -> repeatOne -> off
                    final bool newRepeatAll;
                    final bool newRepeatSingle;
                    if (isRepeatOne) {
                      // repeatOne -> off
                      newRepeatAll = false;
                      newRepeatSingle = false;
                    } else if (isRepeatAll) {
                      // repeatAll -> repeatOne
                      newRepeatAll = false;
                      newRepeatSingle = true;
                    } else {
                      // off -> repeatAll
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
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Next track info and Queue button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Next track info (left-aligned)
                Expanded(
                  child: nextTrack != null
                      ? Text(
                          'Next: ${nextTrack.title} by ${nextTrack.performer?.name ?? '—'}',
                          style: theme.textTheme.bodySmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.left,
                        )
                      : Text(
                          'Next: —',
                          style: theme.textTheme.bodySmall,
                          textAlign: TextAlign.left,
                        ),
                ),
                const SizedBox(width: 8),
                // Queue button (right-aligned)
                TextButton.icon(
                  onPressed: () {
                    ref.read(queueExpansionProvider.notifier).toggle();
                  },
                  icon: const Icon(Icons.queue_music, size: 18),
                  label: Text('Queue(${trackList.length})'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactPlaybar(BuildContext context, ThemeData theme) {
    final queueState = ref.watch(playQueueStateStoreProvider);
    final playbackState = queueState.playbackState;
    final currentTrack = playbackState.currentTrack;
    final playbackTimeMs = ref.watch(playbackTimeMsProvider);
    final urlResolver = ref.read(urlResolverProvider);

    final playerState = playbackState.state;
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

    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                // Album cover (48x48)
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: resolvedImageUrl != null
                        ? Image.network(
                            resolvedImageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.album,
                                size: 24,
                                color: theme.colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.3),
                              );
                            },
                          )
                        : Icon(
                            Icons.album,
                            size: 24,
                            color: theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.3),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                // Track info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        currentTrack?.title ?? 'No track',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        currentTrack?.performer?.name ?? '—',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Play/pause button
                IconButton(
                  icon: Icon(
                    playPauseIcon(playerState),
                    size: 28,
                  ),
                  onPressed: isPlayPauseDisabled(playerState)
                      ? null
                      : () => sendPlayPauseCommand(ref, playerState),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Non-interactive progress bar
            LinearProgressIndicator(
              value: progress,
              minHeight: 2,
              backgroundColor: theme.colorScheme.outline.withValues(alpha: 0.3),
              valueColor: AlwaysStoppedAnimation<Color>(
                theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
