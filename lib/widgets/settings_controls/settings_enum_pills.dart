import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../utils/haptics.dart';

/// Segmented pill group for enum-like settings.
///
/// Active pill: accentFaded bg, accent border, accent text.
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
        return Material(
          color: isActive
              ? KalinkaColors.accentFaded
              : KalinkaColors.surfaceOverlay,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(7),
            side: BorderSide(
              color: isActive
                  ? KalinkaColors.accent
                  : KalinkaColors.borderDefault,
              width: 0.1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              KalinkaHaptics.selectionClick();
              onChanged(option);
            },
            overlayColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.pressed)) {
                return Colors.white.withValues(alpha: 0.08);
              }
              return null;
            }),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Text(
                option,
                style: isActive
                    ? KalinkaTextStyles.filterPillActive
                    : KalinkaTextStyles.filterPillInactive,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
