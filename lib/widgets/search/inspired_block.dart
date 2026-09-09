import 'package:flutter/material.dart';

import '../../data_model/browse_filters.dart';
import '../../data_model/search_results.dart';
import '../../providers/source_modules_provider.dart';
import '../../theme/app_theme.dart';
import '../browse_rows_shimmer.dart';
import '../search_cards/browse_item_rows.dart';
import '../shelf_heading.dart';
import '../source_badge.dart';
import 'source_unavailable_row.dart';
import 'track_group_actions.dart';

/// What the sources suggest for the query, kept apart by source: their
/// rankings are not comparable, so each group keeps its own order, its own
/// batch actions and its own way of opening in full. Each group stands on
/// its own answer — one still loading shimmers, one that failed says so,
/// while the others show. The Discover mark on the heading and a bar on the
/// page edge, fading out in the height of the heading, hold them together
/// as the one section they are.
class InspiredBlock extends StatelessWidget {
  final SearchResults results;
  final NarrowedResults narrowed;
  final BrowseFilterQuery filter;

  /// Opens one source's recommendations in full.
  final ValueChanged<String> onViewAll;
  final ValueChanged<String> onRetry;

  /// How far the page edge lies left of the block. The bar sits on the edge,
  /// as the queue's now-playing bar does, not in the text column.
  final double gutter;

  /// How many of a group's tracks lead before VIEW ALL.
  static const previewCount = 3;

  /// Solid through the title, gone before the first source.
  static const _barHeight = 56.0;

  const InspiredBlock({
    super.key,
    required this.results,
    required this.narrowed,
    required this.filter,
    required this.onViewAll,
    required this.onRetry,
    this.gutter = 0,
  });

  /// Whether any group has anything to show under [filter].
  static bool visible(
    SearchResults results,
    NarrowedResults narrowed,
    BrowseFilterQuery filter,
  ) {
    if (filter.kind == ResultKind.nameMatches) return false;
    return narrowed.groups.any(_groupVisible);
  }

  static bool _groupVisible(InspiredGroup group) =>
      group.state is! LegReady || group.tracks.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final groups = narrowed.groups.where(_groupVisible).toList();
    final total = narrowed.recommendationCount;
    final expanded = filter.kind == ResultKind.recommendations;
    final loading = groups.any((g) => g.state is LegLoading);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: -gutter,
          top: 0,
          width: 4,
          height: _barHeight,
          child: const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0, 0.3, 1],
                  // Section chrome, not a signal: the bar marks where the
                  // block starts, and berry in the app means a decision or
                  // one in effect. Grey keeps it from competing with the
                  // selection edge, which is berry and does mean something.
                  colors: [
                    KalinkaColors.textMuted,
                    KalinkaColors.textMuted,
                    Color(0x00858585),
                  ],
                ),
              ),
            ),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ShelfHeading(
              title: 'INSPIRED BY YOUR REQUEST',
              icon: Icons.auto_awesome,
              count: loading ? null : total,
              subtitle: 'Smart recommendations, kept by source',
            ),
            for (final group in groups)
              _SourceGroup(
                group: group,
                title: results.sources.titleOf(group.source),
                expanded: expanded,
                onViewAll: () => onViewAll(group.source),
                onRetry: () => onRetry(group.source),
              ),
          ],
        ),
      ],
    );
  }
}

class _SourceGroup extends StatelessWidget {
  final InspiredGroup group;
  final String title;
  final bool expanded;
  final VoidCallback onViewAll;
  final VoidCallback onRetry;

  const _SourceGroup({
    required this.group,
    required this.title,
    required this.expanded,
    required this.onViewAll,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final state = group.state;
    if (state is LegFailed) {
      return SourceUnavailableRow(
        source: group.source,
        title: title,
        onRetry: onRetry,
      );
    }
    final tracks = group.tracks;
    final trackIds = [for (final item in tracks) item.id];
    final more = !expanded && tracks.length > InspiredBlock.previewCount;
    final letter = sourceLetter(group.source);
    final shown = expanded
        ? tracks
        : tracks.take(InspiredBlock.previewCount).toList();

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (letter != null) ...[letter, const SizedBox(width: 10)],
              // Name and count share the one flex slot, so the link takes
              // the edge and only the name gives way.
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        isLocalSource(group.source)
                            ? 'YOUR LIBRARY'
                            : title.toUpperCase(),
                        style: KalinkaTextStyles.sectionLabel.copyWith(
                          color: KalinkaColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (state is LegReady) ...[
                      const SizedBox(width: 8),
                      Text(
                        '· ${tracks.length}',
                        style: KalinkaTextStyles.sectionLabel.copyWith(
                          color: KalinkaColors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (more) ...[
                const SizedBox(width: 12),
                ViewAllAction(label: 'VIEW ALL', onTap: onViewAll),
              ],
            ],
          ),
          // Its own row under the name, like an unrolled album's actions.
          if (tracks.isNotEmpty) ...[
            const SizedBox(height: 8),
            TrackGroupActions(trackIds: trackIds),
          ],
          const SizedBox(height: 8),
          if (state is LegLoading)
            const BrowseRowsShimmer(count: 2)
          else
            // Tapping a track plays the group from it: the group is the
            // queue, which gives it a coherent identity.
            BrowseItemRows(
              items: shown,
              dividers: false,
              queueContextIds: trackIds,
            ),
        ],
      ),
    );
  }
}
