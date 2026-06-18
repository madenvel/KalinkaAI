import 'package:flutter/material.dart';
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
import 'track_row_support.dart';

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

class _SearchPlaylistRowState extends ConsumerState<SearchPlaylistRow>
    with LongPressRingMixin {
  void _toggleExpand() {
    ref.read(searchStateProvider.notifier).toggleAlbumExpanded(widget.item.id);
  }

  Future<void> _addToQueue() async {
    final api = ref.read(kalinkaProxyProvider);
    final title = widget.item.playlist?.name ?? widget.item.name ?? 'playlist';
    await runQueueActivity(
      pending: 'Adding to queue…',
      action: () => api.add([widget.item.id]),
      done: (r) {
        final n = r.count ?? widget.item.playlist?.trackCount;
        return n != null
            ? '$title — $n ${n == 1 ? 'track' : 'tracks'} added to queue'
            : '$title added to queue';
      },
      failed: (e) => 'Failed to add: $e',
    );
  }

  Future<void> _playNext() async {
    final api = ref.read(kalinkaProxyProvider);
    final title = widget.item.playlist?.name ?? widget.item.name ?? 'playlist';
    final insertIndex = playNextInsertIndex(ref);
    await runQueueActivity(
      pending: 'Queueing next…',
      action: () => api.add([widget.item.id], index: insertIndex),
      done: (_) => '$title playing next',
      failed: (e) => 'Failed to add: $e',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isExpanded = ref.watch(
      searchStateProvider.select(
        (s) => s.expandedAlbumIds.contains(widget.item.id),
      ),
    );
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
      if (trackCount != null)
        '$trackCount ${trackCount == 1 ? 'track' : 'tracks'}',
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
            onLongPressStart: selectionMode
                ? null
                : (_) => startLongPressRing(
                    () => ref
                        .read(selectionStateProvider.notifier)
                        .toggleContainer(widget.item.id),
                  ),
            onLongPressEnd: selectionMode ? null : (_) => cancelLongPressRing(),
            onLongPressCancel: selectionMode ? null : cancelLongPressRing,
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: EdgeInsets.only(
                top: 8,
                bottom: 8,
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
                  // Thumbnail 56x56 with mosaic overlay
                  SizedBox(
                    width: 56,
                    height: 56,
                    child: Stack(
                      children: [
                        // Note: previously wrapped in a Container with
                        // BoxShadow(blurRadius: 6). Removed for the same
                        // GPU/saveLayer reason as the album row — see
                        // comment in search_album_row.dart.
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Stack(
                            children: [
                              if (resolvedImageUrl != null)
                                Image.network(
                                  resolvedImageUrl,
                                  fit: BoxFit.cover,
                                  width: 56,
                                  height: 56,
                                  cacheWidth: 168,
                                  cacheHeight: 168,
                                  gaplessPlayback: true,
                                  filterQuality: FilterQuality.low,
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
                              // Playlist marker badge — bottom-right corner
                              const Positioned(
                                right: 3,
                                bottom: 3,
                                child: _PlaylistBadge(),
                              ),
                            ],
                          ),
                        ),
                        // Long-press ring
                        if (longPressing && longPressProgress > 0)
                          Positioned.fill(
                            child: CustomPaint(
                              painter: LongPressRingPainter(
                                progress: longPressProgress,
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
                              SourceBadge(entityId: widget.item.id),
                              if (ref.watch(sourceCountProvider) > 1)
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
                  child: _ExpandedPlaylistTracks(playlistId: widget.item.id),
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

class _ExpandedPlaylistTracks extends ConsumerWidget {
  final String playlistId;

  const _ExpandedPlaylistTracks({required this.playlistId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracksAsync = ref.watch(browseDetailProvider(playlistId));

    return tracksAsync.when(
      data: (browseList) => _buildTrackList(browseList.items, ref),
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
    return Column(
      children: [
        for (int i = 0; i < items.length; i++) ...[
          _InlinePlaylistTrack(
            item: items[i],
            index: i + 1,
            containerId: playlistId,
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

class _InlinePlaylistTrackState extends ConsumerState<_InlinePlaylistTrack>
    with SingleTickerProviderStateMixin, LongPressRingMixin {
  // ── Play-on-tap flash animation (mirrors the album inline track row) ──────
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

  @override
  Widget build(BuildContext context) {
    final track = widget.item.track;
    final title = track?.title ?? widget.item.name ?? 'Unknown';
    final artist = track?.performer?.name ?? '';
    final album = track?.album?.title ?? '';
    final subtitle = [
      artist,
      album,
    ].where((s) => s.isNotEmpty).join(' \u00B7 ');
    final duration = formatTrackDuration(
      track?.duration != null ? track!.duration * 1000 : null,
    );
    final urlResolver = ref.read(urlResolverProvider);
    final imageUrl =
        widget.item.image?.small ??
        widget.item.image?.thumbnail ??
        widget.item.image?.large;
    final resolvedImageUrl = imageUrl != null
        ? urlResolver.abs(imageUrl)
        : null;

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

    // Now-playing detection — scope the watch so we don't rebuild on every
    // position tick (PlaybackState.position updates frequently while playing).
    final currentTrackId = ref.watch(
      playerStateProvider.select((s) => s.currentTrack?.id),
    );
    final isCurrentTrack =
        widget.item.id.isNotEmpty && currentTrackId == widget.item.id;

    // Clear optimistic flash once server confirms, or revert if different track.
    ref.listen(playerStateProvider.select((s) => s.currentTrack?.id), (
      prev,
      next,
    ) {
      if (!mounted) return;
      if (next == widget.item.id && _tappedToPlay) {
        setState(() => _tappedToPlay = false);
      } else if (_tappedToPlay && next != null && next != widget.item.id) {
        _flashController.reset();
        setState(() => _tappedToPlay = false);
      }
    });

    // Now-playing row decoration (only outside selection mode).
    final showNowPlaying = !selectionMode && (_tappedToPlay || isCurrentTrack);
    final Color rowBg;
    if (selectionMode && inSelectionHighlight) {
      rowBg = KalinkaColors.accent.withValues(alpha: 0.07);
    } else if (showNowPlaying && _flashController.isAnimating) {
      rowBg = _flashColorAnim.value ?? Colors.transparent;
    } else if (showNowPlaying) {
      rowBg = KalinkaColors.accentSubtle;
    } else {
      rowBg = Colors.transparent;
    }

    // Left-edge now-playing bar, drawn as an overlay so it doesn't push
    // content right the way the selection Border does.
    final Color? barColor = showNowPlaying ? KalinkaColors.accentBorder : null;

    return SwipeToActRow(
      enabled: !selectionMode,
      onAddToQueue: () => addTrackToQueue(widget.item),
      onPlayNext: () => playTrackNext(widget.item),
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
        onLongPressStart: selectionMode
            ? null
            : (_) => startLongPressRing(
                () => ref
                    .read(selectionStateProvider.notifier)
                    .selectSingleTrackInContainer(
                      widget.containerId,
                      widget.item.id,
                    ),
              ),
        onLongPressEnd: selectionMode ? null : (_) => cancelLongPressRing(),
        onLongPressCancel: selectionMode ? null : cancelLongPressRing,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: rowBg,
                border: selectionMode && inSelectionHighlight
                    ? const Border(
                        left: BorderSide(color: KalinkaColors.accent, width: 2),
                      )
                    : null,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Artwork + selection overlay (search-results style)
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: resolvedImageUrl != null
                              ? Image.network(
                                  resolvedImageUrl,
                                  width: 44,
                                  height: 44,
                                  cacheWidth: 132,
                                  cacheHeight: 132,
                                  fit: BoxFit.cover,
                                  gaplessPlayback: true,
                                  filterQuality: FilterQuality.low,
                                  errorBuilder: (_, __, ___) =>
                                      ProceduralAlbumArt(
                                        trackId: widget.item.id,
                                        size: 44,
                                      ),
                                )
                              : ProceduralAlbumArt(
                                  trackId: widget.item.id,
                                  size: 44,
                                ),
                        ),
                        if (longPressing && longPressProgress > 0)
                          Positioned.fill(
                            child: CustomPaint(
                              painter: LongPressRingPainter(
                                progress: longPressProgress,
                                color: KalinkaColors.accent,
                              ),
                            ),
                          ),
                        if (selectionMode && inSelectionHighlight)
                          Container(
                            decoration: BoxDecoration(
                              color: KalinkaColors.accent.withValues(
                                alpha: 0.4,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: KalinkaTextStyles.trackRowTitle.copyWith(
                            color:
                                selectionMode &&
                                    containerSelected &&
                                    !trackSelected
                                ? KalinkaColors.textSecondary
                                : null,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        if (subtitle.isNotEmpty)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              SourceBadge(
                                entityId: widget.item.id,
                                size: SourceBadgeSize.small,
                              ),
                              if (ref.watch(sourceCountProvider) > 1)
                                const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  subtitle,
                                  style: KalinkaTextStyles.trackRowSubtitle
                                      .copyWith(
                                        color:
                                            selectionMode &&
                                                containerSelected &&
                                                !trackSelected
                                            ? KalinkaColors.textMuted
                                            : null,
                                      ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                      ],
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
}

/// Tiny corner glyph that marks a thumbnail as a playlist (a collection of
/// tracks) rather than a single album.
class _PlaylistBadge extends StatelessWidget {
  const _PlaylistBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Icon(Icons.queue_music, size: 11, color: Colors.white),
    );
  }
}
