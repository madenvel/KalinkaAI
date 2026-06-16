import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data_model/data_model.dart';
import '../providers/search_state_provider.dart';
import '../providers/selection_state_provider.dart';
import '../providers/indexer_status_provider.dart';
import 'browse_list.dart';
import 'indexer_status_banner.dart';
import 'search_cards/browse_item_rows.dart';
import 'search_cards/results_count_line.dart';
import 'search_cards/results_filter_chip_row.dart';
import 'search_cards/search_album_row.dart';
import 'search_cards/search_artist_row.dart';
import 'search_cards/search_playlist_row.dart';
import 'search_cards/search_track_row.dart';
import 'search_cards/section_header.dart';
import 'selection_overlay.dart';
import 'zero_state_surface.dart';
import '../theme/app_theme.dart';
import '../utils/haptics.dart';

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
  final ScrollController _scrollController = ScrollController();
  int _previousResultCount = -1;
  ResultsFilterType _previousFilter = ResultsFilterType.all;

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
    _scrollController.dispose();
    super.dispose();
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification is! ScrollStartNotification) return false;
    if (notification.metrics.axis != Axis.vertical) return false;
    if (notification.metrics.pixels <= 0.5) return false;

    final hasFocus = FocusManager.instance.primaryFocus != null;
    final searchState = ref.read(searchStateProvider);
    if (!hasFocus && !searchState.keyboardVisible) return false;

    if (hasFocus) FocusManager.instance.primaryFocus?.unfocus();
    if (searchState.keyboardVisible) {
      ref.read(searchStateProvider.notifier).setKeyboardVisible(false);
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

    // Connection state no longer gates this feed: cached content stays live
    // and browsable through reconnects and outages alike. The reconnect
    // banner and the escalation card (above the mini-player) are the sole
    // connection-state UI — the surface isn't greyed out or replaced.

    // Reset scroll on filter change
    if (searchState.resultsFilter != _previousFilter) {
      _previousFilter = searchState.resultsFilter;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(0);
        }
      });
    }

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
        } else if (searchState.isAiEnabled &&
            searchState.aiSearchResults != null) {
          inner = _buildAiResultsFeed(searchState);
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
        content = (!searchState.isAiEnabled && searchState.searchResults != null)
            ? _wrapWithResultsFilter(inner, searchState)
            : inner;

      case SearchPhase.results:
        // Full results
        Widget inner;
        if (searchState.isLoading) {
          inner = _buildSkeletonLoading();
        } else if (searchState.error != null) {
          inner = _buildErrorView(searchState.error!);
        } else if (searchState.isAiEnabled &&
            searchState.aiSearchResults != null) {
          inner = _buildAiResultsFeed(searchState);
        } else if (searchState.searchResults != null) {
          inner = _buildResultsFeed(context, ref, searchState);
        } else {
          inner = _buildSkeletonLoading();
        }
        content = (!searchState.isAiEnabled && searchState.searchResults != null)
            ? _wrapWithResultsFilter(inner, searchState)
            : inner;

      case SearchPhase.cleared:
        // Session history only (1-2 items)
        content = _buildSessionHistory(searchState);
    }

    return Stack(
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
        if (selection.isActive)
          const Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: MultiSelectBottomBar(),
          ),
      ],
    );
  }

  /// Wraps results content with the type-based filter chip row, then the
  /// indexer progress strip (so it sits immediately below the chip panel).
  Widget _wrapWithResultsFilter(Widget inner, SearchState searchState) {
    final counts = _resultCounts(searchState);
    return Column(
      children: [
        ResultsFilterChipRow(
          activeFilter: searchState.resultsFilter,
          counts: counts,
          onFilterChanged: (type) =>
              ref.read(searchStateProvider.notifier).setResultsFilter(type),
        ),
        // Indexer progress strip lives in its own Consumer so the 5s poll
        // loop doesn't rebuild the entire results feed.
        if (searchState.isAiEnabled) const _IndexerStatusGate(),
        Expanded(child: inner),
      ],
    );
  }

  Map<SearchType, int> _resultCounts(SearchState searchState) {
    final results = searchState.searchResults;
    if (results == null) return {};
    return {
      for (final entry in results.entries)
        entry.key: entry.value.items.length,
    };
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
    final filter = searchState.resultsFilter;
    final notifier = ref.read(searchStateProvider.notifier);
    final counts = _resultCounts(searchState);

    // Truncation limits for "All" view
    const artistLimit = 3;
    const albumLimit = 5;
    const trackLimit = 3;
    const playlistLimit = 5;

    // Count visible items for stagger animation
    int totalItems = 0;
    if (filter == ResultsFilterType.all) {
      totalItems = min<int>(artistLimit, artists.length) +
          min<int>(albumLimit, albums.length) +
          min<int>(trackLimit, tracks.length) +
          min<int>(playlistLimit, playlists.length);
    } else {
      totalItems = switch (filter) {
        ResultsFilterType.artists => artists.length,
        ResultsFilterType.albums => albums.length,
        ResultsFilterType.tracks => tracks.length,
        ResultsFilterType.playlists => playlists.length,
        ResultsFilterType.all => 0,
      };
    }
    _triggerStagger(totalItems);

    int staggerIdx = 0;

    const divider = Divider(
      color: KalinkaColors.borderSubtle,
      thickness: 1,
      height: 14,
    );
    final children = <Widget>[];

    // Results count line
    children.add(ResultsCountLine(counts: counts));

    void addItemsWithDividers(List<BrowseItem> items, Widget Function(BrowseItem) builder) {
      for (int i = 0; i < items.length; i++) {
        children.add(_StaggeredItem(
          index: staggerIdx++,
          controller: _staggerController,
          totalItems: totalItems,
          child: builder(items[i]),
        ));
        if (i < items.length - 1) {
          children.add(divider);
        }
      }
    }

    if (filter == ResultsFilterType.all) {
      // ── Artists section ──
      if (artists.isNotEmpty) {
        children.add(SectionHeader(
            label: 'Artists',
            count: artists.length,
            showDivider: false,
            onOnlyTap: () => notifier.setResultsFilter(ResultsFilterType.artists),
        ));
        addItemsWithDividers(
          artists.take(artistLimit).toList(),
          (a) => SearchArtistRow(item: a),
        );
        children.add(const SizedBox(height: 10));
      }

      // ── Albums section ──
      if (albums.isNotEmpty) {
        children.add(SectionHeader(
            label: 'Albums',
            count: albums.length,
            showDivider: artists.isNotEmpty,
            onOnlyTap: () => notifier.setResultsFilter(ResultsFilterType.albums),
        ));
        addItemsWithDividers(
          albums.take(albumLimit).toList(),
          (a) => SearchAlbumRow(item: a),
        );
        children.add(const SizedBox(height: 10));
      }

      // ── Tracks section ──
      if (tracks.isNotEmpty) {
        children.add(SectionHeader(
            label: 'Tracks',
            count: tracks.length,
            showDivider: artists.isNotEmpty || albums.isNotEmpty,
            onOnlyTap: () => notifier.setResultsFilter(ResultsFilterType.tracks),
        ));
        addItemsWithDividers(
          tracks.take(trackLimit).toList(),
          (t) => SearchTrackRow(item: t),
        );
        children.add(const SizedBox(height: 10));
      }

      // ── Playlists section ──
      if (playlists.isNotEmpty) {
        children.add(SectionHeader(
            label: 'Playlists',
            count: playlists.length,
            showDivider: artists.isNotEmpty || albums.isNotEmpty || tracks.isNotEmpty,
            onOnlyTap: () => notifier.setResultsFilter(ResultsFilterType.playlists),
        ));
        addItemsWithDividers(
          playlists.take(playlistLimit).toList(),
          (p) => SearchPlaylistRow(item: p),
        );
      }
    } else {
      // ── Filtered view: show all items of the selected type ──
      final List<BrowseItem> items;
      Widget Function(BrowseItem) builder;
      switch (filter) {
        case ResultsFilterType.artists:
          items = artists;
          builder = (item) => SearchArtistRow(item: item);
        case ResultsFilterType.albums:
          items = albums;
          builder = (item) => SearchAlbumRow(item: item);
        case ResultsFilterType.tracks:
          items = tracks;
          builder = (item) => SearchTrackRow(item: item);
        case ResultsFilterType.playlists:
          items = playlists;
          builder = (item) => SearchPlaylistRow(item: item);
        case ResultsFilterType.all:
          items = [];
          builder = (_) => const SizedBox.shrink();
      }
      addItemsWithDividers(items, builder);
    }

    return ListView(
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(16, 0, 16, widget.bottomPadding),
      children: children,
    );
  }

  Widget _buildAiResultsFeed(SearchState state) {
    final topLevel = state.aiSearchResults!.items;

    // The AI endpoint groups results into catalog containers (e.g. "Tracks",
    // "Albums", "Artists") whose actual renderable items live in `sections`.
    // Flatten by walking top-level items: catalogs contribute a section
    // header + their section children; bare items render directly.
    const aiGroupVisibleLimit = 5;
    final expanded = state.aiExpandedSections;
    final groups = <({String? id, String? label, List<BrowseItem> items})>[];
    for (final item in topLevel) {
      if (item.catalog != null && item.sections != null) {
        groups.add((id: item.id, label: item.name, items: item.sections!));
      } else if (item.browseType != BrowseType.unknown &&
          item.browseType != BrowseType.catalog) {
        groups.add((id: null, label: null, items: [item]));
      }
    }

    final totalItems = groups.fold<int>(0, (sum, g) => sum + g.items.length);
    _triggerStagger(totalItems);

    // The primary track group(s) merge with the AI header into one card; album
    // and artist groups render below it as plain "Related …" sections.
    final trackGroups = groups
        .where((g) => _aiGroupType(g.items) == BrowseType.track)
        .toList();
    final relatedGroups = groups
        .where((g) => _aiGroupType(g.items) != BrowseType.track)
        .toList();

    // Every track shown in the card — including ones hidden behind a collapsed
    // section — so "Select all" reaches the full set, not just the visible rows.
    final allTrackIds = <String>[
      for (final group in trackGroups)
        for (final item in group.items)
          if (item.browseType == BrowseType.track) item.id,
    ];

    final children = <Widget>[];

    if (totalItems == 0) {
      children.add(const SizedBox(height: 60));
      children.add(Center(
        child: Column(
          children: [
            Icon(
              Icons.auto_awesome,
              size: 64,
              color: KalinkaColors.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text('No AI matches', style: KalinkaTextStyles.cardTitle),
            const SizedBox(height: 8),
            Text(
              'Try rephrasing your prompt',
              style: KalinkaTextStyles.trackRowSubtitle,
            ),
          ],
        ),
      ));
    } else {
      BrowseItemRows rowsFor(({String? id, String? label, List<BrowseItem> items}) group) {
        final groupId = group.id;
        return BrowseItemRows(
          items: group.items,
          visibleLimit: aiGroupVisibleLimit,
          isExpanded: groupId != null && expanded.contains(groupId),
          onToggleExpand: groupId == null
              ? null
              : () => ref
                  .read(searchStateProvider.notifier)
                  .revealAiSection(groupId),
        );
      }

      // ── AI tracks card: header + track rows merged onto one surface ──
      if (trackGroups.isNotEmpty) {
        children.add(Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          decoration: BoxDecoration(
            color: KalinkaColors.surfaceRaised,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: KalinkaColors.borderSubtle, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _AiSuggestionsHeader(trackIds: allTrackIds),
              const SizedBox(height: 4),
              const Divider(
                color: KalinkaColors.borderSubtle,
                thickness: 1,
                height: 16,
              ),
              for (final group in trackGroups) rowsFor(group),
            ],
          ),
        ));
      } else {
        // No tracks — still label the feed as AI-generated.
        children.add(const Padding(
          padding: EdgeInsets.only(top: 12),
          child: _AiSuggestionsHeader(trackIds: []),
        ));
      }

      // ── Related sections (albums, artists): plain rows, no card ──
      if (relatedGroups.isNotEmpty) {
        children.add(const SizedBox(height: 18));
      }
      for (int g = 0; g < relatedGroups.length; g++) {
        final group = relatedGroups[g];
        if (group.label != null) {
          children.add(SectionHeader(
            label: _relatedLabel(group.label!),
            count: group.items.length,
            showDivider: g > 0,
          ));
        }
        children.add(rowsFor(group));
      }
    }

    return ListView(
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(16, 0, 16, widget.bottomPadding),
      children: children,
    );
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

