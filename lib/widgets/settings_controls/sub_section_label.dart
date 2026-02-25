import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Uppercase section divider label within cards or collapsible bodies.
class SubSectionLabel extends StatelessWidget {
  final String label;

  const SubSectionLabel({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        border: Border(
          top: BorderSide(color: KalinkaColors.borderSubtle),
          bottom: BorderSide(color: KalinkaColors.borderSubtle),
        ),
      ),
      child: Text(
        label.toUpperCase(),
        style: KalinkaTextStyles.sectionHeaderMuted.copyWith(
          fontSize: 9,
          letterSpacing: 1.6,
        ),
      ),
    );
  }
}
