import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_state_provider.dart';
import '../providers/kalinka_player_api_provider.dart';
import '../providers/search_state_provider.dart';
import '../theme/app_theme.dart';
import 'clear_all_confirm_dialog.dart';
import 'empty_queue_state.dart';
import 'queue_item_row.dart';
import 'queue_management_tray.dart';
import 'queue_section_header.dart';
import 'swipe_reveal_item.dart';

/// The main queue content area, split into "Up next" and "Previously played".
class QueueZone extends ConsumerStatefulWidget {
  final double bottomPadding;

  const QueueZone({super.key, this.bottomPadding = 72});

  @override
  ConsumerState<QueueZone> createState() => _QueueZoneState();
}

class _QueueZoneState extends ConsumerState<QueueZone> {
  int _revealedIndex = -1;
  bool _trayOpen = false;
  bool _confirmClearOpen = false;

  void _openManagementTray() {
    setState(() => _trayOpen = true);
  }

  void _showClearAllConfirm() {
    Future.delayed(const Duration(milliseconds: 160), () {
      if (mounted) {
        setState(() => _confirmClearOpen = true);
      }
    });
  }

  Future<void> _clearPlayed() async {
    final queueState = ref.read(playQueueStateStoreProvider);
    final currentIndex = queueState.playbackState.index ?? 0;
    final api = ref.read(kalinkaProxyProvider);

    // Remove from highest index to lowest to avoid index shifting
    for (int i = currentIndex - 1; i >= 0; i--) {
      try {
        await api.remove(i);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to clear played: $e')));
        }
        return;
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Played tracks cleared')));
    }
  }

  void _activateSearch() {
    ref.read(searchStateProvider.notifier).activateSearch();
  }

  Widget _buildOverflowButton() {
    return GestureDetector(
      onTap: _openManagementTray,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: KalinkaColors.inputSurface,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: KalinkaColors.borderElevated),
        ),
        child: const Icon(
          Icons.more_vert,
          size: 14,
          color: KalinkaColors.textSecondary,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final queueState = ref.watch(playQueueStateStoreProvider);
    final trackList = queueState.trackList;
    final currentIndex = queueState.playbackState.index ?? 0;
    final playbackMode = queueState.playbackMode;

    // Split into "up next" (currentIndex onward) and "previously played"
    final upNextTracks = currentIndex < trackList.length
        ? trackList.sublist(currentIndex)
        : <dynamic>[];
    final previousTracks = currentIndex > 0
        ? trackList.sublist(0, currentIndex)
        : <dynamic>[];

    final isQueueEmpty = upNextTracks.isEmpty && previousTracks.isEmpty;

    return Stack(
      children: [
        // Main content
        if (isQueueEmpty)
          EmptyQueueState(onSearchTap: _activateSearch)
        else
          ListView(
            padding: EdgeInsets.only(bottom: widget.bottomPadding + 16),
            children: [
              // "Up next" section header with overflow button
              QueueSectionHeader(
                label: 'UP NEXT',
                trackCount: upNextTracks.length,
                showShuffleBadge: playbackMode.shuffle,
                trailing: _buildOverflowButton(),
              ),
              // Up next items
              if (upNextTracks.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 24,
                  ),
                  child: Text(
                    'Queue is empty',
                    style: KalinkaTextStyles.queueItemArtist,
                    textAlign: TextAlign.center,
                  ),
                )
              else
                ...List.generate(upNextTracks.length, (i) {
                  final absoluteIndex = currentIndex + i;
                  final track = upNextTracks[i];
                  return SwipeRevealItem(
                    key: ValueKey('upnext_${track.id}_$absoluteIndex'),
                    isRevealed: _revealedIndex == absoluteIndex,
                    onReveal: () =>
                        setState(() => _revealedIndex = absoluteIndex),
                    onPlayNext: () async {
                      setState(() => _revealedIndex = -1);
                      final nextIndex = currentIndex + 1;
                      if (absoluteIndex != nextIndex &&
                          absoluteIndex != currentIndex) {
                        ref
                            .read(playQueueStateStoreProvider.notifier)
                            .optimisticallyReorder(absoluteIndex, nextIndex);
                        try {
                          await ref
                              .read(kalinkaProxyProvider)
                              .move(absoluteIndex, nextIndex);
                        } catch (e) {
                          ref
                              .read(playQueueStateStoreProvider.notifier)
                              .optimisticallyReorder(nextIndex, absoluteIndex);
                        }
                      }
                    },
                    onDelete: () async {
                      setState(() => _revealedIndex = -1);
                      try {
                        await ref
                            .read(kalinkaProxyProvider)
                            .remove(absoluteIndex);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to remove: $e')),
                          );
                        }
                      }
                    },
                    child: QueueItemRow(
                      track: track,
                      index: absoluteIndex,
                      displayIndex: i,
                      isCurrentTrack: i == 0,
                    ),
                  );
                }),

              // Previously played section
              if (previousTracks.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Divider(),
                ),
                // "Previously played" section header with clear button
                QueueSectionHeader(
                  label: 'PREVIOUSLY PLAYED',
                  trailing: GestureDetector(
                    onTap: _clearPlayed,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        'CLEAR PLAYED',
                        style: KalinkaTextStyles.clearPlayedButton,
                      ),
                    ),
                  ),
                ),
                // Previously played items at 36% opacity
                Opacity(
                  opacity: 0.36,
                  child: Column(
                    children: List.generate(previousTracks.length, (i) {
                      final track = previousTracks[i];
                      return QueueItemRow(
                        key: ValueKey('prev_${track.id}_$i'),
                        track: track,
                        index: i,
                        displayIndex: i,
                      );
                    }),
                  ),
                ),
              ],
            ],
          ),

        // Management tray overlay
        if (_trayOpen)
          Positioned.fill(
            child: QueueManagementTray(
              onClose: () => setState(() => _trayOpen = false),
              onClearPlayed: () {
                _clearPlayed();
              },
              onClearAllRequested: _showClearAllConfirm,
            ),
          ),

        // Clear all confirmation dialog overlay
        if (_confirmClearOpen)
          Positioned.fill(
            child: ClearAllConfirmDialog(
              onCancel: () => setState(() => _confirmClearOpen = false),
              onConfirmed: () => setState(() => _confirmClearOpen = false),
            ),
          ),
      ],
    );
  }
}
