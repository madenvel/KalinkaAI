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
        return GestureDetector(
          onTap: () {
            KalinkaHaptics.selectionClick();
            onChanged(option);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isActive
                  ? KalinkaColors.accent.withValues(alpha: 0.15)
                  : KalinkaColors.surfaceElevated,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(
                color: isActive
                    ? KalinkaColors.accent.withValues(alpha: 0.35)
                    : KalinkaColors.borderDefault,
              ),
            ),
            child: Text(
              option,
              style: KalinkaTextStyles.tagPill.copyWith(
                color: isActive
                    ? KalinkaColors.accentTint
                    : KalinkaColors.textSecondary,
                height: 1.3,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
