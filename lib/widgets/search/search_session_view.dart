import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/indexer_status_provider.dart';
import '../../providers/search_session_provider.dart';
import '../../providers/selection_state_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/haptics.dart';
import '../indexer_status_banner.dart';
import '../selection_overlay.dart';
import '../server_chip.dart';
import 'query_block_view.dart';
import 'search_composer.dart';
import 'search_zero_state.dart';

/// The search header uses the shared top-bar surface + shadow but drops the
/// hairline bottom rule: the bar and the content below it read as one surface.
const BoxDecoration _kSearchHeaderDecoration = BoxDecoration(
  color: KalinkaColors.surfaceBase,
  boxShadow: [
    BoxShadow(color: Color(0x80000000), offset: Offset(0, 4), blurRadius: 24),
  ],
);

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

  // Captured in initState so dispose() can stop the poll without touching ref.
  late final IndexerStatusNotifier _indexerStatus;

  @override
  void initState() {
    super.initState();
    // Poll pipeline progress while the search surface is up — drives the
    // banner under the header. Runs until dispose() stops it.
    _indexerStatus = ref.read(indexerStatusProvider.notifier);
    Future.microtask(_indexerStatus.refresh);
  }

  @override
  void dispose() {
    _indexerStatus.stop();
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
              const _IndexerBannerSlot(),
              Expanded(
                child: session.isZeroState
                    ? SearchZeroState(
                        onInsert: _insert,
                        onSubmit: _submitFromTile,
                      )
                    // The hint floats over the list on a top-anchored scrim:
                    // content scrolls underneath and shows through the fade.
                    : Stack(
                        children: [
                          _buildBlockList(session),
                          const Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: IgnorePointer(child: _GestureHintLine()),
                          ),
                        ],
                      ),
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
      decoration: _kSearchHeaderDecoration,
      child: SafeArea(
        bottom: false,
        // Shared height so this bar lines up with the queue and settings bars.
        // Content sits centred at rest (the 3px symmetric padding + row height
        // fill the strip) and the back/dot stay pinned to the first line as the
        // composer grows past it multiline.
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: kKalinkaTopBarHeight),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 3, 6, 3),
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
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: SearchComposer(
                      controller: _composerController,
                      focusNode: _composerFocus,
                      onSubmit: _submit,
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                SizedBox(
                  height: _kBarMinHeight,
                  width: 42,
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
      // Top padding clears the hint overlay so content starts below it at
      // rest and only slides under the scrim once scrolled.
      padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
      // +1: the Discover escape hatch under the last block.
      itemCount: blocks.length + 1,
      itemBuilder: (context, i) {
        if (i == blocks.length) {
          return _DiscoverPrompt(
            onTap: () =>
                ref.read(searchSessionProvider.notifier).showDiscover(),
          );
        }
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

/// Subtle pipeline progress strip under the header: stage name + crimson
/// 2px line while the library is indexing / enriching / embedding; gone when
/// the pipeline is idle. Its own consumer so the 5s poll ticks rebuild only
/// this strip, not the whole search surface.
class _IndexerBannerSlot extends ConsumerWidget {
  const _IndexerBannerSlot();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(indexerStatusProvider);
    final stage = status.stage;
    if (stage == null) return const SizedBox.shrink();
    return IndexerStatusBanner(
      label: stage.label,
      progressPct: status.progressPct,
    );
  }
}

/// Quiet one-line "verb map" floating over the results on a top-anchored
/// scrim: solid background at the top fading to transparent at the bottom, so
/// scrolled content stays partially visible underneath. Action keywords pop
/// in bright ink so the eye catches tap / swipe / hold first and reads the
/// consequence attached to each. Persistent guidance, not a dismissible tip.
class _GestureHintLine extends StatelessWidget {
  const _GestureHintLine();

  @override
  Widget build(BuildContext context) {
    final plain = KalinkaFonts.sans(
      fontSize: KalinkaTypography.baseSize - 1,
      fontWeight: FontWeight.w500,
      color: KalinkaColors.textMuted,
    );
    final verb = plain.copyWith(
      fontWeight: FontWeight.w700,
      color: KalinkaColors.textPrimary.withValues(alpha: 0.82),
    );

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          // Translucent veil, never solid: content ghosts through the whole
          // band, just dampened enough to keep the hint legible.
          colors: [
            KalinkaColors.background.withValues(alpha: 0.88),
            KalinkaColors.background.withValues(alpha: 0.55),
            KalinkaColors.background.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.55, 1.0],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 9, 16, 14),
      child: Text.rich(
        TextSpan(
          style: plain,
          children: [
            TextSpan(text: 'Tap', style: verb),
            const TextSpan(text: ' a song to play  ·  '),
            TextSpan(text: 'swipe →', style: verb),
            const TextSpan(text: ' queue it, '),
            TextSpan(text: '← swipe', style: verb),
            const TextSpan(text: ' play next  ·  '),
            TextSpan(text: 'hold', style: verb),
            const TextSpan(text: ' to select'),
          ],
        ),
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// Quiet footer link to Discover when the results didn't deliver; the session
/// stays alive behind it (reachable via the "Back to results" pill).
class _DiscoverPrompt extends StatelessWidget {
  final VoidCallback onTap;

  const _DiscoverPrompt({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 6),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            'Can’t find what you’re looking for? ',
            style: KalinkaTextStyles.trackRowSubtitle,
          ),
          Semantics(
            label: 'Open Discover',
            button: true,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () {
                  KalinkaHaptics.lightImpact();
                  onTap();
                },
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 6,
                  ),
                  child: Text(
                    'Try Discover',
                    style: KalinkaFonts.sans(
                      fontSize: KalinkaTypography.baseSize + 1,
                      fontWeight: FontWeight.w600,
                      color: KalinkaColors.accentTint,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
