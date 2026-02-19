import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/tablet_panel_provider.dart';
import '../providers/search_state_provider.dart';
import '../providers/app_state_provider.dart';
import '../providers/kalinka_player_api_provider.dart';
import '../providers/kalinka_ws_api_provider.dart';
import '../data_model/kalinka_ws_api.dart';
import '../theme/app_theme.dart';
import 'search_content.dart';
import 'queue_item_row.dart';
import 'swipe_reveal_item.dart';

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
  int _revealedIndex = -1;

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
                'Search',
                Icons.search,
                activePanel == TabletPanel.search,
                () => ref.read(tabletPanelProvider.notifier).showSearch(),
              ),
              const SizedBox(width: 8),
              _buildTab(
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
              ? _buildSearchPanel(searchState)
              : _buildQueuePanel(),
        ),
      ],
    );
  }

  Widget _buildTab(
    String label,
    IconData icon,
    bool isActive,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isActive ? KalinkaColors.accent : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isActive
                    ? KalinkaColors.accent
                    : KalinkaColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.ibmPlexMono(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  color: isActive
                      ? KalinkaColors.accent
                      : KalinkaColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchPanel(SearchState searchState) {
    return Column(
      children: [
        // Inline search bar
        Padding(
          padding: const EdgeInsets.all(8),
          child: Container(
            decoration: BoxDecoration(
              color: KalinkaColors.inputSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: KalinkaColors.accent.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
            child: TextField(
              controller: _textController,
              focusNode: _focusNode,
              style: GoogleFonts.ibmPlexMono(
                fontSize: 13,
                color: KalinkaColors.textPrimary,
              ),
              onChanged: (value) {
                ref.read(searchStateProvider.notifier).setQuery(value);
              },
              onSubmitted: (value) {
                if (value.trim().isNotEmpty) {
                  ref.read(searchStateProvider.notifier).performSearch();
                }
              },
              decoration: InputDecoration(
                hintText: 'Search music\u2026',
                hintStyle: KalinkaTextStyles.searchPlaceholder,
                prefixIcon: const Icon(
                  Icons.search,
                  color: KalinkaColors.accent,
                  size: 20,
                ),
                suffixIcon: searchState.query.isNotEmpty
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.clear,
                              size: 18,
                              color: KalinkaColors.textSecondary,
                            ),
                            onPressed: () {
                              _textController.clear();
                              ref
                                  .read(searchStateProvider.notifier)
                                  .clearSearch();
                            },
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.search,
                              size: 18,
                              color: KalinkaColors.accent,
                            ),
                            onPressed: () {
                              ref
                                  .read(searchStateProvider.notifier)
                                  .performSearch();
                            },
                          ),
                        ],
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            ),
          ),
        ),
        // Search content
        const Expanded(child: SearchContent()),
      ],
    );
  }

  Widget _buildQueuePanel() {
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
                label: Text(
                  'Shuffle',
                  style: GoogleFonts.ibmPlexMono(fontSize: 11),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: isShuffle
                      ? KalinkaColors.gold
                      : KalinkaColors.textSecondary,
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
                  style: GoogleFonts.ibmPlexMono(fontSize: 11),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: (isRepeatAll || isRepeatOne)
                      ? KalinkaColors.accent
                      : KalinkaColors.textSecondary,
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
                label: Text(
                  'Clear',
                  style: GoogleFonts.ibmPlexMono(fontSize: 11),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: KalinkaColors.textSecondary,
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
          child: ListView.builder(
            itemCount: trackList.length,
            itemBuilder: (context, index) {
              final track = trackList[index];
              final isCurrentTrack = index == currentIndex;
              return SwipeRevealItem(
                key: ValueKey('sidepanel_queue_${track.id}_$index'),
                isRevealed: _revealedIndex == index,
                onReveal: () => setState(() => _revealedIndex = index),
                onPlayNext: () async {
                  setState(() => _revealedIndex = -1);
                  final nextIndex = currentIndex + 1;
                  if (index != nextIndex && index != currentIndex) {
                    ref
                        .read(playQueueStateStoreProvider.notifier)
                        .optimisticallyReorder(index, nextIndex);
                    try {
                      await ref
                          .read(kalinkaProxyProvider)
                          .move(index, nextIndex);
                    } catch (e) {
                      ref
                          .read(playQueueStateStoreProvider.notifier)
                          .optimisticallyReorder(nextIndex, index);
                    }
                  }
                },
                onDelete: () async {
                  setState(() => _revealedIndex = -1);
                  try {
                    await ref.read(kalinkaProxyProvider).remove(index);
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to remove: $e')),
                    );
                  }
                },
                child: QueueItemRow(
                  track: track,
                  index: index,
                  displayIndex: index,
                  isCurrentTrack: isCurrentTrack,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
