import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/catalog_cards_provider.dart';
import '../../providers/search_session_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/haptics.dart';
import '../search_cards/browse_item_rows.dart';
import 'catalog_cards_section.dart';

/// The Catalogs root body: the search invitation (passed in via [leading]),
/// then an "OR EXPLORE CATALOGS" divider, the catalog cards, and recent
/// favourites. Suggestions and recent searches live in the focused search
/// overlay ([SearchSuggestionsList]), not here.
class SearchZeroState extends ConsumerWidget {
  /// Opens a catalog page directly (browse id + resolved provider label).
  final void Function(CatalogCardPlan plan, String provider) onOpenCatalog;

  /// Widgets pinned to the top of the scroll — the "What shall we play?"
  /// heading, description and the search entry — so they scroll with the
  /// content rather than sitting sticky above it.
  final List<Widget> leading;

  const SearchZeroState({
    super.key,
    required this.onOpenCatalog,
    this.leading = const [],
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favourites = ref.watch(
      searchSessionProvider.select((s) => s.recentFavourites),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        ...leading,

        // ── OR EXPLORE CATALOGS ─────────────────────────────────────────────
        const _DividerLabel('OR EXPLORE CATALOGS'),
        const SizedBox(height: 16),
        CatalogCardsSection(onOpenCatalog: onOpenCatalog),

        // ── RECENTLY FAVOURITED ─────────────────────────────────────────────
        if (favourites.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('RECENTLY FAVOURITED', style: KalinkaTextStyles.sectionLabel),
          const SizedBox(height: 6),
          BrowseItemRows(items: favourites),
        ],
      ],
    );
  }
}

/// A centred section label flanked by hairline rules — the "OR EXPLORE
/// CATALOGS" separator between the AI search invitation and the catalog cards.
class _DividerLabel extends StatelessWidget {
  final String text;

  const _DividerLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Divider(color: KalinkaColors.borderSubtle, thickness: 1),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(text, style: KalinkaTextStyles.sectionLabel),
        ),
        const Expanded(
          child: Divider(color: KalinkaColors.borderSubtle, thickness: 1),
        ),
      ],
    );
  }
}

/// The focused search body under the field: an **AI SUGGESTIONS** section over
/// a **RECENT SEARCHES** section, each under a section label like Discover's.
/// Both narrow to entries containing [query] as the user types; when nothing
/// matches the list goes empty and the composer's send button carries the
/// free-typed query onward. Tap runs a suggestion / history query, long-press
/// drops a suggestion into the field; recent searches clear individually (✕) or
/// all at once.
class SearchSuggestionsList extends ConsumerWidget {
  final String query;
  final ValueChanged<String> onInsert;
  final ValueChanged<String> onSubmit;

  /// Drives the open animation (0→1). Each tile fades + slides in on a
  /// staggered interval so they appear one by one, top to bottom. Null = no
  /// entrance animation (already open).
  final Animation<double>? reveal;

  const SearchSuggestionsList({
    super.key,
    required this.query,
    required this.onInsert,
    required this.onSubmit,
    this.reveal,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(searchSessionProvider);
    final notifier = ref.read(searchSessionProvider.notifier);
    final needle = query.trim().toLowerCase();
    final suggestions = needle.isEmpty
        ? session.suggestions
        : session.suggestions
              .where((s) => s.query.toLowerCase().contains(needle))
              .toList(growable: false);
    final history = needle.isEmpty
        ? session.history
        : session.history
              .where((q) => q.toLowerCase().contains(needle))
              .toList(growable: false);

    // A flat row list — section labels and tiles — so the staggered entrance
    // lands them one by one top-to-bottom across both sections.
    final rows = <Widget>[
      if (suggestions.isNotEmpty) ...[
        _aiHeader(),
        for (final s in suggestions)
          _SuggestionTile(
            text: s.query,
            highlight: needle,
            experimental: s.experimental,
            onInsert: () => onInsert(s.query),
            onRun: () => onSubmit(s.query),
          ),
      ],
      if (history.isNotEmpty) ...[
        _recentHeader(
          divider: suggestions.isNotEmpty,
          onClear: notifier.clearHistory,
        ),
        for (final q in history)
          _HistoryTile(
            query: q,
            onTap: () => onSubmit(q),
            onDelete: () => notifier.removeHistoryItem(q),
          ),
      ],
    ];

    // Nothing in either section matches the typed text: offer the free-typed
    // query itself as the one action, so the field never dead-ends.
    if (rows.isEmpty && needle.isNotEmpty) {
      rows.add(_searchForTile(query.trim()));
    }

    // shrinkWrap: the container hugs the rows and only scrolls if they outgrow
    // the space left above the keyboard.
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 6),
      children: [
        for (var i = 0; i < rows.length; i++) _staggered(i, rows.length, rows[i]),
      ],
    );
  }

  /// Fallback row when nothing matches: runs the free-typed query so the field
  /// never dead-ends.
  Widget _searchForTile(String text) => Semantics(
    label: 'Search for $text',
    button: true,
    child: _HoverRow(
      onTap: () => onSubmit(text),
      child: Row(
        children: [
          const Icon(
            Icons.search_rounded,
            size: 16,
            color: KalinkaColors.textSecondary,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: KalinkaTextStyles.searchOverlayRow.copyWith(
                  color: KalinkaColors.textSecondary,
                ),
                children: [
                  const TextSpan(text: 'Search for '),
                  TextSpan(
                    text: '“$text”',
                    style: const TextStyle(
                      color: KalinkaColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Icon(
            Icons.arrow_forward_rounded,
            size: 15,
            color: KalinkaColors.textMuted,
          ),
        ],
      ),
    ),
  );

  /// AI SUGGESTIONS section label with a leading sparkle.
  Widget _aiHeader() => Padding(
    padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
    child: Row(
      children: [
        const Icon(Icons.auto_awesome, size: 11, color: KalinkaColors.gold),
        const SizedBox(width: 7),
        Text('AI SUGGESTIONS', style: KalinkaTextStyles.searchOverlayLabel),
      ],
    ),
  );

  /// RECENT SEARCHES label with a trailing "Clear" that empties the history.
  /// [divider] draws a hairline above when another section precedes it.
  Widget _recentHeader({required bool divider, required VoidCallback onClear}) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (divider)
            Container(
              height: 1,
              margin: const EdgeInsets.fromLTRB(8, 10, 8, 0),
              color: KalinkaColors.borderSubtle,
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 12, 4, 2),
            child: Row(
              children: [
                const Icon(
                  Icons.history_rounded,
                  size: 12,
                  color: KalinkaColors.textMuted,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'RECENT SEARCHES',
                    style: KalinkaTextStyles.searchOverlayLabel,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    KalinkaHaptics.lightImpact();
                    onClear();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: KalinkaColors.textMuted,
                    textStyle: KalinkaTextStyles.clearAllChips,
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Clear'),
                ),
              ],
            ),
          ),
        ],
      );

  /// Wrap a tile in a fade + short upward slide keyed to its row, so rows land
  /// top-to-bottom as the overlay opens.
  Widget _staggered(int index, int count, Widget child) {
    final reveal = this.reveal;
    if (reveal == null) return child;
    // Spread the entrances across the back half of the open animation.
    final step = count <= 1 ? 0.0 : 0.5 / count;
    final start = (0.35 + index * step).clamp(0.0, 1.0);
    final anim = CurvedAnimation(
      parent: reveal,
      curve: Interval(start, (start + 0.4).clamp(0.0, 1.0), curve: Curves.easeOut),
    );
    return FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.25),
          end: Offset.zero,
        ).animate(anim),
        child: child,
      ),
    );
  }
}

