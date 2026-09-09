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
/// while the others show. A berry wash behind the heading holds them together
/// as the one section they are, and the display face gives the block a voice
/// of its own: these are answers offered, not a listing of what a source
/// holds.
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

  /// How far the wash reaches before the groups begin. It runs well past
  /// where it is still visible: the fade decides where it ends, not the box.
  static const _washHeight = 120.0;

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
    final expanded = filter.kind == ResultKind.recommendations;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: -gutter,
          right: -gutter,
          top: 0,
          height: _washHeight,
          child: const IgnorePointer(child: _HeadingWash()),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _InspiredHeading(),
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

/// What the block is and then its name, in the shape a page title takes: a
/// quiet label over the display face, and nothing drawn through either.
///
/// No rule and no tally. A rule divides a heading from what follows, and this
/// heading is not separate from its groups — the wash behind it is what says
/// where the block begins. The count belonged to a shelf being opened in
/// full; what a source happened to suggest is not a quantity anyone came for.
class _InspiredHeading extends StatelessWidget {
  const _InspiredHeading();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome,
                size: 14,
                color: KalinkaColors.accentTint,
              ),
              const SizedBox(width: 7),
              Text(
                'SMART RECOMMENDATIONS',
                style: KalinkaTextStyles.sectionLabel.copyWith(
                  color: KalinkaColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            'Inspired by your request',
            style: KalinkaTextStyles.dialogTitle,
          ),
        ],
      ),
    );
  }
}

/// The berry the block is allowed: the Discover root's bloom at a section's
/// scale — off the top-right, dissolved into the ground before its box ends.
///
/// Diffuse rather than drawn. A berry edge or fill would read as a decision,
/// and this is atmosphere for the one section that answers in its own voice.
/// It is also the only thing marking where the block starts, now that nothing
/// there is ruled or barred.
class _HeadingWash extends StatelessWidget {
  const _HeadingWash();

  /// Off to the right and high, so the glow sits in the canvas the heading
  /// leaves empty rather than behind the words.
  static final _bloom = RadialGradient(
    center: const Alignment(0.85, -0.5),
    radius: 1.35,
    colors: [
      KalinkaColors.accentWash,
      KalinkaColors.accentWash.withValues(alpha: 0),
    ],
  );

  /// What ends it: the ground brought up over the bloom a little past the
  /// foot of the heading. The bloom is still tinted where its box stops, so
  /// without this it is clipped there and the cut reads as a line across the
  /// results.
  static final _fadeOut = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      KalinkaColors.background.withValues(alpha: 0),
      KalinkaColors.background,
    ],
    stops: const [0.35, 0.62],
  );

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(decoration: BoxDecoration(gradient: _bloom)),
        DecoratedBox(decoration: BoxDecoration(gradient: _fadeOut)),
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
              Expanded(
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
            BrowseItemRows(items: shown, queueContextIds: trackIds),
        ],
      ),
    );
  }
}
