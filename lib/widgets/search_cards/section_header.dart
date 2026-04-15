import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Section header for search result chunks.
/// Shows uppercase label left and count right, with a divider above.
/// When [onOnlyTap] is provided, shows "Only {label} >" link on the right.
class SectionHeader extends StatelessWidget {
  final String label;
  final int count;
  final bool showDivider;
  final VoidCallback? onOnlyTap;

  const SectionHeader({
    super.key,
    required this.label,
    required this.count,
    this.showDivider = true,
    this.onOnlyTap,
  });

  @override
  Widget build(BuildContext context) {
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
                onOnlyTap != null
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
              else
                Text('$count', style: KalinkaTextStyles.sectionLabel),
            ],
          ),
        ),
      ],
    );
  }
}
