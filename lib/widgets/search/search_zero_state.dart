import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/search_session_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/haptics.dart';
import '../search_cards/browse_item_rows.dart';
import 'catalog_cards_section.dart';

/// Zero state for the search session — shown above the composer before any
/// query. Three sections: example AI prompts, historical queries, and recent
/// favourites.
class SearchZeroState extends ConsumerWidget {
  /// Insert a suggestion into the composer for editing (does not send).
  final ValueChanged<String> onInsert;

  /// Submit a query immediately (suggestion run arrow, history tile).
  final ValueChanged<String> onSubmit;

  /// Extra bottom padding so the list tail clears the floating composer.
  final double bottomInset;

  const SearchZeroState({
    super.key,
    required this.onInsert,
    required this.onSubmit,
    this.bottomInset = 0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(searchSessionProvider);
    final history = session.history;
    final favourites = session.recentFavourites;

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 24 + bottomInset),
      children: [
        // ── BACK TO RESULTS ─────────────────────────────────────────────────
        // One tap returns to the live session parked behind Discover.
        if (session.blocks.isNotEmpty) ...[
          _BackToResultsPill(
            query: session.blocks.last.query,
            onTap: () =>
                ref.read(searchSessionProvider.notifier).showResults(),
          ),
          const SizedBox(height: 20),
        ],

        // ── ASK THE AI ──────────────────────────────────────────────────────
        _label('ASK THE AI'),
        const SizedBox(height: 12),
        ...session.suggestions.map(
          (s) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _SuggestionTile(
              text: s.query,
              experimental: s.experimental,
              onInsert: () => onInsert(s.query),
              onRun: () => onSubmit(s.query),
            ),
          ),
        ),

        // ── EXPLORE THE CATALOGS ────────────────────────────────────────────
        CatalogCardsSection(onSubmit: onSubmit),

        // ── RECENT SEARCHES ─────────────────────────────────────────────────
        if (history.isNotEmpty) ...[
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _label('RECENT SEARCHES')),
              GestureDetector(
                onTap: () =>
                    ref.read(searchSessionProvider.notifier).clearHistory(),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 4,
                  ),
                  child: Text('Clear', style: KalinkaTextStyles.clearAllChips),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ...history.map(
            (q) => _HistoryTile(
              query: q,
              onTap: () => onSubmit(q),
              onDelete: () =>
                  ref.read(searchSessionProvider.notifier).removeHistoryItem(q),
            ),
          ),
        ],

        // ── RECENTLY FAVOURITED ─────────────────────────────────────────────
        if (favourites.isNotEmpty) ...[
          const SizedBox(height: 20),
          _label('RECENTLY FAVOURITED'),
          const SizedBox(height: 6),
          BrowseItemRows(items: favourites),
        ],
      ],
    );
  }

  Widget _label(String text) =>
      Text(text, style: KalinkaTextStyles.sectionLabel);
}

/// Slim accent pill returning to the live session, captioned with its query.
class _BackToResultsPill extends StatelessWidget {
  final String query;
  final VoidCallback onTap;

  const _BackToResultsPill({required this.query, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Back to results for $query',
      button: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () {
            KalinkaHaptics.lightImpact();
            onTap();
          },
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 11, 10, 11),
            decoration: BoxDecoration(
              color: KalinkaColors.accentSubtle,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: KalinkaColors.accentBorder, width: 1),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.manage_search_rounded,
                  size: 16,
                  color: KalinkaColors.accentTint,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    'Back to results · “$query”',
                    style: KalinkaTextStyles.aiPromptChipText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: KalinkaColors.accentTint,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// AI prompt suggestion. Tapping runs it straight away — the expected action;
/// long-pressing drops it into the composer to edit before sending.
/// [experimental] marks the server's serendipity pick (context-matched but
/// not validated against the library) with a compass icon instead of the
/// sparkle.
class _SuggestionTile extends StatefulWidget {
  final String text;
  final bool experimental;
  final VoidCallback onInsert;
  final VoidCallback onRun;

  const _SuggestionTile({
    required this.text,
    required this.onInsert,
    required this.onRun,
    this.experimental = false,
  });

  @override
  State<_SuggestionTile> createState() => _SuggestionTileState();
}

class _SuggestionTileState extends State<_SuggestionTile> {
  bool _hovering = false;
  bool _pressed = false;

  void _setHover(bool value) {
    if (value == _hovering) return;
    setState(() => _hovering = value);
  }

  void _setPressed(bool value) {
    if (value == _pressed) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    // Rest → hover → pressed lifts the pill a step on the depth scale so the
    // suggestion reads as interactive under a cursor (desktop) and on tap.
    final background = _pressed
        ? KalinkaColors.surfaceOverlay
        : _hovering
        ? KalinkaColors.surfaceElevated
        : KalinkaColors.surfaceRaised;
    final border = (_hovering || _pressed)
        ? KalinkaColors.borderDefault
        : KalinkaColors.borderSubtle;

    return Semantics(
      label: widget.experimental
          ? 'Run experimental suggestion: ${widget.text}'
          : 'Run suggestion: ${widget.text}',
      hint: 'Long press to edit before sending',
      button: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => _setHover(true),
        onExit: (_) => _setHover(false),
        child: GestureDetector(
          onTap: () {
            KalinkaHaptics.lightImpact();
            widget.onRun();
          },
          onLongPress: widget.onInsert,
          onTapDown: (_) => _setPressed(true),
          onTapUp: (_) => _setPressed(false),
          onTapCancel: () => _setPressed(false),
          behavior: HitTestBehavior.opaque,
          // A quiet, neutral pill rather than an accent-red gradient card: these
          // are lightweight prompts, not primary actions, so they sit low in the
          // hierarchy (below the catalog cards) and don't crowd the screen.
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: border, width: 1),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 11, 12, 11),
              child: Row(
                children: [
                  Icon(
                    widget.experimental
                        ? Icons.explore_outlined
                        : Icons.auto_awesome,
                    size: 14,
                    color: widget.experimental
                        ? KalinkaColors.accentTint
                        : KalinkaColors.gold,
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      widget.text,
                      style: KalinkaTextStyles.aiPromptChipText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 15,
                    color: KalinkaColors.textMuted,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A historical query tile. Tapping submits it immediately.
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
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            const Icon(
              Icons.history_rounded,
              size: 16,
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
            GestureDetector(
              onTap: onDelete,
              behavior: HitTestBehavior.opaque,
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(
                  Icons.close_rounded,
                  size: 14,
                  color: KalinkaColors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
