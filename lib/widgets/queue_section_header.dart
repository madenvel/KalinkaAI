import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Reusable section header for queue sections ("UP NEXT" / "PREVIOUSLY PLAYED").
class QueueSectionHeader extends StatelessWidget {
  final String label;
  final int? trackCount;
  final bool showShuffleBadge;
  final Widget? trailing;

  const QueueSectionHeader({
    super.key,
    required this.label,
    this.trackCount,
    this.showShuffleBadge = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Row(
        children: [
          // Left cluster
          Expanded(
            child: Row(
              children: [
                Text(label, style: KalinkaTextStyles.sectionHeader),
                if (trackCount != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    '($trackCount)',
                    style: KalinkaTextStyles.trackCountBadge,
                  ),
                ],
                if (showShuffleBadge) ...[
                  const SizedBox(width: 8),
                  AnimatedOpacity(
                    opacity: 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.shuffle,
                          size: 12,
                          color: KalinkaColors.gold,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '\u00b7 Shuffled',
                          style: KalinkaTextStyles.shuffleBadgeText,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Right side
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
