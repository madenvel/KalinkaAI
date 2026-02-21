import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Slider control for bounded numeric ranges.
///
/// Gradient fill from accent to accentTint, value readout, range labels.
class SettingsSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String? minLabel;
  final String? maxLabel;
  final String? valueLabel;
  final ValueChanged<double> onChanged;

  const SettingsSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    this.divisions,
    this.minLabel,
    this.maxLabel,
    this.valueLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header row: label left, value readout right
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                label,
                style: KalinkaTextStyles.trayRowSublabel.copyWith(fontSize: 12),
              ),
              Text(
                valueLabel ??
                    value.toStringAsFixed(
                      value == value.roundToDouble() ? 0 : 1,
                    ),
                style: KalinkaTextStyles.trayRowLabel.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: KalinkaColors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          // Slider
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: KalinkaColors.accent,
              inactiveTrackColor: KalinkaColors.pillSurface,
              thumbColor: Colors.white,
              overlayColor: KalinkaColors.accent.withValues(alpha: 0.15),
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
          // Range labels
          if (minLabel != null || maxLabel != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    minLabel ?? min.toString(),
                    style: KalinkaTextStyles.sectionHeaderMuted.copyWith(
                      letterSpacing: 0,
                    ),
                  ),
                  Text(
                    maxLabel ?? max.toString(),
                    style: KalinkaTextStyles.sectionHeaderMuted.copyWith(
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
