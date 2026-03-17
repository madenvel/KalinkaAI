import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../utils/haptics.dart';

/// Segmented pill group for enum-like settings.
///
/// Active pill: accent bg 0.15, accent border 0.35, accent text.
class SettingsEnumPills extends StatelessWidget {
  final List<String> options;
  final String selected;
  final ValueChanged<String> onChanged;

  const SettingsEnumPills({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 5,
      runSpacing: 5,
      children: options.map((option) {
        final isActive = option == selected;
        return ChoiceChip(
          label: Text(option),
          selected: isActive,
          onSelected: (_) {
            KalinkaHaptics.selectionClick();
            onChanged(option);
          },
          selectedColor: KalinkaColors.surfaceElevated,
          backgroundColor: KalinkaColors.surfaceOverlay,
          side: BorderSide(
            color: isActive ? KalinkaColors.accent : KalinkaColors.borderDefault,
          ),
          labelStyle: KalinkaTextStyles.tagPill.copyWith(
            color: isActive ? KalinkaColors.accent : KalinkaColors.textSecondary,
            height: 1.3,
          ),
          showCheckmark: false,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          labelPadding: const EdgeInsets.symmetric(horizontal: 4),
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        );
      }).toList(),
    );
  }
}
