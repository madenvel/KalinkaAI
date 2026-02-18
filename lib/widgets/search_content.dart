import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/search_state_provider.dart';
import '../providers/selection_state_provider.dart';
import '../data_model/data_model.dart';
import 'browse_list.dart';
import 'selection_overlay.dart';

const _defaultSuggestions = [
  'Miles Davis',
  'Kind of Blue',
  'So What',
  'music for relaxation',
];

class SearchContent extends ConsumerWidget {
  const SearchContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchState = ref.watch(searchStateProvider);
    final selection = ref.watch(selectionStateProvider);

    Widget content;

    if (searchState.isLoading) {
      content = const Center(child: CircularProgressIndicator());
    } else if (searchState.error != null) {
      content = Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            searchState.error!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    } else if (searchState.searchResults != null) {
      content = _buildSearchResults(
        context, ref, searchState.searchResults!, selection,
      );
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
        const Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SelectionActionBar(),
        ),
      ],
    );
  }

  Widget _buildHistoryAndSuggestions(BuildContext context, WidgetRef ref) {
    final history = ref.read(searchStateProvider.notifier).getSearchHistory();
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        if (history.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent searches',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {
                  ref.read(searchStateProvider.notifier).clearHistory();
                },
                child: const Text('Clear'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...history.map((query) => _buildHistoryItem(context, ref, query)),
          const SizedBox(height: 24),
        ],
        Text(
          history.isEmpty ? 'Suggestions' : 'Try searching for',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ..._defaultSuggestions.map(
          (suggestion) => _buildSuggestionItem(context, ref, suggestion),
        ),
      ],
    );
  }

  Widget _buildHistoryItem(BuildContext context, WidgetRef ref, String query) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: () {
        ref.read(searchStateProvider.notifier).setQuery(query);
        ref.read(searchStateProvider.notifier).performSearch();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(
              Icons.history,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 16),
            Expanded(child: Text(query, style: theme.textTheme.bodyLarge)),
            Icon(
              Icons.north_west,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
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
    final theme = Theme.of(context);

    return InkWell(
      onTap: () {
        ref.read(searchStateProvider.notifier).setQuery(suggestion);
        ref.read(searchStateProvider.notifier).performSearch();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(
              Icons.search,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 16),
            Expanded(child: Text(suggestion, style: theme.textTheme.bodyLarge)),
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
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No recommendations available'),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: recommendations.length,
      itemBuilder: (context, index) {
        final browseList = recommendations[index];
        if (browseList.items.isEmpty) return const SizedBox.shrink();

        // Group items by sections
        final sections = <BrowseItem>[];
        for (final item in browseList.items) {
          if (item.sections != null && item.sections!.isNotEmpty) {
            sections.addAll(item.sections!);
          } else {
            sections.add(item);
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: sections.map((section) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: BrowseList(section: section),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildSearchResults(
    BuildContext context,
    WidgetRef ref,
    Map<SearchType, BrowseItemsList> results,
    SelectionState selection,
  ) {
    final theme = Theme.of(context);

    // Check if all results are empty
    final hasResults = results.values.any((list) => list.items.isNotEmpty);

    if (!hasResults) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.search_off,
                size: 64,
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.5,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'No results found',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Try different keywords',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Show results in fixed order: tracks, albums, artists, playlists
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        _buildSearchSection(
          context, ref, 'Tracks', results[SearchType.track], selection,
        ),
        _buildSearchSection(
          context, ref, 'Albums', results[SearchType.album], selection,
        ),
        _buildSearchSection(
          context, ref, 'Artists', results[SearchType.artist], selection,
        ),
        _buildSearchSection(
          context, ref, 'Playlists', results[SearchType.playlist], selection,
        ),
      ],
    );
  }

  Widget _buildSearchSection(
    BuildContext context,
    WidgetRef ref,
    String title,
    BrowseItemsList? items,
    SelectionState selection,
  ) {
    if (items == null || items.items.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        BrowseList(
          section: BrowseItem(
            id: 'search-$title',
            name: title,
            canBrowse: false,
            canAdd: false,
            sections: items.items,
          ),
          isSearchResult: true,
          selectionMode: selection.isActive,
          selectedIds: selection.selectedIds,
          onSelectionToggle: (id) {
            ref.read(selectionStateProvider.notifier).toggle(id);
          },
          onSelectionStart: () {
            // Selection mode is entered via long-press in BrowseList
          },
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
