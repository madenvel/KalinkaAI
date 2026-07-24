import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/search_session_provider.dart';
import '../../theme/app_theme.dart';
import 'search_loading_indicator.dart';
import 'staging_result_sections.dart';

/// The Results layer: a compact summary of the current query with a pencil
/// that reopens the search overlay, then the AI results. Holds a single query
/// — a new search replaces it. Going back to Catalogs is the title bar's `‹`
/// (or system back), never a button here.
class ResultsView extends ConsumerWidget {
  /// Reopen the search overlay pre-filled with the current query.
  final VoidCallback onEdit;

  const ResultsView({super.key, required this.onEdit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(searchSessionProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _QuerySummary(query: session.searchQuery, onEdit: onEdit),
        const SizedBox(height: 20),
        if (session.searchLoading)
          const SearchLoadingIndicator()
        else if (session.searchError != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
            child: Text(
              session.searchError!,
              style: KalinkaTextStyles.trackRowSubtitle.copyWith(
                color: KalinkaColors.actionDelete,
              ),
            ),
          )
        else if (session.searchResults != null)
          StagingResultSections(
            results: session.searchResults!,
            expandedSections: session.expandedSections,
            onToggleSection: (id) =>
                ref.read(searchSessionProvider.notifier).toggleSection(id),
          ),
      ],
    );
  }
}

/// `✦ query / AI-interpreted search` with a ✎ pencil that reopens the overlay.
class _QuerySummary extends StatelessWidget {
  final String query;
  final VoidCallback onEdit;

  const _QuerySummary({required this.query, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: KalinkaColors.surfaceRaised,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KalinkaColors.borderSubtle, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.auto_awesome,
              size: 17,
              color: KalinkaColors.gold,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  query,
                  style: KalinkaTextStyles.trackRowTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'AI-interpreted search',
                  style: KalinkaTextStyles.trackRowSubtitle.copyWith(
                    color: KalinkaColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 18),
            color: KalinkaColors.textSecondary,
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            tooltip: 'Edit search',
          ),
        ],
      ),
    );
  }
}
