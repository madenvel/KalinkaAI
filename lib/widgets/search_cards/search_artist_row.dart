import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data_model/data_model.dart';
import '../../providers/browse_detail_provider.dart';
import '../../providers/kalinka_player_api_provider.dart';
import '../../providers/search_state_provider.dart';
import '../../providers/selection_state_provider.dart';
import '../../providers/url_resolver.dart';
import '../../theme/app_theme.dart';
import '../../utils/play_next.dart';
import '../procedural_album_art.dart';
import '../source_badge.dart';
import '../swipe_to_act_row.dart';
import 'long_press_ring_painter.dart';
import '../../providers/toast_provider.dart';
import 'expand_chevron_button.dart';
import 'search_album_row.dart';
import 'track_row_support.dart';

const _dimmedColor = Color(0xFF48485A);

/// Artist row for search results.
/// Collapsed: 52x52 circular avatar, name, stats, Top Tracks + Browse buttons.
/// Browse expands into a two-level tree: album rows with inline track lists.
class SearchArtistRow extends ConsumerStatefulWidget {
  final BrowseItem item;

  const SearchArtistRow({super.key, required this.item});

  @override
  ConsumerState<SearchArtistRow> createState() => _SearchArtistRowState();
}

class _SearchArtistRowState extends ConsumerState<SearchArtistRow> {
  void _toggleExpand() {
    ref.read(searchStateProvider.notifier).toggleArtistExpanded(widget.item.id);
  }

