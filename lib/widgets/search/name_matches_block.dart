import 'package:flutter/material.dart';

import '../../data_model/browse_filters.dart';
import '../../data_model/search_results.dart';
import '../browse_rows_shimmer.dart';
import '../search_cards/browse_item_rows.dart';
import '../shelf_heading.dart';
import 'source_unavailable_row.dart';

/// What every source found by name, as one list — the best few, with the
/// rest a VIEW ALL away.
///
/// Waits for every source before showing anything: the list is a merge, and
/// a merge that fills in as sources answer would reshuffle under the eye. A
/// source that failed is named below the rows instead of thinning them.
class NameMatchesBlock extends StatelessWidget {
  final SearchResults results;
  final NarrowedResults narrowed;
  final BrowseFilterQuery filter;
  final VoidCallback onViewAll;
  final ValueChanged<String> onRetry;

  /// How many lead the block before VIEW ALL.
  static const previewCount = 4;

  const NameMatchesBlock({
    super.key,
    required this.results,
    required this.narrowed,
    required this.filter,
    required this.onViewAll,
    required this.onRetry,
  });

  /// Whether the block has anything to say under [filter]: rows, rows still
  /// coming, or a source that could not answer.
  static bool visible(
    SearchResults results,
    NarrowedResults narrowed,
    BrowseFilterQuery filter,
  ) {
    if (filter.kind == ResultKind.recommendations) return false;
    return !results.matchesSettled ||
        narrowed.matches.isNotEmpty ||
        _unavailable(results, filter).isNotEmpty;
  }

  static List<String> _unavailable(
    SearchResults results,
    BrowseFilterQuery filter,
  ) => [
    for (final source in results.unavailableMatchSources)
      if (filter.sources.isEmpty || filter.sources.contains(source)) source,
  ];

  @override
  Widget build(BuildContext context) {
    final settled = results.matchesSettled;
    final all = narrowed.matches;
    final expanded = filter.kind == ResultKind.nameMatches;
    final shown = expanded ? all : all.take(previewCount).toList();
    final unavailable = _unavailable(results, filter);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ShelfHeading(
          title: 'MATCHES BY NAME',
          count: settled ? all.length : null,
          subtitle: _subtitle(),
          onViewAll: settled && shown.length < all.length ? onViewAll : null,
        ),
        const SizedBox(height: 10),
        if (!settled)
          const BrowseRowsShimmer(count: previewCount)
        else
          BrowseItemRows(items: shown),
        for (final source in unavailable)
          SourceUnavailableRow(
            source: source,
            title: results.sources.titleOf(source),
            onRetry: () => onRetry(source),
          ),
      ],
    );
  }

  String _subtitle() {
    if (filter.sources.isEmpty) return 'Separate results from every source';
    return 'From ${filter.sources.map(results.sources.titleOf).join(', ')}';
  }
}
