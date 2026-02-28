import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data_model/data_model.dart';
import '../data_model/kalinka_ws_api.dart' show QueueCommand;
import '../providers/app_state_provider.dart';
import '../providers/connection_state_provider.dart';
import '../providers/kalinka_player_api_provider.dart';
import '../providers/kalinka_ws_api_provider.dart';
import '../providers/toast_provider.dart';
import '../providers/search_state_provider.dart';
import '../theme/app_theme.dart';
import '../utils/haptics.dart';
import 'clear_all_confirm_dialog.dart';
import 'empty_queue_state.dart';
import 'queue_item_row.dart';
import 'queue_management_tray.dart';
import 'queue_section_header.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────

/// Height of the pinned section header.
const double _kHeaderHeight = QueueSectionHeader.height;

// ─────────────────────────────────────────────────────────────────────────────
// QueueZone
// ─────────────────────────────────────────────────────────────────────────────

/// The main queue content area, split into "Up next" and "Previously played".
class QueueZone extends ConsumerStatefulWidget {
  final double bottomPadding;
  final bool isTablet;

  const QueueZone({super.key, this.bottomPadding = 72, this.isTablet = false});

  @override
  ConsumerState<QueueZone> createState() => _QueueZoneState();
}

class _QueueZoneState extends ConsumerState<QueueZone> {
  // ── Overlay / tray state ──────────────────────────────────────────────────
  bool _trayOpen = false;
  bool _confirmClearOpen = false;
  OverlayEntry? _managementTrayEntry;
  OverlayEntry? _clearAllConfirmEntry;

  // ── Scroll ────────────────────────────────────────────────────────────────
  final _scrollController = ScrollController();

  // ── Drag state ────────────────────────────────────────────────────────────
  bool _isDragging = false;

  // ── Live references (updated each build, used by reorder callback) ────────
  int _currentIndex = 0;

  @override
  void dispose() {
    _scrollController.dispose();
    _closeManagementTray();
    _closeClearAllConfirm();
    super.dispose();
  }

  // ── Management tray ───────────────────────────────────────────────────────

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

  // ── Queue actions ─────────────────────────────────────────────────────────

  Future<void> _clearPlayed() async {
    final queueState = ref.read(playQueueStateStoreProvider);
    final currentIndex = queueState.playbackState.index ?? 0;
    final api = ref.read(kalinkaProxyProvider);
    final toast = ref.read(toastProvider.notifier);

    for (int i = currentIndex - 1; i >= 0; i--) {
      try {
        await api.remove(i);
      } catch (e) {
        toast.show('Failed to clear played: $e', isError: true);
        return;
      }
    }
    toast.show('Played tracks cleared');
  }

  Future<void> _clearAll() async {
    final api = ref.read(kalinkaProxyProvider);
    final toast = ref.read(toastProvider.notifier);
    await api.clear();
    toast.show('Queue cleared');
  }

  void _activateSearch() {
    ref.read(searchStateProvider.notifier).activateSearch();
  }

  // ── Reorder ───────────────────────────────────────────────────────────────

  void _onReorder(int oldIndex, int newIndex) {
    // SliverReorderableList passes newIndex as the insertion point in the
    // original list (before removal). Adjust so it becomes the final position.
    if (newIndex > oldIndex) newIndex--;

    final from = _currentIndex + oldIndex;
    final to = _currentIndex + newIndex;

    if (from != to) {
      ref
          .read(playQueueStateStoreProvider.notifier)
          .optimisticallyReorder(from, to);
      ref
          .read(kalinkaWsApiProvider)
          .sendQueueCommand(QueueCommand.move(fromIndex: from, toIndex: to));
      KalinkaHaptics.mediumImpact();
    }
  }

