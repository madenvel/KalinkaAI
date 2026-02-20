import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data_model/data_model.dart';
import '../providers/search_state_provider.dart';
import '../providers/selection_state_provider.dart';
import 'browse_list.dart';
import 'search_cards/ai_suggestion_card.dart';
import 'search_cards/search_album_row.dart';
import 'search_cards/search_artist_row.dart';
import 'search_cards/search_playlist_row.dart';
import 'search_cards/search_track_row.dart';
import 'search_cards/section_header.dart';
import 'search_cards/show_more_row.dart';
import 'selection_overlay.dart';
import '../theme/app_theme.dart';

const _defaultSuggestions = [
  'Miles Davis',
  'Kind of Blue',
  'So What',
  'music for relaxation',
];

/// Inline search results feed for the phone content zone.
/// Manages its own ScrollController. Includes skeleton loading,
/// staggered card entrance animations, and result count hint.
class SearchResultsFeed extends ConsumerStatefulWidget {
  const SearchResultsFeed({super.key});

  @override
  ConsumerState<SearchResultsFeed> createState() => _SearchResultsFeedState();
}

class _SearchResultsFeedState extends ConsumerState<SearchResultsFeed>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  late AnimationController _staggerController;
  int _previousResultCount = -1;

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _staggerController.dispose();
    super.dispose();
  }

  void _triggerStagger(int itemCount) {
    if (itemCount == _previousResultCount) return;
    _previousResultCount = itemCount;
    final duration = 200 + (min(itemCount, 20) * 30);
    _staggerController.duration = Duration(milliseconds: duration);
    _staggerController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchStateProvider);
    final selection = ref.watch(selectionStateProvider);

    Widget content;

    if (searchState.isLoading) {
      content = _buildSkeletonLoading();
    } else if (searchState.error != null) {
      content = ListView(
        controller: _scrollController,
        children: [
          const SizedBox(height: 40),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                searchState.error!,
                style: KalinkaTextStyles.trackRowSubtitle.copyWith(
                  color: KalinkaColors.deleteRed,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      );
    } else if (searchState.searchResults != null) {
      content = _buildResultsFeed(context, ref, searchState);
    } else if (searchState.browseRecommendations != null) {
      content = _buildBrowseRecommendations(
        context,
        ref,
        searchState.browseRecommendations!,
      );
    } else {
      content = _buildHistoryAndSuggestions(context, ref);
    }

    return Stack(
      children: [
        content,
        if (selection.isActive) ...[
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: MultiSelectTopBar(
              allItemIds: searchState.searchResults?[SearchType.track]?.items
                  .map((item) => item.id),
            ),
          ),
          const Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: MultiSelectBottomBar(),
          ),
        ],
      ],
    );
  }

  Widget _buildSkeletonLoading() {
    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        // AI card skeleton (taller, full-width)
        const _ShimmerRow(height: 120, isAiCard: true),
        const SizedBox(height: 12),
        // Track row skeletons
        for (int i = 0; i < 3; i++) ...[
          const _ShimmerRow(height: 60, isAiCard: false),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _buildResultsFeed(
    BuildContext context,
    WidgetRef ref,
    SearchState searchState,
  ) {
    final results = searchState.searchResults!;
    final hasResults = results.values.any((list) => list.items.isNotEmpty);

    if (!hasResults) {
      return ListView(
        controller: _scrollController,
        children: [
          const SizedBox(height: 60),
          Center(
            child: Column(
              children: [
                Icon(
                  Icons.search_off,
                  size: 64,
                  color: KalinkaColors.textSecondary.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text('No results found', style: KalinkaTextStyles.cardTitle),
                const SizedBox(height: 8),
                Text(
                  'Try different keywords',
                  style: KalinkaTextStyles.trackRowSubtitle,
                ),
              ],
            ),
          ),
        ],
      );
    }

    final tracks = results[SearchType.track]?.items ?? [];
    final albums = results[SearchType.album]?.items ?? [];
    final artists = results[SearchType.artist]?.items ?? [];
    final playlists = results[SearchType.playlist]?.items ?? [];

    // Count total items for stagger animation
    final trackDisplayCount = searchState.tracksExpanded
        ? tracks.length
        : min<int>(3, tracks.length);
    final totalItems =
        1 + // AI card
        trackDisplayCount +
        albums.length +
        artists.length +
        playlists.length;
    _triggerStagger(totalItems);

    int itemIndex = 0;

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      children: [
        // Result count hint
        if (searchState.totalResultCount > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '${searchState.totalResultCount} RESULTS \u00B7 RANKED BY RELEVANCE',
              style: KalinkaTextStyles.resultCountHint,
            ),
          ),
        // AI Suggestion Card (always first when present)
        _StaggeredItem(
          index: itemIndex++,
          controller: _staggerController,
          totalItems: totalItems,
          child: const AiSuggestionCard(),
        ),
        const SizedBox(height: 16),

        // Tracks section
        if (tracks.isNotEmpty) ...[
          SectionHeader(
            label: 'Tracks',
            count: tracks.length,
            showDivider: false,
          ),
          ..._buildTracksSection(
            ref,
            tracks,
            searchState,
            itemIndex,
            totalItems,
          ),
        ],

        // Albums section
        if (albums.isNotEmpty) ...[
          SectionHeader(label: 'Albums', count: albums.length),
          ...albums.map((item) {
            final idx = itemIndex++;
            return _StaggeredItem(
              index: idx,
              controller: _staggerController,
              totalItems: totalItems,
              child: SearchAlbumRow(item: item),
            );
          }),
        ],

        // Artists section
        if (artists.isNotEmpty) ...[
          SectionHeader(label: 'Artists', count: artists.length),
          ...artists.map((item) {
            final idx = itemIndex++;
            return _StaggeredItem(
              index: idx,
              controller: _staggerController,
              totalItems: totalItems,
              child: SearchArtistRow(item: item),
            );
          }),
        ],

        // Playlists section
        if (playlists.isNotEmpty) ...[
          SectionHeader(label: 'Playlists', count: playlists.length),
          ...playlists.map((item) {
            final idx = itemIndex++;
            return _StaggeredItem(
              index: idx,
              controller: _staggerController,
              totalItems: totalItems,
              child: SearchPlaylistRow(item: item),
            );
          }),
        ],
      ],
    );
  }

  List<Widget> _buildTracksSection(
    WidgetRef ref,
    List<BrowseItem> tracks,
    SearchState searchState,
    int startIndex,
    int totalItems,
  ) {
    final isExpanded = searchState.tracksExpanded;
    final displayCount = isExpanded ? tracks.length : min(3, tracks.length);
    final remaining = tracks.length - 3;

    return [
      for (int i = 0; i < displayCount; i++)
        _StaggeredItem(
          index: startIndex + i,
          controller: _staggerController,
          totalItems: totalItems,
          child: SearchTrackRow(item: tracks[i]),
        ),
      if (!isExpanded && remaining > 0)
        ShowMoreRow(
          remainingCount: remaining,
          isExpanded: false,
          onTap: () =>
              ref.read(searchStateProvider.notifier).toggleTracksExpanded(),
        ),
      if (isExpanded && tracks.length > 3)
        ShowMoreRow(
          remainingCount: 0,
          isExpanded: true,
          onTap: () =>
              ref.read(searchStateProvider.notifier).toggleTracksExpanded(),
        ),
    ];
  }

  Widget _buildHistoryAndSuggestions(BuildContext context, WidgetRef ref) {
    final history = ref.read(searchStateProvider.notifier).getSearchHistory();

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        if (history.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('RECENT SEARCHES', style: KalinkaTextStyles.sectionLabel),
              GestureDetector(
                onTap: () {
                  ref.read(searchStateProvider.notifier).clearHistory();
                },
                child: Text('CLEAR', style: KalinkaTextStyles.showMoreLabel),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...history.map((query) => _buildHistoryItem(context, ref, query)),
          const SizedBox(height: 24),
        ],
        Text(
          history.isEmpty ? 'SUGGESTIONS' : 'TRY SEARCHING FOR',
          style: KalinkaTextStyles.sectionLabel,
        ),
        const SizedBox(height: 8),
        ..._defaultSuggestions.map(
          (suggestion) => _buildSuggestionItem(context, ref, suggestion),
        ),
      ],
    );
  }

  Widget _buildHistoryItem(BuildContext context, WidgetRef ref, String query) {
    return InkWell(
      onTap: () {
        ref.read(searchStateProvider.notifier).setQuery(query);
        ref.read(searchStateProvider.notifier).performSearch();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            const Icon(
              Icons.history,
              size: 18,
              color: KalinkaColors.textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(query, style: KalinkaTextStyles.trackRowTitle),
            ),
            const Icon(
              Icons.north_west,
              size: 14,
              color: KalinkaColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionItem(
    BuildContext context,
    WidgetRef ref,
    String suggestion,
  ) {
    return InkWell(
      onTap: () {
        ref.read(searchStateProvider.notifier).setQuery(suggestion);
        ref.read(searchStateProvider.notifier).performSearch();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            const Icon(
              Icons.search,
              size: 18,
              color: KalinkaColors.textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(suggestion, style: KalinkaTextStyles.trackRowTitle),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrowseRecommendations(
    BuildContext context,
    WidgetRef ref,
    List<BrowseItemsList> recommendations,
  ) {
    if (recommendations.isEmpty) {
      return ListView(
        controller: _scrollController,
        children: const [
          Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: Text('No recommendations available')),
          ),
        ],
      );
    }

    // Flatten sections from recommendations
    final sections = <BrowseItem>[];
    for (final browseList in recommendations) {
      for (final item in browseList.items) {
        if (item.sections != null && item.sections!.isNotEmpty) {
          sections.addAll(item.sections!);
        } else {
          sections.add(item);
        }
      }
    }

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: sections.map((section) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: BrowseList(section: section),
        );
      }).toList(),
    );
  }
}

/// Wraps a child widget with staggered fade + slide-up entrance animation.
class _StaggeredItem extends StatelessWidget {
  final int index;
  final AnimationController controller;
  final int totalItems;
  final Widget child;

  const _StaggeredItem({
    required this.index,
    required this.controller,
    required this.totalItems,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final clampedTotal = max(1, totalItems);
    final start = (index * 30 / (200 + clampedTotal * 30)).clamp(0.0, 1.0);
    final end = ((index * 30 + 200) / (200 + clampedTotal * 30)).clamp(
      0.0,
      1.0,
    );

    final animation = CurvedAnimation(
      parent: controller,
      curve: Interval(start, end, curve: Curves.easeOut),
    );

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Opacity(
          opacity: animation.value,
          child: Transform.translate(
            offset: Offset(0, 8 * (1 - animation.value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

/// Shimmer skeleton row for loading state.
class _ShimmerRow extends StatefulWidget {
  final double height;
  final bool isAiCard;

  const _ShimmerRow({required this.height, required this.isAiCard});

  @override
  State<_ShimmerRow> createState() => _ShimmerRowState();
}

class _ShimmerRowState extends State<_ShimmerRow>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _shimmerAnimation = Tween<double>(begin: 0.4, end: 0.7).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (context, child) {
        return Opacity(opacity: _shimmerAnimation.value, child: child);
      },
      child: widget.isAiCard ? _buildAiSkeleton() : _buildTrackSkeleton(),
    );
  }

  Widget _buildAiSkeleton() {
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: KalinkaColors.inputSurface,
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: KalinkaColors.pillSurface,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 160,
                    height: 8,
                    decoration: BoxDecoration(
                      color: KalinkaColors.pillSurface,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 120,
                    height: 12,
                    decoration: BoxDecoration(
                      color: KalinkaColors.pillSurface,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
          Container(
            height: 28,
            decoration: BoxDecoration(
              color: KalinkaColors.pillSurface,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackSkeleton() {
    return SizedBox(
      height: widget.height,
      child: Row(
        children: [
          // Thumbnail placeholder
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: KalinkaColors.inputSurface,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(width: 12),
          // Text placeholders
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  height: 10,
                  margin: const EdgeInsets.only(right: 60),
                  decoration: BoxDecoration(
                    color: KalinkaColors.inputSurface,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: 120,
                  height: 8,
                  decoration: BoxDecoration(
                    color: KalinkaColors.inputSurface,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
          // Duration placeholder
          Container(
            width: 32,
            height: 8,
            decoration: BoxDecoration(
              color: KalinkaColors.inputSurface,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }
}
