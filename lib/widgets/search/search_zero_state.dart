import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/search_session_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/haptics.dart';
import '../search_cards/browse_item_rows.dart';
import 'catalog_cards_section.dart';

/// Discover (resting) state for the search session — shown under the search
/// entry when the field is idle. Catalog cards and recent favourites. AI
/// prompt suggestions and recent searches live in the focused search view
/// ([SearchSuggestionsList]), not here.
class SearchZeroState extends ConsumerWidget {
  /// Submit a query immediately (catalog card, history tile).
  final ValueChanged<String> onSubmit;

  /// Widgets pinned to the top of the scroll — the "What shall we play?"
  /// heading and the search entry — so they scroll away with the content
  /// rather than sitting sticky above it.
  final List<Widget> leading;

  /// Extra bottom padding so the list tail clears the floating composer.
  final double bottomInset;

  const SearchZeroState({
    super.key,
    required this.onSubmit,
    this.leading = const [],
    this.bottomInset = 0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(searchSessionProvider);
    final favourites = session.recentFavourites;

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 24 + bottomInset),
      children: [
        ...leading,

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

        // ── EXPLORE THE CATALOGS ────────────────────────────────────────────
        CatalogCardsSection(onSubmit: onSubmit),

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

  /// AI SUGGESTIONS label — a gold sparkle anchors the section; the muted
  /// mono label recedes so the bright rows below carry the eye.
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
                _ClearLink(onTap: onClear),
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
            _HoverIcon(
              icon: Icons.close_rounded,
              semanticsLabel: 'Remove $query from history',
              onTap: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

/// Shared interaction shell for overlay rows: pointer cursor, hover lift
/// (surfaceElevated), pressed lift (surfaceOverlay), rounded 14 — so every row
/// in the card answers the pointer the same way.
class _HoverRow extends StatefulWidget {
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Widget child;

  const _HoverRow({required this.onTap, this.onLongPress, required this.child});

  @override
  State<_HoverRow> createState() => _HoverRowState();
}

class _HoverRowState extends State<_HoverRow> {
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
    final background = _pressed
        ? KalinkaColors.surfaceOverlay
        : _hovering
        ? KalinkaColors.surfaceElevated
        : Colors.transparent;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _setHover(true),
      onExit: (_) => _setHover(false),
      child: GestureDetector(
        onTap: () {
          KalinkaHaptics.lightImpact();
          widget.onTap();
        },
        onLongPress: widget.onLongPress,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.fromLTRB(10, 11, 10, 11),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Small icon button inside a row (the history ✕): muted at rest, brightening
/// under the pointer, with its own tap target so it doesn't fire the row.
class _HoverIcon extends StatefulWidget {
  final IconData icon;
  final String semanticsLabel;
  final VoidCallback onTap;

  const _HoverIcon({
    required this.icon,
    required this.semanticsLabel,
    required this.onTap,
  });

  @override
  State<_HoverIcon> createState() => _HoverIconState();
}

class _HoverIconState extends State<_HoverIcon> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.semanticsLabel,
      button: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: GestureDetector(
          onTap: () {
            KalinkaHaptics.lightImpact();
            widget.onTap();
          },
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(
              widget.icon,
              size: 15,
              color: _hovering
                  ? KalinkaColors.textPrimary
                  : KalinkaColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

/// The "Clear" link on the RECENT SEARCHES header — muted at rest, bright
/// under the pointer.
class _ClearLink extends StatefulWidget {
  final VoidCallback onTap;

  const _ClearLink({required this.onTap});

  @override
  State<_ClearLink> createState() => _ClearLinkState();
}

class _ClearLinkState extends State<_ClearLink> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Clear search history',
      button: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: GestureDetector(
          onTap: () {
            KalinkaHaptics.lightImpact();
            widget.onTap();
          },
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 120),
              style: KalinkaTextStyles.clearAllChips.copyWith(
                color: _hovering
                    ? KalinkaColors.textPrimary
                    : KalinkaColors.textMuted,
              ),
              child: const Text('Clear'),
            ),
          ),
        ),
      ),
    );
  }
}
