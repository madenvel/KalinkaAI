import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data_model/data_model.dart';
import '../providers/app_state_provider.dart';
import '../providers/connection_state_provider.dart';
import '../providers/kalinka_player_api_provider.dart';
import '../providers/toast_provider.dart';
import '../providers/search_state_provider.dart';
import '../theme/app_theme.dart';
import 'clear_all_confirm_dialog.dart';
import 'empty_queue_state.dart';
import 'queue_item_row.dart';
import 'queue_management_tray.dart';
import 'queue_section_header.dart';

/// The main queue content area, split into "Up next" and "Previously played".
class QueueZone extends ConsumerStatefulWidget {
  final double bottomPadding;
  final bool isTablet;

  const QueueZone({super.key, this.bottomPadding = 72, this.isTablet = false});

  @override
  ConsumerState<QueueZone> createState() => _QueueZoneState();
}

class _QueueZoneState extends ConsumerState<QueueZone> {
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
        ref.read(toastProvider.notifier).show('Failed to clear played: $e', isError: true);
        return;
      }
    }
    ref.read(toastProvider.notifier).show('Played tracks cleared');
  }

  Future<void> _clearAll() async {
    await ref.read(kalinkaProxyProvider).clear();
    ref.read(toastProvider.notifier).show('Queue cleared');
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
          color: KalinkaColors.surfaceInput,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: KalinkaColors.borderDefault),
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

    // No server configured — don't render queue items to avoid provider errors
    // (e.g. right after the user taps "Disconnect").
    if (connectionState == ConnectionStatus.none) {
      return const SizedBox.shrink();
    }

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

    return CustomScrollView(
      slivers: [
        // "Up next" section header with overflow button
        SliverToBoxAdapter(
          child: QueueSectionHeader(
            label: 'UP NEXT',
            trackCount: upNextTracks.length,
            showShuffleBadge: playbackMode.shuffle,
            trailing: _buildOverflowButton(),
          ),
        ),
        // Up next items — built lazily
        if (upNextTracks.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Text(
                'Queue is empty',
                style: KalinkaTextStyles.queueItemArtist,
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          SliverList.builder(
            itemCount: upNextTracks.length,
            itemBuilder: (context, i) {
              final absoluteIndex = currentIndex + i;
              final track = upNextTracks[i] as Track;
              return QueueItemRow(
                key: ValueKey('upnext_${track.id}_$absoluteIndex'),
                track: track,
                index: absoluteIndex,
                displayIndex: i,
                isCurrentTrack: i == 0,
              );
            },
          ),

        // Previously played section — built lazily
        if (previousTracks.isNotEmpty) ...[
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Divider(),
            ),
          ),
          SliverToBoxAdapter(
            child: QueueSectionHeader(
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
          ),
          SliverList.builder(
            itemCount: previousTracks.length,
            itemBuilder: (context, i) {
              final track = previousTracks[i] as Track;
              return Opacity(
                opacity: 0.36,
                child: QueueItemRow(
                  key: ValueKey('prev_${track.id}_$i'),
                  track: track,
                  index: i,
                  displayIndex: i,
                ),
              );
            },
          ),
        ],

        // Bottom padding
        SliverPadding(
          padding: EdgeInsets.only(bottom: widget.bottomPadding + 16),
        ),
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
      color: KalinkaColors.surfaceElevated,
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
