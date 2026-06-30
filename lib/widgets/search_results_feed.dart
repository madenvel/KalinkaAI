import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data_model/data_model.dart';
import '../providers/search_state_provider.dart';
import '../providers/selection_state_provider.dart';
import '../providers/indexer_status_provider.dart';
import '../providers/source_modules_provider.dart';
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
        content =
            (!searchState.isAiEnabled && searchState.searchResults != null)
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
        content =
            (!searchState.isAiEnabled && searchState.searchResults != null)
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
      for (final entry in results.entries) entry.key: entry.value.items.length,
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
    return _AiSearchShimmer(bottomPadding: widget.bottomPadding);
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
      totalItems =
          min<int>(artistLimit, artists.length) +
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

    void addItemsWithDividers(
      List<BrowseItem> items,
      Widget Function(BrowseItem) builder,
    ) {
      for (int i = 0; i < items.length; i++) {
        children.add(
          _StaggeredItem(
            index: staggerIdx++,
            controller: _staggerController,
            totalItems: totalItems,
            child: builder(items[i]),
          ),
        );
        if (i < items.length - 1) {
          children.add(divider);
        }
      }
    }

    if (filter == ResultsFilterType.all) {
      // ── Artists section ──
      if (artists.isNotEmpty) {
        children.add(
          SectionHeader(
            label: 'Artists',
            count: artists.length,
            showDivider: false,
            onOnlyTap: () =>
                notifier.setResultsFilter(ResultsFilterType.artists),
          ),
        );
        addItemsWithDividers(
          artists.take(artistLimit).toList(),
          (a) => SearchArtistRow(item: a),
        );
        children.add(const SizedBox(height: 10));
      }

      // ── Albums section ──
      if (albums.isNotEmpty) {
        children.add(
          SectionHeader(
            label: 'Albums',
            count: albums.length,
            showDivider: artists.isNotEmpty,
            onOnlyTap: () =>
                notifier.setResultsFilter(ResultsFilterType.albums),
          ),
        );
        addItemsWithDividers(
          albums.take(albumLimit).toList(),
          (a) => SearchAlbumRow(item: a),
        );
        children.add(const SizedBox(height: 10));
      }

      // ── Tracks section ──
      if (tracks.isNotEmpty) {
        children.add(
          SectionHeader(
            label: 'Tracks',
            count: tracks.length,
            showDivider: artists.isNotEmpty || albums.isNotEmpty,
            onOnlyTap: () =>
                notifier.setResultsFilter(ResultsFilterType.tracks),
          ),
        );
        addItemsWithDividers(
          tracks.take(trackLimit).toList(),
          (t) => SearchTrackRow(item: t),
        );
        children.add(const SizedBox(height: 10));
      }

      // ── Playlists section ──
      if (playlists.isNotEmpty) {
        children.add(
          SectionHeader(
            label: 'Playlists',
            count: playlists.length,
            showDivider:
                artists.isNotEmpty || albums.isNotEmpty || tracks.isNotEmpty,
            onOnlyTap: () =>
                notifier.setResultsFilter(ResultsFilterType.playlists),
          ),
        );
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

    // Each top-level item is a backend-described section: a catalog carrying a
    // preview_config (icon + layout) plus its renderable children in
    // `sections`. The feed renders each section verbatim — it does not rename,
    // regroup by content type, or re-interpret what the server sent. The
    // section's representation (card vs plain list) comes from
    // preview_config.type; its label / subtitle / icon come from the section.
    const defaultVisibleLimit = 5;
    final expanded = state.aiExpandedSections;
    final sections = topLevel
        .where((s) => s.catalog != null && (s.sections?.isNotEmpty ?? false))
        .toList();

    final totalItems = sections.fold<int>(
      0,
      (sum, s) => sum + s.sections!.length,
    );
    _triggerStagger(totalItems);

    final children = <Widget>[];

    if (totalItems == 0) {
      children.add(const SizedBox(height: 60));
      children.add(
        Center(
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
        ),
      );
    } else {
      children.add(const SizedBox(height: 12));
      for (int i = 0; i < sections.length; i++) {
        final section = sections[i];
        final items = section.sections!;
        final groupId = section.id;
        final preview = section.catalog?.previewConfig;
        final title = section.name ?? '';
        final icon = _sectionIcon(preview?.icon);

        final rows = BrowseItemRows(
          items: items,
          visibleLimit: defaultVisibleLimit,
          isExpanded: expanded.contains(groupId),
          onToggleExpand: () {
            final wasExpanded = expanded.contains(groupId);
            ref.read(searchStateProvider.notifier).revealAiSection(groupId);
            // Collapsing leaves the viewport scrolled down past the now-hidden
            // rows — return to the top of the feed.
            if (wasExpanded && _scrollController.hasClients) {
              _scrollController.animateTo(
                0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            }
          },
        );

        if (i > 0) children.add(const SizedBox(height: 24));

        if (preview?.type == PreviewType.card) {
          // Card representation: bordered surface + select-all for tracks.
          final trackIds = <String>[
            for (final item in items)
              if (item.browseType == BrowseType.track) item.id,
          ];
          children.add(
            _SectionCard(
              icon: icon,
              accentColor: _sectionAccent(section),
              title: title,
              subtitle: section.subname,
              trackIds: trackIds,
              child: rows,
            ),
          );
        } else {
          // Plain section: header + rows. Tint the icon to the section's
          // source badge colour when it resolves to a single source.
          children.add(
            SectionHeader(
              label: title,
              subtitle: section.subname,
              icon: icon,
              iconColor: _sectionAccent(section),
              count: items.length,
              showDivider: false,
            ),
          );
          children.add(rows);
        }
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
    final progressPct = ref.watch(
      indexerStatusProvider.select((s) => s.progressPct),
    );
    return IndexerStatusBanner(progressPct: progressPct);
  }
}

/// Maps a backend section icon id (from `preview_config.icon`) to a concrete
/// icon. Unknown / null ids render no icon — the UI never invents one.
IconData? _sectionIcon(String? id) {
  switch (id) {
    case 'best_match':
      return Icons.star_rounded;
    case 'ai_suggestions':
      return Icons.auto_awesome;
    case 'album':
      return Icons.album_outlined;
    case 'artist':
      return Icons.person_outline;
    default:
      return null;
  }
}

/// Source-badge colour for an AI section, so its icon / card tint match that
/// source's badge. Uses the catalog's `sources` list — colouring only when it
/// names exactly one source — and falls back to the id's source when the list
/// is absent (unless that's the synthetic "server"). Returns null for
/// cross-source sections (e.g. Related Albums) and unattributable ones, which
/// keep the default accent / surface.
Color? _sectionAccent(BrowseItem section) {
  final sources = section.catalog?.sources ?? const <String>[];
  String? source;
  if (sources.length == 1) {
    source = sources.first;
  } else if (sources.isEmpty) {
    final idSource = _parseSource(section.id);
    if (idSource != 'server') source = idSource;
  }
  if (source == null || source.isEmpty) return null;
  return colorForSourceName(source);
}

/// Source segment of a `kalinka:{source}:{type}:{id}` entity id, or null when
/// absent / unparseable.
String? _parseSource(String? id) {
  if (id == null) return null;
  try {
    final source = EntityId.fromString(id).source;
    return source.isEmpty ? null : source;
  } catch (_) {
    return null;
  }
}

/// A backend-described "card" section (preview_config.type == card): a bordered
/// surface with a header (icon + title + subtitle) wrapping a list of rows. When
/// the section contains tracks it also offers a one-tap select/clear affordance
/// covering every track id — including ones hidden behind a collapsed section —
/// so the bottom batch bar can act on the whole set.
class _SectionCard extends ConsumerWidget {
  final IconData? icon;
  final Color? accentColor;
  final String title;
  final String? subtitle;
  final List<String> trackIds;
  final Widget child;

  const _SectionCard({
    required this.icon,
    required this.accentColor,
    required this.title,
    required this.subtitle,
    required this.trackIds,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasTracks = trackIds.isNotEmpty;
    final allSelected = ref.watch(
      selectionStateProvider.select(
        (s) => hasTracks && trackIds.every(s.selectedIds.contains),
      ),
    );

    final tint = accentColor;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      decoration: BoxDecoration(
        // Subtle wash of the source colour in the leading corner, fading into
        // the normal raised surface — ties the card to its source badge.
        color: tint == null ? KalinkaColors.surfaceRaised : null,
        gradient: tint == null
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: const [0.0, 0.55],
                colors: [
                  Color.alphaBlend(
                    tint.withValues(alpha: 0.10),
                    KalinkaColors.surfaceRaised,
                  ),
                  KalinkaColors.surfaceRaised,
                ],
              ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: tint == null
              ? KalinkaColors.borderSubtle
              : tint.withValues(alpha: 0.22),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: tint ?? KalinkaColors.accentTint),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.toUpperCase(),
                      style: KalinkaTextStyles.sectionLabel.copyWith(
                        color: KalinkaColors.accentTint,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: KalinkaTextStyles.trackRowSubtitle,
                      ),
                    ],
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
          ),
          const SizedBox(height: 4),
          const Divider(
            color: KalinkaColors.borderSubtle,
            thickness: 1,
            height: 16,
          ),
          child,
        ],
      ),
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

/// Shimmer placeholder mirroring the AI search results structure: a plain
/// section (icon + title + count, then rows) followed by a bordered card
/// section (icon + title + Select-all chip, then rows). Shown while AI results
/// load, so the skeleton matches the real feed instead of a now-removed card.
class _AiSearchShimmer extends StatefulWidget {
  final double bottomPadding;

  const _AiSearchShimmer({required this.bottomPadding});

  @override
  State<_AiSearchShimmer> createState() => _AiSearchShimmerState();
}

class _AiSearchShimmerState extends State<_AiSearchShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _opacity = Tween<double>(
      begin: 0.4,
      end: 0.7,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacity,
      builder: (context, child) =>
          Opacity(opacity: _opacity.value, child: child),
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16, 12, 16, widget.bottomPadding),
        children: [
          // Plain section: header (icon + title + count) then rows.
          _sectionHeader(titleWidth: 150, withCount: true),
          const SizedBox(height: 4),
          ..._rows(2),
          const SizedBox(height: 18),
          // Card section: bordered surface with header + Select-all then rows.
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            decoration: BoxDecoration(
              color: KalinkaColors.surfaceRaised,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: KalinkaColors.borderSubtle, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _sectionHeader(titleWidth: 130, withSelectAll: true),
                const Divider(
                  color: KalinkaColors.borderSubtle,
                  thickness: 1,
                  height: 16,
                ),
                ..._rows(3),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Header row: a small icon box, a title bar with a subtitle bar beneath,
  /// and a trailing count bar or Select-all chip.
  Widget _sectionHeader({
    required double titleWidth,
    bool withCount = false,
    bool withSelectAll = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          _box(16, radius: 5),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _bar(titleWidth, 10),
                const SizedBox(height: 5),
                _bar(titleWidth * 0.8, 8),
              ],
            ),
          ),
          if (withCount) _bar(14, 10),
          if (withSelectAll) _chip(72),
        ],
      ),
    );
  }

  List<Widget> _rows(int count) {
    final rows = <Widget>[];
    for (int i = 0; i < count; i++) {
      rows.add(_row());
      if (i < count - 1) {
        rows.add(
          const Divider(
            color: KalinkaColors.borderSubtle,
            thickness: 1,
            height: 14,
          ),
        );
      }
    }
    return rows;
  }

  /// One row mirroring a track tile: 44×44 artwork + two text lines + a
  /// duration bar, matching [TrackTileLayout]'s 12/8 padding and 10px gap.
  Widget _row() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          _box(44),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _line(0.55, 12),
                const SizedBox(height: 7),
                _line(0.35, 9),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _bar(28, 9),
        ],
      ),
    );
  }

  /// Fixed-size bar — section labels, count, duration.
  Widget _bar(double width, double height) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: KalinkaColors.surfaceInput,
      borderRadius: BorderRadius.circular(4),
    ),
  );

  /// Fractional-width line for row text (fills its column slot to [factor]).
  Widget _line(double factor, double height) => Align(
    alignment: Alignment.centerLeft,
    child: FractionallySizedBox(
      widthFactor: factor,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: KalinkaColors.surfaceInput,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    ),
  );

  /// Rounded square placeholder (artwork or section icon).
  Widget _box(double size, {double radius = 6}) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: KalinkaColors.surfaceInput,
      borderRadius: BorderRadius.circular(radius),
    ),
  );

  /// Pill placeholder for the Select-all affordance.
  Widget _chip(double width) => Container(
    width: width,
    height: 30,
    decoration: BoxDecoration(
      color: KalinkaColors.surfaceInput,
      borderRadius: BorderRadius.circular(8),
    ),
  );
}
