import 'dart:math';

import 'package:flutter/material.dart';
import '../../data_model/data_model.dart';
import '../../theme/app_theme.dart';
import 'search_album_row.dart';
import 'search_artist_row.dart';
import 'search_catalog_row.dart';
import 'search_playlist_row.dart';
import 'search_track_row.dart';
import 'show_more_row.dart';

/// Renders a list of [BrowseItem]s as stacked rows, dispatching to the correct
/// Search*Row widget by [BrowseItem.browseType]. Rows are separated by hairline
/// dividers unless [dividers] is false, in which case they simply stack.
///
/// When [visibleLimit] is set and [items.length] exceeds it, the list is
/// truncated and a [ShowMoreRow] is appended that toggles [isExpanded] via
/// [onToggleExpand].
///
/// Used by both the search-results feed (AI groups) and the zero-state
/// surface (Recently Favourited, Based on Now Playing) so tap-to-play
/// animation, sibling dim, and row styling stay consistent between them.
class BrowseItemRows extends StatelessWidget {
  final List<BrowseItem> items;
  final int? visibleLimit;
  final bool isExpanded;
  final VoidCallback? onToggleExpand;

  /// Draw a hairline divider between adjacent rows. Off for the search-result
  /// sections, where the only divider is between sections, not their rows.
  final bool dividers;

  /// When set, tapping a track row plays this whole list as the queue,
  /// starting from the tapped track, instead of playing the track alone.
  final List<String>? queueContextIds;

  const BrowseItemRows({
    super.key,
    required this.items,
    this.visibleLimit,
    this.isExpanded = false,
    this.onToggleExpand,
    this.dividers = true,
    this.queueContextIds,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final limit = visibleLimit;
    final shownCount = (limit == null || isExpanded)
        ? items.length
        : min(limit, items.length);
    final displayed = items.take(shownCount).toList();

    final children = <Widget>[];
    for (int i = 0; i < displayed.length; i++) {
      // Per-row RepaintBoundary: each row becomes its own composited layer
      // so scroll just shifts layers instead of re-rasterising the whole
      // section. Matters most for sections that pack many rows into a single
      // outer ListView child (BASED ON NOW PLAYING, RECENTLY FAVOURITED).
      children.add(RepaintBoundary(child: _rowFor(displayed[i])));
      if (dividers && i < displayed.length - 1) {
        children.add(const Divider(
          color: KalinkaColors.borderSubtle,
          thickness: 1,
          height: 14,
        ));
      }
    }

    final hiddenCount = items.length - shownCount;
    final showMore =
        limit != null && onToggleExpand != null &&
        (hiddenCount > 0 || isExpanded);
    if (showMore) {
      children.add(RepaintBoundary(
        child: ShowMoreRow(
          remainingCount: items.length - limit,
          isExpanded: isExpanded,
          onTap: onToggleExpand!,
        ),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  Widget _rowFor(BrowseItem item) {
    switch (item.browseType) {
      case BrowseType.track:
        return SearchTrackRow(item: item, queueContextIds: queueContextIds);
      case BrowseType.album:
        return SearchAlbumRow(item: item);
      case BrowseType.artist:
        return SearchArtistRow(item: item);
      case BrowseType.playlist:
        return SearchPlaylistRow(item: item);
      case BrowseType.catalog:
        return SearchCatalogRow(item: item);
      case BrowseType.unknown:
        return const SizedBox.shrink();
    }
  }
}
