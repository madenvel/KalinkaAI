import 'dart:math';

import 'package:flutter/material.dart';

/// Marks a panel as the horizontal anchor for modal bottom sheets launched
/// from inside it.
///
/// [showModalBottomSheet] positions sheets against the whole window, so on
/// the tablet layout a sheet opened from the settings panel would pop up in
/// the window centre. Sheet helpers capture [elementOf] when opening and
/// inset a window-wide sheet with [paddingFor] on every build, so the sheet
/// tracks the panel across live resizes. With no anchor in scope (phone
/// layout) the padding is zero and the default placement is kept.
class SheetAnchor extends InheritedWidget {
  const SheetAnchor({super.key, required super.child});

  /// The nearest enclosing anchor. Must be captured from the launching
  /// context — the sheet route itself builds outside the anchor's subtree.
  static InheritedElement? elementOf(BuildContext context) =>
      context.getElementForInheritedWidgetOfExactType<SheetAnchor>();

  /// Horizontal insets that place a window-wide sheet over [anchor]. Zero
  /// when there is no anchor or it is gone (e.g. the layout re-homed across
  /// the tablet breakpoint mid-resize), letting the sheet fall back to full
  /// width.
  static EdgeInsets paddingFor(InheritedElement? anchor, double windowWidth) {
    if (anchor == null || !anchor.mounted) return EdgeInsets.zero;
    var active = true;
    // findRenderObject asserts on deactivated elements in debug builds
    // (debugIsActive is debug-only: it always returns false in release).
    assert(() {
      active = anchor.debugIsActive;
      return true;
    }());
    if (!active) return EdgeInsets.zero;
    final box = anchor.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) {
      return EdgeInsets.zero;
    }
    final left = box.localToGlobal(Offset.zero).dx;
    final right = windowWidth - left - box.size.width;
    return EdgeInsets.only(left: max(0, left), right: max(0, right));
  }

  @override
  bool updateShouldNotify(SheetAnchor oldWidget) => false;
}
