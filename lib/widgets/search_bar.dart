import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/search_state_provider.dart';
import 'search_content.dart';

class ExpandableSearchBar extends ConsumerStatefulWidget {
  const ExpandableSearchBar({super.key});

  @override
  ConsumerState<ExpandableSearchBar> createState() =>
      _ExpandableSearchBarState();
}

class _ExpandableSearchBarState extends ConsumerState<ExpandableSearchBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  late TextEditingController _textController;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _textController = TextEditingController();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final searchState = ref.watch(searchStateProvider);

    // Sync animation with state
    if (searchState.isExpanded) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }

    // Sync text controller with state
    if (_textController.text != searchState.query) {
      _textController.text = searchState.query;
    }

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final expandProgress = _animation.value;
        final isCollapsed = expandProgress == 0.0;

        // When expanded, calculate height to fill space until playbar
        // Compact playbar is approximately 76px (48px album + 16px padding + 2px progress + 10px spacing)
        final screenHeight = MediaQuery.of(context).size.height;
        final compactPlaybarHeight = 76.0;
        final maxHeight = screenHeight - compactPlaybarHeight;

        return Container(
          height: isCollapsed ? null : maxHeight,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(16 * (1 - expandProgress)),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1 * expandProgress),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16 - (8 * expandProgress),
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _textController,
                          focusNode: _focusNode,
                          onChanged: (value) {
                            ref
                                .read(searchStateProvider.notifier)
                                .setQuery(value);
                          },
                          onSubmitted: (value) {
                            if (value.trim().isNotEmpty) {
                              ref
                                  .read(searchStateProvider.notifier)
                                  .performSearch();
                            }
                          },
                          onTap: () {
                            if (!searchState.isExpanded) {
                              ref.read(searchStateProvider.notifier).expand();
                            }
                          },
                          decoration: InputDecoration(
                            hintText: 'Search music...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: searchState.query.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _textController.clear();
                                      ref
                                          .read(searchStateProvider.notifier)
                                          .clearSearch();
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor:
                                theme.colorScheme.surfaceContainerHighest,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (searchState.query.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.search),
                          onPressed: () {
                            ref
                                .read(searchStateProvider.notifier)
                                .performSearch();
                          },
                          tooltip: 'Search',
                          style: IconButton.styleFrom(
                            backgroundColor: theme.colorScheme.primaryContainer,
                            foregroundColor:
                                theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      if (searchState.isExpanded)
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            ref.read(searchStateProvider.notifier).collapse();
                            _focusNode.unfocus();
                          },
                          tooltip: 'Close',
                        ),
                    ],
                  ),
                ),
              ),
              if (expandProgress > 0)
                Expanded(
                  child: Opacity(
                    opacity: expandProgress,
                    child: const SearchContent(),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
