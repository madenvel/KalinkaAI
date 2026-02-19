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

/// Playlist row for search results.
/// Same structure as Album Row but with 2x2 mosaic grid overlay on art.
class SearchPlaylistRow extends ConsumerStatefulWidget {
  final BrowseItem item;
  final DraggableScrollableController? sheetController;

  const SearchPlaylistRow({
    super.key,
    required this.item,
    this.sheetController,
  });

  @override
  ConsumerState<SearchPlaylistRow> createState() => _SearchPlaylistRowState();
}

class _SearchPlaylistRowState extends ConsumerState<SearchPlaylistRow> {
  bool _showAddCheck = false;
  Timer? _resetTimer;

  Future<void> _addPlaylist() async {
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
            content: Text('Added "${widget.item.name ?? 'playlist'}" to queue'),
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
    // Reuse expandedAlbumId for playlists too (only one expanded at a time)
    if (currentExpanded == widget.item.id) {
      searchNotifier.collapseAlbum();
    } else {
      searchNotifier.expandAlbum(widget.item.id);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final controller = widget.sheetController;
        if (controller != null && controller.isAttached) {
          final currentSize = controller.size;
          if (currentSize < 0.65) {
            controller.animateTo(
              0.65,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
            );
          }
        }
      });
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

    final playlist = widget.item.playlist;
    final title = playlist?.name ?? widget.item.name ?? 'Unknown';
    final trackCount = playlist?.trackCount;
    final description = playlist?.description ?? '';

    final subtitleParts = <String>[
      if (trackCount != null) '$trackCount tracks',
      if (description.isNotEmpty) description,
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
                // Thumbnail 56x56 with mosaic overlay
                SizedBox(
                  width: 56,
                  height: 56,
                  child: Container(
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
                          ProceduralAlbumArt(trackId: widget.item.id, size: 56),
                          // 2x2 mosaic overlay at 25% opacity
                          Opacity(
                            opacity: 0.25,
                            child: GridView.count(
                              crossAxisCount: 2,
                              physics: const NeverScrollableScrollPhysics(),
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
                    ],
                  ),
                ),
                // Stacked buttons
                Column(
                  children: [
                    GestureDetector(
                      onTap: _addPlaylist,
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
      ),
    );
  }

  Widget _buildTrackList(List<BrowseItem> items, WidgetRef ref) {
    return Column(
      children: items.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        return _InlinePlaylistTrack(item: item, index: index + 1);
      }).toList(),
    );
  }
}

class _InlinePlaylistTrack extends ConsumerStatefulWidget {
  final BrowseItem item;
  final int index;

  const _InlinePlaylistTrack({required this.item, required this.index});

  @override
  ConsumerState<_InlinePlaylistTrack> createState() =>
      _InlinePlaylistTrackState();
}

class _InlinePlaylistTrackState extends ConsumerState<_InlinePlaylistTrack> {
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
