import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/search_state_provider.dart';
import '../theme/app_theme.dart';

/// Pinned query completion strip shown between the search bar and results feed
/// while the user is typing. Displays matching completions from library data
/// and an optional AI-generated natural-language completion.
class CompletionStrip extends ConsumerWidget {
  const CompletionStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchState = ref.watch(searchStateProvider);
    final visible = searchState.completionStripVisible;
    final completions = searchState.completions;
    final aiCompletion = searchState.aiCompletionSuggestion;
    final query = searchState.query.trim();

    final hasContent =
        completions.isNotEmpty ||
        (aiCompletion != null && aiCompletion.isNotEmpty);

    return AnimatedOpacity(
      opacity: visible && hasContent ? 1.0 : 0.0,
      duration: Duration(milliseconds: visible ? 120 : 150),
      curve: Curves.easeOut,
      child: AnimatedContainer(
        duration: Duration(milliseconds: visible ? 120 : 150),
        height: visible && hasContent
            ? _calcHeight(completions.length, aiCompletion != null)
            : 0,
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: KalinkaColors.headerSurface,
          border: const Border(
            bottom: BorderSide(color: KalinkaColors.borderDefault, width: 1),
          ),
        ),
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Library completions
              ...completions.map(
                (completion) => _CompletionRow(
                  completion: completion,
                  query: query,
                  isAi: false,
                  onTap: () {
                    ref
                        .read(searchStateProvider.notifier)
                        .reExecuteQuery(completion);
                  },
                ),
              ),
              // AI completion (last)
              if (aiCompletion != null && aiCompletion.isNotEmpty)
                _CompletionRow(
                  completion: aiCompletion,
                  query: query,
                  isAi: true,
                  onTap: () {
                    ref
                        .read(searchStateProvider.notifier)
                        .reExecuteQuery(aiCompletion);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  double _calcHeight(int completionCount, bool hasAi) {
    final rows = completionCount + (hasAi ? 1 : 0);
    return rows * 44.0;
  }
}

/// A single completion row — 44px tall.
class _CompletionRow extends StatelessWidget {
  final String completion;
  final String query;
  final bool isAi;
  final VoidCallback onTap;

  const _CompletionRow({
    required this.completion,
    required this.query,
    required this.isAi,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 44,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              // Icon
              Icon(
                isAi ? Icons.auto_awesome : Icons.search,
                size: 14,
                color: isAi
                    ? KalinkaColors.accent.withValues(alpha: 0.7)
                    : KalinkaColors.textSecondary,
              ),
              const SizedBox(width: 12),
              // Completion text with match highlighting
              Expanded(child: _buildHighlightedText()),
              const SizedBox(width: 8),
              // Arrow
              const Icon(
                Icons.arrow_forward,
                size: 14,
                color: KalinkaColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHighlightedText() {
    if (isAi) {
      return Text(
        completion,
        style: KalinkaTextStyles.aiCompletionText,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    // Highlight the matching prefix in accent color
    final lower = completion.toLowerCase();
    final queryLower = query.toLowerCase();
    if (lower.startsWith(queryLower) && queryLower.isNotEmpty) {
      final matchEnd = query.length;
      return RichText(
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        text: TextSpan(
          children: [
            TextSpan(
              text: completion.substring(0, matchEnd),
              style: KalinkaTextStyles.completionMatchHighlight,
            ),
            TextSpan(
              text: completion.substring(matchEnd),
              style: KalinkaTextStyles.completionText,
            ),
          ],
        ),
      );
    }

    return Text(
      completion,
      style: KalinkaTextStyles.completionText,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
