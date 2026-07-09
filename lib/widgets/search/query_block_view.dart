import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../../providers/search_session_provider.dart';
import '../../theme/app_theme.dart';
import 'search_loading_indicator.dart';
import 'staging_result_sections.dart';

/// Renders one [SearchQueryBlock]. When [expanded] it shows the query as a
/// playlist-style title header followed by the loading state or its results;
/// when folded it collapses to a single tappable summary line.
class QueryBlockView extends StatelessWidget {
  final SearchQueryBlock block;
  final bool expanded;
  final VoidCallback onExpand;
  final ValueChanged<String> onToggleSection;

  const QueryBlockView({
    super.key,
    required this.block,
    required this.expanded,
    required this.onExpand,
    required this.onToggleSection,
  });

  @override
  Widget build(BuildContext context) {
    // Ease the fold/unfold: the height animates (and clips) as the block swaps
    // between its compact summary and its full bubble + results.
    return AnimatedSize(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: expanded ? _buildExpanded(context) : _buildFolded(context),
    );
  }

  Widget _buildExpanded(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildQueryHeader(context),
        const SizedBox(height: 20),
        if (block.loading)
          const SearchLoadingIndicator()
        else if (block.error != null)
          _buildError(block.error!)
        else if (block.results != null)
          StagingResultSections(
            results: block.results!,
            expandedSections: block.expandedSections,
            onToggleSection: onToggleSection,
          ),
        const SizedBox(height: 20),
      ],
    );
  }

  /// The query captioned over its results: an accent double-note glyph and
  /// "You asked for `query`", the query itself in the accent tint, all wrapped
  /// in a soft rounded card. Reads as "the request this search is about".
  Widget _buildQueryHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: KalinkaColors.surfaceRaised,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KalinkaColors.borderSubtle, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              CupertinoIcons.double_music_note,
              size: 18,
              color: KalinkaColors.accentTint,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                text: 'You asked for ',
                style: KalinkaTextStyles.trackRowTitle.copyWith(
                  color: KalinkaColors.textSecondary,
                ),
                children: [
                  TextSpan(
                    text: block.query,
                    style: KalinkaTextStyles.trackRowTitle.copyWith(
                      color: KalinkaColors.accentTint,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(String error) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
      child: Text(
        error,
        style: KalinkaTextStyles.trackRowSubtitle.copyWith(
          color: KalinkaColors.actionDelete,
        ),
      ),
    );
  }

  Widget _buildFolded(BuildContext context) {
    final count = block.resultCount;
    final summary = block.loading
        ? 'Searching…'
        : count > 0
        ? '$count result${count == 1 ? '' : 's'}'
        : 'No results';

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Semantics(
        label: 'Expand query: ${block.query}',
        button: true,
        child: GestureDetector(
          onTap: onExpand,
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            decoration: BoxDecoration(
              color: KalinkaColors.surfaceRaised,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: KalinkaColors.borderSubtle, width: 1),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.history_rounded,
                  size: 15,
                  color: KalinkaColors.textMuted,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    block.query,
                    style: KalinkaTextStyles.trackRowTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(summary, style: KalinkaTextStyles.trackRowSubtitle),
                const SizedBox(width: 4),
                const Icon(
                  Icons.unfold_more_rounded,
                  size: 16,
                  color: KalinkaColors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
