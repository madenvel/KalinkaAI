import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data_model/data_model.dart';
import '../providers/connection_state_provider.dart';
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
import 'zero_state_surface.dart';
import '../theme/app_theme.dart';

/// Inline search results feed used in both phone and tablet layouts.
/// Manages its own ScrollController. Includes skeleton loading,
/// staggered card entrance animations, and result count hint.
/// Switches content based on the current search phase.
class SearchResultsFeed extends ConsumerStatefulWidget {
  /// Bottom padding for scroll content. Use 100 on phone (mini player clearance),
  /// 0 on tablet.
  final double bottomPadding;

  const SearchResultsFeed({super.key, this.bottomPadding = 100});

  @override
  ConsumerState<SearchResultsFeed> createState() => _SearchResultsFeedState();
}

class _SearchResultsFeedState extends ConsumerState<SearchResultsFeed>
    with SingleTickerProviderStateMixin {
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
    _staggerController.dispose();
    super.dispose();
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;

    if (notification.metrics.pixels > 0.5) {
      FocusManager.instance.primaryFocus?.unfocus();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(searchStateProvider.notifier).setKeyboardVisible(false);
        }
      });
    }

    return false;
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
    final connectionStatus = ref.watch(connectionStateProvider);
    final isOffline =
        connectionStatus == ConnectionStatus.none ||
        connectionStatus == ConnectionStatus.reconnecting ||
        connectionStatus == ConnectionStatus.offline;

    Widget content;

    switch (searchState.searchPhase) {
      case SearchPhase.inactive:
        // Should not be shown — parent shows QueueZone instead
        content = const SizedBox.shrink();

      case SearchPhase.activated:
        // Zero-state surface (history + AI suggestions + library items)
        content = const ZeroStateSurface();

      case SearchPhase.typing:
        // Partial results or skeleton while typing
        Widget inner;
        if (searchState.isLoading) {
          inner = _buildSkeletonLoading();
        } else if (searchState.searchResults != null) {
          inner = _buildResultsFeed(context, ref, searchState);
        } else if (searchState.browseRecommendations != null) {
          inner = _buildBrowseRecommendations(
            context,
            ref,
            searchState.browseRecommendations!,
          );
        } else {
          inner = _buildSkeletonLoading();
        }
        content = _wrapWithFilterPills(inner, searchState);

      case SearchPhase.results:
        // Full results
        Widget inner;
        if (searchState.isLoading) {
          inner = _buildSkeletonLoading();
        } else if (searchState.error != null) {
          inner = _buildErrorView(searchState.error!);
        } else if (searchState.searchResults != null) {
          inner = _buildResultsFeed(context, ref, searchState);
        } else {
          inner = _buildSkeletonLoading();
        }
        content = _wrapWithFilterPills(inner, searchState);

      case SearchPhase.cleared:
        // Session history only (1-2 items)
        content = _buildSessionHistory(searchState);
    }

    return IgnorePointer(
      ignoring: isOffline,
      child: AnimatedOpacity(
        opacity: isOffline ? 0.38 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        child: Stack(
          children: [
            NotificationListener<ScrollNotification>(
              onNotification: _onScrollNotification,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeOut,
                transitionBuilder: (child, animation) {
                  return FadeTransition(opacity: animation, child: child);
                },
                child: KeyedSubtree(
                  key: ValueKey(searchState.searchPhase),
                  child: content,
                ),
              ),
            ),
            if (selection.isActive) ...[
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: MultiSelectTopBar(
                  allItemIds: searchState
                      .searchResults?[SearchType.track]
                      ?.items
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
        ),
      ),
    );
  }

  /// Wraps results content with a pinned filter pill row when a filter is active.
  Widget _wrapWithFilterPills(Widget inner, SearchState searchState) {
    final hasActiveFilter =
        searchState.activeScopeFilter != null ||
        searchState.activeGenreId != null;
    if (!hasActiveFilter) return inner;
    return Column(
      children: [
        SearchFilterPillRow(
          searchState: searchState,
          onScopeToggle: (type) =>
              ref.read(searchStateProvider.notifier).toggleScopeFilter(type),
          onGenreToggle: (id) =>
              ref.read(searchStateProvider.notifier).toggleGenreFilter(id),
        ),
        Expanded(child: inner),
      ],
    );
  }

  Widget _buildErrorView(String error) {
    return ListView(
      children: [
        const SizedBox(height: 40),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              error,
              style: KalinkaTextStyles.trackRowSubtitle.copyWith(
                color: KalinkaColors.actionDelete,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSessionHistory(SearchState searchState) {
    final sessionHistory = searchState.sessionHistory;
    if (sessionHistory.isEmpty) {
      return const SizedBox.shrink();
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: sessionHistory.take(2).map((query) {
        return GestureDetector(
          onTap: () {
            ref.read(searchStateProvider.notifier).reExecuteQuery(query);
          },
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                const Icon(
                  Icons.access_time,
                  size: 14,
                  color: KalinkaColors.textSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    query,
                    style: KalinkaTextStyles.trackRowTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
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
      }).toList(),
    );
  }

  Widget _buildSkeletonLoading() {
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, widget.bottomPadding),
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
    const trackDisplayLimit = 3;
    const albumDisplayLimit = 5;
    const artistDisplayLimit = 3;
    const playlistDisplayLimit = 5;

    // Count total items for stagger animation
    final trackDisplayCount = searchState.tracksExpanded
        ? tracks.length
        : min<int>(trackDisplayLimit, tracks.length);
    final albumsVisibleCount = searchState.albumsExpanded
        ? albums.length
        : min<int>(albumDisplayLimit, albums.length);
    final artistsVisibleCount = searchState.artistsExpanded
        ? artists.length
        : min<int>(artistDisplayLimit, artists.length);
    final playlistsVisibleCount = searchState.playlistsExpanded
        ? playlists.length
        : min<int>(playlistDisplayLimit, playlists.length);
    final totalItems =
        1 + // AI card
        trackDisplayCount +
        albumsVisibleCount +
        artistsVisibleCount +
        playlistsVisibleCount;
    _triggerStagger(totalItems);

    int itemIndex = 1; // 0 is reserved for the AI suggestion card.
    final artistStartIndex = itemIndex;
    itemIndex += artistsVisibleCount;
    final albumStartIndex = itemIndex;
    itemIndex += albumsVisibleCount;
    final trackStartIndex = itemIndex;
    itemIndex += trackDisplayCount;
    final playlistStartIndex = itemIndex;

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 0, 16, widget.bottomPadding),
      children: [
        // Result count hint
        if (searchState.totalResultCount > 0)
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Text(
              '${searchState.totalResultCount} RESULTS \u00B7 RANKED BY RELEVANCE',
              style: KalinkaTextStyles.resultCountHint,
            ),
          ),
        // AI Suggestion Card (always first when present)
        _StaggeredItem(
          index: 0,
          controller: _staggerController,
          totalItems: totalItems,
          child: const AiSuggestionCard(),
        ),
        const SizedBox(height: 16),

        // Artists section
        if (artists.isNotEmpty) ...[
          SectionHeader(label: 'Artists', count: artists.length),
          ..._buildArtistsSection(
            ref,
            artists,
            searchState,
            artistDisplayLimit,
            artistStartIndex,
            totalItems,
          ),
        ],

        if (artists.isNotEmpty) const SizedBox(height: 10),

        // Albums section in rounded panel (expands with section state)
        if (albums.isNotEmpty)
          _buildAlbumsPanel(
            ref,
            albums,
            searchState,
            albumDisplayLimit,
            albumStartIndex,
            totalItems,
          ),

        if (albums.isNotEmpty) const SizedBox(height: 10),

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
            trackStartIndex,
            totalItems,
          ),
        ],

        // Playlists section
        if (playlists.isNotEmpty) ...[
          SectionHeader(label: 'Playlists', count: playlists.length),
          ..._buildPlaylistsSection(
            ref,
            playlists,
            searchState,
            playlistDisplayLimit,
            playlistStartIndex,
            totalItems,
          ),
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

  List<Widget> _buildAlbumsSection(
    WidgetRef ref,
    List<BrowseItem> albums,
    SearchState searchState,
    int limit,
    int startIndex,
    int totalItems,
  ) {
    final isExpanded = searchState.albumsExpanded;
    final displayCount = isExpanded ? albums.length : min(limit, albums.length);
    final remaining = albums.length - limit;

    return [
      for (int i = 0; i < displayCount; i++)
        _StaggeredItem(
          index: startIndex + i,
          controller: _staggerController,
          totalItems: totalItems,
          child: SearchAlbumRow(item: albums[i]),
        ),
      if (!isExpanded && remaining > 0)
        ShowMoreRow(
          remainingCount: remaining,
          isExpanded: false,
          onTap: () =>
              ref.read(searchStateProvider.notifier).toggleAlbumsExpanded(),
        ),
      if (isExpanded && albums.length > limit)
        ShowMoreRow(
          remainingCount: 0,
          isExpanded: true,
          onTap: () =>
              ref.read(searchStateProvider.notifier).toggleAlbumsExpanded(),
        ),
    ];
  }

  Widget _buildAlbumsPanel(
    WidgetRef ref,
    List<BrowseItem> albums,
    SearchState searchState,
    int limit,
    int startIndex,
    int totalItems,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: KalinkaColors.surfaceBase,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KalinkaColors.borderSubtle),
      ),
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      child: Column(
        children: [
          SectionHeader(
            label: 'Albums',
            count: albums.length,
            showDivider: false,
          ),
          ..._buildAlbumsSection(
            ref,
            albums,
            searchState,
            limit,
            startIndex,
            totalItems,
          ),
        ],
      ),
    );
  }

  List<Widget> _buildArtistsSection(
    WidgetRef ref,
    List<BrowseItem> artists,
    SearchState searchState,
    int limit,
    int startIndex,
    int totalItems,
  ) {
    final isExpanded = searchState.artistsExpanded;
    final displayCount = isExpanded
        ? artists.length
        : min(limit, artists.length);
    final remaining = artists.length - limit;

    return [
      for (int i = 0; i < displayCount; i++)
        _StaggeredItem(
          index: startIndex + i,
          controller: _staggerController,
          totalItems: totalItems,
          child: SearchArtistRow(item: artists[i]),
        ),
      if (!isExpanded && remaining > 0)
        ShowMoreRow(
          remainingCount: remaining,
          isExpanded: false,
          onTap: () =>
              ref.read(searchStateProvider.notifier).toggleArtistsExpanded(),
        ),
      if (isExpanded && artists.length > limit)
        ShowMoreRow(
          remainingCount: 0,
          isExpanded: true,
          onTap: () =>
              ref.read(searchStateProvider.notifier).toggleArtistsExpanded(),
        ),
    ];
  }

  List<Widget> _buildPlaylistsSection(
    WidgetRef ref,
    List<BrowseItem> playlists,
    SearchState searchState,
    int limit,
    int startIndex,
    int totalItems,
  ) {
    final isExpanded = searchState.playlistsExpanded;
    final displayCount = isExpanded
        ? playlists.length
        : min(limit, playlists.length);
    final remaining = playlists.length - limit;

    return [
      for (int i = 0; i < displayCount; i++)
        _StaggeredItem(
          index: startIndex + i,
          controller: _staggerController,
          totalItems: totalItems,
          child: SearchPlaylistRow(item: playlists[i]),
        ),
      if (!isExpanded && remaining > 0)
        ShowMoreRow(
          remainingCount: remaining,
          isExpanded: false,
          onTap: () =>
              ref.read(searchStateProvider.notifier).togglePlaylistsExpanded(),
        ),
      if (isExpanded && playlists.length > limit)
        ShowMoreRow(
          remainingCount: 0,
          isExpanded: true,
          onTap: () =>
              ref.read(searchStateProvider.notifier).togglePlaylistsExpanded(),
        ),
    ];
  }

  Widget _buildBrowseRecommendations(
    BuildContext context,
    WidgetRef ref,
    List<BrowseItemsList> recommendations,
  ) {
    if (recommendations.isEmpty) {
      return ListView(
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
        color: KalinkaColors.surfaceInput,
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
                  color: KalinkaColors.surfaceElevated,
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
                      color: KalinkaColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 120,
                    height: 12,
                    decoration: BoxDecoration(
                      color: KalinkaColors.surfaceElevated,
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
              color: KalinkaColors.surfaceElevated,
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
              color: KalinkaColors.surfaceInput,
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
                    color: KalinkaColors.surfaceInput,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: 120,
                  height: 8,
                  decoration: BoxDecoration(
                    color: KalinkaColors.surfaceInput,
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
              color: KalinkaColors.surfaceInput,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }
}
