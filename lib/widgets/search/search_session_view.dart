import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/search_session_provider.dart';
import '../../providers/selection_state_provider.dart';
import '../../theme/app_theme.dart';
import '../measure_size.dart';
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
  String _lastBottomBlockId = '';

  /// Live height of the floating composer, used to pad the content so its tail
  /// clears the bar as it grows (multi-line) or the keyboard toggles.
  double _composerHeight = 0;

  void _onComposerHeightChanged(double height) {
    if (!mounted || _composerHeight == height) return;
    setState(() => _composerHeight = height);
  }

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

    // Newest block sits at the bottom (chat order); scroll down to it when one
    // is appended.
    final bottomId = session.blocks.isEmpty ? '' : session.blocks.last.id;
    if (bottomId != _lastBottomBlockId) {
      _lastBottomBlockId = bottomId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
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
          // Content fills the surface and scrolls behind the composer; its tail
          // is padded clear of the bar by the composer's live height so nothing
          // important stays hidden under it.
          Positioned.fill(
            child: session.isZeroState
                ? SearchZeroState(
                    onInsert: _insert,
                    onSubmit: _submitFromTile,
                    bottomInset: _composerHeight,
                  )
                : _buildBlockList(session, _composerHeight),
          ),
          // The composer floats over a gradient that fades the content into the
          // page. Measured so the content padding above tracks its live height.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: MeasureSize(
              onChange: (size) => _onComposerHeightChanged(size.height),
              child: SearchComposer(
                controller: _composerController,
                focusNode: _composerFocus,
                onSubmit: _submit,
              ),
            ),
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

  Widget _buildBlockList(SearchSessionState session, double bottomInset) {
    final blocks = session.blocks;
    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottomInset),
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
