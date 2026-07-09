import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';
import '../../utils/haptics.dart';

/// The search bar pill at the top of the search screen. One line at rest —
/// an AI sparkle, the text field, then the send button on the right — and
/// grows to a few lines as the content wraps, the controls staying
/// pinned to the first line. The send button (an accent down-arrow) surfaces
/// only once the field holds non-whitespace text. Submitting fires the query
/// and clears the field. The border is accent while the field holds focus,
/// grey otherwise.
///
/// The parent owns the framing (top-bar strip, safe area); this widget is
/// just the pill.
///
/// There is deliberately no onChanged search hook: typing never triggers a
/// query. The query fires only on explicit send (the button, or hardware Enter
/// where a physical keyboard exists — Shift+Enter inserts a newline).
class SearchComposer extends StatefulWidget {
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
  State<SearchComposer> createState() => _SearchComposerState();
}

class _SearchComposerState extends State<SearchComposer> {
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    // The node is owned by the parent; only drop our listener.
    widget.focusNode.removeListener(_handleFocusChange);
    super.dispose();
  }

  // Recolour the pill border (accent when focused, grey otherwise) on focus
  // changes.
  void _handleFocusChange() {
    if (mounted) setState(() {});
  }

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
    // One row, everything anchored to the top: at one line it reads as a
    // centred bar; as the field wraps taller, the mode icon and the AI toggle
    // + send stay pinned to the first line and only the text grows downward.
    // Plain top-anchoring avoids IntrinsicHeight, whose probe of a multiline
    // TextField reports more than the live line count and inflates the pill.
    final focused = widget.focusNode.hasFocus;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: KalinkaColors.surfaceInput,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: focused ? KalinkaColors.accent : KalinkaColors.borderDefault,
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 6, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // AI sparkle — centred against the first text line.
            const Padding(
              padding: EdgeInsets.only(top: 8, right: 10),
              child: Icon(
                Icons.auto_awesome,
                size: 16,
                color: KalinkaColors.gold,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
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
                      hintText: 'Ask for music…',
                      hintStyle: KalinkaTextStyles.searchPlaceholder,
                      border: InputBorder.none,
                      isCollapsed: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ),
            ),
            // Send — appears only when there's text to submit; pinned to the
            // first line as the field grows.
            _buildSendButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildSendButton() {
    // Rebuilds on every keystroke (without firing any search) so the button
    // shows up only once there's non-whitespace text to submit. Results appear
    // below the bar, so a downward accent arrow reads as "send it down".
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final hasText = widget.controller.text.trim().isNotEmpty;
        if (!hasText) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Semantics(
            label: 'Send',
            button: true,
            child: GestureDetector(
              onTap: _submit,
              behavior: HitTestBehavior.opaque,
              child: const SizedBox(
                width: 32,
                height: 32,
                child: Icon(
                  Icons.arrow_downward_rounded,
                  size: 22,
                  color: KalinkaColors.accent,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
