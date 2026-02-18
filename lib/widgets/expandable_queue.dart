import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dismissible_queue_item.dart';
import '../providers/app_state_provider.dart';
import '../providers/kalinka_player_api_provider.dart';
import '../providers/kalinka_ws_api_provider.dart';
import '../data_model/kalinka_ws_api.dart';

class ExpandableQueue extends ConsumerStatefulWidget {
  const ExpandableQueue({super.key});

  @override
  ConsumerState<ExpandableQueue> createState() => _ExpandableQueueState();
}

class _ExpandableQueueState extends ConsumerState<ExpandableQueue>
    with SingleTickerProviderStateMixin {
  late AnimationController _queueAnimationController;
  late Animation<double> _queueAnimation;

  @override
  void initState() {
    super.initState();
    _queueAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _queueAnimation = CurvedAnimation(
      parent: _queueAnimationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _queueAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isQueueExpanded = ref.watch(queueExpansionProvider);
    final queueState = ref.watch(playQueueStateStoreProvider);
    final trackList = queueState.trackList;
    final currentIndex = queueState.playbackState.index ?? 0;
    final playbackMode = queueState.playbackMode;
    final api = ref.read(kalinkaWsApiProvider);

    final isShuffle = playbackMode.shuffle;
    final isRepeatAll = playbackMode.repeatAll;
    final isRepeatOne = playbackMode.repeatSingle;

    // Sync animation with state
    if (isQueueExpanded) {
      _queueAnimationController.forward();
    } else {
      _queueAnimationController.reverse();
    }

    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 1), // Start off-screen at bottom
        end: Offset.zero, // End at normal position
      ).animate(_queueAnimation),
      child: Container(
        color: theme.colorScheme.surface,
        child: SafeArea(
          child: Column(
            children: [
              // Queue header with controls
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Row(
                  children: [
                    // Shuffle button with label
                    TextButton.icon(
                      onPressed: () {
                        api.sendQueueCommand(
                          QueueCommand.setPlaybackMode(
                            shuffle: !isShuffle,
                            repeatAll: playbackMode.repeatAll,
                            repeatSingle: playbackMode.repeatSingle,
                          ),
                        );
                      },
                      icon: Icon(Icons.shuffle, size: 18),
                      label: const Text('Shuffle'),
                      style: TextButton.styleFrom(
                        foregroundColor: isShuffle
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Repeat button with label
                    TextButton.icon(
                      onPressed: () {
                        // Cycle: off -> repeatAll -> repeatOne -> off
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
                      icon: Icon(
                        isRepeatOne ? Icons.repeat_one : Icons.repeat,
                        size: 18,
                      ),
                      label: Text(
                        isRepeatOne
                            ? 'Repeat One'
                            : isRepeatAll
                            ? 'Repeat All'
                            : 'Repeat',
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: (isRepeatAll || isRepeatOne)
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    const Spacer(),
                    // Clear button
                    TextButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (dialogContext) => AlertDialog(
                            title: const Text('Clear Queue'),
                            content: const Text(
                              'Remove all tracks from the queue?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(dialogContext),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(dialogContext);
                                  ref.read(kalinkaProxyProvider).clear();
                                },
                                child: const Text('Clear'),
                              ),
                            ],
                          ),
                        );
                      },
                      icon: const Icon(Icons.clear_all, size: 18),
                      label: const Text('Clear'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Close button
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        ref.read(queueExpansionProvider.notifier).collapse();
                      },
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
              // Queue list
              Expanded(
                child: ShaderMask(
                  shaderCallback: (Rect bounds) {
                    return LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: const [
                        Colors.transparent,
                        Colors.black,
                        Colors.black,
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.05, 0.95, 1.0],
                    ).createShader(bounds);
                  },
                  blendMode: BlendMode.dstIn,
                  child: ReorderableListView.builder(
                    itemCount: trackList.length,
                    onReorder: (oldIndex, newIndex) async {
                      if (newIndex > oldIndex) newIndex--;
                      if (oldIndex == newIndex) return;
                      ref
                          .read(playQueueStateStoreProvider.notifier)
                          .optimisticallyReorder(oldIndex, newIndex);
                      try {
                        await ref
                            .read(kalinkaProxyProvider)
                            .move(oldIndex, newIndex);
                      } catch (e) {
                        ref
                            .read(playQueueStateStoreProvider.notifier)
                            .optimisticallyReorder(newIndex, oldIndex);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to reorder: $e')),
                          );
                        }
                      }
                    },
                    proxyDecorator: (child, index, animation) {
                      return AnimatedBuilder(
                        animation: animation,
                        builder: (context, child) => Material(
                          elevation: lerpDouble(0, 6, animation.value)!,
                          color: Colors.transparent,
                          shadowColor: Colors.black.withValues(alpha: 0.4),
                          child: child,
                        ),
                        child: child,
                      );
                    },
                    itemBuilder: (context, index) {
                      final track = trackList[index];
                      final isCurrentTrack = index == currentIndex;
                      return DismissibleQueueItem(
                        key: ValueKey('queue_${track.id}_$index'),
                        track: track,
                        index: index,
                        isCurrentTrack: isCurrentTrack,
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
