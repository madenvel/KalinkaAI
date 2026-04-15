import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Expand/collapse chevron button with 44px tap target and 28px visual.
/// Used in album and playlist search result rows.
class ExpandChevronButton extends StatelessWidget {
  final bool isExpanded;
  final VoidCallback onTap;

  const ExpandChevronButton({
    super.key,
    required this.isExpanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Center(
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: KalinkaColors.borderDefault),
            ),
            child: AnimatedRotation(
              turns: isExpanded ? 0.5 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: const Icon(
                Icons.expand_more,
                size: 14,
                color: KalinkaColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
