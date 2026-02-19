import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_state_provider.dart';
import '../providers/kalinka_player_api_provider.dart';
import '../theme/app_theme.dart';
import 'queue_item_row.dart';
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

  @override
  Widget build(BuildContext context) {
    final queueState = ref.watch(playQueueStateStoreProvider);
    final trackList = queueState.trackList;
    final currentIndex = queueState.playbackState.index ?? 0;

    // Split into "up next" (currentIndex onward) and "previously played" (before currentIndex)
    final upNextTracks = currentIndex < trackList.length
        ? trackList.sublist(currentIndex)
        : <dynamic>[];
    final previousTracks = currentIndex > 0
        ? trackList.sublist(0, currentIndex)
        : <dynamic>[];

    return ListView(
      padding: EdgeInsets.only(bottom: widget.bottomPadding + 16),
      children: [
        // "Up next" section header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text('UP NEXT', style: KalinkaTextStyles.sectionHeader),
        ),
        // Up next items
        if (upNextTracks.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
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
              onReveal: () => setState(() => _revealedIndex = absoluteIndex),
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
                  await ref.read(kalinkaProxyProvider).remove(absoluteIndex);
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

        // Divider between sections
        if (previousTracks.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Divider(),
          ),
          // "Previously played" section header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              'PREVIOUSLY PLAYED',
              style: KalinkaTextStyles.sectionHeader,
            ),
          ),
          // Previously played items at 36% opacity, tappable
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
    );
  }
}
