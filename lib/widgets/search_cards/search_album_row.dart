import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data_model/data_model.dart';
import '../../providers/add_mode_provider.dart';
import '../../providers/browse_detail_provider.dart';
import '../../providers/kalinka_player_api_provider.dart';
import '../../providers/search_state_provider.dart';
import '../../providers/selection_state_provider.dart';
import '../../providers/url_resolver.dart';
import '../../theme/app_theme.dart';
import '../procedural_album_art.dart';
import '../source_badge.dart';
import 'add_context_menu.dart';
import 'long_press_ring_painter.dart';

/// Album row for search results.
/// 56x56 thumbnail, title/artist/year/trackCount, tag pills,
/// two stacked icon buttons (add + expand).
/// Expands inline to show track list.
/// Long-press enters multi-select mode.
class SearchAlbumRow extends ConsumerStatefulWidget {
  final BrowseItem item;

  const SearchAlbumRow({super.key, required this.item});

  @override
  ConsumerState<SearchAlbumRow> createState() => _SearchAlbumRowState();
}

class _SearchAlbumRowState extends ConsumerState<SearchAlbumRow>
    with SingleTickerProviderStateMixin {
  bool _showAddCheck = false;
  Timer? _resetTimer;

  // Long-press ring animation (row long-press → multi-select)
  bool _longPressing = false;
  double _longPressProgress = 0.0;
  Timer? _longPressTimer;

  // + button long-press (escape hatch)
  bool _plusLongPressing = false;
  double _plusLongPressProgress = 0.0;
  Timer? _plusLongPressTimer;

  Future<void> _addAlbum() async {
    final addModeState = ref.read(addModeProvider);

    // First-encounter intercept
    if (!addModeState.firstEncounterShown) {
      ref.read(addModeProvider.notifier).triggerFirstEncounter(widget.item);
      return;
    }

    if (addModeState.addMode == AddMode.askEachTime) {
      _showContextMenu(context, showAddToPlaylist: false);
      return;
    }

    // Mode B: instant append
    await _instantAppend();
  }

  Future<void> _instantAppend() async {
    try {
      final api = ref.read(kalinkaProxyProvider);
      await api.add([widget.item.id]);
      if (!mounted) return;
      setState(() => _showAddCheck = true);
      _resetTimer?.cancel();
      _resetTimer = Timer(const Duration(milliseconds: 1600), () {
        if (mounted) setState(() => _showAddCheck = false);
      });
      if (mounted) {
        final name = widget.item.album?.title ?? widget.item.name ?? 'album';
        final trackCount = widget.item.album?.trackCount;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$name — ${trackCount ?? ''} tracks appended'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to add: $e')));
      }
    }
  }

  void _showContextMenu(
    BuildContext context, {
    bool showAddToPlaylist = false,
  }) {
    final renderBox = context.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (ctx) => AddContextMenu(
        item: widget.item,
        showAddToPlaylist: showAddToPlaylist,
        anchorPosition: Offset(
          position.dx + size.width - 40,
          position.dy + size.height / 2,
        ),
        onConfirm: () {
          setState(() => _showAddCheck = true);
          _resetTimer?.cancel();
          _resetTimer = Timer(const Duration(milliseconds: 1600), () {
            if (mounted) setState(() => _showAddCheck = false);
          });
        },
      ),
    );
  }

  void _toggleExpand() {
    final searchNotifier = ref.read(searchStateProvider.notifier);
    final currentExpanded = ref.read(searchStateProvider).expandedAlbumId;
    if (currentExpanded == widget.item.id) {
      searchNotifier.collapseAlbum();
    } else {
      searchNotifier.expandAlbum(widget.item.id);
    }
  }

  // --- Row long-press (multi-select) ---

  void _startLongPress() {
    _longPressing = true;
    _longPressProgress = 0.0;
    const tickDuration = Duration(milliseconds: 16);
    _longPressTimer = Timer.periodic(tickDuration, (timer) {
      if (!mounted || !_longPressing) {
        timer.cancel();
        if (mounted) setState(() => _longPressProgress = 0.0);
        return;
      }
      setState(() {
        _longPressProgress = min(1.0, _longPressProgress + 16 / 500);
      });
      if (_longPressProgress >= 1.0) {
        timer.cancel();
        HapticFeedback.mediumImpact();
        ref
            .read(selectionStateProvider.notifier)
            .toggleContainer(widget.item.id);
        setState(() {
          _longPressing = false;
          _longPressProgress = 0.0;
        });
      }
    });
  }

  void _cancelLongPress() {
    _longPressing = false;
    _longPressTimer?.cancel();
    if (mounted) setState(() => _longPressProgress = 0.0);
  }

  // --- + button long-press (escape hatch) ---

  void _startPlusLongPress() {
    _plusLongPressing = true;
    _plusLongPressProgress = 0.0;
    const tickDuration = Duration(milliseconds: 16);
    _plusLongPressTimer = Timer.periodic(tickDuration, (timer) {
      if (!mounted || !_plusLongPressing) {
        timer.cancel();
        if (mounted) setState(() => _plusLongPressProgress = 0.0);
        return;
      }
      setState(() {
        _plusLongPressProgress = min(1.0, _plusLongPressProgress + 16 / 400);
      });
      if (_plusLongPressProgress >= 1.0) {
        timer.cancel();
        HapticFeedback.mediumImpact();
        setState(() {
          _plusLongPressing = false;
          _plusLongPressProgress = 0.0;
        });
        _showContextMenu(context, showAddToPlaylist: false);
      }
    });
  }

  void _cancelPlusLongPress() {
    _plusLongPressing = false;
    _plusLongPressTimer?.cancel();
    if (mounted) setState(() => _plusLongPressProgress = 0.0);
  }

  @override
  void dispose() {
    _resetTimer?.cancel();
    _longPressTimer?.cancel();
    _plusLongPressTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchStateProvider);
    final isExpanded = searchState.expandedAlbumId == widget.item.id;

    final selection = ref.watch(selectionStateProvider);
    final selectionMode = selection.isActive;
    final isSelected = selection.isContainerSelected(widget.item.id);
    final isPartial = selection.isContainerPartial(widget.item.id);

    final album = widget.item.album;
    final title = album?.title ?? widget.item.name ?? 'Unknown';
    final artist = album?.artist?.name ?? '';
    final trackCount = album?.trackCount;
    final genre = album?.genre?.name;

    final urlResolver = ref.read(urlResolverProvider);
    final imageUrl = widget.item.image?.small ?? widget.item.image?.thumbnail;
    final resolvedImageUrl = imageUrl != null
        ? urlResolver.abs(imageUrl)
        : null;

    final subtitleParts = <String>[
      if (artist.isNotEmpty) artist,
      if (trackCount != null) '$trackCount tracks',
    ];
    final subtitle = subtitleParts.join(' \u00B7 ');

    // Scale for + button during long-press (1.0 → 0.88)
    final plusScale = _plusLongPressing
        ? 1.0 - (0.12 * _plusLongPressProgress)
        : 1.0;

    return Column(
      children: [
        // Main row
        GestureDetector(
          onTap: () {
            if (selectionMode) {
              ref
                  .read(selectionStateProvider.notifier)
                  .toggleContainer(widget.item.id);
            } else {
              _toggleExpand();
            }
          },
          onLongPressStart: selectionMode ? null : (_) => _startLongPress(),
          onLongPressEnd: selectionMode ? null : (_) => _cancelLongPress(),
          onLongPressCancel: selectionMode ? null : _cancelLongPress,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: selectionMode && isSelected
                  ? KalinkaColors.accent.withValues(alpha: 0.07)
                  : Colors.transparent,
              border: selectionMode && isSelected
                  ? const Border(
                      left: BorderSide(color: KalinkaColors.accent, width: 2),
                    )
                  : null,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail 56x56 with selection overlay
                SizedBox(
                  width: 56,
                  height: 56,
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: resolvedImageUrl != null
                              ? Image.network(
                                  resolvedImageUrl,
                                  width: 56,
                                  height: 56,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      ProceduralAlbumArt(
                                        trackId: widget.item.id,
                                        size: 56,
                                      ),
                                )
                              : ProceduralAlbumArt(
                                  trackId: widget.item.id,
                                  size: 56,
                                ),
                        ),
                      ),
                      // Long-press ring
                      if (_longPressing && _longPressProgress > 0)
                        Positioned.fill(
                          child: CustomPaint(
                            painter: LongPressRingPainter(
                              progress: _longPressProgress,
                              color: KalinkaColors.accent,
                            ),
                          ),
                        ),
                      // Selection overlay
                      if (selectionMode && isSelected)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: KalinkaColors.accent.withValues(
                                alpha: 0.7,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              isPartial ? Icons.remove : Icons.check,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      // Source badge
                      if (!(selectionMode && isSelected))
                        Positioned(
                          bottom: 2,
                          right: 2,
                          child: SourceBadge(entityId: widget.item.id),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Info column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: KalinkaTextStyles.cardTitle.copyWith(
                          color: selectionMode && isSelected
                              ? KalinkaColors.accent
                              : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle.isNotEmpty)
                        Text(
                          subtitle,
                          style: KalinkaTextStyles.trackRowSubtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (genre != null) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: KalinkaColors.pillSurface,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(genre, style: KalinkaTextStyles.tagPill),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Stacked buttons
                Column(
                  children: [
                    // Add button (hidden in selection mode)
                    if (!selectionMode)
                      Transform.scale(
                        scale: plusScale,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _addAlbum,
                          onLongPressStart: (_) => _startPlusLongPress(),
                          onLongPressEnd: (_) => _cancelPlusLongPress(),
                          onLongPressCancel: _cancelPlusLongPress,
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: _showAddCheck
                                    ? KalinkaColors.confirmGreen
                                    : KalinkaColors.gold,
                                width: 1,
                              ),
                            ),
                            child: Icon(
                              _showAddCheck ? Icons.check : Icons.add,
                              size: 14,
                              color: _showAddCheck
                                  ? KalinkaColors.confirmGreen
                                  : KalinkaColors.gold,
                            ),
                          ),
                        ),
                      ),
                    if (!selectionMode) const SizedBox(height: 4),
                    // Expand button (always visible)
                    GestureDetector(
                      onTap: _toggleExpand,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: KalinkaColors.borderElevated,
                            width: 1,
                          ),
                        ),
                        child: AnimatedRotation(
                          turns: isExpanded ? 0.5 : 0.0,
                          duration: const Duration(milliseconds: 200),
                          child: const Icon(
                            Icons.expand_more,
                            size: 14,
                            color: KalinkaColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        // Expanded inline track list
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: isExpanded
              ? _ExpandedAlbumTracks(albumId: widget.item.id)
              : const SizedBox.shrink(),
          crossFadeState: isExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 320),
          firstCurve: Curves.easeInOutQuart,
          secondCurve: Curves.easeInOutQuart,
          sizeCurve: Curves.easeInOutQuart,
        ),
      ],
    );
  }
}

