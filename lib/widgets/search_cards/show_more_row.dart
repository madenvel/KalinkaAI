import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Expandable "Show N more" / "Show fewer" toggle row.
class ShowMoreRow extends StatelessWidget {
  final int remainingCount;
  final bool isExpanded;
  final VoidCallback onTap;

  const ShowMoreRow({
    super.key,
    required this.remainingCount,
    required this.isExpanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: KalinkaColors.textSecondary,
        overlayColor: Colors.white.withValues(alpha: 0.06),
        padding: const EdgeInsets.symmetric(vertical: 10),
        minimumSize: const Size(double.infinity, 0),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            isExpanded ? 'Show fewer' : 'Show $remainingCount more',
            style: KalinkaTextStyles.showMoreLabel,
          ),
          const SizedBox(width: 4),
          AnimatedRotation(
            turns: isExpanded ? 0.5 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: const Icon(
              Icons.expand_more,
              size: 16,
              color: KalinkaColors.accent,
            ),
          ),
        ],
      ),
    );
  }
}
