import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/haptics.dart';

/// A textual action: mono caps, no fill, its colour lifting under the pointer.
///
/// The shape the app uses where an action belongs to a heading or a row rather
/// than standing on its own — RESET, RESET ALL, VIEW ALL. Its palette is the
/// caller's, because what it must not compete with differs by surface.
class HoverTextAction extends StatefulWidget {
  final String label;
  final VoidCallback onTap;

  /// What the button announces, where the label alone would not read as an
  /// instruction ('Reset all filters' for RESET ALL).
  final String? semanticsLabel;

  final Color color;
  final Color hoverColor;
  final double fontSize;
  final EdgeInsetsGeometry padding;

  const HoverTextAction({
    super.key,
    required this.label,
    required this.onTap,
    required this.color,
    required this.hoverColor,
    this.semanticsLabel,
    this.fontSize = KalinkaTypography.baseSize,
    this.padding = EdgeInsets.zero,
  });

  @override
  State<HoverTextAction> createState() => _HoverTextActionState();
}

class _HoverTextActionState extends State<HoverTextAction> {
  bool _hovering = false;

  void _setHovering(bool value) {
    if (value == _hovering) return;
    setState(() => _hovering = value);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.semanticsLabel ?? widget.label,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => _setHovering(true),
        onExit: (_) => _setHovering(false),
        child: GestureDetector(
          onTap: () {
            KalinkaHaptics.selectionClick();
            widget.onTap();
          },
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: widget.padding,
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 130),
              curve: Curves.easeOut,
              style: KalinkaFonts.mono(
                fontSize: widget.fontSize,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.4,
                color: _hovering ? widget.hoverColor : widget.color,
              ),
              child: Text(widget.label),
            ),
          ),
        ),
      ),
    );
  }
}
