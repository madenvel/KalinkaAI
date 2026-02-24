import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data_model/data_model.dart';
import '../../providers/browse_detail_provider.dart';
import '../../providers/kalinka_player_api_provider.dart';
import '../../providers/search_state_provider.dart';
import '../../providers/selection_state_provider.dart';
import '../../providers/toast_provider.dart';
import '../../providers/url_resolver.dart';
import '../../theme/app_theme.dart';
import '../procedural_album_art.dart';
import '../source_badge.dart';
import '../swipe_to_act_row.dart';
import 'long_press_ring_painter.dart';

/// Playlist row for search results.
/// Same structure as Album Row but with 2x2 mosaic grid overlay on art.
/// Tap = expand inline track list. Swipe right = add to queue / play next.
/// Long-press enters multi-select mode.
class SearchPlaylistRow extends ConsumerStatefulWidget {
  final BrowseItem item;

  const SearchPlaylistRow({super.key, required this.item});

  @override
  ConsumerState<SearchPlaylistRow> createState() => _SearchPlaylistRowState();
}

class _SearchPlaylistRowState extends ConsumerState<SearchPlaylistRow> {
  // Long-press ring animation (row-level multi-select)
  bool _longPressing = false;
  double _longPressProgress = 0.0;
  Timer? _longPressTimer;

  void _toggleExpand() {
    final searchNotifier = ref.read(searchStateProvider.notifier);
    final currentExpanded = ref.read(searchStateProvider).expandedAlbumId;
    // Reuse expandedAlbumId for playlists too (only one expanded at a time)
    if (currentExpanded == widget.item.id) {
      searchNotifier.collapseAlbum();
    } else {
      searchNotifier.expandAlbum(widget.item.id);
    }
  }

  Future<void> _addToQueue() async {
    try {
      final api = ref.read(kalinkaProxyProvider);
      await api.add([widget.item.id]);
      final title =
          widget.item.playlist?.name ?? widget.item.name ?? 'playlist';
      final trackCount = widget.item.playlist?.trackCount;
      ref.read(toastProvider.notifier).show('$title — ${trackCount ?? ''} tracks added to queue');
    } catch (e) {
      ref.read(toastProvider.notifier).show('Failed to add: $e', isError: true);
    }
  }

  Future<void> _playNext() async {
    try {
      final api = ref.read(kalinkaProxyProvider);
      await api.add([widget.item.id]);
      final title =
          widget.item.playlist?.name ?? widget.item.name ?? 'playlist';
      ref.read(toastProvider.notifier).show('$title playing next');
    } catch (e) {
      ref.read(toastProvider.notifier).show('Failed to add: $e', isError: true);
    }
  }

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

  @override
  void dispose() {
    _longPressTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchStateProvider);
    final isExpanded = searchState.expandedAlbumId == widget.item.id;
    final urlResolver = ref.read(urlResolverProvider);

    final selection = ref.watch(selectionStateProvider);
    final selectionMode = selection.isActive;
    final isSelected = selection.isContainerSelected(widget.item.id);
    final isPartial = selection.isContainerPartial(widget.item.id);

    final playlist = widget.item.playlist;
    final title = playlist?.name ?? widget.item.name ?? 'Unknown';
    final trackCount = playlist?.trackCount;
    final description = playlist?.description ?? '';

    final subtitleParts = <String>[
      if (trackCount != null) '$trackCount tracks',
      if (description.isNotEmpty) description,
    ];
    final subtitle = subtitleParts.join(' \u00B7 ');
    final imageUrl =
        widget.item.image?.small ??
        widget.item.image?.thumbnail ??
        widget.item.image?.large;
    final resolvedImageUrl = imageUrl != null
        ? urlResolver.abs(imageUrl)
        : null;

    return Column(
      children: [
        // Main row
        SwipeToActRow(
          enabled: !selectionMode,
          onAddToQueue: _addToQueue,
          onPlayNext: _playNext,
          child: GestureDetector(
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
                  // Thumbnail 56x56 with mosaic overlay
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
                            child: Stack(
                              children: [
                                if (resolvedImageUrl != null)
                                  Image.network(
                                    resolvedImageUrl,
                                    fit: BoxFit.cover,
                                    width: 56,
                                    height: 56,
                                    errorBuilder: (context, error, stackTrace) {
                                      return ProceduralAlbumArt(
                                        trackId: widget.item.id,
                                        size: 56,
                                      );
                                    },
                                  )
                                else
                                  ProceduralAlbumArt(
                                    trackId: widget.item.id,
                                    size: 56,
                                  ),
                                // 2x2 mosaic overlay at 25% opacity
                                Opacity(
                                  opacity: 0.25,
                                  child: GridView.count(
                                    crossAxisCount: 2,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    children: List.generate(4, (i) {
                                      return ProceduralAlbumArt(
                                        trackId: '${widget.item.id}_$i',
                                        size: 28,
                                      );
                                    }),
                                  ),
                                ),
                              ],
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
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Expand chevron button (always visible)
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
            ),
          ),
        ),
        // Expanded inline track list
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: isExpanded
              ? _ExpandedPlaylistTracks(playlistId: widget.item.id)
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

class _ExpandedPlaylistTracks extends ConsumerWidget {
  final String playlistId;

  const _ExpandedPlaylistTracks({required this.playlistId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracksAsync = ref.watch(browseDetailProvider(playlistId));

    return Container(
      margin: const EdgeInsets.only(left: 16),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: KalinkaColors.accent, width: 2)),
      ),
      child: tracksAsync.when(
        data: (browseList) => _buildTrackList(browseList.items),
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
        return _InlinePlaylistTrack(
          item: item,
          index: index + 1,
          containerId: playlistId,
        );
      }).toList(),
    );
  }
}

