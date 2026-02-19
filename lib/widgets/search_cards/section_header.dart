import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Section header for search result chunks.
/// Shows uppercase label left and count right, with a divider above.
class SectionHeader extends StatelessWidget {
  final String label;
  final int count;
  final bool showDivider;

  const SectionHeader({
    super.key,
    required this.label,
    required this.count,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (showDivider)
          const Divider(
            color: KalinkaColors.borderDefault,
            thickness: 1,
            height: 24,
          ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label.toUpperCase(), style: KalinkaTextStyles.sectionLabel),
              Text('$count', style: KalinkaTextStyles.sectionLabel),
            ],
          ),
        ),
      ],
    );
  }
}
