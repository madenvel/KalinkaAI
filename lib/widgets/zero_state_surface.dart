import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/search_state_provider.dart';
import '../theme/app_theme.dart';
import 'search_cards/search_album_row.dart';
import 'search_cards/search_artist_row.dart';
import 'search_cards/search_track_row.dart';
import '../data_model/data_model.dart';

/// Zero-state content surface shown when search is activated but no query
/// has been typed. Displays AI prompt suggestions, "In your library" items,
/// and optionally recent search history.
class ZeroStateSurface extends ConsumerStatefulWidget {
  const ZeroStateSurface({super.key});

  @override
  ConsumerState<ZeroStateSurface> createState() => _ZeroStateSurfaceState();
}

class _ZeroStateSurfaceState extends ConsumerState<ZeroStateSurface>
    with SingleTickerProviderStateMixin {
  late AnimationController _staggerController;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
  }

  @override
  void dispose() {
    _staggerController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchStateProvider);
    final history = ref.read(searchStateProvider.notifier).getSearchHistory();
    final aiSuggestions = searchState.aiPromptSuggestions;
    final browseRecs = searchState.browseRecommendations;

    final libraryItemCount =
        browseRecs != null ? _countLibraryItems(browseRecs) : 0;
    final showLibrarySection =
        searchState.isLoading || libraryItemCount > 0;

    int itemIndex = 0;
    int totalItems =
        (history.isNotEmpty ? history.length + 1 : 0) +
        aiSuggestions.length +
        1 + // AI section label
        (showLibrarySection ? libraryItemCount + 1 : 0);

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      children: [
        // Recent searches section (State 3)
        if (history.isNotEmpty) ...[
          _StaggeredZeroItem(
            index: itemIndex++,
            controller: _staggerController,
            totalItems: totalItems,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('RECENT', style: KalinkaTextStyles.sectionLabel),
                GestureDetector(
                  onTap: () {
                    ref.read(searchStateProvider.notifier).clearHistory();
                    setState(() {});
                  },
                  child: Text(
                    'Clear all',
                    style: KalinkaTextStyles.clearAllLink,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ...history.take(5).map((query) {
            final idx = itemIndex++;
            return _StaggeredZeroItem(
              index: idx,
              controller: _staggerController,
              totalItems: totalItems,
              child: _HistoryRow(
                query: query,
                onTap: () {
                  ref.read(searchStateProvider.notifier).reExecuteQuery(query);
                },
                onDelete: () {
                  ref
                      .read(searchStateProvider.notifier)
                      .removeHistoryItem(query);
                  setState(() {});
                },
              ),
            );
          }),
          const SizedBox(height: 16),
          Container(height: 1, color: KalinkaColors.borderDefault),
          const SizedBox(height: 16),
        ],

        // AI prompt suggestions section
        _StaggeredZeroItem(
          index: itemIndex++,
          controller: _staggerController,
          totalItems: totalItems,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('ASK THE AI', style: KalinkaTextStyles.sectionLabel),
          ),
        ),
        ...aiSuggestions.map((prompt) {
          final idx = itemIndex++;
          return _StaggeredZeroItem(
            index: idx,
            controller: _staggerController,
            totalItems: totalItems,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _AiPromptChip(
                promptText: prompt,
                onTap: () {
                  ref.read(searchStateProvider.notifier).reExecuteQuery(prompt);
                },
              ),
            ),
          );
        }),

        const SizedBox(height: 16),
        Container(height: 1, color: KalinkaColors.borderDefault),
        const SizedBox(height: 16),

        // In your library section
        if (showLibrarySection) ...[
          _StaggeredZeroItem(
            index: itemIndex++,
            controller: _staggerController,
            totalItems: totalItems,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'IN YOUR LIBRARY',
                style: KalinkaTextStyles.sectionLabel,
              ),
            ),
          ),
          if (browseRecs != null)
            ..._buildLibraryItems(browseRecs, itemIndex, totalItems)
          else if (searchState.isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: KalinkaColors.accent,
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }

  int _countLibraryItems(List<BrowseItemsList> recs) {
    int count = 0;
    for (final browseList in recs) {
      count += browseList.items.take(4).length;
    }
    return count.clamp(0, 4);
  }

  List<Widget> _buildLibraryItems(
    List<BrowseItemsList> recs,
    int startIndex,
    int totalItems,
  ) {
    final items = <BrowseItem>[];
    for (final browseList in recs) {
      for (final item in browseList.items) {
        items.add(item);
        if (items.length >= 4) break;
      }
      if (items.length >= 4) break;
    }

    int idx = startIndex;
    return items.map((item) {
      final currentIdx = idx++;
      Widget row;
      if (item.track != null) {
        row = SearchTrackRow(item: item);
      } else if (item.album != null) {
        row = SearchAlbumRow(item: item);
      } else if (item.artist != null) {
        row = SearchArtistRow(item: item);
      } else {
        row = SearchAlbumRow(item: item);
      }
      return _StaggeredZeroItem(
        index: currentIdx,
        controller: _staggerController,
        totalItems: totalItems,
        child: row,
      );
    }).toList();
  }
}

/// A single AI prompt suggestion chip.
class _AiPromptChip extends StatelessWidget {
  final String promptText;
  final VoidCallback onTap;

  const _AiPromptChip({required this.promptText, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: KalinkaColors.accent.withValues(alpha: 0.08),
          border: Border.all(
            color: KalinkaColors.accent.withValues(alpha: 0.18),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.auto_awesome,
              size: 16,
              color: KalinkaColors.accent.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                promptText,
                style: KalinkaTextStyles.aiPromptChipText,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.arrow_forward,
              size: 14,
              color: KalinkaColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

/// A single recent search history row with delete button.
class _HistoryRow extends StatefulWidget {
  final String query;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _HistoryRow({
    required this.query,
    required this.onTap,
    required this.onDelete,
  });

  @override
  State<_HistoryRow> createState() => _HistoryRowState();
}

class _HistoryRowState extends State<_HistoryRow> {
  bool _deleting = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      height: _deleting ? 0 : 44,
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(),
      child: GestureDetector(
        onTap: widget.onTap,
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
                  widget.query,
                  style: KalinkaTextStyles.trackRowTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              GestureDetector(
                onTap: () {
                  setState(() => _deleting = true);
                  Future.delayed(const Duration(milliseconds: 200), () {
                    widget.onDelete();
                  });
                },
                child: const SizedBox(
                  width: 20,
                  height: 20,
                  child: Icon(
                    Icons.close,
                    size: 14,
                    color: KalinkaColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Staggered entrance animation for zero-state items.
/// Each item fades in + slides up with 40ms stagger.
class _StaggeredZeroItem extends StatelessWidget {
  final int index;
  final AnimationController controller;
  final int totalItems;
  final Widget child;

  const _StaggeredZeroItem({
    required this.index,
    required this.controller,
    required this.totalItems,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final clampedTotal = totalItems.clamp(1, 999);
    final totalDuration = 180 + clampedTotal * 40;
    final start = (index * 40 / totalDuration).clamp(0.0, 1.0);
    final end = ((index * 40 + 180) / totalDuration).clamp(0.0, 1.0);

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
            offset: Offset(0, 6 * (1 - animation.value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
