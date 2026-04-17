import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data_model/data_model.dart';
import '../../providers/app_state_provider.dart';
import '../../providers/browse_detail_provider.dart';
import '../../providers/kalinka_player_api_provider.dart';
import '../../providers/search_state_provider.dart';
import '../../providers/selection_state_provider.dart';
import '../../providers/toast_provider.dart';
import '../../providers/url_resolver.dart';
import '../../providers/source_modules_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/play_next.dart';
import '../procedural_album_art.dart';
import '../source_badge.dart';
import '../swipe_to_act_row.dart';
import 'expand_chevron_button.dart';
import 'long_press_ring_painter.dart';

/// Album row for search results.
/// 56x56 thumbnail, title/artist/year/trackCount, tag pills, expand chevron.
/// Tap = expand inline track list. Swipe right = add to queue / play next.
/// Long-press enters multi-select mode.
class SearchAlbumRow extends ConsumerStatefulWidget {
  final BrowseItem item;

  const SearchAlbumRow({super.key, required this.item});

  @override
  ConsumerState<SearchAlbumRow> createState() => _SearchAlbumRowState();
}

class _SearchAlbumRowState extends ConsumerState<SearchAlbumRow> {
  // Long-press ring animation (row long-press → multi-select)
  bool _longPressing = false;
  double _longPressProgress = 0.0;
  Timer? _longPressTimer;

  void _toggleExpand() {
    ref.read(searchStateProvider.notifier).toggleAlbumExpanded(widget.item.id);
  }

  Future<void> _addToQueue() async {
    final api = ref.read(kalinkaProxyProvider);
    final name = widget.item.album?.title ?? widget.item.name ?? 'album';
    final trackCount = widget.item.album?.trackCount;
    try {
      await api.add([widget.item.id]);
      showSafeToast('$name — ${trackCount ?? ''} tracks added to queue');
    } catch (e) {
      showSafeToast('Failed to add: $e', isError: true);
    }
  }