  @override
  Widget build(BuildContext context) {
    final isExpanded = ref.watch(
      searchStateProvider.select(
        (s) => s.expandedArtistIds.contains(widget.item.id),
      ),
    );

    final artist = widget.item.artist;
    final name = artist?.name ?? widget.item.name ?? 'Unknown';
    final albumCount = artist?.albumCount;

    final urlResolver = ref.read(urlResolverProvider);
    final imageUrl = widget.item.image?.small;
    final resolvedImageUrl = imageUrl != null
        ? urlResolver.abs(imageUrl)
        : null;

    final statsParts = <String>[];
    if (albumCount != null) statsParts.add('$albumCount albums');
    final stats = statsParts.join(' \u00B7 ');

    return Column(
      children: [
        // Artist header row
        GestureDetector(
          onTap: _toggleExpand,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: EdgeInsets.only(
              top: 10,
              bottom: 10,
              left: isExpanded ? 0 : 3,
              right: 4,
            ),
            decoration: BoxDecoration(
              color: isExpanded
                  ? KalinkaColors.surfaceRaised
                  : Colors.transparent,
              border: isExpanded
                  ? Border(
                      left: BorderSide(
                        color: KalinkaColors.gold.withValues(alpha: 0.40),
                        width: 3,
                      ),
                    )
                  : null,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 52),
              child: Row(
                children: [
                  // Circular avatar 52x52
                  // Note: previously wrapped in a Container with
                  // BoxShadow(blurRadius: 14). The 14px blur is GPU-
                  // expensive (~5x cost of a 6px blur) and forces a
                  // saveLayer per artist row. Removed to keep scroll smooth
                  // when the BASED ON NOW PLAYING section surfaces several
                  // artist rows in the first viewport.
                  SizedBox(
                    width: 52,
                    height: 52,
                    child: ClipOval(
                      child: resolvedImageUrl != null
                          ? Image(
                              // ResizeImage.fit preserves aspect ratio at decode
                              // time. The Image.network shortcut wraps with the
                              // default ResizeImagePolicy.exact, which squashes
                              // non-square artist photos into 156x156 — visible
                              // as stretching even after BoxFit.cover.
                              image: ResizeImage(
                                NetworkImage(resolvedImageUrl),
                                width: 156,
                                height: 156,
                                policy: ResizeImagePolicy.fit,
                              ),
                              width: 52,
                              height: 52,
                              fit: BoxFit.cover,
                              gaplessPlayback: true,
                              filterQuality: FilterQuality.low,
                              errorBuilder: (_, __, ___) => ProceduralAlbumArt(
                                trackId: widget.item.id,
                                size: 52,
                              ),
                            )
                          : ProceduralAlbumArt(
                              trackId: widget.item.id,
                              size: 52,
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Name (with source badge) + stats
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            if (sourceBadgeVisible(ref, widget.item.id)) ...[
                              SourceBadge(entityId: widget.item.id),
                              const SizedBox(width: 6),
                            ],
                            Flexible(
                              child: Text(
                                name,
                                style: KalinkaTextStyles.trackRowTitle.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (stats.isNotEmpty)
                          Text(
                            stats,
                            style: KalinkaTextStyles.trackRowSubtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Chevron button
                  ExpandChevronButton(
                    isExpanded: isExpanded,
                    onTap: _toggleExpand,
                  ),
                ],
              ),
            ),
          ),
        ),
        // Expanded section
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: isExpanded
              ? _ArtistExpansionContent(
                  artistId: widget.item.id,
                  artistName: artist?.name ?? widget.item.name ?? 'Unknown',
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

// ---------------------------------------------------------------------------
// Expansion content: album rows + singles + "N more" row
// ---------------------------------------------------------------------------

class _ArtistExpansionContent extends ConsumerWidget {
  final String artistId;
  final String artistName;

  const _ArtistExpansionContent({
    required this.artistId,
    required this.artistName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final browseAsync = ref.watch(browseDetailProvider(artistId));
    final showAllAlbums = ref.watch(
      searchStateProvider.select(
        (s) => s.artistMoreAlbumsExpanded.contains(artistId),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: browseAsync.when(
        data: (browseList) {
          final allItems = browseList.items;
          // Separate browsable albums from loose tracks
          final albums = allItems.where((item) => item.canBrowse).toList();
          final looseTracks = allItems
              .where((item) => item.track != null && !item.canBrowse)
              .toList();

          // Determine albums to display
          final maxInitial = albums.length > 4 ? 3 : albums.length;
          final displayAlbums = showAllAlbums
              ? albums
              : albums.take(maxInitial).toList();
          final moreCount = albums.length - maxInitial;

          if (albums.isEmpty && looseTracks.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No albums found',
                style: KalinkaTextStyles.trackRowSubtitle,
              ),
            );
          }

          return Column(
            children: [
              // Album rows — reuse the same SearchAlbumRow as top-level
              for (int i = 0; i < displayAlbums.length; i++) ...[
                SearchAlbumRow(item: displayAlbums[i]),
                if (i < displayAlbums.length - 1)
                  const Divider(
                    color: KalinkaColors.borderSubtle,
                    thickness: 1,
                    height: 1,
                  ),
              ],
              // "N more albums" row
              if (!showAllAlbums && moreCount > 0)
                GestureDetector(
                  onTap: () => ref
                      .read(searchStateProvider.notifier)
                      .revealArtistMoreAlbums(artistId),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Text(
                      '\u00B7\u00B7\u00B7 $moreCount more albums',
                      style: KalinkaTextStyles.showMoreLabel,
                    ),
                  ),
                ),
              // Singles & Loose Tracks
              if (looseTracks.isNotEmpty)
                _SinglesSection(
                  tracks: looseTracks,
                  artistId: artistId,
                  artistName: artistName,
                ),
            ],
          );
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
            'Failed to load albums',
            style: KalinkaTextStyles.trackRowSubtitle,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Individual track row within album expansion (used by _SinglesSection)
// ---------------------------------------------------------------------------

class _ArtistTrackRow extends ConsumerStatefulWidget {
  final BrowseItem item;
  final int index;
  final String containerId;

  const _ArtistTrackRow({
    required this.item,
    required this.index,
    required this.containerId,
  });

  @override
  ConsumerState<_ArtistTrackRow> createState() => _ArtistTrackRowState();
}

class _ArtistTrackRowState extends ConsumerState<_ArtistTrackRow>
    with LongPressRingMixin {
  Future<void> _playTrack() async {
    final api = ref.read(kalinkaProxyProvider);
    try {
      await api.clear();
      if (widget.containerId.startsWith('singles_')) {
        await api.add([widget.item.id]);
        // Explicit index 0 avoids a backend race where a stale FINISHED event
        // from the just-cleared stream advances current_track_id before play().
        await api.play(0);
      } else {
        await api.add([widget.containerId]);
        await api.play(widget.index - 1);
      }
    } catch (e) {
      showSafeToast('Failed to play: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final track = widget.item.track;
    final title = track?.title ?? widget.item.name ?? 'Unknown';
    final duration = formatTrackDuration(
      track?.duration != null ? track!.duration * 1000 : null,
    );

    final selection = ref.watch(selectionStateProvider);
    final selectionMode = selection.isActive;
    // Loose tracks select individually — the 'singles_<artistId>' key is
    // synthetic and has no browseDetailProvider backing.
    final isSelected = selection.selectedIds.contains(widget.item.id);
    final inSelectionHighlight = isSelected;

    return SwipeToActRow(
      enabled: !selectionMode,
      onAddToQueue: () => addTrackToQueue(widget.item),
      onPlayNext: () => playTrackNext(widget.item),
      child: GestureDetector(
        onTap: () {
          if (selectionMode) {
            ref.read(selectionStateProvider.notifier).toggle(widget.item.id);
          } else {
            _playTrack();
          }
        },
        onLongPressStart: selectionMode
            ? null
            : (_) => startLongPressRing(
                () => ref
                    .read(selectionStateProvider.notifier)
                    .enterSelectionMode(widget.item.id),
              ),
        onLongPressEnd: selectionMode ? null : (_) => cancelLongPressRing(),
        onLongPressCancel: selectionMode ? null : cancelLongPressRing,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selectionMode && inSelectionHighlight
                ? KalinkaColors.accent.withValues(alpha: 0.05)
                : Colors.transparent,
          ),
          child: Row(
            children: [
              // Track number / long-press indicator / selection icon
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
                    if (longPressing && longPressProgress > 0)
                      Positioned.fill(
                        child: CustomPaint(
                          painter: LongPressRingPainter(
                            progress: longPressProgress,
                            color: KalinkaColors.accent,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Title
              Expanded(
                child: Text(
                  title,
                  style: KalinkaTextStyles.trackRowTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Duration
              if (!selectionMode)
                if (duration != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      duration,
                      style: KalinkaTextStyles.trackRowSubtitle,
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Singles & Loose Tracks pseudo-album section
// ---------------------------------------------------------------------------

class _SinglesSection extends ConsumerStatefulWidget {
  final List<BrowseItem> tracks;
  final String artistId;
  final String artistName;

  const _SinglesSection({
    required this.tracks,
    required this.artistId,
    required this.artistName,
  });

  @override
  ConsumerState<_SinglesSection> createState() => _SinglesSectionState();
}

class _SinglesSectionState extends ConsumerState<_SinglesSection>
    with LongPressRingMixin {
  bool _expanded = false;

  /// Loose tracks have no real container, so "select the whole singles bucket"
  /// is just selecting/clearing every loose track id individually.
  void _toggleSelectAll(bool anySelected) {
    final ids = widget.tracks.map((t) => t.id);
    final notifier = ref.read(selectionStateProvider.notifier);
    if (anySelected) {
      notifier.deselectTracks(ids);
    } else {
      notifier.selectTracks(ids);
    }
  }

  Future<void> _addToQueue() async {
    final api = ref.read(kalinkaProxyProvider);
    final ids = widget.tracks.map((t) => t.id).toList();
    await runQueueActivity(
      pending: 'Adding to queue…',
      action: () => api.add(ids),
      done: (r) {
        final n = r.count ?? widget.tracks.length;
        return '$n ${n == 1 ? 'track' : 'tracks'} by ${widget.artistName} '
            'added to queue';
      },
      failed: (e) => 'Failed to add: $e',
    );
  }

  Future<void> _playNext() async {
    final api = ref.read(kalinkaProxyProvider);
    final ids = widget.tracks.map((t) => t.id).toList();
    final insertIndex = playNextInsertIndex(ref);
    await runQueueActivity(
      pending: 'Queueing next…',
      action: () => api.add(ids, index: insertIndex),
      done: (r) {
        final n = r.count ?? widget.tracks.length;
        return '$n ${n == 1 ? 'track' : 'tracks'} by ${widget.artistName} '
            'playing next';
      },
      failed: (e) => 'Failed to add: $e',
    );
  }

  @override
  Widget build(BuildContext context) {
    final singlesKey = 'singles_${widget.artistId}';
    final showAllTracks = ref.watch(
      searchStateProvider.select(
        (s) => s.albumMoreTracksExpanded.contains(singlesKey),
      ),
    );
    final selection = ref.watch(selectionStateProvider);
    final selectionMode = selection.isActive;
    final anySelected = widget.tracks.any(
      (t) => selection.selectedIds.contains(t.id),
    );
    final allSelected =
        widget.tracks.isNotEmpty &&
        widget.tracks.every((t) => selection.selectedIds.contains(t.id));
    final isPartial = anySelected && !allSelected;
    final showSelected = selectionMode && anySelected;

    return Column(
      children: [
        // Singles header row — mirrors SearchAlbumRow (list icon for artwork).
        SwipeToActRow(
          enabled: !selectionMode,
          onAddToQueue: _addToQueue,
          onPlayNext: _playNext,
          child: GestureDetector(
            onTap: () {
              if (selectionMode) {
                _toggleSelectAll(anySelected);
              } else {
                setState(() => _expanded = !_expanded);
              }
            },
            onLongPressStart: selectionMode
                ? null
                : (_) => startLongPressRing(() => _toggleSelectAll(false)),
            onLongPressEnd: selectionMode ? null : (_) => cancelLongPressRing(),
            onLongPressCancel: selectionMode ? null : cancelLongPressRing,
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: EdgeInsets.only(
                top: 8,
                bottom: 8,
                left: _expanded || showSelected ? 0 : 3,
                right: 0,
              ),
              decoration: BoxDecoration(
                color: showSelected
                    ? KalinkaColors.accent.withValues(alpha: 0.07)
                    : _expanded
                    ? KalinkaColors.surfaceRaised
                    : Colors.transparent,
                border: showSelected
                    ? const Border(
                        left: BorderSide(color: KalinkaColors.accent, width: 3),
                      )
                    : _expanded
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
                  // List icon, sized like the 60x60 album thumbnail
                  SizedBox(
                    width: 60,
                    height: 60,
                    child: Stack(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: KalinkaColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.queue_music,
                            size: 22,
                            color: _dimmedColor,
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
                        if (showSelected)
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
                  // Title + count
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Singles & Loose Tracks',
                          style: KalinkaTextStyles.trackRowTitle.copyWith(
                            color: showSelected
                                ? KalinkaColors.accentTint
                                : null,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${widget.tracks.length} '
                          '${widget.tracks.length == 1 ? 'track' : 'tracks'}',
                          style: KalinkaTextStyles.trackRowSubtitle,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  ExpandChevronButton(
                    isExpanded: _expanded,
                    onTap: () => setState(() => _expanded = !_expanded),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Expanded track list
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: _expanded
              ? _buildTrackList(showAllTracks, ref)
              : const SizedBox.shrink(),
          crossFadeState: _expanded
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

  Widget _buildTrackList(bool showAll, WidgetRef ref) {
    final tracks = widget.tracks;
    final maxInitial = tracks.length > 5 ? 4 : tracks.length;
    final displayTracks = showAll ? tracks : tracks.take(maxInitial).toList();
    final moreCount = tracks.length - maxInitial;
    final singlesKey = 'singles_${widget.artistId}';

    return Container(
      margin: const EdgeInsets.only(left: 16),
      decoration: const BoxDecoration(
        border: Border(
          left: BorderSide(
            color: KalinkaColors.borderSubtle,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          for (int i = 0; i < displayTracks.length; i++) ...[
            _ArtistTrackRow(
              item: displayTracks[i],
              index: i + 1,
              containerId: singlesKey,
            ),
            if (i < displayTracks.length - 1)
              const Divider(
                color: KalinkaColors.borderSubtle,
                thickness: 1,
                height: 1,
              ),
          ],
          if (!showAll && moreCount > 0)
            GestureDetector(
              onTap: () => ref
                  .read(searchStateProvider.notifier)
                  .revealAlbumMoreTracks(singlesKey),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Text(
                  '\u00B7\u00B7\u00B7 $moreCount more tracks',
                  style: KalinkaTextStyles.showMoreLabel,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