/// Renders the indexer banner only while indexing is in progress. Watching
/// [indexerStatusProvider] in its own Consumer keeps the 5s poll loop from
/// rebuilding the surrounding results feed.
class _IndexerStatusGate extends ConsumerWidget {
  const _IndexerStatusGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showIndexer = ref.watch(
      indexerStatusProvider.select((s) {
        final status = s.status;
        return status != null && !status.isEmpty && !status.isComplete;
      }),
    );
    if (!showIndexer) return const SizedBox.shrink();
    final progressPct =
        ref.watch(indexerStatusProvider.select((s) => s.progressPct));
    return IndexerStatusBanner(progressPct: progressPct);
  }
}

/// Dominant renderable type of an AI result group — the first item that isn't a
/// catalog/unknown wrapper. Used to split track groups (the card) from album and
/// artist groups (the "Related …" sections below).
BrowseType _aiGroupType(List<BrowseItem> items) {
  for (final item in items) {
    if (item.browseType != BrowseType.unknown &&
        item.browseType != BrowseType.catalog) {
      return item.browseType;
    }
  }
  return BrowseType.unknown;
}

/// Prefixes a group label with "Related " unless it already starts that way,
/// e.g. "Albums" → "Related Albums".
String _relatedLabel(String label) {
  return label.toLowerCase().startsWith('related') ? label : 'Related $label';
}

