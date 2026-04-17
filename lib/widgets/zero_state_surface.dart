import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data_model/data_model.dart';
import '../providers/search_state_provider.dart';
import '../theme/app_theme.dart';
import 'search_cards/browse_item_rows.dart';
import 'search_cards/section_header.dart';

/// Zero-state content surface shown when search is activated but no query
/// has been typed. Comprises two layers:
///  Layer 1: non-scrollable recent chips + filter pills (pinned)
///  Layer 2: scrollable content sections responding to active filters
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Layer 1 — Filter pills (pinned, part of header complex)
        SearchFilterPillRow(
          searchState: searchState,
          onScopeToggle: (type) =>
              ref.read(searchStateProvider.notifier).toggleScopeFilter(type),
        ),

        // Layer 2 — Scrollable content (recent chips are first section inside)
        Expanded(
          child: _ZeroStateContent(
            searchState: searchState,
            scrollController: _scrollController,
            staggerController: _staggerController,
            onAiTap: (prompt) =>
                ref.read(searchStateProvider.notifier).reExecuteQuery(prompt),
            onSectionExpand: (id) => ref
                .read(searchStateProvider.notifier)
                .toggleLibrarySectionExpanded(id),
            onHistoryChanged: () => setState(() {}),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Recent chips — scrollable section (first item in Layer 2)
// ─────────────────────────────────────────────────────────────────────────────

class _RecentChipsSection extends StatelessWidget {
  final List<String> history;
  final ValueChanged<String> onTap;
  final ValueChanged<String> onDelete;
  final VoidCallback onClearAll;

  const _RecentChipsSection({
    required this.history,
    required this.onTap,
    required this.onDelete,
    required this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        // Section header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('RECENT', style: KalinkaTextStyles.sectionLabel),
            GestureDetector(
              onTap: onClearAll,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Text(
                  'Clear all',
                  style: KalinkaTextStyles.clearAllChips,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // One-line horizontal chip scroller for recent searches.
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              ...history.map(
                (q) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _RecentChip(
                    query: q,
                    onTap: () => onTap(q),
                    onDelete: () => onDelete(q),
                  ),
                ),
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _RecentChip extends StatelessWidget {
  final String query;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _RecentChip({
    required this.query,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: KalinkaColors.surfaceInput,
      shape: const StadiumBorder(
        side: BorderSide(color: KalinkaColors.borderDefault, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) {
            return Colors.white.withValues(alpha: 0.08);
          }
          return null;
        }),
        child: SizedBox(
          height: 30,
          child: Padding(
            padding: const EdgeInsets.only(left: 8, right: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(
                  Icons.access_time,
                  size: 12,
                  color: KalinkaColors.textMuted,
                ),
                const SizedBox(width: 5),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 160),
                  child: Text(
                    query,
                    style: KalinkaTextStyles.recentChipLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 2),
                GestureDetector(
                  onTap: onDelete,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      Icons.close,
                      size: 10,
                      color: KalinkaColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Layer 1b: Filter pill row (also used as carry-through in typed search)
// ─────────────────────────────────────────────────────────────────────────────

/// Filter pill row shared between the zero-state and the typed-search view.
/// Shows scope filters: All, Favourites, My Playlists.
class SearchFilterPillRow extends StatelessWidget {
  final SearchState searchState;
  final ValueChanged<FilterPillType> onScopeToggle;

  const SearchFilterPillRow({
    super.key,
    required this.searchState,
    required this.onScopeToggle,
  });

  @override
  Widget build(BuildContext context) {
    final activeScopeFilter = searchState.activeScopeFilter;
    final isAllActive = activeScopeFilter == null;

    return Container(
      decoration: const BoxDecoration(
        color: KalinkaColors.surfaceBase,
        border: Border(bottom: BorderSide(color: Color(0x1AFFFFFF), width: 1)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 0, 10),
      child: Row(
        children: [
          // "All" pill — pinned, never scrolls
          _FilterPill(
            label: 'All',
            isActive: isAllActive,
            onTap: () {
              if (!isAllActive) onScopeToggle(activeScopeFilter);
            },
          ),

          // Vertical divider separating pinned "All" from scrollable pills
          Container(
            width: 1,
            height: 16,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            color: const Color(0x1AFFFFFF),
          ),

          // Scrollable remaining pills
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _FilterPill(
                    label: 'Favourites',
                    isActive: activeScopeFilter == FilterPillType.favourites,
                    onTap: () => onScopeToggle(FilterPillType.favourites),
                  ),
                  const SizedBox(width: 6),
                  _FilterPill(
                    label: 'My Playlists',
                    isActive: activeScopeFilter == FilterPillType.myPlaylists,
                    onTap: () => onScopeToggle(FilterPillType.myPlaylists),
                  ),
                  const SizedBox(width: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _FilterPill({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isActive ? KalinkaColors.accentFaded : KalinkaColors.surfaceRaised,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isActive ? KalinkaColors.accent : const Color(0x17FFFFFF),
          width: 0.1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) {
            return Colors.white.withValues(alpha: 0.08);
          }
          return null;
        }),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            label,
            style: isActive
                ? KalinkaTextStyles.filterPillActive
                : KalinkaTextStyles.filterPillInactive,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Layer 2: Scrollable content sections
// ─────────────────────────────────────────────────────────────────────────────

class _ZeroStateContent extends ConsumerWidget {
  final SearchState searchState;
  final ScrollController scrollController;
  final AnimationController staggerController;
  final ValueChanged<String> onAiTap;
  final ValueChanged<String> onSectionExpand;
  final VoidCallback onHistoryChanged;

  const _ZeroStateContent({
    required this.searchState,
    required this.scrollController,
    required this.staggerController,
    required this.onAiTap,
    required this.onSectionExpand,
    required this.onHistoryChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.read(searchStateProvider.notifier).getSearchHistory();
    final scopeFilter = searchState.activeScopeFilter;
    final genreId = searchState.activeGenreId;
    final isAll = scopeFilter == null && genreId == null;
    final isFavourites = scopeFilter == FilterPillType.favourites;
    final isMyPlaylists = scopeFilter == FilterPillType.myPlaylists;
    final isGenre = genreId != null;

    final showAskAi = isAll && searchState.isAiEnabled;
    final showNowPlaying = isAll || isGenre;
    // The merged "Recently Favourited" card is the zero-state exploration
    // teaser — not shown when the Favourites scope is active (that mode
    // renders the split-by-type sections instead).
    final showRecentlyFavourited = isAll || isGenre;

    final librarySections = searchState.librarySections;
    final favItems = _filteredFavourites(searchState, genreId);

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        // RECENT CHIPS — first section, always shown when history exists
        _AnimatedSection(
          visible: history.isNotEmpty,
          child: _RecentChipsSection(
            history: history,
            onTap: (q) =>
                ref.read(searchStateProvider.notifier).reExecuteQuery(q),
            onDelete: (q) {
              ref.read(searchStateProvider.notifier).removeHistoryItem(q);
              onHistoryChanged();
            },
            onClearAll: () {
              ref.read(searchStateProvider.notifier).clearHistory();
              onHistoryChanged();
            },
          ),
        ),

        // ASK THE AI
        _AnimatedSection(
          visible: showAskAi,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Text('ASK THE AI', style: KalinkaTextStyles.sectionLabel),
              const SizedBox(height: 12),
              ...searchState.aiPromptSuggestions.map(
                (prompt) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _AiPromptChip(
                    promptText: prompt,
                    onTap: () => onAiTap(prompt),
                  ),
                ),
              ),
            ],
          ),
        ),

        // BASED ON NOW PLAYING
        _AnimatedSection(
          visible:
              showNowPlaying &&
              (searchState.isLoading || librarySections?.isNotEmpty == true),
          child: _BasedOnNowPlayingSection(
            searchState: searchState,
            staggerController: staggerController,
            onSectionExpand: onSectionExpand,
          ),
        ),

        // RECENTLY FAVOURITED — merged zero-state teaser
        _AnimatedSection(
          visible: showRecentlyFavourited && favItems.isNotEmpty,
          child: _RecentlyFavouritedSection(
            items: favItems,
            isExpanded: searchState.recentlyFavouritedExpanded,
            onToggleExpand: () => ref
                .read(searchStateProvider.notifier)
                .toggleRecentlyFavouritedExpanded(),
          ),
        ),

        // FAVOURITES scope — split-by-type sections with text filtering
        if (isFavourites)
          _ScopedFavouritesSection(searchState: searchState),

        // MY PLAYLISTS scope — flat list
        if (isMyPlaylists) _ScopedPlaylistsSection(searchState: searchState),
      ],
    );
  }

  List<BrowseItem> _filteredFavourites(SearchState state, String? genreId) {
    if (genreId == null) return state.recentlyFavourited;
    return state.recentlyFavourited.where((item) {
      final albumGenreId =
          item.track?.album?.genre?.id ?? item.album?.genre?.id;
      return albumGenreId == genreId;
    }).toList();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Animated section show/hide
// ─────────────────────────────────────────────────────────────────────────────

class _AnimatedSection extends StatefulWidget {
  final bool visible;
  final Widget child;

  const _AnimatedSection({required this.visible, required this.child});

  @override
  State<_AnimatedSection> createState() => _AnimatedSectionState();
}

class _AnimatedSectionState extends State<_AnimatedSection>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 180),
      value: widget.visible ? 1.0 : 0.0,
    );
    _opacity = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );
  }

  @override
  void didUpdateWidget(_AnimatedSection old) {
    super.didUpdateWidget(old);
    if (widget.visible != old.visible) {
      if (widget.visible) {
        Future.delayed(const Duration(milliseconds: 40), () {
          if (mounted) _controller.forward();
        });
      } else {
        _controller.reverse();
      }
    }
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
      builder: (context, child) {
        return ClipRect(
          child: Align(
            heightFactor: _opacity.value,
            child: Opacity(opacity: _opacity.value, child: child),
          ),
        );
      },
      child: widget.child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Based on Now Playing section
// ─────────────────────────────────────────────────────────────────────────────

class _BasedOnNowPlayingSection extends StatelessWidget {
  final SearchState searchState;
  final AnimationController staggerController;
  final ValueChanged<String> onSectionExpand;

  const _BasedOnNowPlayingSection({
    required this.searchState,
    required this.staggerController,
    required this.onSectionExpand,
  });

  @override
  Widget build(BuildContext context) {
    final librarySections = searchState.librarySections;
    final expandedSectionIds = searchState.expandedLibrarySectionIds;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text('BASED ON NOW PLAYING', style: KalinkaTextStyles.sectionLabel),
        if (librarySections != null)
          ..._buildSections(librarySections, expandedSectionIds)
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
    );
  }

  List<Widget> _buildSections(
    List<LibrarySection> sections,
    Set<String> expandedSectionIds,
  ) {
    final widgets = <Widget>[];
    for (final section in sections) {
      final sectionId = section.sectionItem.id;
      final sectionName =
          section.sectionItem.name ?? section.sectionItem.catalog?.title ?? '';
      final isExpanded = expandedSectionIds.contains(sectionId);
      final allItems = section.browseResult.items;

      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 18, bottom: 4),
          child: Text(
            sectionName.toUpperCase(),
            style: KalinkaTextStyles.sectionLabel.copyWith(
              color: KalinkaColors.textMuted,
              fontSize: KalinkaTypography.baseSize + 0,
            ),
          ),
        ),
      );

      widgets.add(Consumer(
        builder: (context, ref, _) => BrowseItemRows(
          items: allItems,
          visibleLimit: 3,
          isExpanded: isExpanded,
          onToggleExpand: () => ref
              .read(searchStateProvider.notifier)
              .toggleLibrarySectionExpanded(sectionId),
        ),
      ));
    }
    return widgets;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Recently Favourited section
// ─────────────────────────────────────────────────────────────────────────────

class _RecentlyFavouritedSection extends StatelessWidget {
  final List<BrowseItem> items;
  final bool isExpanded;
  final VoidCallback onToggleExpand;

  const _RecentlyFavouritedSection({
    required this.items,
    required this.isExpanded,
    required this.onToggleExpand,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Row(
          children: [
            Text('RECENTLY FAVOURITED', style: KalinkaTextStyles.sectionLabel),
            const Spacer(),
            Text(
              'Showing recent 30 days',
              style: KalinkaTextStyles.clearAllChips,
            ),
          ],
        ),
        const SizedBox(height: 12),
        BrowseItemRows(
          items: items,
          visibleLimit: 5,
          isExpanded: isExpanded,
          onToggleExpand: onToggleExpand,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Scoped Favourites section — shown when the "Favourites" pill is active.
// Loads favourites split by type via /favorite/list/{type}; the current
// search query is passed as the `filter` arg so typing narrows the list.
// ─────────────────────────────────────────────────────────────────────────────

class _ScopedFavouritesSection extends ConsumerWidget {
  final SearchState searchState;

  const _ScopedFavouritesSection({required this.searchState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scoped = searchState.scopedFavourites;

    if (scoped == null) {
      if (searchState.isScopedLoading) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
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
        );
      }
      return const SizedBox.shrink();
    }

    final sections = <_ScopedTypeSection>[
      _ScopedTypeSection(
        label: 'Artists',
        type: SearchType.artist,
        list: scoped[SearchType.artist],
      ),
      _ScopedTypeSection(
        label: 'Albums',
        type: SearchType.album,
        list: scoped[SearchType.album],
      ),
      _ScopedTypeSection(
        label: 'Tracks',
        type: SearchType.track,
        list: scoped[SearchType.track],
      ),
      _ScopedTypeSection(
        label: 'Playlists',
        type: SearchType.playlist,
        list: scoped[SearchType.playlist],
      ),
    ];

    final nonEmpty = sections.where((s) => s.items.isNotEmpty).toList();

    if (nonEmpty.isEmpty) {
      final query = searchState.query.trim();
      return Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Center(
          child: Text(
            query.isEmpty ? 'No favourites yet' : 'No favourites match "$query"',
            style: KalinkaFonts.sans(
              fontSize: KalinkaTypography.baseSize + 4,
              color: KalinkaColors.textMuted,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final expanded = searchState.scopedExpandedTypes;
    final children = <Widget>[];
    for (int i = 0; i < nonEmpty.length; i++) {
      final section = nonEmpty[i];
      children.add(const SizedBox(height: 12));
      children.add(SectionHeader(
        label: section.label,
        count: section.totalCount,
        showDivider: false,
      ));
      children.add(BrowseItemRows(
        items: section.items,
        visibleLimit: 5,
        isExpanded: expanded.contains(section.type),
        onToggleExpand: section.items.length > 5
            ? () => ref
                .read(searchStateProvider.notifier)
                .toggleScopedTypeExpanded(section.type)
            : null,
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

class _ScopedTypeSection {
  final String label;
  final SearchType type;
  final BrowseItemsList? list;

  const _ScopedTypeSection({
    required this.label,
    required this.type,
    required this.list,
  });

  List<BrowseItem> get items => list?.items ?? const [];
  int get totalCount => list?.total ?? items.length;
}

// ─────────────────────────────────────────────────────────────────────────────
// Scoped Playlists section — shown when the "My Playlists" pill is active.
// The playlist/list endpoint has no text filter, so typing is a no-op here.
// ─────────────────────────────────────────────────────────────────────────────

class _ScopedPlaylistsSection extends StatelessWidget {
  final SearchState searchState;

  const _ScopedPlaylistsSection({required this.searchState});

  @override
  Widget build(BuildContext context) {
    final list = searchState.scopedPlaylists;

    if (list == null) {
      if (searchState.isScopedLoading) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
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
        );
      }
      return const SizedBox.shrink();
    }

    if (list.items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Center(
          child: Text(
            'No playlists yet',
            style: KalinkaFonts.sans(
              fontSize: KalinkaTypography.baseSize + 4,
              color: KalinkaColors.textMuted,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        SectionHeader(
          label: 'My Playlists',
          count: list.total,
          showDivider: false,
        ),
        BrowseItemRows(items: list.items),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AI prompt chip
// ─────────────────────────────────────────────────────────────────────────────

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
          borderRadius: BorderRadius.circular(10),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [KalinkaColors.accentFaded, KalinkaColors.surfaceBase],
          ),
          border: Border.all(color: KalinkaColors.borderDefault, width: 1),
        ),
        child: Row(
          children: [
            Icon(Icons.auto_awesome, size: 14, color: KalinkaColors.gold),
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
            Icon(Icons.arrow_forward, size: 14, color: KalinkaColors.textMuted),
          ],
        ),
      ),
    );
  }
}
