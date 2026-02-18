import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/tablet_panel_provider.dart';
import '../providers/search_state_provider.dart';
import '../providers/app_state_provider.dart';
import '../providers/kalinka_player_api_provider.dart';
import '../providers/kalinka_ws_api_provider.dart';
import '../data_model/kalinka_ws_api.dart';
import 'search_content.dart';
import 'dismissible_queue_item.dart';
import 'dart:ui' show lerpDouble;

/// Tabbed side panel for tablet layout.
/// Shows Search or Queue content, inline (no overlays).
class SidePanel extends ConsumerStatefulWidget {
  const SidePanel({super.key});

  @override
  ConsumerState<SidePanel> createState() => _SidePanelState();
}

class _SidePanelState extends ConsumerState<SidePanel> {
  late TextEditingController _textController;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activePanel = ref.watch(tabletPanelProvider);
    final searchState = ref.watch(searchStateProvider);

    // Sync text controller
    if (_textController.text != searchState.query) {
      _textController.text = searchState.query;
    }

    return Column(
      children: [
        // Tab selector
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: Row(
            children: [
              _buildTab(
                theme,
                'Search',
                Icons.search,
                activePanel == TabletPanel.search,
                () => ref.read(tabletPanelProvider.notifier).showSearch(),
              ),
              const SizedBox(width: 8),
              _buildTab(
                theme,
                'Queue',
                Icons.queue_music,
                activePanel == TabletPanel.queue,
                () => ref.read(tabletPanelProvider.notifier).showQueue(),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Content
        Expanded(
          child: activePanel == TabletPanel.search
              ? _buildSearchPanel(theme, searchState)
              : _buildQueuePanel(theme),
        ),
      ],
    );
  }

  Widget _buildTab(
    ThemeData theme,
    String label,
    IconData icon,
    bool isActive,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: isActive
                ? theme.colorScheme.primaryContainer
                : Colors.transparent,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isActive
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: isActive
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchPanel(ThemeData theme, SearchState searchState) {
    return Column(
      children: [
        // Inline search bar
        Padding(
          padding: const EdgeInsets.all(8),
          child: TextField(
            controller: _textController,
            focusNode: _focusNode,
            onChanged: (value) {
              ref.read(searchStateProvider.notifier).setQuery(value);
            },
            onSubmitted: (value) {
              if (value.trim().isNotEmpty) {
                ref.read(searchStateProvider.notifier).performSearch();
              }
            },
            decoration: InputDecoration(
              hintText: 'Search music...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: searchState.query.isNotEmpty
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _textController.clear();
                            ref
                                .read(searchStateProvider.notifier)
                                .clearSearch();
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.search),
                          onPressed: () {
                            ref
                                .read(searchStateProvider.notifier)
                                .performSearch();
                          },
                          style: IconButton.styleFrom(
                            backgroundColor: theme.colorScheme.primaryContainer,
                            foregroundColor:
                                theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    )
                  : null,
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
          ),
        ),
        // Search content
        const Expanded(child: SearchContent()),
      ],
    );
  }

  Widget _buildQueuePanel(ThemeData theme) {
    final queueState = ref.watch(playQueueStateStoreProvider);
    final trackList = queueState.trackList;
    final currentIndex = queueState.playbackState.index ?? 0;
    final playbackMode = queueState.playbackMode;
    final api = ref.read(kalinkaWsApiProvider);

    final isShuffle = playbackMode.shuffle;
    final isRepeatAll = playbackMode.repeatAll;
    final isRepeatOne = playbackMode.repeatSingle;

    return Column(
      children: [
        // Queue header controls
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: Row(
            children: [
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
              TextButton.icon(
                onPressed: () {
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
              TextButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('Clear Queue'),
                      content: const Text('Remove all tracks from the queue?'),
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
            ],
          ),
        ),
        // Queue list
        Expanded(
          child: ReorderableListView.builder(
            itemCount: trackList.length,
            onReorder: (oldIndex, newIndex) async {
              if (newIndex > oldIndex) newIndex--;
              if (oldIndex == newIndex) return;
              ref
                  .read(playQueueStateStoreProvider.notifier)
                  .optimisticallyReorder(oldIndex, newIndex);
              try {
                await ref.read(kalinkaProxyProvider).move(oldIndex, newIndex);
              } catch (e) {
                ref
                    .read(playQueueStateStoreProvider.notifier)
                    .optimisticallyReorder(newIndex, oldIndex);
                if (mounted) {
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
      ],
    );
  }
}