/// Header above AI-generated search results. Labels the feed as AI suggestions
/// and offers a one-tap select/clear affordance covering every track — including
/// those hidden behind a collapsed section — so the bottom batch bar can act on
/// the whole set (play / play next / add to queue).
class _AiSuggestionsHeader extends ConsumerWidget {
  final List<String> trackIds;

  const _AiSuggestionsHeader({required this.trackIds});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasTracks = trackIds.isNotEmpty;
    final allSelected = ref.watch(
      selectionStateProvider.select(
        (s) => hasTracks && trackIds.every(s.selectedIds.contains),
      ),
    );

    return Row(
        children: [
          const Icon(
            Icons.auto_awesome,
            size: 16,
            color: KalinkaColors.accentTint,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI SUGGESTIONS',
                  style: KalinkaTextStyles.sectionLabel.copyWith(
                    color: KalinkaColors.accentTint,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Curated for your search',
                  style: KalinkaTextStyles.trackRowSubtitle,
                ),
              ],
            ),
          ),
          if (hasTracks)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                KalinkaHaptics.lightImpact();
                final notifier = ref.read(selectionStateProvider.notifier);
                if (allSelected) {
                  notifier.deselectTracks(trackIds);
                } else {
                  notifier.selectTracks(trackIds);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: allSelected
                      ? KalinkaColors.accentSubtle
                      : KalinkaColors.surfaceElevated,
                  border: Border.all(
                    color: allSelected
                        ? KalinkaColors.accentBorder
                        : KalinkaColors.borderDefault,
                    width: 1,
                  ),
                ),
                child: Text(
                  allSelected ? 'Clear' : 'Select all',
                  style: KalinkaFonts.sans(
                    fontSize: KalinkaTypography.baseSize + 1,
                    fontWeight: FontWeight.w600,
                    color: allSelected
                        ? KalinkaColors.accentTint
                        : KalinkaColors.textPrimary,
                  ),
                ),
              ),
            ),
        ],
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
