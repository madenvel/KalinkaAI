import 'package:flutter/material.dart';

import '../../data_model/browse_filters.dart';
import '../../theme/app_theme.dart';
import '../../utils/haptics.dart';
import '../kalinka_button.dart';
import 'browse_filter_form.dart';

/// The unfolded state of the search-and-filters control: a card resting under
/// the title bar, holding the search field and every facet group the surface
/// offers.
///
/// Edits are **staged** — nothing reaches the list until Show results, so a
/// visit costs one reload however many pills are touched. Cancel and the
/// system back both discard; Reset empties the staged selection without
/// leaving.
class SearchFilterOverlay extends StatefulWidget {
  final BrowseFilterCapabilities capabilities;

  /// The filter currently applied to the list — the starting point, and what
  /// Cancel returns to.
  final BrowseFilterQuery applied;

  final String searchHint;

  final ValueChanged<BrowseFilterQuery> onApply;
  final VoidCallback onCancel;

  /// Vertical space the card may occupy before its body starts scrolling.
  final double maxHeight;

  const SearchFilterOverlay({
    super.key,
    required this.capabilities,
    required this.applied,
    required this.onApply,
    required this.onCancel,
    required this.maxHeight,
    this.searchHint = 'Search',
  });

  @override
  State<SearchFilterOverlay> createState() => _SearchFilterOverlayState();
}

class _SearchFilterOverlayState extends State<SearchFilterOverlay> {
  late BrowseFilterQuery _staged = widget.applied;

  @override
  Widget build(BuildContext context) {
    return TextFieldTapRegion(
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          constraints: BoxConstraints(maxHeight: widget.maxHeight),
          decoration: BoxDecoration(
            color: KalinkaColors.surfaceRaised,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: KalinkaColors.borderDefault, width: 1),
            // Elevation so the card lifts off the fading scrim.
            boxShadow: const [
              BoxShadow(
                color: Color(0xB3000000),
                offset: Offset(0, 12),
                blurRadius: 40,
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                  child: BrowseFilterForm(
                    capabilities: widget.capabilities,
                    query: _staged,
                    searchHint: widget.searchHint,
                    // Staged: nothing is sent until Show results, so there is
                    // nothing to coalesce and the badge can track every key.
                    textDebounce: Duration.zero,
                    onChanged: (query) => setState(() => _staged = query),
                  ),
                ),
              ),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'SEARCH & FILTERS',
              style: KalinkaFonts.mono(
                fontSize: KalinkaTypography.baseSize + 2,
                fontWeight: FontWeight.w600,
                letterSpacing: 2.0,
                color: KalinkaColors.textPrimary,
              ),
            ),
          ),
          if (!_staged.isEmpty)
            _HoverText(
              label: 'RESET',
              onTap: () {
                KalinkaHaptics.selectionClick();
                setState(() => _staged = const BrowseFilterQuery());
              },
            ),
          _CloseButton(onTap: widget.onCancel),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: KalinkaColors.borderSubtle)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            KalinkaButton(
              label: 'Cancel',
              variant: KalinkaButtonVariant.neutral,
              size: KalinkaButtonSize.compact,
              onTap: widget.onCancel,
            ),
            const SizedBox(width: 10),
            KalinkaButton(
              // The app's primary CTA, filled — the same weight as committing
              // anything else. No count: the filtered total is not known until
              // the request this button sends comes back.
              label: 'Show results',
              size: KalinkaButtonSize.compact,
              onTap: () => widget.onApply(_staged),
            ),
          ],
        ),
      ),
    );
  }
}

/// The card's textual action (Reset). Crimson here, unlike the row of chips
/// on the page behind — inside the card there is nothing tinted for it to
/// compete with, and it is the one destructive control.
class _HoverText extends StatefulWidget {
  final String label;
  final VoidCallback onTap;

  const _HoverText({required this.label, required this.onTap});

  @override
  State<_HoverText> createState() => _HoverTextState();
}

class _HoverTextState extends State<_HoverText> {
  bool _hovering = false;

  void _setHovering(bool value) {
    if (value == _hovering) return;
    setState(() => _hovering = value);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.label,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => _setHovering(true),
        onExit: (_) => _setHovering(false),
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 130),
              curve: Curves.easeOut,
              style: KalinkaFonts.mono(
                fontSize: KalinkaTypography.baseSize + 1,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.4,
                color: _hovering
                    ? KalinkaColors.accentBright
                    : KalinkaColors.accentTint,
              ),
              child: Text(widget.label),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dismisses the card. Its ring lightens under the pointer, the same cue the
/// pills and the title-bar button use.
class _CloseButton extends StatefulWidget {
  final VoidCallback onTap;

  const _CloseButton({required this.onTap});

  @override
  State<_CloseButton> createState() => _CloseButtonState();
}

class _CloseButtonState extends State<_CloseButton> {
  bool _hovering = false;

  void _setHovering(bool value) {
    if (value == _hovering) return;
    setState(() => _hovering = value);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Close filters',
      button: true,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => _setHovering(true),
        onExit: (_) => _setHovering(false),
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 130),
            curve: Curves.easeOut,
            width: 34,
            height: 34,
            margin: const EdgeInsets.only(left: 4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _hovering
                  ? KalinkaColors.surfaceOverlay
                  : Colors.transparent,
              border: Border.all(
                color: _hovering
                    ? KalinkaColors.textMuted
                    : KalinkaColors.borderDefault,
              ),
            ),
            child: const Icon(
              Icons.close_rounded,
              size: 18,
              color: KalinkaColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
