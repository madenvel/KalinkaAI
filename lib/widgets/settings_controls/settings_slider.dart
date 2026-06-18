import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../utils/haptics.dart';

/// Slider control for bounded numeric ranges.
///
/// Accent track fill, a value readout that floats above the thumb, and range
/// labels beneath.
///
/// The readout updates live while dragging, but [onChanged] only fires on
/// release — so staging (and the "apply" banner) reflects committed values,
/// not every intermediate drag tick.
class SettingsSlider extends StatefulWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String? minLabel;
  final String? maxLabel;

  /// Formats a value for the live readout. Falls back to a plain numeric
  /// string when omitted.
  final String Function(num)? formatValue;

  /// Fired on release (drag end / tap), not on every intermediate value.
  final ValueChanged<double> onChanged;

  /// Tightens padding and gaps for dense contexts (e.g. the expert/about:config
  /// rows, which already supply their own label and outer padding).
  final bool dense;

  const SettingsSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    this.divisions,
    this.minLabel,
    this.maxLabel,
    this.formatValue,
    required this.onChanged,
    this.dense = false,
  });

  @override
  State<SettingsSlider> createState() => _SettingsSliderState();
}

class _SettingsSliderState extends State<SettingsSlider> {
  // Track inset the Material slider reserves on each side for the overlay —
  // matches RoundSliderOverlayShape(14) below, so the floating readout lines up
  // with the thumb across the full range.
  static const double _trackInset = 14.0;

  double _lastHapticPosition = double.negativeInfinity;

  /// Live value while a drag is in progress; null when settled (the committed
  /// [widget.value] is shown). Kept local so dragging doesn't stage changes.
  double? _dragValue;

  String _format(num n) =>
      widget.formatValue?.call(n) ??
      n.toStringAsFixed(n == n.roundToDouble() ? 0 : 1);

  @override
  Widget build(BuildContext context) {
    final dense = widget.dense;
    final hasLabel = widget.label.isNotEmpty;
    final liveValue = (_dragValue ?? widget.value)
        .clamp(widget.min, widget.max)
        .toDouble();
    final range = widget.max - widget.min;
    final fraction = range > 0 ? (liveValue - widget.min) / range : 0.0;

    final valueText = Text(
      _format(liveValue),
      maxLines: 1,
      softWrap: false,
      style: KalinkaTextStyles.trayRowLabel.copyWith(
        fontSize: KalinkaTypography.baseSize + 1,
        fontWeight: FontWeight.w500,
        color: KalinkaColors.accent,
      ),
    );

    return Padding(
      padding: dense
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasLabel) ...[
            Text(
              widget.label,
              style: KalinkaTextStyles.trayRowSublabel.copyWith(
                fontSize: KalinkaTypography.baseSize + 2,
              ),
            ),
            SizedBox(height: dense ? 2 : 6),
          ],
          // Value readout floating above the thumb.
          SizedBox(
            height: 18,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final trackWidth = constraints.maxWidth - 2 * _trackInset;
                final thumbX = _trackInset + fraction * trackWidth;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: thumbX,
                      bottom: 0,
                      // Center the label horizontally on the thumb.
                      child: FractionalTranslation(
                        translation: const Offset(-0.5, 0),
                        child: valueText,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          // Slider — constrained to a tight height in dense mode so the
          // hidden Material tap target doesn't inflate the row.
          SizedBox(
            height: dense ? 28 : null,
            child: SliderTheme(
              data: SliderThemeData(
                activeTrackColor: KalinkaColors.accent,
                inactiveTrackColor: KalinkaColors.surfaceElevated,
                thumbColor: Colors.white,
                overlayColor: KalinkaColors.accent.withValues(alpha: 0.15),
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              ),
              child: Slider(
                value: liveValue,
                min: widget.min,
                max: widget.max,
                divisions: widget.divisions,
                onChanged: (value) {
                  final tickSize = (widget.max - widget.min) * 0.10;
                  if ((value - _lastHapticPosition).abs() >= tickSize) {
                    KalinkaHaptics.selectionClick();
                    _lastHapticPosition = value;
                  }
                  setState(() => _dragValue = value);
                },
                onChangeEnd: (value) {
                  setState(() => _dragValue = null);
                  widget.onChanged(value);
                },
              ),
            ),
          ),
          // Range labels.
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
