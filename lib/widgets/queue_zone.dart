import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data_model/data_model.dart';
import '../data_model/kalinka_ws_api.dart' show QueueCommand;
import '../providers/app_state_provider.dart';
import '../providers/connection_state_provider.dart';
import '../providers/kalinka_player_api_provider.dart';
import '../providers/kalinka_ws_api_provider.dart';
import '../providers/toast_provider.dart';
import '../theme/app_theme.dart';
import '../utils/haptics.dart';
import 'clear_all_confirm_dialog.dart';
import 'empty_queue_state.dart';
import 'kalinka_bottom_sheet.dart';
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
  final VoidCallback? onOpenManagementTray;

  const QueueZone({
    super.key,
    this.bottomPadding = 72,
    this.isTablet = false,
    this.onOpenManagementTray,
  });

  @override
  ConsumerState<QueueZone> createState() => _QueueZoneState();
}

class _QueueZoneState extends ConsumerState<QueueZone> {
  // ── Scroll ────────────────────────────────────────────────────────────────
  final _scrollController = ScrollController();

  // ── Drag state ────────────────────────────────────────────────────────────
  bool _isDragging = false;
  bool _managementTrayOpen = false;

  // ── Live references (updated each build, used by reorder callback) ────────
  int _currentIndex = 0;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // ── Management tray ───────────────────────────────────────────────────────

  Future<void> _openManagementTray() async {
    if (!widget.isTablet) {
      widget.onOpenManagementTray?.call();
      return;
    }
    if (_managementTrayOpen) return;
    setState(() => _managementTrayOpen = true);
  }

  Future<void> _onTabletTrayAction(TrayAction action) async {
    switch (action) {
      case TrayAction.clearPlayed:
        await _clearPlayed();
      case TrayAction.clearAll:
        await Future.delayed(const Duration(milliseconds: 160));
        if (!mounted) return;
        await showKalinkaConfirmDialog<bool>(
          context: context,
          builder: (_) => ClearAllConfirmDialog(onConfirmClearAll: _clearAll),
        );
    }
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
    final queueSnapshot = ref.watch(
      playQueueStateStoreProvider.select(
        (s) => (
          trackList: s.trackList,
          playbackIndex: s.playbackState.index ?? 0,
          shuffleEnabled: s.playbackMode.shuffle,
        ),
      ),
    );
    final trackList = queueSnapshot.trackList;
    final playbackIndex = queueSnapshot.playbackIndex;
    final currentIndex = playbackIndex.clamp(0, trackList.length);
    final shuffleEnabled = queueSnapshot.shuffleEnabled;
    final connectionState = ref.watch(connectionStateProvider);

    final isOfflineOrNone =
        connectionState == ConnectionStatus.offline ||
        connectionState == ConnectionStatus.none;
    final isOffline =
        connectionState == ConnectionStatus.reconnecting ||
        connectionState == ConnectionStatus.offline;

    final upNextTracks = currentIndex < trackList.length
        ? trackList.sublist(currentIndex).cast<Track>()
        : <Track>[];
    final previousTracks = currentIndex > 0
        ? trackList.sublist(0, currentIndex).cast<Track>().reversed.toList()
        : <Track>[];

    final nowPlayingTrack = upNextTracks.isNotEmpty ? upNextTracks[0] : null;
    final queueTracks = upNextTracks.length > 1
        ? upNextTracks.sublist(1).cast<Track>()
        : <Track>[];

    // Keep live reference for reorder callback.
    // Queue section starts one past the currently playing track.
    _currentIndex = currentIndex + 1;

    final isQueueEmpty = upNextTracks.isEmpty && previousTracks.isEmpty;

    if (isQueueEmpty) {
      return EmptyQueueState(isOffline: isOfflineOrNone);
    }

    if (connectionState == ConnectionStatus.none) {
      return const SizedBox.shrink();
    }

    return Stack(
      children: [
        if (isOffline)
          Expanded(
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.4,
                child: _buildQueueContent(
                  nowPlayingTrack,
                  queueTracks,
                  previousTracks,
                  currentIndex,
                  shuffleEnabled,
                ),
              ),
            ),
          )
        else
          _buildQueueContent(
            nowPlayingTrack,
            queueTracks,
            previousTracks,
            currentIndex,
            shuffleEnabled,
          ),

        // Floating menu button — always sits in the pinned header area.
        if (!isOffline)
          Positioned(
            top: (_kHeaderHeight - 36) / 2,
            right: 20,
            child: _buildMenuButton(),
          ),
        if (widget.isTablet && _managementTrayOpen)
          Positioned.fill(
            child: TabletQueueManagementTray(
              onClose: () {
                if (mounted) {
                  setState(() => _managementTrayOpen = false);
                }
              },
              onAction: (action) {
                _onTabletTrayAction(action);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildMenuButton() {
    return Material(
      color: KalinkaColors.surfaceInput,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(9),
        side: const BorderSide(color: KalinkaColors.borderDefault),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _openManagementTray,
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) {
            return Colors.white.withValues(alpha: 0.08);
          }
          return null;
        }),
        child: const SizedBox(
          width: 36,
          height: 36,
          child: Icon(
            Icons.more_vert,
            size: 16,
            color: KalinkaColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildQueueContent(
    Track? nowPlayingTrack,
    List<Track> queueTracks,
    List<Track> previousTracks,
    int currentIndex,
    bool shuffleEnabled,
  ) {
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
                showShuffleBadge: shuffleEnabled,
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
                  child: Divider(color: Color(0x26FFFFFF)),
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
                delegate: const _HistoryHeaderDelegate(),
              ),
              SliverList.builder(
                itemCount: previousTracks.length,
                itemBuilder: (context, i) {
                  final track = previousTracks[i];
                  final queueIndex = currentIndex - 1 - i;
                  return QueueItemRow(
                    key: ValueKey('history_${track.id}_$i'),
                    track: track,
                    index: queueIndex,
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

  const _UpNextHeaderDelegate({
    required this.trackCount,
    required this.showShuffleBadge,
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
    return SizedBox(
      height: _kHeaderHeight,
      child: ColoredBox(
        color: KalinkaColors.background,
        child: QueueSectionHeader(
          label: 'UP NEXT',
          trackCount: trackCount,
          showShuffleBadge: showShuffleBadge,
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_UpNextHeaderDelegate old) =>
      trackCount != old.trackCount || showShuffleBadge != old.showShuffleBadge;
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
  const _HistoryHeaderDelegate();

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
    return SizedBox(
      height: _kHeaderHeight,
      child: ColoredBox(
        color: KalinkaColors.background,
        child: const QueueSectionHeader(label: 'PREVIOUSLY PLAYED'),
      ),
    );
  }

  @override
  bool shouldRebuild(_HistoryHeaderDelegate old) => false;
}