class _ExpandedAlbumTracks extends ConsumerWidget {
  final String albumId;

  const _ExpandedAlbumTracks({required this.albumId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracksAsync = ref.watch(browseDetailProvider(albumId));

    return Container(
      margin: const EdgeInsets.only(left: 16),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: KalinkaColors.accent, width: 2)),
      ),
      child: tracksAsync.when(
        data: (browseList) {
          final tracks = browseList.items
              .where((item) => item.track != null)
              .toList();

          if (tracks.isEmpty) {
            return _buildTrackList(browseList.items);
          }
          return _buildTrackList(tracks);
        },
        loading: () => const Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            'Failed to load tracks',
            style: KalinkaTextStyles.trackRowSubtitle,
          ),
        ),
      ),
    );
  }

  Widget _buildTrackList(List<BrowseItem> items) {
    return Column(
      children: items.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        return _InlineTrackRow(
          item: item,
          index: index + 1,
          containerId: albumId,
        );
      }).toList(),
    );
  }
}

class _InlineTrackRow extends ConsumerStatefulWidget {
  final BrowseItem item;
  final int index;
  final String containerId;

  const _InlineTrackRow({
    required this.item,
    required this.index,
    required this.containerId,
  });

  @override
  ConsumerState<_InlineTrackRow> createState() => _InlineTrackRowState();
}