class _InlinePlaylistTrack extends ConsumerStatefulWidget {
  final BrowseItem item;
  final int index;
  final String containerId;

  const _InlinePlaylistTrack({
    required this.item,
    required this.index,
    required this.containerId,
  });

  @override
  ConsumerState<_InlinePlaylistTrack> createState() =>
      _InlinePlaylistTrackState();
}

class _InlinePlaylistTrackState extends ConsumerState<_InlinePlaylistTrack> {
  bool _longPressing = false;
  double _longPressProgress = 0.0;
  Timer? _longPressTimer;

  @override
  void dispose() {
    _longPressTimer?.cancel();
    super.dispose();
  }

  Future<void> _playTrack() async {
    try {
      final api = ref.read(kalinkaProxyProvider);
      await api.clear();
      await api.add([widget.containerId]);
      await api.play(widget.index - 1);
    } catch (e) {
      ref.read(toastProvider.notifier).show('Failed to play: $e', isError: true);
    }
  }

  Future<void> _addToQueue() async {
    try {
      final api = ref.read(kalinkaProxyProvider);
      await api.add([widget.item.id]);
      final title = widget.item.track?.title ?? widget.item.name ?? 'track';
      ref.read(toastProvider.notifier).show('"$title" added to queue');
    } catch (e) {
      ref.read(toastProvider.notifier).show('Failed to add: $e', isError: true);
    }
  }

  Future<void> _playNext() async {
    try {
      final api = ref.read(kalinkaProxyProvider);
      await api.add([widget.item.id]);
      final title = widget.item.track?.title ?? widget.item.name ?? 'track';
      ref.read(toastProvider.notifier).show('"$title" playing next');
    } catch (e) {
      ref.read(toastProvider.notifier).show('Failed to add: $e', isError: true);
    }
  }

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
            .enterSelectionMode(widget.item.id);
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

  @override
  Widget build(BuildContext context) {
    final track = widget.item.track;
    final title = track?.title ?? widget.item.name ?? 'Unknown';
    final duration = _formatDuration(
      track?.duration != null ? track!.duration * 1000 : null,
    );

    final selection = ref.watch(selectionStateProvider);
    final selectionMode = selection.isActive;
    final isSelected = selection.selectedIds.contains(widget.item.id);
    final containerSelected = selection.isContainerSelected(widget.containerId);
    final trackSelected =
        containerSelected &&
        selection.isTrackInContainerSelected(
          widget.containerId,
          widget.item.id,
        );
    final inSelectionHighlight = isSelected || trackSelected;

    return SwipeToActRow(
      enabled: !selectionMode,
      onAddToQueue: _addToQueue,
      onPlayNext: _playNext,
      child: GestureDetector(
        onTap: () {
          if (selectionMode) {
            if (containerSelected) {
              ref
                  .read(selectionStateProvider.notifier)
                  .toggleTrackInContainer(widget.containerId, widget.item.id);
            } else {
              ref.read(selectionStateProvider.notifier).toggle(widget.item.id);
            }
          } else {
            _playTrack();
          }
        },
        onLongPressStart: selectionMode ? null : (_) => _startLongPress(),
        onLongPressEnd: selectionMode ? null : (_) => _cancelLongPress(),
        onLongPressCancel: selectionMode ? null : _cancelLongPress,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selectionMode && inSelectionHighlight
                ? KalinkaColors.accent.withValues(alpha: 0.05)
                : Colors.transparent,
          ),
          child: Row(
            children: [
              // Track number or selection indicator
              SizedBox(
                width: 24,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (selectionMode)
                      Icon(
                        inSelectionHighlight
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        size: 16,
                        color: inSelectionHighlight
                            ? KalinkaColors.accent
                            : KalinkaColors.textSecondary,
                      )
                    else
                      Text(
                        '${widget.index}',
                        style: KalinkaTextStyles.trackRowSubtitle,
                        textAlign: TextAlign.center,
                      ),
                    if (_longPressing && _longPressProgress > 0)
                      Positioned.fill(
                        child: CustomPaint(
                          painter: LongPressRingPainter(
                            progress: _longPressProgress,
                            color: KalinkaColors.accent,
                          ),
                        ),
                      ),
                  ],
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
              if (!selectionMode) ...[
                if (duration != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      duration,
                      style: KalinkaTextStyles.trackRowSubtitle,
                    ),
                  ),
              ],
            ],
          ),
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
