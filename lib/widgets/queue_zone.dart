import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_state_provider.dart';
import '../providers/connection_state_provider.dart';
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
  final bool isTablet;

  const QueueZone({super.key, this.bottomPadding = 72, this.isTablet = false});

  @override
  ConsumerState<QueueZone> createState() => _QueueZoneState();
}

class _QueueZoneState extends ConsumerState<QueueZone> {
  int _revealedIndex = -1;
  bool _trayOpen = false;
  bool _confirmClearOpen = false;
  OverlayEntry? _managementTrayEntry;
  OverlayEntry? _clearAllConfirmEntry;

  void _openManagementTray() {
    if (widget.isTablet) {
      if (_trayOpen) return;
      setState(() => _trayOpen = true);
      return;
    }

    if (_managementTrayEntry != null) return;

    _managementTrayEntry = OverlayEntry(
      builder: (context) => Positioned.fill(
        child: DefaultTextStyle.merge(
          style: const TextStyle(decoration: TextDecoration.none),
          child: QueueManagementTray(
            onClose: _closeManagementTray,
            onClearPlayed: _clearPlayed,
            onClearAllRequested: _showClearAllConfirm,
          ),
        ),
      ),
    );

    Overlay.of(context, rootOverlay: true).insert(_managementTrayEntry!);
  }

  void _closeManagementTray() {
    if (widget.isTablet) {
      if (!_trayOpen) return;
      setState(() => _trayOpen = false);
      return;
    }

    _managementTrayEntry?.remove();
    _managementTrayEntry = null;
  }

  void _showClearAllConfirm() {
    Future.delayed(const Duration(milliseconds: 160), () {
      if (!mounted) return;

      if (widget.isTablet) {
        if (_confirmClearOpen) return;
        setState(() => _confirmClearOpen = true);
        return;
      }

      if (!mounted || _clearAllConfirmEntry != null) return;

      _clearAllConfirmEntry = OverlayEntry(
        builder: (context) => Positioned.fill(
          child: DefaultTextStyle.merge(
            style: const TextStyle(decoration: TextDecoration.none),
            child: ClearAllConfirmDialog(
              onCancel: _closeClearAllConfirm,
              onConfirmed: _closeClearAllConfirm,
              onConfirmClearAll: _clearAll,
            ),
          ),
        ),
      );

      Overlay.of(context, rootOverlay: true).insert(_clearAllConfirmEntry!);
    });
  }

  void _closeClearAllConfirm() {
    if (widget.isTablet) {
      if (!_confirmClearOpen) return;
      setState(() => _confirmClearOpen = false);
      return;
    }

    _clearAllConfirmEntry?.remove();
    _clearAllConfirmEntry = null;
  }

  @override
  void dispose() {
    _closeManagementTray();
    _closeClearAllConfirm();
    super.dispose();
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

  Future<void> _clearAll() async {
    await ref.read(kalinkaProxyProvider).clear();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Queue cleared')));
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
    final playbackIndex = queueState.playbackState.index ?? 0;
    final currentIndex = playbackIndex.clamp(0, trackList.length);
    final playbackMode = queueState.playbackMode;
    final connectionState = ref.watch(connectionStateProvider);
    final connectionNotifier = ref.read(connectionStateProvider.notifier);

    final isOffline =
        connectionState == ConnectionStatus.reconnecting ||
        connectionState == ConnectionStatus.offline;

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
        // Frozen label when offline
        if (isOffline)
          Column(
            children: [
              _buildFrozenLabel(connectionNotifier),
              Expanded(
                child: IgnorePointer(
                  child: Opacity(
                    opacity: 0.4,
                    child: _buildQueueContent(
                      isQueueEmpty,
                      upNextTracks,
                      previousTracks,
                      currentIndex,
                      playbackMode,
                    ),
                  ),
                ),
              ),
            ],
          )
        else
          _buildQueueContent(
            isQueueEmpty,
            upNextTracks,
            previousTracks,
            currentIndex,
            playbackMode,
          ),

        if (widget.isTablet && _trayOpen)
          Positioned.fill(
            child: QueueManagementTray(
              onClose: _closeManagementTray,
              onClearPlayed: _clearPlayed,
              onClearAllRequested: _showClearAllConfirm,
            ),
          ),

        if (widget.isTablet && _confirmClearOpen)
          Positioned.fill(
            child: ClearAllConfirmDialog(
              onCancel: _closeClearAllConfirm,
              onConfirmed: _closeClearAllConfirm,
              onConfirmClearAll: _clearAll,
            ),
          ),
      ],
    );
  }

  Widget _buildQueueContent(
    bool isQueueEmpty,
    List<dynamic> upNextTracks,
    List<dynamic> previousTracks,
    int currentIndex,
    dynamic playbackMode,
  ) {
    if (isQueueEmpty) {
      return EmptyQueueState(onSearchTap: _activateSearch);
    }

    return ListView(
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
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await ref.read(kalinkaProxyProvider).remove(absoluteIndex);
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Failed to remove: $e')),
                  );
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
          ...List.generate(previousTracks.length, (i) {
            final track = previousTracks[i];
            return Opacity(
              opacity: 0.36,
              child: QueueItemRow(
                key: ValueKey('prev_${track.id}_$i'),
                track: track,
                index: i,
                displayIndex: i,
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildFrozenLabel(ConnectionStateNotifier notifier) {
    final lastConnected = notifier.lastConnectedAt;
    String syncText = 'Read-only';
    if (lastConnected != null) {
      final elapsed = DateTime.now().difference(lastConnected);
      if (elapsed.inMinutes < 1) {
        syncText = 'Read-only \u00b7 last synced just now';
      } else {
        syncText = 'Read-only \u00b7 last synced ${elapsed.inMinutes} min ago';
      }
    }

    return Container(
      width: double.infinity,
      color: KalinkaColors.pillSurface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.lock_outline,
            size: 11,
            color: KalinkaColors.textMuted,
          ),
          const SizedBox(width: 6),
          Text(
            syncText.toUpperCase(),
            style: KalinkaTextStyles.sectionHeaderMuted,
          ),
        ],
      ),
    );
  }
}
