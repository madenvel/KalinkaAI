import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// A single setting row with label, optional sublabel, staged/non-default pills,
/// and a control widget on the right.
///
/// Use [isVertical] for controls that need full width (enum pills, list editors).
class SettingsRow extends StatelessWidget {
  final String label;
  final String? sublabel;
  final bool isStaged;
  final bool differsFromDefault;
  final Widget control;
  final bool isVertical;

  const SettingsRow({
    super.key,
    required this.label,
    this.sublabel,
    this.isStaged = false,
    this.differsFromDefault = false,
    required this.control,
    this.isVertical = false,
  });

  @override
  Widget build(BuildContext context) {
    final showAmber = isStaged || differsFromDefault;
    final pillText = isStaged ? 'Staged' : 'Differs from Default';

    return Container(
      decoration: showAmber
          ? BoxDecoration(color: KalinkaColors.statusPending.withValues(alpha: 0.04))
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Amber left bar
          if (showAmber)
            Container(
              width: 2,
              constraints: const BoxConstraints(minHeight: 44),
              decoration: BoxDecoration(
                color: KalinkaColors.statusPending,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: isVertical
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoBlock(showAmber, pillText),
                        const SizedBox(height: 10),
                        control,
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(child: _buildInfoBlock(showAmber, pillText)),
                        const SizedBox(width: 12),
                        control,
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBlock(bool showAmber, String pillText) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: KalinkaTextStyles.trayRowLabel.copyWith(
            fontSize: 13,
            letterSpacing: -0.01,
          ),
        ),
        if (sublabel != null) ...[
          const SizedBox(height: 2),
          Text(
            sublabel!,
            style: KalinkaTextStyles.trayRowSublabel.copyWith(
              fontSize: 10,
              height: 1.45,
            ),
          ),
        ],
        if (showAmber) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: KalinkaColors.statusPending.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: KalinkaColors.statusPending.withValues(alpha: 0.2),
              ),
            ),
            child: Text(
              pillText,
              style: KalinkaTextStyles.tagPill.copyWith(
                color: KalinkaColors.statusPending,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