class _InlineTrackRowState extends ConsumerState<_InlineTrackRow> {
  bool _showCheck = false;
  Timer? _resetTimer;

  // + button long-press (escape hatch)
  bool _plusLongPressing = false;
  double _plusLongPressProgress = 0.0;
  Timer? _plusLongPressTimer;

  @override
  void dispose() {
    _resetTimer?.cancel();
    _plusLongPressTimer?.cancel();
    super.dispose();
  }

  Future<void> _addTrack() async {
    final addModeState = ref.read(addModeProvider);

    // First-encounter intercept
    if (!addModeState.firstEncounterShown) {
      ref.read(addModeProvider.notifier).triggerFirstEncounter(widget.item);
      return;
    }

    if (addModeState.addMode == AddMode.askEachTime) {
      _showContextMenu(context, showAddToPlaylist: true);
      return;
    }

    // Mode B: instant append
    await _instantAppend();
  }

  Future<void> _instantAppend() async {
    try {
      final api = ref.read(kalinkaProxyProvider);
      await api.add([widget.item.id]);
      if (!mounted) return;
      setState(() => _showCheck = true);
      _resetTimer?.cancel();
      _resetTimer = Timer(const Duration(milliseconds: 1600), () {
        if (mounted) setState(() => _showCheck = false);
      });
      if (mounted) {
        final title = widget.item.track?.title ?? widget.item.name ?? 'track';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"$title" appended'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {}
  }

  void _showContextMenu(BuildContext context, {bool showAddToPlaylist = true}) {
    final renderBox = context.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (ctx) => AddContextMenu(
        item: widget.item,
        showAddToPlaylist: showAddToPlaylist,
        anchorPosition: Offset(
          position.dx + size.width - 40,
          position.dy + size.height / 2,
        ),
        onConfirm: () {
          setState(() => _showCheck = true);
          _resetTimer?.cancel();
          _resetTimer = Timer(const Duration(milliseconds: 1600), () {
            if (mounted) setState(() => _showCheck = false);
          });
        },
      ),
    );
  }

  Future<void> _playTrack() async {
    try {
      final api = ref.read(kalinkaProxyProvider);
      await api.add([widget.item.id]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to play: $e')));
      }
    }
  }

  // --- + button long-press (escape hatch) ---

  void _startPlusLongPress() {
    _plusLongPressing = true;
    _plusLongPressProgress = 0.0;
    const tickDuration = Duration(milliseconds: 16);
    _plusLongPressTimer = Timer.periodic(tickDuration, (timer) {
      if (!mounted || !_plusLongPressing) {
        timer.cancel();
        if (mounted) setState(() => _plusLongPressProgress = 0.0);
        return;
      }
      setState(() {
        _plusLongPressProgress = min(1.0, _plusLongPressProgress + 16 / 400);
      });
      if (_plusLongPressProgress >= 1.0) {
        timer.cancel();
        HapticFeedback.mediumImpact();
        setState(() {
          _plusLongPressing = false;
          _plusLongPressProgress = 0.0;
        });
        _showContextMenu(context, showAddToPlaylist: true);
      }
    });
  }

  void _cancelPlusLongPress() {
    _plusLongPressing = false;
    _plusLongPressTimer?.cancel();
    if (mounted) setState(() => _plusLongPressProgress = 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final track = widget.item.track;
    final title = track?.title ?? widget.item.name ?? 'Unknown';
    final duration = _formatDuration(
      track?.duration != null ? track!.duration * 1000 : null,
    );

    final selection = ref.watch(selectionStateProvider);
    final selectionMode = selection.isActive;
    final containerSelected = selection.isContainerSelected(widget.containerId);
    final trackSelected =
        containerSelected &&
        selection.isTrackInContainerSelected(
          widget.containerId,
          widget.item.id,
        );

    // Scale for + button during long-press (1.0 → 0.88)
    final plusScale = _plusLongPressing
        ? 1.0 - (0.12 * _plusLongPressProgress)
        : 1.0;

    return GestureDetector(
      onTap: () {
        if (selectionMode && containerSelected) {
          ref
              .read(selectionStateProvider.notifier)
              .toggleTrackInContainer(widget.containerId, widget.item.id);
        } else if (!selectionMode) {
          _playTrack();
        }
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selectionMode && containerSelected && trackSelected
              ? KalinkaColors.accent.withValues(alpha: 0.05)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            // Track number or selection indicator
            SizedBox(
              width: 24,
              child: selectionMode && containerSelected
                  ? Icon(
                      trackSelected
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      size: 16,
                      color: trackSelected
                          ? KalinkaColors.accent
                          : KalinkaColors.textSecondary,
                    )
                  : Text(
                      '${widget.index}',
                      style: KalinkaTextStyles.trackRowSubtitle,
                      textAlign: TextAlign.center,
                    ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: KalinkaTextStyles.trackRowTitle.copyWith(
                  color: selectionMode && containerSelected && !trackSelected
                      ? KalinkaColors.textSecondary
                      : null,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (!(selectionMode && containerSelected)) ...[
              if (duration != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    duration,
                    style: KalinkaTextStyles.trackRowSubtitle,
                  ),
                ),
              Transform.scale(
                scale: plusScale,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _addTrack,
                  onLongPressStart: (_) => _startPlusLongPress(),
                  onLongPressEnd: (_) => _cancelPlusLongPress(),
                  onLongPressCancel: _cancelPlusLongPress,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _showCheck
                            ? KalinkaColors.confirmGreen
                            : KalinkaColors.gold,
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      _showCheck ? Icons.check : Icons.add,
                      size: 12,
                      color: _showCheck
                          ? KalinkaColors.confirmGreen
                          : KalinkaColors.gold,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String? _formatDuration(int? ms) {
    if (ms == null) return null;
    final seconds = ms ~/ 1000;
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
