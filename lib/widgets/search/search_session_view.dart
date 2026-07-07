import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/search_session_provider.dart';
import '../../providers/selection_state_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/haptics.dart';
import '../selection_overlay.dart';
import '../server_chip.dart';
import 'query_block_view.dart';
import 'search_composer.dart';
import 'search_zero_state.dart';

/// Full-screen search session surface. The search bar sits in a header strip
/// at the top — back button on its left, connection dot on its right — with
/// the scrollable content (zero state, then query blocks, newest on top)
/// below it.
///
/// The bar does not take focus when the session opens; it focuses only when
/// tapped.
class SearchSessionView extends ConsumerStatefulWidget {
  /// Opens the server sheet — the connection dot's tap target.
  final VoidCallback? onServerTap;

  const SearchSessionView({super.key, this.onServerTap});

  @override
  ConsumerState<SearchSessionView> createState() => _SearchSessionViewState();
}

class _SearchSessionViewState extends ConsumerState<SearchSessionView> {
  final _composerController = TextEditingController();
  final _composerFocus = FocusNode();
  final _scrollController = ScrollController();
  String _lastNewestBlockId = '';

  // Hit-box height for the back button and connection dot, centred in the bar
  // (whose height is the shared kKalinkaTopBarHeight).
  static const double _kBarMinHeight = 46;

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
    // Sending clears focus and dismisses the keyboard, like the send button.
    _composerFocus.unfocus();
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

    // Newest block renders on top, right under the search bar; scroll back up
    // to it when one is appended.
    final newestId = session.blocks.isEmpty ? '' : session.blocks.last.id;
    if (newestId != _lastNewestBlockId) {
      _lastNewestBlockId = newestId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0,
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
          Column(
            children: [
              _buildHeader(),
              Expanded(
                child: session.isZeroState
                    ? SearchZeroState(
                        onInsert: _insert,
                        onSubmit: _submitFromTile,
                      )
                    : _buildBlockList(session),
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

  /// Top strip: back · search bar · connection dot. Solid, same framing as
  /// the main screen's top bar; the bar growing multiline pushes the content
  /// down rather than overlaying it.
  Widget _buildHeader() {
    return Container(
      decoration: kKalinkaTopBarDecoration,
      child: SafeArea(
        bottom: false,
        // Shared height so this bar lines up with the queue and settings bars.
        // Content sits centred at rest (the 3px symmetric padding + row height
        // fill the strip) and the back/dot stay pinned to the first line as the
        // composer grows past it multiline.
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: kKalinkaTopBarHeight),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 3, 6, 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Back — exits the search mode (system back works too).
                Semantics(
                  label: 'Close search',
                  button: true,
                  child: GestureDetector(
                    onTap: () {
                      KalinkaHaptics.lightImpact();
                      ref.read(searchSessionProvider.notifier).close();
                    },
                    behavior: HitTestBehavior.opaque,
                    child: const SizedBox(
                      width: 42,
                      height: _kBarMinHeight,
                      child: Icon(
                        Icons.arrow_back,
                        size: 22,
                        color: KalinkaColors.textPrimary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: SearchComposer(
                    controller: _composerController,
                    focusNode: _composerFocus,
                    onSubmit: _submit,
                  ),
                ),
                const SizedBox(width: 2),
                SizedBox(
                  height: _kBarMinHeight,
                  child: Center(
                    child: ServerChip(compact: true, onTap: widget.onServerTap),
                  ),
                ),
              ],
            ),
          ),
        ),
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
        // The session appends newest last; the list shows newest first.
        final block = blocks[blocks.length - 1 - i];
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