  Widget _proxyDecorator(Widget child, int index, Animation<double> animation) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = Curves.easeOut.transform(animation.value);
        return Transform.scale(
          scale: 1.0 + 0.04 * t,
          child: Material(
            elevation: 12 * t,
            shadowColor: Colors.black54,
            borderRadius: BorderRadius.circular(6),
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final queueState = ref.watch(playQueueStateStoreProvider);
    final trackList = queueState.trackList;
    final playbackIndex = queueState.playbackState.index ?? 0;
    final currentIndex = playbackIndex.clamp(0, trackList.length);
    final playbackMode = queueState.playbackMode;
    final connectionState = ref.watch(connectionStateProvider);
    final connectionNotifier = ref.read(connectionStateProvider.notifier);

    if (connectionState == ConnectionStatus.none) {
      return const SizedBox.shrink();
    }

    final isOffline =
        connectionState == ConnectionStatus.reconnecting ||
        connectionState == ConnectionStatus.offline;

    final upNextTracks = currentIndex < trackList.length
        ? trackList.sublist(currentIndex).cast<Track>()
        : <Track>[];
    final previousTracks = currentIndex > 0
        ? trackList.sublist(0, currentIndex).cast<Track>()
        : <Track>[];

    final nowPlayingTrack =
        upNextTracks.isNotEmpty ? upNextTracks[0] : null;
    final queueTracks = upNextTracks.length > 1
        ? upNextTracks.sublist(1).cast<Track>()
        : <Track>[];

    // Keep live reference for reorder callback.
    // Queue section starts one past the currently playing track.
    _currentIndex = currentIndex + 1;

    final isQueueEmpty = upNextTracks.isEmpty && previousTracks.isEmpty;

    return Stack(
      children: [
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
                      nowPlayingTrack,
                      queueTracks,
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
            nowPlayingTrack,
            queueTracks,
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

  Widget _buildHistoryHeaderTrailing() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
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
        const SizedBox(width: 8),
        _buildMenuButton(),
      ],
    );
  }

  Widget _buildMenuButton() {
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

  Widget _buildQueueContent(
    bool isQueueEmpty,
    Track? nowPlayingTrack,
    List<Track> queueTracks,
    List<Track> previousTracks,
    int currentIndex,
    dynamic playbackMode,
  ) {
    if (isQueueEmpty) {
      return EmptyQueueState(onSearchTap: _activateSearch);
    }

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        // ── NOW PLAYING ────────────────────────────────────────────────────
        if (nowPlayingTrack != null)
          SliverMainAxisGroup(
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: const _NowPlayingHeaderDelegate(),
              ),
              SliverToBoxAdapter(
                child: QueueItemRow(
                  key: ValueKey('nowplaying_${nowPlayingTrack.id}'),
                  track: nowPlayingTrack,
                  index: currentIndex,
                  displayIndex: 0,
                  isCurrentTrack: true,
                  showDragHandle: false,
                  isDragging: _isDragging,
                ),
              ),
            ],
          ),

        // ── UP NEXT ────────────────────────────────────────────────────────
        SliverMainAxisGroup(
          slivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: _UpNextHeaderDelegate(
                trackCount: queueTracks.length,
                showShuffleBadge: playbackMode.shuffle,
                trailing: _buildMenuButton(),
              ),
            ),
            if (queueTracks.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 24,
                  ),
                  child: Text(
                    'Queue is empty',
                    style: KalinkaTextStyles.queueItemArtist,
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              SliverReorderableList(
                itemCount: queueTracks.length,
                onReorder: _onReorder,
                onReorderStart: (i) => setState(() => _isDragging = true),
                onReorderEnd: (i) => setState(() => _isDragging = false),
                proxyDecorator: _proxyDecorator,
                itemBuilder: (context, i) {
                  final track = queueTracks[i];
                  final absoluteIndex = currentIndex + 1 + i;
                  return QueueItemRow(
                    key: ValueKey('upnext_${track.id}'),
                    track: track,
                    index: absoluteIndex,
                    displayIndex: i,
                    isDragging: _isDragging,
                  );
                },
              ),
            if (previousTracks.isNotEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Divider(),
                ),
              ),
          ],
        ),

        // ── PREVIOUSLY PLAYED ──────────────────────────────────────────────
        if (previousTracks.isNotEmpty)
          SliverMainAxisGroup(
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: _HistoryHeaderDelegate(
                  trailing: _buildHistoryHeaderTrailing(),
                ),
              ),
              SliverList.builder(
                itemCount: previousTracks.length,
                itemBuilder: (context, i) {
                  final track = previousTracks[i];
                  return QueueItemRow(
                    key: ValueKey('history_${track.id}_$i'),
                    track: track,
                    index: i,
                    displayIndex: i,
                    isHistory: true,
                    isDragging: _isDragging,
                  );
                },
              ),
            ],
          ),

        // Bottom padding
        SliverPadding(
          padding: EdgeInsets.only(bottom: widget.bottomPadding + 16),
        ),
      ],
    );
  }

  // ── Frozen offline label ──────────────────────────────────────────────────

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

