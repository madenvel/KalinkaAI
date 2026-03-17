import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../utils/haptics.dart';

/// Slider control for bounded numeric ranges.
///
/// Gradient fill from accent to accentTint, value readout, range labels.
class SettingsSlider extends StatefulWidget {
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
  State<SettingsSlider> createState() => _SettingsSliderState();
}

class _SettingsSliderState extends State<SettingsSlider> {
  double _lastHapticPosition = double.negativeInfinity;

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
                widget.label,
                style: KalinkaTextStyles.trayRowSublabel.copyWith(
                  fontSize: KalinkaTypography.baseSize + 2,
                ),
              ),
              Text(
                widget.valueLabel ??
                    widget.value.toStringAsFixed(
                      widget.value == widget.value.roundToDouble() ? 0 : 1,
                    ),
                style: KalinkaTextStyles.trayRowLabel.copyWith(
                  fontSize: KalinkaTypography.baseSize + 1,
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
              inactiveTrackColor: KalinkaColors.surfaceElevated,
              thumbColor: Colors.white,
              overlayColor: KalinkaColors.accent.withValues(alpha: 0.15),
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            ),
            child: Slider(
              value: widget.value.clamp(widget.min, widget.max),
              min: widget.min,
              max: widget.max,
              divisions: widget.divisions,
              onChanged: (value) {
                final tickSize = (widget.max - widget.min) * 0.10;
                if ((value - _lastHapticPosition).abs() >= tickSize) {
                  KalinkaHaptics.selectionClick();
                  _lastHapticPosition = value;
                }
                widget.onChanged(value);
              },
            ),
          ),
          // Range labels
          if (widget.minLabel != null || widget.maxLabel != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.minLabel ?? widget.min.toString(),
                    style: KalinkaTextStyles.sectionHeaderMuted.copyWith(
                      letterSpacing: 0,
                    ),
                  ),
                  Text(
                    widget.maxLabel ?? widget.max.toString(),
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
