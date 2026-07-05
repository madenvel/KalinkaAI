import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/search_session_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/haptics.dart';
import '../search_cards/browse_item_rows.dart';

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
        // ── ASK THE AI ──────────────────────────────────────────────────────
        _label('ASK THE AI'),
        const SizedBox(height: 12),
        ...session.suggestions.map(
          (s) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _SuggestionTile(
              text: s,
              onInsert: () => onInsert(s),
              onRun: () => onSubmit(s),
            ),
          ),
        ),

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

/// AI prompt suggestion: tapping the body inserts the text into the composer;
/// the run arrow submits it immediately.
class _SuggestionTile extends StatelessWidget {
  final String text;
  final VoidCallback onInsert;
  final VoidCallback onRun;

  const _SuggestionTile({
    required this.text,
    required this.onInsert,
    required this.onRun,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
          // Body — inserts into the composer for editing.
          Expanded(
            child: Semantics(
              label: 'Edit suggestion: $text',
              button: true,
              child: GestureDetector(
                onTap: onInsert,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.auto_awesome,
                        size: 14,
                        color: KalinkaColors.gold,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          text,
                          style: KalinkaTextStyles.aiPromptChipText,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Run arrow — submits immediately.
          Semantics(
            label: 'Run suggestion: $text',
            button: true,
            child: GestureDetector(
              onTap: () {
                KalinkaHaptics.lightImpact();
                onRun();
              },
              behavior: HitTestBehavior.opaque,
              child: const Padding(
                padding: EdgeInsets.fromLTRB(6, 8, 12, 8),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 18,
                  color: KalinkaColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
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