// ─────────────────────────────────────────────────────────────────────────────
// _UpNextHeaderDelegate — pinned "UP NEXT" header.
//
// This header keeps full height while scrolling the UP NEXT section, and then
// yields the pinned slot as the PREVIOUSLY PLAYED section reaches the top.
// ─────────────────────────────────────────────────────────────────────────────

class _UpNextHeaderDelegate extends SliverPersistentHeaderDelegate {
  final int trackCount;
  final bool showShuffleBadge;
  final Widget trailing;

  const _UpNextHeaderDelegate({
    required this.trackCount,
    required this.showShuffleBadge,
    required this.trailing,
  });

  @override
  double get minExtent => _kHeaderHeight;

  @override
  double get maxExtent => _kHeaderHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return ColoredBox(
      color: KalinkaColors.background,
      child: QueueSectionHeader(
        label: 'UP NEXT',
        trackCount: trackCount,
        showShuffleBadge: showShuffleBadge,
        trailing: trailing,
      ),
    );
  }

  @override
  bool shouldRebuild(_UpNextHeaderDelegate old) =>
      trackCount != old.trackCount ||
      showShuffleBadge != old.showShuffleBadge ||
      trailing != old.trailing;
}

// ─────────────────────────────────────────────────────────────────────────────
// _NowPlayingHeaderDelegate — pinned "NOW PLAYING" header.
// ─────────────────────────────────────────────────────────────────────────────

class _NowPlayingHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _NowPlayingHeaderDelegate();

  @override
  double get minExtent => _kHeaderHeight;

  @override
  double get maxExtent => _kHeaderHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    // No trailing widget → QueueSectionHeader would shrink to ~32 px.
    // Tighten to _kHeaderHeight so paintExtent == scrollExtent == 46 px and
    // the SliverGeometry assertion (paintExtent < scrollExtent → hasVisualOverflow)
    // never fires.
    return SizedBox(
      height: _kHeaderHeight,
      child: ColoredBox(
        color: KalinkaColors.background,
        child: const QueueSectionHeader(label: 'NOW PLAYING'),
      ),
    );
  }

  @override
  bool shouldRebuild(_NowPlayingHeaderDelegate old) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// _HistoryHeaderDelegate — pinned "PREVIOUSLY PLAYED" header.
//
// Fixed minExtent=maxExtent=_kHeaderHeight.
// ─────────────────────────────────────────────────────────────────────────────

class _HistoryHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget trailing;

  const _HistoryHeaderDelegate({required this.trailing});

  @override
  double get minExtent => _kHeaderHeight;

  @override
  double get maxExtent => _kHeaderHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return ColoredBox(
      color: KalinkaColors.background,
      child: QueueSectionHeader(label: 'PREVIOUSLY PLAYED', trailing: trailing),
    );
  }

  @override
  bool shouldRebuild(_HistoryHeaderDelegate old) => trailing != old.trailing;
}
