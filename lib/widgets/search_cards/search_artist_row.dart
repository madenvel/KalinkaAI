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
import '../../providers/url_resolver.dart';
import '../../providers/source_modules_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/play_next.dart';
import '../procedural_album_art.dart';
import '../source_badge.dart';
import '../swipe_to_act_row.dart';
import 'long_press_ring_painter.dart';
import '../../providers/toast_provider.dart';
import 'expand_chevron_button.dart';
import 'search_album_row.dart';

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
    final searchState = ref.watch(searchStateProvider);
    final isExpanded = searchState.expandedArtistIds.contains(widget.item.id);

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
              top: 10, bottom: 10,
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
                  SizedBox(
                    width: 52,
                    height: 52,
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: resolvedImageUrl != null
                            ? Image.network(
                                resolvedImageUrl,
                                width: 52,
                                height: 52,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    ProceduralAlbumArt(
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
                  ),
                  const SizedBox(width: 12),
                  // Name + stats
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          name,
                          style: KalinkaTextStyles.trackRowTitle.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SourceBadge(entityId: widget.item.id),
                            if (stats.isNotEmpty) ...[
                              if (ref.watch(sourceCountProvider) > 1)
                                const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  stats,
                                  style: KalinkaTextStyles.trackRowSubtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
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
    final searchState = ref.watch(searchStateProvider);
    final showAllAlbums = searchState.artistMoreAlbumsExpanded.contains(
      artistId,
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

class _ArtistTrackRowState extends ConsumerState<_ArtistTrackRow> {
  // Long-press ring animation
  bool _longPressing = false;
  double _longPressProgress = 0.0;
  Timer? _longPressTimer;

  @override
  void dispose() {
    _longPressTimer?.cancel();
    super.dispose();
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

  Future<void> _playTrack() async {
    final api = ref.read(kalinkaProxyProvider);
    try {
      await api.clear();
      if (widget.containerId.startsWith('singles_')) {
        await api.add([widget.item.id]);
        await api.play();
      } else {
        await api.add([widget.containerId]);
        await api.play(widget.index - 1);
      }
    } catch (e) {
      showSafeToast('Failed to play: $e', isError: true);
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
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: selectionMode && inSelectionHighlight
                ? KalinkaColors.accent.withValues(alpha: 0.07)
                : KalinkaColors.surfaceInput,
          ),
          child: Row(
            children: [
              // Track number / long-press indicator / selection icon
              SizedBox(
                width: 20,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (selectionMode)
                      Icon(
                        inSelectionHighlight
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        size: 14,
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
              // Title
              Expanded(
                child: Text(
                  title,
                  style: KalinkaTextStyles.trackRowTitle.copyWith(
                    fontSize: KalinkaTypography.baseSize + 2,
                    color: selectionMode && containerSelected && !trackSelected
                        ? KalinkaColors.textSecondary
                        : null,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Duration
              if (!selectionMode)
                if (duration != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
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

  String? _formatDuration(int? ms) {
    if (ms == null) return null;
    final seconds = ms ~/ 1000;
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
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

class _SinglesSectionState extends ConsumerState<_SinglesSection> {
  bool _expanded = false;

  Future<void> _addToQueue() async {
    final api = ref.read(kalinkaProxyProvider);
    final ids = widget.tracks.map((t) => t.id).toList();
    final message =
        '${widget.tracks.length} tracks by ${widget.artistName} added to queue';
    try {
      await api.add(ids);
      showSafeToast(message);
    } catch (e) {
      showSafeToast('Failed to add: $e', isError: true);
    }
  }

  Future<void> _playNext() async {
    final api = ref.read(kalinkaProxyProvider);
    final ids = widget.tracks.map((t) => t.id).toList();
    final message =
        '${widget.tracks.length} tracks by ${widget.artistName} playing next';
    try {
      await api.add(ids, index: playNextInsertIndex(ref));
      showSafeToast(message);
    } catch (e) {
      showSafeToast('Failed to add: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchStateProvider);
    final showAllTracks = searchState.albumMoreTracksExpanded.contains(
      'singles_${widget.artistId}',
    );
    final selectionMode = ref.watch(selectionStateProvider).isActive;

    return Column(
      children: [
        // Singles header row
        SwipeToActRow(
          enabled: !selectionMode,
          onAddToQueue: _addToQueue,
          onPlayNext: _playNext,
          child: GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: const BoxDecoration(
                color: KalinkaColors.surfaceRaised,
              ),
              child: Row(
                children: [
                  // List icon in 44x44 container
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: KalinkaColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.queue_music,
                      size: 16,
                      color: _dimmedColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Title + count
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Singles & Loose Tracks',
                          style: KalinkaTextStyles.trackRowTitle.copyWith(
                            color: KalinkaColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${widget.tracks.length} tracks',
                          style: KalinkaTextStyles.trackRowSubtitle,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Chevron
                  Material(
                    color: KalinkaColors.surfaceElevated,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(
                        color: KalinkaColors.borderDefault,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => setState(() => _expanded = !_expanded),
                      overlayColor: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.pressed)) {
                          return Colors.white.withValues(alpha: 0.08);
                        }
                        return null;
                      }),
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: AnimatedRotation(
                          turns: _expanded ? 0.5 : 0.0,
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOut,
                          child: const Icon(
                            Icons.expand_more,
                            size: 14,
                            color: KalinkaColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
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
      margin: const EdgeInsets.only(left: 8),
      decoration: BoxDecoration(
        color: KalinkaColors.surfaceInput,
        border: Border(
          left: BorderSide(
            color: KalinkaColors.gold.withValues(alpha: 0.18),
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
