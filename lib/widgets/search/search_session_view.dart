import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/search_session_provider.dart';
import '../../providers/selection_state_provider.dart';
import '../../theme/app_theme.dart';
import '../selection_overlay.dart';
import 'query_block_view.dart';
import 'search_composer.dart';
import 'search_zero_state.dart';

/// Full-screen search session surface: a continuous scrollable list of query
/// blocks (newest on top) with the chat composer docked at the bottom. Shows
/// the zero state until the first query is submitted.
class SearchSessionView extends ConsumerStatefulWidget {
  const SearchSessionView({super.key});

  @override
  ConsumerState<SearchSessionView> createState() => _SearchSessionViewState();
}

class _SearchSessionViewState extends ConsumerState<SearchSessionView> {
  final _composerController = TextEditingController();
  final _composerFocus = FocusNode();
  final _scrollController = ScrollController();
  String _lastTopBlockId = '';

  @override
  void initState() {
    super.initState();
    // Focus lands in the composer automatically; the keyboard slides up.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _composerFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _composerController.dispose();
    _composerFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _submit(String text) {
    ref.read(searchSessionProvider.notifier).submit(text);
  }

  /// Submit from a zero-state tile (history / suggestion run arrow).
  void _submitFromTile(String text) {
    ref.read(searchSessionProvider.notifier).submit(text);
    _composerFocus.requestFocus();
  }

  /// Insert a suggestion into the composer for editing (does not send).
  void _insert(String text) {
    _composerController.text = text;
    _composerController.selection = TextSelection.collapsed(
      offset: text.length,
    );
    _composerFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(searchSessionProvider);

    // Keep the newest block in view when one is added.
    final topId = session.blocks.isEmpty ? '' : session.blocks.first.id;
    if (topId != _lastTopBlockId) {
      _lastTopBlockId = topId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) _scrollController.jumpTo(0);
      });
    }

    // The shared tiles long-press into multi-select; surface the same batch
    // bar the old search feed used so the selection can be acted on.
    final selectionActive = ref.watch(
      selectionStateProvider.select((s) => s.isActive),
    );

    return ColoredBox(
      color: KalinkaColors.background,
      child: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: session.isZeroState
                    ? SearchZeroState(
                        onInsert: _insert,
                        onSubmit: _submitFromTile,
                      )
                    : _buildBlockList(session),
              ),
              SearchComposer(
                controller: _composerController,
                focusNode: _composerFocus,
                onSubmit: _submit,
              ),
            ],
          ),
          if (selectionActive)
            const Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: MultiSelectBottomBar(),
            ),
        ],
      ),
    );
  }

  Widget _buildBlockList(SearchSessionState session) {
    final blocks = session.blocks;
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      itemCount: blocks.length,
      itemBuilder: (context, i) {
        final block = blocks[i];
        return QueryBlockView(
          key: ValueKey(block.id),
          block: block,
          expanded: block.id == session.expandedBlockId,
          onExpand: () =>
              ref.read(searchSessionProvider.notifier).expandBlock(block.id),
          onToggleSection: (sectionId) => ref
              .read(searchSessionProvider.notifier)
              .toggleSection(block.id, sectionId),
        );
      },
    );
  }
}
