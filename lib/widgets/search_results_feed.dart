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

/// Search results feed for the phone sheet.
/// Receives ScrollController from DraggableScrollableSheet.
class SearchResultsFeed extends ConsumerWidget {
  final ScrollController scrollController;
  final DraggableScrollableController? sheetController;

  const SearchResultsFeed({
    super.key,
    required this.scrollController,
    this.sheetController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchState = ref.watch(searchStateProvider);
    final selection = ref.watch(selectionStateProvider);

    Widget content;

    if (searchState.isLoading) {
      content = ListView(
        controller: scrollController,
        children: const [
          SizedBox(height: 80),
          Center(child: CircularProgressIndicator()),
        ],
      );
    } else if (searchState.error != null) {
      content = ListView(
        controller: scrollController,
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
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: MultiSelectTopBar(),
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

  Widget _buildResultsFeed(
    BuildContext context,
    WidgetRef ref,
    SearchState searchState,
  ) {
    final results = searchState.searchResults!;
    final hasResults = results.values.any((list) => list.items.isNotEmpty);

    if (!hasResults) {
      return ListView(
        controller: scrollController,
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

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      children: [
        // AI Suggestion Card (always first when present)
        const AiSuggestionCard(),
        const SizedBox(height: 16),

        // Tracks section
        if (tracks.isNotEmpty) ...[
          SectionHeader(
            label: 'Tracks',
            count: tracks.length,
            showDivider: false,
          ),
          ..._buildTracksSection(ref, tracks, searchState),
        ],

        // Albums section
        if (albums.isNotEmpty) ...[
          SectionHeader(label: 'Albums', count: albums.length),
          ...albums.map(
            (item) =>
                SearchAlbumRow(item: item, sheetController: sheetController),
          ),
        ],

        // Artists section
        if (artists.isNotEmpty) ...[
          SectionHeader(label: 'Artists', count: artists.length),
          ...artists.map(
            (item) =>
                SearchArtistRow(item: item, sheetController: sheetController),
          ),
        ],

        // Playlists section
        if (playlists.isNotEmpty) ...[
          SectionHeader(label: 'Playlists', count: playlists.length),
          ...playlists.map(
            (item) =>
                SearchPlaylistRow(item: item, sheetController: sheetController),
          ),
        ],
      ],
    );
  }

  List<Widget> _buildTracksSection(
    WidgetRef ref,
    List<BrowseItem> tracks,
    SearchState searchState,
  ) {
    final isExpanded = searchState.tracksExpanded;
    final displayCount = isExpanded ? tracks.length : min(3, tracks.length);
    final remaining = tracks.length - 3;

    return [
      for (int i = 0; i < displayCount; i++)
        SearchTrackRow(item: tracks[i], sheetController: sheetController),
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
      controller: scrollController,
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
        controller: scrollController,
        children: [
          const Padding(
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
      controller: scrollController,
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
