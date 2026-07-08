import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Shared framing for the floating search bar — the active composer and the
/// inert dock both sit in one of these.
///
/// Instead of an opaque slab with a rule joining it to the content, a vertical
/// gradient dissolves the scrolling content into the page as it passes behind
/// the bar, and the [child] (the pill) floats on top with a horizontal margin
/// and a soft shadow so it clearly detaches from the content — which stays
/// faintly visible around it.
///
/// The fade is a plain linear-gradient fill (no blur, no `saveLayer`): one
/// gradient rect per frame, a negligible cost.
class FloatingSearchBar extends StatelessWidget {
  /// The floating pill (opaque, rounded, uses [pillShadow]).
  final Widget child;

  /// Apply the bottom safe-area inset. False on phone when something below the
  /// bar owns it (the mini-player); true where the bar is the bottom-most
  /// element (tablet panel, or the phone search composer).
  final bool bottomSafeArea;

  const FloatingSearchBar({
    super.key,
    required this.child,
    this.bottomSafeArea = false,
  });

  /// Lift applied to the floating pill so it reads as detached even when the
  /// content behind it is the same width.
  static const List<BoxShadow> pillShadow = [
    BoxShadow(color: Color(0x66000000), blurRadius: 22, offset: Offset(0, 6)),
  ];

  @override
  Widget build(BuildContext context) {
    return Stack(
      // Let the pill's shadow bleed past the bar bounds so it isn't clipped.
      clipBehavior: Clip.none,
      children: [
        // Gradient scrim — fades content scrolling behind the bar into the
        // page. Ignores pointers so content behind it stays scrollable.
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    KalinkaColors.background.withValues(alpha: 0.0),
                    KalinkaColors.background,
                  ],
                  stops: const [0.0, 0.9],
                ),
              ),
            ),
          ),
        ),
        // The floating pill: inset a little more than the 16px content gutter
        // so the content peeks (and fades) at its sides, and lifted above it.
        SafeArea(
          top: false,
          bottom: bottomSafeArea,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 34, 22, 10),
            child: child,
          ),
        ),
      ],
    );
  }
}
