import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data_model/data_model.dart';
import '../../providers/browse_detail_provider.dart';
import '../../providers/kalinka_player_api_provider.dart';
import '../../providers/search_state_provider.dart';
import '../../providers/url_resolver.dart';
import '../../theme/app_theme.dart';
import '../procedural_album_art.dart';

/// Album row for search results.
/// 56x56 thumbnail, title/artist/year/trackCount, tag pills,
/// two stacked icon buttons (add + expand).
/// Expands inline to show track list.
class SearchAlbumRow extends ConsumerStatefulWidget {
  final BrowseItem item;
  final DraggableScrollableController? sheetController;

  const SearchAlbumRow({super.key, required this.item, this.sheetController});

  @override
  ConsumerState<SearchAlbumRow> createState() => _SearchAlbumRowState();
}

class _SearchAlbumRowState extends ConsumerState<SearchAlbumRow>
    with SingleTickerProviderStateMixin {
  bool _showAddCheck = false;
  Timer? _resetTimer;

  Future<void> _addAlbum() async {
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added "${widget.item.name ?? 'album'}" to queue'),
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

  void _toggleExpand() {
    final searchNotifier = ref.read(searchStateProvider.notifier);
    final currentExpanded = ref.read(searchStateProvider).expandedAlbumId;
    if (currentExpanded == widget.item.id) {
      searchNotifier.collapseAlbum();
    } else {
      searchNotifier.expandAlbum(widget.item.id);
      // Auto-snap sheet up if needed
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _tryAutoSnap();
      });
    }
  }

  void _tryAutoSnap() {
    final controller = widget.sheetController;
    if (controller == null || !controller.isAttached) return;
    final currentSize = controller.size;
    if (currentSize < 0.65) {
      controller.animateTo(
        0.65,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchStateProvider);
    final isExpanded = searchState.expandedAlbumId == widget.item.id;

    final album = widget.item.album;
    final title = album?.title ?? widget.item.name ?? 'Unknown';
    final artist = album?.artist?.name ?? '';
    final trackCount = album?.trackCount;
    final genre = album?.genre?.name;

    final urlResolver = ref.read(urlResolverProvider);
    final imageUrl = widget.item.image?.thumbnail ?? widget.item.image?.small;
    final resolvedImageUrl = imageUrl != null
        ? urlResolver.abs(imageUrl)
        : null;

    final subtitleParts = <String>[
      if (artist.isNotEmpty) artist,
      if (trackCount != null) '$trackCount tracks',
    ];
    final subtitle = subtitleParts.join(' \u00B7 ');

    return Column(
      children: [
        // Main row
        GestureDetector(
          onTap: _toggleExpand,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail 56x56
                Container(
                  width: 56,
                  height: 56,
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
                            errorBuilder: (_, __, ___) => ProceduralAlbumArt(
                              trackId: widget.item.id,
                              size: 56,
                            ),
                          )
                        : ProceduralAlbumArt(trackId: widget.item.id, size: 56),
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
                        style: KalinkaTextStyles.cardTitle,
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
                // Stacked buttons
                Column(
                  children: [
                    // Add button
                    GestureDetector(
                      onTap: _addAlbum,
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
                    const SizedBox(height: 4),
                    // Expand button
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
              ? _ExpandedAlbumTracks(
                  albumId: widget.item.id,
                  sheetController: widget.sheetController,
                )
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
  final DraggableScrollableController? sheetController;

  const _ExpandedAlbumTracks({required this.albumId, this.sheetController});

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
            // Show all items if none have track data
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
      ),
    );
  }

  Widget _buildTrackList(List<BrowseItem> items, WidgetRef ref) {
    return Column(
      children: items.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        return _InlineTrackRow(item: item, index: index + 1);
      }).toList(),
    );
  }
}

class _InlineTrackRow extends ConsumerStatefulWidget {
  final BrowseItem item;
  final int index;

  const _InlineTrackRow({required this.item, required this.index});

  @override
  ConsumerState<_InlineTrackRow> createState() => _InlineTrackRowState();
}

class _InlineTrackRowState extends ConsumerState<_InlineTrackRow> {
  bool _showCheck = false;
  Timer? _resetTimer;

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }

  Future<void> _addTrack() async {
    try {
      final api = ref.read(kalinkaProxyProvider);
      await api.add([widget.item.id]);
      if (!mounted) return;
      setState(() => _showCheck = true);
      _resetTimer?.cancel();
      _resetTimer = Timer(const Duration(milliseconds: 1600), () {
        if (mounted) setState(() => _showCheck = false);
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final track = widget.item.track;
    final title = track?.title ?? widget.item.name ?? 'Unknown';
    final duration = _formatDuration(track?.duration);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(
              '${widget.index}',
              style: KalinkaTextStyles.trackRowSubtitle,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: KalinkaTextStyles.trackRowTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (duration != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(duration, style: KalinkaTextStyles.trackRowSubtitle),
            ),
          GestureDetector(
            onTap: _addTrack,
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
        ],
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