  Future<void> _playNext() async {
    final api = ref.read(kalinkaProxyProvider);
    final name = widget.item.album?.title ?? widget.item.name ?? 'album';
    try {
      await api.add([widget.item.id], index: playNextInsertIndex(ref));
      showSafeToast('$name playing next');
    } catch (e) {
      showSafeToast('Failed to add: $e', isError: true);
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

  @override
  void dispose() {
    _longPressTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchStateProvider);
    final isExpanded = searchState.expandedAlbumIds.contains(widget.item.id);

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
      if (trackCount != null) '$trackCount ${trackCount == 1 ? 'track' : 'tracks'}',
    ];
    final subtitle = subtitleParts.join(' \u00B7 ');

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
              padding: EdgeInsets.only(
                top: 8, bottom: 8,
                left: isExpanded || (selectionMode && isSelected) ? 0 : 3,
                right: 0,
              ),
              decoration: BoxDecoration(
                color: selectionMode && isSelected
                    ? KalinkaColors.accent.withValues(alpha: 0.07)
                    : isExpanded
                        ? KalinkaColors.surfaceRaised
                        : Colors.transparent,
                border: selectionMode && isSelected
                    ? const Border(
                        left: BorderSide(color: KalinkaColors.accent, width: 3),
                      )
                    : isExpanded
                        ? Border(
                            left: BorderSide(
                              color: KalinkaColors.accent.withValues(alpha: 0.40),
                              width: 3,
                            ),
                          )
                        : null,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Thumbnail 56x56 with selection overlay
                  SizedBox(
                    width: 60,
                    height: 60,
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
                                    width: 60,
                                    height: 60,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        ProceduralAlbumArt(
                                          trackId: widget.item.id,
                                          size: 60,
                                        ),
                                  )
                                : ProceduralAlbumArt(
                                    trackId: widget.item.id,
                                    size: 60,
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
                                  alpha: 0.4,
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
                          style: KalinkaTextStyles.trackRowTitle.copyWith(
                            color: selectionMode && isSelected
                                ? KalinkaColors.accentTint
                                : null,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (subtitle.isNotEmpty)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              if (!(selectionMode && isSelected))
                                SourceBadge(entityId: widget.item.id),
                              if (!(selectionMode && isSelected) &&
                                  ref.watch(sourceCountProvider) > 1)
                                const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  subtitle,
                                  style: KalinkaTextStyles.trackRowSubtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        if (genre != null) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: KalinkaColors.surfaceElevated,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              genre,
                              style: KalinkaTextStyles.tagPill,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  ExpandChevronButton(
                    isExpanded: isExpanded,
                    onTap: _toggleExpand,
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
              ? Container(
                  margin: const EdgeInsets.only(left: 16),
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(
                        color: KalinkaColors.borderSubtle,
                        width: 1,
                      ),
                    ),
                  ),
                  child: _ExpandedAlbumTracks(albumId: widget.item.id),
                )
              : const SizedBox.shrink(),
          crossFadeState: isExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
          firstCurve: Curves.easeOut,
          secondCurve: Curves.easeOut,
          sizeCurve: Curves.easeOut,
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

    return tracksAsync.when(
        data: (browseList) {
          final tracks = browseList.items
              .where((item) => item.track != null)
              .toList();

          if (tracks.isEmpty) {
            return _buildTrackList(browseList.items, ref);
          }
          return _buildTrackList(tracks, ref);
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
    );
  }

  Widget _buildTrackList(List<BrowseItem> items, WidgetRef ref) {
    final currentTrackId = ref.watch(
      playerStateProvider.select((s) => s.currentTrack?.id),
    );
    final hasPlayingSibling = items.any((item) => item.id == currentTrackId);

    return Column(
      children: [
        for (int i = 0; i < items.length; i++) ...[
          _InlineTrackRow(
            item: items[i],
            index: i + 1,
            containerId: albumId,
            siblingIsPlaying:
                hasPlayingSibling && items[i].id != currentTrackId,
          ),
          if (i < items.length - 1)
            const Divider(
              color: KalinkaColors.borderSubtle,
              thickness: 1,
              height: 1,
            ),
        ],
      ],
    );
  }
}

class _InlineTrackRow extends ConsumerStatefulWidget {
  final BrowseItem item;
  final int index;
  final String containerId;
  final bool siblingIsPlaying;

  const _InlineTrackRow({
    required this.item,
    required this.index,
    required this.containerId,
    required this.siblingIsPlaying,
  });

  @override
  ConsumerState<_InlineTrackRow> createState() => _InlineTrackRowState();
}

class _InlineTrackRowState extends ConsumerState<_InlineTrackRow>
    with SingleTickerProviderStateMixin {
  bool _longPressing = false;
  double _longPressProgress = 0.0;
  Timer? _longPressTimer;

  // ── Play-on-tap flash animation ──────────────────────────────────────────
  late final AnimationController _flashController;
  late final Animation<Color?> _flashColorAnim;
  bool _tappedToPlay = false;

  @override
  void initState() {
    super.initState();
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _flashColorAnim = TweenSequence<Color?>([
      TweenSequenceItem(
        tween: ColorTween(
          begin: Colors.transparent,
          end: KalinkaColors.accent.withValues(alpha: 0.15),
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: ColorTween(
          begin: KalinkaColors.accent.withValues(alpha: 0.15),
          end: KalinkaColors.accentSubtle,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 2,
      ),
    ]).animate(_flashController);
    _flashController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _flashController.dispose();
    _longPressTimer?.cancel();
    super.dispose();
  }

  Future<void> _playTrack() async {
    // Start flash animation immediately on tap, before the async API call.
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    setState(() => _tappedToPlay = true);
    if (!reduceMotion) _flashController.forward(from: 0.0);

    final api = ref.read(kalinkaProxyProvider);
    try {
      await api.clear();
      await api.add([widget.containerId]);
      await api.play(widget.index - 1);
    } catch (e) {
      // API failed — revert optimistic flash.
      if (mounted) {
        _flashController.reset();
        setState(() => _tappedToPlay = false);
      }
      showSafeToast('Failed to play: $e', isError: true);
    }
  }

  Future<void> _addToQueue() async {
    final api = ref.read(kalinkaProxyProvider);
    final title = widget.item.track?.title ?? widget.item.name ?? 'track';
    try {
      await api.add([widget.item.id]);
      showSafeToast('"$title" added to queue');
    } catch (e) {
      showSafeToast('Failed to add: $e', isError: true);
    }
  }

  Future<void> _playNext() async {
    final api = ref.read(kalinkaProxyProvider);
    final title = widget.item.track?.title ?? widget.item.name ?? 'track';
    try {
      await api.add([widget.item.id], index: playNextInsertIndex(ref));
      showSafeToast('"$title" playing next');
    } catch (e) {
      showSafeToast('Failed to add: $e', isError: true);
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
            .selectSingleTrackInContainer(widget.containerId, widget.item.id);
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

    // Now-playing detection
    final playerState = ref.watch(playerStateProvider);
    final isCurrentTrack =
        widget.item.id.isNotEmpty &&
        playerState.currentTrack?.id == widget.item.id;

    // Clear optimistic flash once server confirms, or revert if different track.
    ref.listen(
      playerStateProvider.select((s) => s.currentTrack?.id),
      (prev, next) {
        if (!mounted) return;
        if (next == widget.item.id && _tappedToPlay) {
          setState(() => _tappedToPlay = false);
        } else if (_tappedToPlay && next != null && next != widget.item.id) {
          _flashController.reset();
          setState(() => _tappedToPlay = false);
        }
      },
    );

    // Now-playing row decoration
    final showNowPlaying =
        !selectionMode && (_tappedToPlay || isCurrentTrack);
    final Color rowBg;
    if (selectionMode && inSelectionHighlight) {
      rowBg = KalinkaColors.accent.withValues(alpha: 0.05);
    } else if (showNowPlaying && _flashController.isAnimating) {
      rowBg = _flashColorAnim.value ?? Colors.transparent;
    } else if (showNowPlaying) {
      rowBg = KalinkaColors.accentSubtle;
    } else {
      rowBg = Colors.transparent;
    }

    // Left-edge indicator bar drawn as an overlay so it doesn't push content
    // right the way a Border would.
    final Color? barColor =
        showNowPlaying ? KalinkaColors.accentBorder : null;

    // Sibling dimming: animated fade-in (200ms), instant restore.
    final dimmed = widget.siblingIsPlaying && !selectionMode;
    final dimDuration = Duration(milliseconds: dimmed ? 200 : 0);

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
        child: Stack(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: rowBg),
              child: AnimatedOpacity(
            opacity: dimmed ? 0.7 : 1.0,
            duration: dimDuration,
            curve: Curves.easeOut,
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
            if (barColor != null)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: IgnorePointer(
                  child: Container(width: 2, color: barColor),
                ),
              ),
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
