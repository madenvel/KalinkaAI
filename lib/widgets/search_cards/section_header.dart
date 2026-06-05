import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Section header for search result chunks.
/// Shows uppercase label left and count right, with a divider above.
/// When [onOnlyTap] is provided, shows "Only {label} >" link on the right.
/// When [onSelectAll] is provided, shows a "Select all" link on the right that
/// selects every item in the section (used to act on the whole group at once).
class SectionHeader extends StatelessWidget {
  final String label;
  final int count;
  final bool showDivider;
  final VoidCallback? onOnlyTap;
  final VoidCallback? onSelectAll;

  const SectionHeader({
    super.key,
    required this.label,
    required this.count,
    this.showDivider = true,
    this.onOnlyTap,
    this.onSelectAll,
  });

  @override
  Widget build(BuildContext context) {
    // Inline the count next to the label whenever the right slot is taken by
    // an action link, so the count isn't lost.
    final inlineCount = onOnlyTap != null || onSelectAll != null;
    return Column(
      children: [
        if (showDivider)
          const Divider(
            color: KalinkaColors.borderSubtle,
            thickness: 1,
            height: 24,
          ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                inlineCount
                    ? '${label.toUpperCase()} ($count)'
                    : label.toUpperCase(),
                style: KalinkaTextStyles.sectionLabel,
              ),
              if (onOnlyTap != null)
                GestureDetector(
                  onTap: onOnlyTap,
                  behavior: HitTestBehavior.opaque,
                  child: Text(
                    'Only $label \u203A',
                    style: KalinkaTextStyles.trackRowSubtitle.copyWith(
                      color: KalinkaColors.accent,
                    ),
                  ),
                )
              else if (onSelectAll != null)
                GestureDetector(
                  onTap: onSelectAll,
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.checklist_rounded,
                        size: 16,
                        color: KalinkaColors.accent,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Select all',
                        style: KalinkaTextStyles.trackRowSubtitle.copyWith(
                          color: KalinkaColors.accent,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Text('$count', style: KalinkaTextStyles.sectionLabel),
            ],
          ),
        ),
      ],
    );
  }
}
