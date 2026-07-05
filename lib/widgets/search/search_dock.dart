import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../utils/haptics.dart';

/// Inert search pill docked at the bottom of the main screen, directly above
/// the miniplayer. It is a tap target only — no text field, no keyboard, no
/// queries fire from here. Tapping opens the full-screen search session.
class SearchDock extends StatelessWidget {
  final VoidCallback onTap;

  /// Apply bottom safe-area inset. False on phone (the miniplayer below owns
  /// the inset); true on tablet, where the dock is the bottom-most element.
  final bool bottomSafeArea;

  const SearchDock({
    super.key,
    required this.onTap,
    this.bottomSafeArea = false,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: KalinkaColors.surfaceBase,
        border: Border(
          top: BorderSide(color: KalinkaColors.borderSubtle, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        bottom: bottomSafeArea,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Semantics(
            label: 'Search music',
            hint: 'Opens the search screen',
            button: true,
            child: GestureDetector(
              onTap: () {
                KalinkaHaptics.lightImpact();
                onTap();
              },
              behavior: HitTestBehavior.opaque,
              child: Container(
                height: 46,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: KalinkaColors.surfaceInput,
                  borderRadius: BorderRadius.circular(23),
                  border: Border.all(
                    color: KalinkaColors.borderDefault,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.auto_awesome,
                      size: 16,
                      color: KalinkaColors.gold,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Ask for music…',
                        style: KalinkaTextStyles.searchPlaceholder,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: KalinkaColors.surfaceElevated,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: KalinkaColors.borderDefault,
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.arrow_upward_rounded,
                        size: 16,
                        color: KalinkaColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