/// AI prompt suggestion. Tapping runs it straight away — the expected action;
/// long-pressing drops it into the composer to edit before sending.
/// [experimental] marks the server's serendipity pick (context-matched but
/// not validated against the library) with a compass icon instead of the
/// sparkle.
class _SuggestionTile extends StatelessWidget {
  final String text;
  final bool experimental;

  /// Lower-cased substring the list filtered on; the matching run inside [text]
  /// is emphasised so the user sees why it surfaced. Empty = no emphasis.
  final String highlight;
  final VoidCallback onInsert;
  final VoidCallback onRun;

  const _SuggestionTile({
    required this.text,
    required this.onInsert,
    required this.onRun,
    this.experimental = false,
    this.highlight = '',
  });

  /// The prompt text, emphasising the run that matched the current filter so
  /// the user sees why this suggestion surfaced. Plain text when unfiltered.
  Widget _buildText() {
    final base = KalinkaTextStyles.searchOverlayRow;
    final needle = highlight;
    final start = needle.isEmpty ? -1 : text.toLowerCase().indexOf(needle);
    if (start < 0) {
      return Text(
        text,
        style: base,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }
    final end = start + needle.length;
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          TextSpan(text: text.substring(0, start)),
          TextSpan(
            text: text.substring(start, end),
            style: const TextStyle(
              color: KalinkaColors.accentTint,
              fontWeight: FontWeight.w600,
            ),
          ),
          TextSpan(text: text.substring(end)),
        ],
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: experimental
          ? 'Run experimental suggestion: $text'
          : 'Run suggestion: $text',
      hint: 'Long press to edit before sending',
      button: true,
      child: _HoverRow(
        onTap: onRun,
        onLongPress: onInsert,
        child: Row(
          children: [
            Icon(
              experimental ? Icons.explore_outlined : Icons.auto_awesome,
              size: 14,
              color: experimental
                  ? KalinkaColors.accentTint
                  : KalinkaColors.gold,
            ),
            const SizedBox(width: 11),
            Expanded(child: _buildText()),
            const SizedBox(width: 8),
            const Icon(
              Icons.arrow_forward_rounded,
              size: 15,
              color: KalinkaColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

/// A historical query tile. Tapping the row runs the query again (the hover
/// lift carries the affordance); the single trailing ✕ deletes just this entry.
class _HistoryTile extends StatelessWidget {
  final String query;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _HistoryTile({
    required this.query,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Search again for $query',
      button: true,
      child: _HoverRow(
        onTap: onTap,
        child: Row(
          children: [
            const Icon(
              Icons.history_rounded,
              size: 15,
              color: KalinkaColors.textMuted,
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                query,
                style: KalinkaTextStyles.searchOverlayRow,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              onPressed: () {
                KalinkaHaptics.lightImpact();
                onDelete();
              },
              icon: const Icon(Icons.close_rounded, size: 18),
              color: KalinkaColors.textMuted,
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              tooltip: 'Remove from history',
            ),
          ],
        ),
      ),
    );
  }
}

/// Shared shell for the overlay rows: an [InkWell] on a transparent [Material]
/// so hover, press ripple, and pointer cursor are the standard ones. Rounded 14
/// to match the card.
class _HoverRow extends StatelessWidget {
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Widget child;

  const _HoverRow({required this.onTap, this.onLongPress, required this.child});

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: () {
          KalinkaHaptics.lightImpact();
          onTap();
        },
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(14),
        hoverColor: KalinkaColors.surfaceElevated,
        highlightColor: KalinkaColors.surfaceOverlay,
        splashColor: KalinkaColors.surfaceOverlay,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 11, 10, 11),
          child: child,
        ),
      ),
    );
  }
}
