import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/search_session_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/haptics.dart';
import 'floating_search_bar.dart';

/// Chat-style composer docked at the bottom of the search screen. Multiline,
/// grows to a few lines then scrolls internally. The send button appears only
/// when the field holds non-whitespace text. Submitting fires the query and
/// clears the field while keeping focus. A switch line underneath carries the
/// AI-mode toggle.
///
/// The composer floats over the scrolling content (see [SearchSessionView]):
/// rather than an opaque slab with a rule on top, a short gradient fades the
/// content into the page as it scrolls behind the bar. That fade is a plain
/// linear-gradient fill — no blur, no `saveLayer` — so it costs one extra
/// gradient rect per frame, which is negligible.
///
/// There is deliberately no onChanged search hook: typing never triggers a
/// query. The query fires only on explicit send (the button, or hardware Enter
/// where a physical keyboard exists — Shift+Enter inserts a newline).
class SearchComposer extends ConsumerStatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onSubmit;

  const SearchComposer({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSubmit,
  });

  @override
  ConsumerState<SearchComposer> createState() => _SearchComposerState();
}

class _SearchComposerState extends ConsumerState<SearchComposer> {
  void _submit() {
    final text = widget.controller.text.trim();
    if (text.isEmpty) return;
    KalinkaHaptics.lightImpact();
    widget.onSubmit(text);
    widget.controller.clear();
    // Drop focus and dismiss the keyboard once the query is sent.
    widget.focusNode.unfocus();
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.enter &&
        !HardwareKeyboard.instance.isShiftPressed) {
      _submit();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final isAiEnabled = ref.watch(
      searchSessionProvider.select((s) => s.isAiEnabled),
    );

    // The search bar floats over a gradient that fades the content scrolling
    // behind it (see [FloatingSearchBar]). The pill has two halves — the text
    // input on top (the only part that grows with content) and, below a
    // divider, the AI switch with the send button (fixed height).
    return FloatingSearchBar(
      bottomSafeArea: true,
      child: Container(
        decoration: BoxDecoration(
          color: KalinkaColors.surfaceInput,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: KalinkaColors.borderDefault, width: 1.5),
          boxShadow: FloatingSearchBar.pillShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // TOP — text input; grows to a few lines then scrolls.
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 11, 14, 9),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 1, right: 10),
                    child: Icon(
                      isAiEnabled ? Icons.auto_awesome : Icons.search_rounded,
                      size: 16,
                      color: isAiEnabled
                          ? KalinkaColors.gold
                          : KalinkaColors.textMuted,
                    ),
                  ),
                  Expanded(
                    child: Focus(
                      onKeyEvent: _onKeyEvent,
                      child: TextField(
                        controller: widget.controller,
                        focusNode: widget.focusNode,
                        style: KalinkaTextStyles.searchBarInput,
                        cursorColor: KalinkaColors.accent,
                        minLines: 1,
                        maxLines: 5,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: isAiEnabled
                              ? 'Ask for music…'
                              : 'Search music…',
                          hintStyle: KalinkaTextStyles.searchPlaceholder,
                          border: InputBorder.none,
                          isCollapsed: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Divider between the two halves.
            const Divider(
              height: 1,
              thickness: 1,
              color: KalinkaColors.borderSubtle,
            ),
            // BOTTOM — AI switch (left) + send (right). Fixed height.
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
              child: Row(
                children: [
                  _buildAiToggle(isAiEnabled),
                  const Spacer(),
                  _buildSendButton(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// AI-mode toggle pill in the bottom half of the search bar.
  Widget _buildAiToggle(bool isAiEnabled) {
    final color = isAiEnabled ? KalinkaColors.gold : KalinkaColors.textMuted;
    return Semantics(
      label: isAiEnabled
          ? 'AI search on. Tap to switch to keyword search.'
          : 'AI search off. Tap to enable AI search.',
      button: true,
      child: GestureDetector(
        onTap: () {
          KalinkaHaptics.lightImpact();
          ref.read(searchSessionProvider.notifier).toggleAiMode();
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: const Color(0x0DFFFFFF),
            border: Border.all(
              color: isAiEnabled
                  ? KalinkaColors.gold.withValues(alpha: 0.6)
                  : KalinkaColors.borderDefault,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome, size: 12, color: color),
              const SizedBox(width: 5),
              Text(
                'AI',
                style: KalinkaTextStyles.aiBadge.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSendButton() {
    // Rebuilds on every keystroke so the button appears/disappears with the
    // presence of non-whitespace text — without firing any search. When empty
    // the button is absent from the tree entirely (not just faded), so there is
    // no hidden send target.
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final hasText = widget.controller.text.trim().isNotEmpty;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 140),
          transitionBuilder: (child, animation) => ScaleTransition(
            scale: animation,
            child: FadeTransition(opacity: animation, child: child),
          ),
          // The empty slot keeps the bottom half a constant height whether or
          // not the send button is present.
          child: hasText
              ? Semantics(
                  key: const ValueKey('send'),
                  label: 'Send',
                  button: true,
                  child: GestureDetector(
                    onTap: _submit,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                        color: KalinkaColors.accent,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_upward_rounded,
                        size: 20,
                        color: Colors.white,
                      ),
                    ),
                  ),
                )
              : const SizedBox(key: ValueKey('empty'), width: 0, height: 38),
        );
      },
    );
  }
}
