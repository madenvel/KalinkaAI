import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data_model/data_model.dart';
import '../providers/app_state_provider.dart';
import '../providers/connection_state_provider.dart';
import '../providers/kalinka_player_api_provider.dart';
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

/// Approximate rendered height of a queue row (padding 8 + artwork 44 + padding 8).
const double _kRowHeight = 60.0;

/// Height of the pinned section header.
const double _kHeaderHeight = 48.0;

/// Edge scroll zone height (dp from top/bottom of scroll area).
const double _kEdgeZone = 80.0;

/// Maximum auto-scroll speed in logical pixels per second.
const double _kMaxScrollSpeed = 600.0;

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

class _QueueZoneState extends ConsumerState<QueueZone>
    with TickerProviderStateMixin {
  // ── Overlay / tray state ──────────────────────────────────────────────────
  bool _trayOpen = false;
  bool _confirmClearOpen = false;
  OverlayEntry? _managementTrayEntry;
  OverlayEntry? _clearAllConfirmEntry;

  // ── Scroll ────────────────────────────────────────────────────────────────
  final _scrollController = ScrollController();

  // ── Key for scroll coordinate mapping ────────────────────────────────────
  final _scrollViewKey = GlobalKey();

  // ── Auto-scroll ticker ────────────────────────────────────────────────────
  late final Ticker _autoScrollTicker;
  RenderBox? _scrollViewBox; // cached at drag start

  // ── Drag state ────────────────────────────────────────────────────────────
  /// Index into upNextTracks of the row being dragged (null = no drag).
  int? _draggingIndex;

  /// Current target insertion position in the display list.
  int? _placeholderIndex;

  /// Global Y coordinate of the drag pointer.
  double _dragY = 0;

  // ── Ghost overlay ─────────────────────────────────────────────────────────
  Track? _draggingTrack;
  double _ghostOffsetY = 0;

  late final AnimationController _ghostAnimController;
  late final Animation<double> _ghostScaleAnim;
  late final Animation<double> _ghostOpacityAnim;

  // ── Live references (updated each build, used by drag callbacks) ──────────
  List<Track> _upNextTracks = [];
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _autoScrollTicker = createTicker(_onAutoScrollTick);
    _ghostAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _ghostScaleAnim = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: _ghostAnimController, curve: Curves.easeOut),
    );
    _ghostOpacityAnim = Tween<double>(begin: 0.0, end: 0.96).animate(
      CurvedAnimation(parent: _ghostAnimController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _autoScrollTicker.dispose();
    _ghostAnimController.dispose();
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

  // ── Drag — lifecycle ──────────────────────────────────────────────────────

  void _onDragStarted(int trackIndex, Offset handleGlobalOffset) {
    final upNextIdx = trackIndex - _currentIndex;
    if (upNextIdx < 0 || upNextIdx >= _upNextTracks.length) return;

    _scrollViewBox =
        _scrollViewKey.currentContext?.findRenderObject() as RenderBox?;

    setState(() {
      _draggingIndex = upNextIdx;
      _placeholderIndex = upNextIdx;
      _draggingTrack = _upNextTracks[upNextIdx];
      _ghostOffsetY = -_kRowHeight / 2;
      _dragY = handleGlobalOffset.dy;
    });

    _ghostAnimController.forward(from: 0);
    _autoScrollTicker.start();
    KalinkaHaptics.heavyImpact();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_draggingIndex == null) return;
    setState(() => _dragY = details.globalPosition.dy);
    _updatePlaceholderFromY();
  }

  void _onDragEnd(DraggableDetails details) {
    if (_draggingIndex == null) return;

    _autoScrollTicker.stop();
    _ghostAnimController.reverse();

    final from = _currentIndex + _draggingIndex!;
    final to = _currentIndex + (_placeholderIndex ?? _draggingIndex!);

    if (from != to) {
      ref
          .read(playQueueStateStoreProvider.notifier)
          .optimisticallyReorder(from, to);
      ref.read(kalinkaProxyProvider).move(from, to);
      KalinkaHaptics.mediumImpact();
    }

    _resetDragState();
  }

  void _onDragCanceled(Velocity velocity, Offset offset) {
    if (_draggingIndex == null) return;
    _autoScrollTicker.stop();
    _ghostAnimController.reverse();
    _resetDragState();
  }

  void _resetDragState() {
    setState(() {
      _draggingIndex = null;
      _placeholderIndex = null;
      _draggingTrack = null;
      _dragY = 0;
    });
  }

  // ── Drag — auto-scroll ────────────────────────────────────────────────────

  void _onAutoScrollTick(Duration elapsed) {
    if (_draggingIndex == null || !mounted) {
      _autoScrollTicker.stop();
      return;
    }

    final dt = elapsed.inMicroseconds == 0
        ? 1.0 / 60.0
        : elapsed.inMicroseconds / Duration.microsecondsPerSecond;

    final velocity = _edgeScrollVelocity(_dragY);
    if (velocity != 0.0 && _scrollController.hasClients) {
      final newOffset = (_scrollController.offset + velocity * dt)
          .clamp(0.0, _scrollController.position.maxScrollExtent);
      _scrollController.jumpTo(newOffset);
    }

    _updatePlaceholderFromY();
  }

  double _edgeScrollVelocity(double globalY) {
    final box = _scrollViewBox;
    if (box == null || !box.attached) return 0.0;

    final viewTop = box.localToGlobal(Offset.zero).dy;
    final viewHeight = box.size.height;
    final localY = globalY - viewTop;

    if (localY < _kEdgeZone) {
      final depth = (_kEdgeZone - localY) / _kEdgeZone;
      return -_kMaxScrollSpeed * depth.clamp(0.0, 1.0);
    } else if (localY > viewHeight - _kEdgeZone) {
      final depth = (localY - (viewHeight - _kEdgeZone)) / _kEdgeZone;
      return _kMaxScrollSpeed * depth.clamp(0.0, 1.0);
    }
    return 0.0;
  }

  // ── Drag — placeholder ────────────────────────────────────────────────────

  void _updatePlaceholderFromY() {
    if (_draggingIndex == null || !mounted) return;

    final box = _scrollViewBox;
    if (box == null || !box.attached) return;

    final viewTopGlobal = box.localToGlobal(Offset.zero).dy;
    final localY = _dragY - viewTopGlobal;
    final scrollOffset =
        _scrollController.hasClients ? _scrollController.offset : 0.0;

    // Coordinate relative to the top of the list content (below sticky header).
    final listRelativeY = localY + scrollOffset - _kHeaderHeight;

    final maxIdx = math.max(0, _upNextTracks.length - 1);
    final candidate = (listRelativeY / _kRowHeight).floor().clamp(0, maxIdx);

    if (candidate != _placeholderIndex) {
      setState(() => _placeholderIndex = candidate);
      KalinkaHaptics.selectionClick();
    }
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

    // Keep live references for drag callbacks.
    _upNextTracks = upNextTracks;
    _currentIndex = currentIndex;

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
    List<Track> upNextTracks,
    List<Track> previousTracks,
    int currentIndex,
    dynamic playbackMode,
  ) {
    if (isQueueEmpty) {
      return EmptyQueueState(onSearchTap: _activateSearch);
    }

    return Stack(
      children: [
        CustomScrollView(
          key: _scrollViewKey,
          controller: _scrollController,
          slivers: [
            // "UP NEXT" pinned header — collapses to 0 when "PREVIOUSLY PLAYED"
            // scrolls up and takes its place. minExtent=0 lets it be fully pushed
            // off by the second pinned header.
            SliverPersistentHeader(
              pinned: true,
              delegate: _UpNextHeaderDelegate(
                trackCount: upNextTracks.length,
                showShuffleBadge: playbackMode.shuffle,
                trailing: _buildMenuButton(),
              ),
            ),

            // Up Next rows (with placeholder injection during drag)
            if (upNextTracks.isEmpty)
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
              SliverList.builder(
                itemCount: upNextTracks.length,
                itemBuilder: (context, i) =>
                    _buildUpNextItem(i, upNextTracks, currentIndex),
              ),

            // History section — divider then a second pinned header.
            // Because _UpNextHeaderDelegate has minExtent=0 and
            // _HistoryHeaderDelegate has minExtent=_kHeaderHeight, Flutter's
            // sliver stack pushes the UP NEXT header off the top smoothly as
            // the PREVIOUSLY PLAYED header pins — no manual breakpoint needed.
            if (previousTracks.isNotEmpty) ...[
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Divider(),
                ),
              ),
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
                    isDragging: _draggingIndex != null,
                  );
                },
              ),
            ],

            // Bottom padding
            SliverPadding(
              padding: EdgeInsets.only(bottom: widget.bottomPadding + 16),
            ),
          ],
        ),

        // Ghost overlay (floating row during drag)
        if (_draggingIndex != null && _draggingTrack != null)
          _buildGhostOverlay(currentIndex),
      ],
    );
  }

  // ── Up Next item builder ──────────────────────────────────────────────────

  Widget _buildUpNextItem(
    int displayIdx,
    List<Track> upNextTracks,
    int currentIndex,
  ) {
    final d = _draggingIndex;
    final p = _placeholderIndex;

    // Placeholder slot
    if (d != null && p != null && displayIdx == p) {
      return _buildPlaceholder();
    }

    // Map display index → track index accounting for the "hole" left by the
    // dragged item and the placeholder insertion point.
    int trackIdx;
    if (d == null || p == null) {
      trackIdx = displayIdx;
    } else if (d < p) {
      // Moving down: items between D and P shift up one slot.
      trackIdx = (displayIdx < d)
          ? displayIdx
          : (displayIdx < p ? displayIdx + 1 : displayIdx);
    } else if (d > p) {
      // Moving up: items between P and D shift down one slot.
      trackIdx = (displayIdx < p)
          ? displayIdx
          : (displayIdx <= d ? displayIdx - 1 : displayIdx);
    } else {
      trackIdx = displayIdx;
    }

    if (trackIdx < 0 || trackIdx >= upNextTracks.length) {
      return const SizedBox(height: _kRowHeight);
    }

    final track = upNextTracks[trackIdx];
    final absoluteIndex = currentIndex + trackIdx;

    return QueueItemRow(
      key: ValueKey('upnext_${track.id}_$absoluteIndex'),
      track: track,
      index: absoluteIndex,
      displayIndex: trackIdx,
      isCurrentTrack: trackIdx == 0,
      isDragging: d != null,
      onDragStarted: _onDragStarted,
      onDragUpdate: _onDragUpdate,
      onDragEnd: _onDragEnd,
      onDragCanceled: _onDragCanceled,
    );
  }

  // ── Ghost overlay ─────────────────────────────────────────────────────────

  Widget _buildGhostOverlay(int currentIndex) {
    final track = _draggingTrack!;
    return Positioned(
      top: (_dragY + _ghostOffsetY).clamp(0.0, double.infinity),
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _ghostAnimController,
          builder: (ctx, _) => Transform.scale(
            scale: _ghostScaleAnim.value,
            child: Opacity(
              opacity: _ghostOpacityAnim.value,
              child: Material(
                elevation: 8,
                shadowColor: Colors.black54,
                borderRadius: BorderRadius.circular(6),
                child: QueueItemRow(
                  track: track,
                  index: currentIndex + (_draggingIndex ?? 0),
                  displayIndex: _draggingIndex ?? 0,
                  isHistory: false,
                  isDragging: false,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Placeholder widget ────────────────────────────────────────────────────

  Widget _buildPlaceholder() {
    return SizedBox(
      height: _kRowHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: CustomPaint(
          painter: _DashedRectPainter(
            strokeColor: KalinkaColors.accentBorder,
            fillColor: KalinkaColors.accentSubtle,
            radius: 8,
            dashLength: 6,
            gapLength: 4,
          ),
        ),
      ),
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
// _UpNextHeaderDelegate — pinned "UP NEXT" header that can collapse to 0.
//
// minExtent=0 lets the PREVIOUSLY PLAYED header push it off the top smoothly
// as that second pinned header rises. The content fades out as it shrinks.
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
  double get minExtent => 0;

  @override
  double get maxExtent => _kHeaderHeight;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final t = (1.0 - shrinkOffset / maxExtent).clamp(0.0, 1.0);
    return Opacity(
      opacity: t,
      child: ColoredBox(
        color: KalinkaColors.background,
        child: QueueSectionHeader(
          label: 'UP NEXT',
          trackCount: trackCount,
          showShuffleBadge: showShuffleBadge,
          trailing: trailing,
        ),
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
// _HistoryHeaderDelegate — pinned "PREVIOUSLY PLAYED" header.
//
// Fixed minExtent=maxExtent=_kHeaderHeight. As this header pins at the top it
// pushes _UpNextHeaderDelegate (minExtent=0) off the screen completely.
// ─────────────────────────────────────────────────────────────────────────────

class _HistoryHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget trailing;

  const _HistoryHeaderDelegate({required this.trailing});

  @override
  double get minExtent => _kHeaderHeight;

  @override
  double get maxExtent => _kHeaderHeight;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return ColoredBox(
      color: KalinkaColors.background,
      child: QueueSectionHeader(
        label: 'PREVIOUSLY PLAYED',
        trailing: trailing,
      ),
    );
  }

  @override
  bool shouldRebuild(_HistoryHeaderDelegate old) => trailing != old.trailing;
}

// ─────────────────────────────────────────────────────────────────────────────
// _DashedRectPainter — dashed border with filled background for placeholder
// ─────────────────────────────────────────────────────────────────────────────

class _DashedRectPainter extends CustomPainter {
  final Color strokeColor;
  final Color fillColor;
  final double radius;
  final double dashLength;
  final double gapLength;

  const _DashedRectPainter({
    required this.strokeColor,
    required this.fillColor,
    required this.radius,
    required this.dashLength,
    required this.gapLength,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(radius),
    );

    // Fill
    canvas.drawRRect(rrect, Paint()..color = fillColor);

    // Dashed border
    final paint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    _drawDashedPath(canvas, Path()..addRRect(rrect), paint);
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double distance = 0;
      bool draw = true;
      while (distance < metric.length) {
        final len = draw ? dashLength : gapLength;
        if (draw) {
          canvas.drawPath(
            metric.extractPath(
              distance,
              math.min(distance + len, metric.length),
            ),
            paint,
          );
        }
        distance += len;
        draw = !draw;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRectPainter old) =>
      strokeColor != old.strokeColor ||
      fillColor != old.fillColor ||
      radius != old.radius ||
      dashLength != old.dashLength ||
      gapLength != old.gapLength;
}
