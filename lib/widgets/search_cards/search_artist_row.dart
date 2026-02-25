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
import '../../theme/app_theme.dart';
import '../procedural_album_art.dart';
import '../source_badge.dart';
import '../swipe_to_act_row.dart';
import 'long_press_ring_painter.dart';
import '../../providers/toast_provider.dart';

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

class _SearchArtistRowState extends ConsumerState<SearchArtistRow>
    with SingleTickerProviderStateMixin {
  late AnimationController _topTracksConfirmController;
  late Animation<double> _topTracksScale;
  late Animation<Color?> _topTracksColor;
  bool _topTracksConfirmed = false;
  Timer? _topTracksResetTimer;

  @override
  void initState() {
    super.initState();
    _topTracksConfirmController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _topTracksScale =
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.85), weight: 20),
          TweenSequenceItem(tween: Tween(begin: 0.85, end: 1.15), weight: 50),
          TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0), weight: 30),
        ]).animate(
          CurvedAnimation(
            parent: _topTracksConfirmController,
            curve: Curves.easeInOut,
          ),
        );
    _topTracksColor = ColorTween(
      begin: KalinkaColors.accent,
      end: KalinkaColors.confirmGreen,
    ).animate(_topTracksConfirmController);
  }

  @override
  void dispose() {
    _topTracksConfirmController.dispose();
    _topTracksResetTimer?.cancel();
    super.dispose();
  }

  Future<void> _handleTopTracks() async {
    try {
      final api = ref.read(kalinkaProxyProvider);
      await api.add([widget.item.id]);
      if (!mounted) return;
      setState(() => _topTracksConfirmed = true);
      _topTracksConfirmController.forward(from: 0);
      _topTracksResetTimer?.cancel();
      _topTracksResetTimer = Timer(const Duration(milliseconds: 1400), () {
        if (mounted) {
          setState(() => _topTracksConfirmed = false);
          _topTracksConfirmController.reset();
        }
      });
      final name = widget.item.artist?.name ?? widget.item.name ?? 'Artist';
      ref.read(toastProvider.notifier).show('Top 5 by $name appended');
    } catch (e) {
      ref.read(toastProvider.notifier).show('Failed to queue: $e', isError: true);
    }
  }

  void _toggleExpand() {
    final searchNotifier = ref.read(searchStateProvider.notifier);
    final currentId = ref.read(searchStateProvider).artistPreviewId;
    if (currentId == widget.item.id) {
      searchNotifier.collapseArtistPreview();
    } else {
      searchNotifier.previewArtist(widget.item.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchStateProvider);
    final isExpanded = searchState.artistPreviewId == widget.item.id;

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
        // Collapsed row
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Row(
              children: [
                // Circular avatar 52x52
                SizedBox(
                  width: 52,
                  height: 52,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
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
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: SourceBadge(entityId: widget.item.id),
                      ),
                    ],
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
                        style: KalinkaTextStyles.cardTitle.copyWith(
                          letterSpacing: -0.14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (stats.isNotEmpty)
                        Text(stats, style: KalinkaTextStyles.trackRowSubtitle),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Top Tracks button
                AnimatedBuilder(
                  animation: _topTracksConfirmController,
                  builder: (context, child) {
                    final color = _topTracksConfirmed
                        ? _topTracksColor.value ?? KalinkaColors.accent
                        : KalinkaColors.accent;
                    return Transform.scale(
                      scale: _topTracksConfirmController.isAnimating
                          ? _topTracksScale.value
                          : 1.0,
                      child: GestureDetector(
                        onTap: _handleTopTracks,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(
                              color: color.withValues(alpha: 0.28),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            _topTracksConfirmed
                                ? '\u2713 QUEUED'
                                : '\u25B6 TOP',
                            style: KalinkaTextStyles.browseButtonLabel.copyWith(
                              color: color,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 6),
                // Browse / Close button
                GestureDetector(
                  onTap: _toggleExpand,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: KalinkaColors.pillSurface,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: KalinkaColors.borderElevated,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedCrossFade(
                          firstChild: Text(
                            'BROWSE',
                            style: KalinkaTextStyles.browseButtonLabel.copyWith(
                              color: KalinkaColors.textSecondary,
                            ),
                          ),
                          secondChild: Text(
                            'CLOSE',
                            style: KalinkaTextStyles.browseButtonLabel.copyWith(
                              color: KalinkaColors.textSecondary,
                            ),
                          ),
                          crossFadeState: isExpanded
                              ? CrossFadeState.showSecond
                              : CrossFadeState.showFirst,
                          duration: const Duration(milliseconds: 150),
                          firstCurve: Curves.easeOut,
                          secondCurve: Curves.easeOut,
                          sizeCurve: Curves.easeOut,
                        ),
                        const SizedBox(width: 4),
                        AnimatedRotation(
                          turns: isExpanded ? 0.5 : 0.0,
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOut,
                          child: const Icon(
                            Icons.expand_more,
                            size: 12,
                            color: KalinkaColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
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
          duration: const Duration(milliseconds: 340),
          firstCurve: Curves.easeInOutQuart,
          secondCurve: Curves.easeInOutQuart,
          sizeCurve: Curves.easeInOutQuart,
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

    return Container(
      decoration: const BoxDecoration(color: KalinkaColors.headerSurface),
      child: Container(
        margin: const EdgeInsets.only(left: 4),
        decoration: const BoxDecoration(
          border: Border(
            left: BorderSide(
              color: Color(0x40C23B5C), // accent at ~0.25 alpha
              width: 2,
            ),
          ),
        ),
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
                // Album rows
                for (final album in displayAlbums)
                  _ArtistAlbumRow(
                    item: album,
                    artistId: artistId,
                    artistName: artistName,
                  ),
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
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Album row within artist expansion
// ---------------------------------------------------------------------------

class _ArtistAlbumRow extends ConsumerStatefulWidget {
  final BrowseItem item;
  final String artistId;
  final String artistName;

  const _ArtistAlbumRow({
    required this.item,
    required this.artistId,
    required this.artistName,
  });

  @override
  ConsumerState<_ArtistAlbumRow> createState() => _ArtistAlbumRowState();
}

class _ArtistAlbumRowState extends ConsumerState<_ArtistAlbumRow> {
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
    try {
      final api = ref.read(kalinkaProxyProvider);
      await api.add([widget.item.id]);
      final name = widget.item.album?.title ?? widget.item.name ?? 'album';
      final trackCount = widget.item.album?.trackCount;
      ref.read(toastProvider.notifier).show('$name — ${trackCount ?? ''} tracks added to queue');
    } catch (e) {
      ref.read(toastProvider.notifier).show('Failed to add: $e', isError: true);
    }
  }

  Future<void> _playNext() async {
    try {
      final api = ref.read(kalinkaProxyProvider);
      await api.add([widget.item.id]);
      final name = widget.item.album?.title ?? widget.item.name ?? 'album';
      ref.read(toastProvider.notifier).show('$name playing next');
    } catch (e) {
      ref.read(toastProvider.notifier).show('Failed to add: $e', isError: true);
    }
  }

  void _toggleExpand() {
    final notifier = ref.read(searchStateProvider.notifier);
    final currentExpanded = ref
        .read(searchStateProvider)
        .expandedAlbumIdWithinArtist;
    if (currentExpanded == widget.item.id) {
      notifier.collapseAlbumWithinArtist();
    } else {
      notifier.expandAlbumWithinArtist(widget.item.id);
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
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchStateProvider);
    final isExpanded =
        searchState.expandedAlbumIdWithinArtist == widget.item.id;

    final selection = ref.watch(selectionStateProvider);
    final selectionMode = selection.isActive;

    final title = widget.item.album?.title ?? widget.item.name ?? 'Unknown';
    final subtitle = widget.item.subname ?? '';
    final trackCount = widget.item.album?.trackCount;

    final urlResolver = ref.read(urlResolverProvider);
    final imageUrl = widget.item.image?.small ?? widget.item.image?.thumbnail;
    final resolvedImageUrl = imageUrl != null
        ? urlResolver.abs(imageUrl)
        : null;

    // Build subtitle
    final subtitleParts = <String>[
      if (subtitle.isNotEmpty) subtitle,
      if (trackCount != null) '$trackCount tracks',
    ];
    final subtitleText = subtitleParts.join(' \u00B7 ');

    final isSelected = selection.isContainerSelected(widget.item.id);
    final isPartial = selection.isContainerPartial(widget.item.id);

    return Column(
      children: [
        // Album row
        SwipeToActRow(
          enabled: !selectionMode,
          onAddToQueue: _addToQueue,
          onPlayNext: _playNext,
          child: GestureDetector(
            onTap: selectionMode
                ? () => ref
                      .read(selectionStateProvider.notifier)
                      .toggleContainer(widget.item.id)
                : _toggleExpand,
            onLongPressStart: selectionMode ? null : (_) => _startLongPress(),
            onLongPressEnd: selectionMode ? null : (_) => _cancelLongPress(),
            onLongPressCancel: selectionMode ? null : _cancelLongPress,
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: selectionMode && isSelected
                    ? KalinkaColors.accent.withValues(alpha: 0.07)
                    : KalinkaColors.miniPlayerSurface,
                border: selectionMode && isSelected
                    ? const Border(
                        left: BorderSide(color: KalinkaColors.accent, width: 2),
                      )
                    : null,
              ),
              child: Row(
                children: [
                  // Album art 44x44
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: resolvedImageUrl != null
                              ? Image.network(
                                  resolvedImageUrl,
                                  width: 44,
                                  height: 44,
                                  fit: BoxFit.cover,
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
                        if (_longPressing && _longPressProgress > 0)
                          Positioned.fill(
                            child: CustomPaint(
                              painter: LongPressRingPainter(
                                progress: _longPressProgress,
                                color: KalinkaColors.accent,
                              ),
                            ),
                          ),
                        if (selectionMode && isSelected)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                color: KalinkaColors.accent.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                isPartial ? Icons.remove : Icons.check,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Title + subtitle
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
                        if (subtitleText.isNotEmpty)
                          Text(
                            subtitleText,
                            style: KalinkaTextStyles.trackRowSubtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Chevron button
                  GestureDetector(
                    onTap: _toggleExpand,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: KalinkaColors.pillSurface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: KalinkaColors.borderElevated,
                          width: 1,
                        ),
                      ),
                      child: AnimatedRotation(
                        turns: isExpanded ? 0.5 : 0.0,
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
                ],
              ),
            ),
          ),
        ),
        // Expanded track list
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: isExpanded
              ? _AlbumTrackList(
                  albumId: widget.item.id,
                  albumName: title,
                  artistName: widget.artistName,
                )
              : const SizedBox.shrink(),
          crossFadeState: isExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 260),
          firstCurve: Curves.easeInOutQuart,
          secondCurve: Curves.easeInOutQuart,
          sizeCurve: Curves.easeInOutQuart,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Track list within expanded album
// ---------------------------------------------------------------------------

class _AlbumTrackList extends ConsumerWidget {
  final String albumId;
  final String albumName;
  final String artistName;

  const _AlbumTrackList({
    required this.albumId,
    required this.albumName,
    required this.artistName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracksAsync = ref.watch(browseDetailProvider(albumId));
    final searchState = ref.watch(searchStateProvider);
    final showAllTracks = searchState.albumMoreTracksExpanded.contains(albumId);

    return Container(
      margin: const EdgeInsets.only(left: 8),
      decoration: BoxDecoration(
        color: KalinkaColors.inputSurface,
        border: Border(
          left: BorderSide(
            color: KalinkaColors.gold.withValues(alpha: 0.18),
            width: 1,
          ),
        ),
      ),
      child: tracksAsync.when(
        data: (browseList) {
          final tracks = browseList.items;
          if (tracks.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'No tracks found',
                style: KalinkaTextStyles.trackRowSubtitle,
              ),
            );
          }

          // Overflow: >5 tracks → show 4 + "N more"
          final maxInitial = tracks.length > 5 ? 4 : tracks.length;
          final displayTracks = showAllTracks
              ? tracks
              : tracks.take(maxInitial).toList();
          final moreCount = tracks.length - maxInitial;

          return Column(
            children: [
              for (int i = 0; i < displayTracks.length; i++)
                _ArtistTrackRow(
                  item: displayTracks[i],
                  index: i + 1,
                  containerId: albumId,
                ),
              if (!showAllTracks && moreCount > 0)
                GestureDetector(
                  onTap: () => ref
                      .read(searchStateProvider.notifier)
                      .revealAlbumMoreTracks(albumId),
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
          );
        },
        loading: () => const Padding(
          padding: EdgeInsets.all(12),
          child: Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 1.5),
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
}

// ---------------------------------------------------------------------------
// Individual track row within album expansion
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

  Future<void> _playTrack() async {
    try {
      final api = ref.read(kalinkaProxyProvider);
      await api.clear();
      if (widget.containerId.startsWith('singles_')) {
        await api.add([widget.item.id]);
        await api.play();
      } else {
        await api.add([widget.containerId]);
        await api.play(widget.index - 1);
      }
    } catch (e) {
      ref.read(toastProvider.notifier).show('Failed to play: $e', isError: true);
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
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: selectionMode && inSelectionHighlight
                ? KalinkaColors.accent.withValues(alpha: 0.07)
                : KalinkaColors.inputSurface,
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
                    fontSize: 12,
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
    try {
      final api = ref.read(kalinkaProxyProvider);
      final ids = widget.tracks.map((t) => t.id).toList();
      await api.add(ids);
      ref.read(toastProvider.notifier).show(
        '${widget.tracks.length} tracks by ${widget.artistName} added to queue',
      );
    } catch (e) {
      ref.read(toastProvider.notifier).show('Failed to add: $e', isError: true);
    }
  }

  Future<void> _playNext() async {
    try {
      final api = ref.read(kalinkaProxyProvider);
      final ids = widget.tracks.map((t) => t.id).toList();
      await api.add(ids);
      ref.read(toastProvider.notifier).show(
        '${widget.tracks.length} tracks by ${widget.artistName} playing next',
      );
    } catch (e) {
      ref.read(toastProvider.notifier).show('Failed to add: $e', isError: true);
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
                color: KalinkaColors.miniPlayerSurface,
              ),
              child: Row(
                children: [
                  // List icon in 44x44 container
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: KalinkaColors.pillSurface,
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
                  GestureDetector(
                    onTap: () => setState(() => _expanded = !_expanded),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: KalinkaColors.pillSurface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: KalinkaColors.borderElevated,
                          width: 1,
                        ),
                      ),
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
          duration: const Duration(milliseconds: 260),
          firstCurve: Curves.easeInOutQuart,
          secondCurve: Curves.easeInOutQuart,
          sizeCurve: Curves.easeInOutQuart,
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
        color: KalinkaColors.inputSurface,
        border: Border(
          left: BorderSide(
            color: KalinkaColors.gold.withValues(alpha: 0.18),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          for (int i = 0; i < displayTracks.length; i++)
            _ArtistTrackRow(
              item: displayTracks[i],
              index: i + 1,
              containerId: singlesKey,
            ),
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
